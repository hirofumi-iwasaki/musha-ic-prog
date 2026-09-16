// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/controllers/programmer_controller.dart';
import '../../core/models/binary_image.dart';
import '../../core/models/device_catalog.dart';
import '../../core/models/device_profile.dart';
import '../../core/models/operation.dart';
import '../../core/models/programmer.dart';
import '../widgets/binary_viewer.dart';

class ProgrammerScreen extends StatefulWidget {
  const ProgrammerScreen({super.key, required this.controller});
  final ProgrammerController controller;

  @override
  State<ProgrammerScreen> createState() => _ProgrammerScreenState();
}

class _ProgrammerScreenState extends State<ProgrammerScreen> {
  ViewerImage? _inputView;
  ViewerImage? _readoutView;
  String? _inputSnapshotId;
  String? _readoutSnapshotId;
  bool _programDialogOpen = false;
  bool _isLoadingInput = false;
  final GlobalKey _inputDropRegionKey = GlobalKey();
  static const MethodChannel _dropChannel = MethodChannel(
    'mushagaeshi/programmer_files',
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refreshSnapshots);
    _dropChannel.setMethodCallHandler(_onNativeDrop);
    _refreshSnapshots();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshSnapshots);
    _dropChannel.setMethodCallHandler(null);
    super.dispose();
  }

  void _refreshSnapshots() {
    _inputView = _cache(
      widget.controller.inputImage,
      _inputSnapshotId,
      _inputView,
      (id) => _inputSnapshotId = id,
    );
    _readoutView = _cache(
      widget.controller.readoutImage,
      _readoutSnapshotId,
      _readoutView,
      (id) => _readoutSnapshotId = id,
    );
    if (widget.controller.needsProgramConfirmation && !_programDialogOpen) {
      _programDialogOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirmProgram());
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmProgram() async {
    if (!mounted) return;
    final c = widget.controller;
    final input = c.inputImage;
    final profile = c.selectedProfile;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_isSimulation(c) ? 'Program simulated IC?' : 'Program IC?'),
        content: Text(
          '${_isSimulation(c) ? 'This simulation will' : 'This operation will'} write the immutable snapshot ${input?.label ?? '—'} (${input?.length ?? 0} bytes), then read it back and verify every byte.\n\nTarget alias: ${_targetLabel(c, profile)}\nCapacity: ${profile?.capacityBytes ?? '—'} bytes\nSHA-1: ${input?.sha1 ?? '—'}${_isSimulation(c) ? '\n\nNo physical hardware is controlled.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_isSimulation(c) ? 'Program simulation' : 'Program'),
          ),
        ],
      ),
    );
    _programDialogOpen = false;
    if (!mounted || !c.needsProgramConfirmation) return;
    if (confirmed == true) {
      await c.confirmProgram();
    } else {
      c.cancelProgramConfirmation();
    }
  }

  ViewerImage? _cache(
    BinaryImage? image,
    String? cachedId,
    ViewerImage? cached,
    void Function(String?) setId,
  ) {
    if (image == null) {
      setId(null);
      return null;
    }
    if (cachedId == image.snapshotId && cached != null) return cached;
    setId(image.snapshotId);
    // BinaryImage returns a defensive copy. Hold this one rendering copy until
    // the immutable snapshot generation changes.
    return ViewerImage(
      bytes: image.bytes,
      name: image.label,
      origin: _originLabel(image.origin),
      sha1: image.sha1,
      capturedAt: image.createdAt,
      stale: false,
    );
  }

  String _originLabel(BinaryImageOrigin origin) => switch (origin) {
    BinaryImageOrigin.file => 'Input BIN',
    BinaryImageOrigin.readout => 'IC readout snapshot',
    BinaryImageOrigin.postWriteVerification =>
      'Post-write verification snapshot',
  };

  Future<void> _openBin() async {
    final file = await openFile();
    if (file != null) {
      await _loadInput(
        label: file.name,
        length: file.length,
        readBytes: file.readAsBytes,
      );
    }
  }

  Future<void> _onNativeDrop(MethodCall call) async {
    if (call.method == 'fileDropError') {
      final arguments = call.arguments;
      _showFileError(
        arguments is Map && arguments['message'] is String
            ? arguments['message'] as String
            : 'The dropped file could not be opened.',
      );
      return;
    }
    if (call.method != 'fileDropped') return;
    final arguments = call.arguments;
    final token = arguments is Map ? arguments['scopeToken'] as String? : null;
    try {
      if (!mounted ||
          arguments is! Map ||
          arguments['path'] is! String ||
          arguments['x'] is! num ||
          arguments['y'] is! num) {
        _showFileError('The dropped file could not be opened.');
        return;
      }
      if (!_isInputDropAt(
        Offset(
          (arguments['x'] as num).toDouble(),
          (arguments['y'] as num).toDouble(),
        ),
      )) {
        _showFileError('Drop a file on the Input BIN panel.');
        return;
      }
      await _loadInputPath(arguments['path'] as String);
    } finally {
      if (token != null) {
        await _dropChannel.invokeMethod<void>('releaseDropScope', token);
      }
    }
  }

  bool _isInputDropAt(Offset point) {
    final box =
        _inputDropRegionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(point));
  }

  Future<void> _loadInputPath(String path, {String? label}) async {
    try {
      final entityType = await FileSystemEntity.type(path, followLinks: true);
      if (entityType != FileSystemEntityType.file) {
        _showFileError('The dropped item is not a readable file.');
        return;
      }
      final file = File(path);
      await _loadInput(
        label: label ?? path.split(Platform.pathSeparator).last,
        length: file.length,
        readBytes: file.readAsBytes,
      );
    } catch (_) {
      _showFileError('The BIN file could not be opened.');
    }
  }

  Future<void> _loadInput({
    required String label,
    required Future<int> Function() length,
    required Future<List<int>> Function() readBytes,
  }) async {
    if (!mounted) return;
    if (_isLoadingInput) {
      _showFileError('Another input file is still loading.');
      return;
    }
    if (widget.controller.isBusy ||
        widget.controller.needsProgramConfirmation) {
      _showFileError('Wait for the current operation before opening a file.');
      return;
    }
    _isLoadingInput = true;
    try {
      final fileLength = await length();
      if (fileLength > ProgrammerController.maxInputBytes) {
        _showFileError('BIN files larger than 64 MiB are not supported yet.');
        return;
      }
      final bytes = await readBytes();
      if (!mounted ||
          widget.controller.isBusy ||
          widget.controller.needsProgramConfirmation) {
        return;
      }
      widget.controller.openBinary(bytes, label: label);
    } catch (_) {
      _showFileError('The BIN file could not be opened.');
    } finally {
      _isLoadingInput = false;
    }
  }

  void _showFileError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isSimulation(ProgrammerController c) => c.usingSimulation;

  String _targetLabel(ProgrammerController c, DeviceProfile? profile) =>
      c.selectedDevice?.label ?? profile?.displayName ?? 'the selected device';

  Future<void> _startOperation(
    ProgrammerController c,
    String operation,
    Future<void> Function() start,
  ) async {
    if (_isSimulation(c)) {
      await start();
      return;
    }
    var acknowledged = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Confirm physical $operation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Target alias: ${_targetLabel(c, c.selectedProfile)}'),
              Text(
                'Capacity: ${c.selectedProfile?.capacityBytes ?? '—'} bytes',
              ),
              const SizedBox(height: 12),
              const Text(
                'Confirm the IC alias, orientation, socket placement, and any required adapter before continuing. This catalog entry is upstream-defined and is not proof of physical support.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acknowledged,
                onChanged: (value) =>
                    setDialogState(() => acknowledged = value ?? false),
                title: const Text('I have checked the IC and setup.'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: acknowledged
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text('Start $operation'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) await start();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _setupCard(c),
              const SizedBox(height: 12),
              Expanded(
                child: BinaryViewer(
                  input: _inputView,
                  readout: _readoutView,
                  inputDropRegionKey: _inputDropRegionKey,
                  inputDropEnabled: !c.isBusy && !c.needsProgramConfirmation,
                  onInputDropRequested: _openBin,
                ),
              ),
              const SizedBox(height: 12),
              _operations(c),
              const SizedBox(height: 12),
              _bottomStatusBar(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomStatusBar(ProgrammerController c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            _connectionIcon(c.connectionStatus),
            color: _connectionColor(c.connectionStatus),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connectionLabel(c),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_phaseLabel(c.phase)}: ${c.message ?? 'No operation in progress.'}',
                ),
                if (c.isBusy)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      c.usingSimulation
                          ? 'Operation in progress — do not touch the programmer, IC or USB cable. Simulation only.'
                          : 'Operation in progress — do not touch the programmer, IC or USB cable.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: c.isBusy || c.needsProgramConfirmation
                ? null
                : c.connectProgrammer,
            child: Text(
              c.usingSimulation ? 'Refresh simulation' : 'Refresh TL866CS',
            ),
          ),
        ],
      ),
    ),
  );

  IconData _connectionIcon(ConnectionStatus status) => switch (status) {
    ConnectionStatus.ready => Icons.usb,
    ConnectionStatus.busy => Icons.usb,
    ConnectionStatus.unknown => Icons.usb_rounded,
    ConnectionStatus.disconnected => Icons.usb_off,
  };

  Color? _connectionColor(ConnectionStatus status) => switch (status) {
    ConnectionStatus.ready => Colors.green,
    ConnectionStatus.busy => Colors.amber.shade800,
    ConnectionStatus.unknown => Colors.amber.shade800,
    ConnectionStatus.disconnected => null,
  };

  String _connectionLabel(
    ProgrammerController c,
  ) => switch (c.connectionStatus) {
    ConnectionStatus.ready =>
      c.usingSimulation
          ? 'Simulation connected · ${c.connection?.model ?? 'mock programmer'} · ${c.connection?.firmware ?? 'firmware unknown'}'
          : c.backendStatus,
    ConnectionStatus.busy =>
      c.usingSimulation
          ? 'Simulation connected · operation in progress'
          : 'TL866CS connected · operation in progress',
    ConnectionStatus.unknown =>
      c.usingSimulation
          ? 'Checking simulation connection…'
          : 'Checking TL866CS connection…',
    ConnectionStatus.disconnected =>
      c.usingSimulation ? 'Simulation disconnected' : c.backendStatus,
  };

  String _phaseLabel(OperationPhase phase) => switch (phase) {
    OperationPhase.idle => 'Idle',
    OperationPhase.awaitingConfirmation => 'Awaiting confirmation',
    OperationPhase.preparing => 'Preparing',
    OperationPhase.running => 'Running',
    OperationPhase.reading => 'Reading',
    OperationPhase.blankChecking => 'Blank checking',
    OperationPhase.programming => 'Programming',
    OperationPhase.readingBack => 'Reading back',
    OperationPhase.comparing => 'Comparing',
    OperationPhase.succeeded => 'Completed',
    OperationPhase.failed => 'Failed',
    OperationPhase.cancelled => 'Cancelled',
    OperationPhase.recoveryRequired => 'Recovery required',
  };

  Widget _setupCard(ProgrammerController c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<ProgrammerOption>(
              initialValue: c.selectedProgrammer,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Programmer'),
              items: c.availableProgrammers
                  .map(
                    (programmer) => DropdownMenuItem(
                      value: programmer,
                      enabled: programmer.available,
                      child: Text(
                        programmer.available
                            ? programmer.label
                            : '${programmer.label} (future)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: c.isBusy || c.needsProgramConfirmation
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      c.selectProgrammer(value);
                    },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                'vendor:${c.selectedProgrammer.id}:${c.selectedVendor}',
              ),
              initialValue: c.selectedVendor,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Vendor'),
              hint: const Text('Choose a vendor'),
              items: c.availableVendors
                  .map(
                    (vendor) => DropdownMenuItem(
                      value: vendor,
                      child: Text(vendor, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: c.isBusy || c.needsProgramConfirmation
                  ? null
                  : (value) {
                      c.selectVendor(value);
                    },
            ),
          ),
          SizedBox(width: 300, child: _catalogDeviceSelector(c)),
          if (c.selectedDevice != null && !c.usingSimulation)
            Text(
              _hardwareEvaluationLabel(c.selectedProfile),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          OutlinedButton.icon(
            onPressed: c.isBusy || c.needsProgramConfirmation ? null : _openBin,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open BIN'),
          ),
          if (c.selectedProfile != null)
            Text(
              'Target: ${c.selectedProfile!.displayName} · ${c.selectedProfile!.capacityBytes ?? '—'} bytes',
            ),
          if (c.blockedReason != null)
            Text(
              c.blockedReason!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );

  String _hardwareEvaluationLabel(DeviceProfile? profile) {
    if (profile?.isTl866Executable != true) {
      return 'Unsupported for authorized hardware evaluation';
    }
    if (profile!.verified) return 'Hardware profile validated';
    return 'Hardware evaluation · not yet validated on this IC';
  }

  Widget _catalogDeviceSelector(
    ProgrammerController c,
  ) => Autocomplete<CatalogDevice>(
    key: ValueKey('${c.selectedVendor}:${c.selectedDevice?.id}'),
    displayStringForOption: (device) => device.label,
    initialValue: TextEditingValue(text: c.selectedDevice?.label ?? ''),
    optionsBuilder: (value) {
      if (c.selectedVendor == null) {
        return const Iterable<CatalogDevice>.empty();
      }
      return c.findCatalogDevices(query: value.text, limit: null);
    },
    onSelected: c.selectDevice,
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled:
            !c.isBusy &&
            !c.needsProgramConfirmation &&
            c.selectedVendor != null,
        decoration: InputDecoration(
          labelText: 'Device',
          hintText: c.selectedVendor == null
              ? 'Choose a vendor first'
              : 'Search all ${c.selectedVendorDeviceCount} device records',
          suffixIcon: IconButton(
            tooltip: 'Show all devices for selected vendor',
            onPressed: c.selectedVendor == null
                ? null
                : () => focusNode.requestFocus(),
            icon: const Icon(Icons.arrow_drop_down),
          ),
        ),
      );
    },
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final device = options.elementAt(index);
              return ListTile(
                dense: true,
                title: Text(device.label, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${device.kindLabel} · ${device.pins ?? 'pins unspecified'}',
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelected(device),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _operations(ProgrammerController c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: c.canRead
                    ? () => _startOperation(c, 'read', c.read)
                    : null,
                child: const Text('Read'),
              ),
              OutlinedButton(
                onPressed: c.canBlankCheck
                    ? () => _startOperation(c, 'blank check', c.blankCheck)
                    : null,
                child: const Text('Blank check'),
              ),
              FilledButton.tonal(
                onPressed: c.canProgram
                    ? () => _startOperation(
                        c,
                        'program',
                        () async => c.requestProgram(),
                      )
                    : null,
                child: const Text('Program'),
              ),
              OutlinedButton(
                onPressed: c.canVerify
                    ? () => _startOperation(c, 'verify', c.verify)
                    : null,
                child: const Text('Verify'),
              ),
              if (c.isBusy)
                TextButton(
                  onPressed: c.cancelActiveOperation,
                  child: const Text('Cancel'),
                ),
            ],
          ),
          if (c.progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(value: c.progress),
            ),
          if (c.lastResult?.mismatch != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'First mismatch: 0x${c.lastResult!.mismatch!.address.toRadixString(16).toUpperCase()} · ${c.lastResult!.mismatchCount} difference(s)',
              ),
            ),
        ],
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant ProgrammerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refreshSnapshots);
      widget.controller.addListener(_refreshSnapshots);
      _refreshSnapshots();
    }
  }
}
