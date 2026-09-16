// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refreshSnapshots);
    _refreshSnapshots();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshSnapshots);
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
        title: const Text('Program simulated IC?'),
        content: Text(
          'This simulation will write the immutable snapshot ${input?.label ?? '—'} (${input?.length ?? 0} bytes) to ${profile?.displayName ?? 'the selected device'}, then read it back and verify every byte.\n\nSHA-1: ${input?.sha1 ?? '—'}\n\nNo physical hardware is controlled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Program simulation'),
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
    const typeGroup = XTypeGroup(label: 'Binary files', extensions: ['bin']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) {
      return;
    }
    try {
      final length = await file.length();
      if (!mounted ||
          widget.controller.isBusy ||
          widget.controller.needsProgramConfirmation) {
        return;
      }
      if (length > ProgrammerController.maxInputBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'BIN files larger than 64 MiB are not supported yet.',
            ),
          ),
        );
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted ||
          widget.controller.isBusy ||
          widget.controller.needsProgramConfirmation) {
        return;
      }
      widget.controller.openBinary(bytes, label: file.name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The BIN file could not be opened.')),
        );
      }
    }
  }

  void _loadDemoBin() {
    final c = widget.controller;
    // The demo is its own mock configuration, never a claim about a selected
    // minipro catalog entry or physical IC.
    c.selectVendor(null);
    c.selectProfile(mockEpromProfile);
    final size = mockEpromProfile.capacityBytes!;
    // A deterministic full-capacity fixture keeps the mock program path usable
    // without a local file and never makes an undersized program input.
    final bytes = List<int>.generate(
      size,
      (index) => (index * 37 + 0x41) & 0xff,
    );
    widget.controller.openBinary(bytes, label: 'demo-${size ~/ 1024}KiB.bin');
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
                child: BinaryViewer(input: _inputView, readout: _readoutView),
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
          const Chip(
            label: Text('SIMULATION MODE'),
            visualDensity: VisualDensity.compact,
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
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Operation in progress — do not touch the programmer, IC or USB cable. Simulation only.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: c.isBusy || c.needsProgramConfirmation
                ? null
                : c.connectMock,
            child: const Text('Connect simulation'),
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
      'Simulation connected · ${c.connection?.model ?? 'mock programmer'} · ${c.connection?.firmware ?? 'firmware unknown'}',
    ConnectionStatus.busy => 'Simulation connected · operation in progress',
    ConnectionStatus.unknown => 'Checking simulation connection…',
    ConnectionStatus.disconnected => 'Simulation disconnected',
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
          OutlinedButton.icon(
            onPressed: c.isBusy || c.needsProgramConfirmation ? null : _openBin,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open BIN'),
          ),
          OutlinedButton.icon(
            onPressed: c.isBusy || c.needsProgramConfirmation
                ? null
                : _loadDemoBin,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Load simulation demo'),
          ),
          if (c.selectedProfile != null)
            Text(
              'Simulation demo target: ${c.selectedProfile!.displayName} · ${c.selectedProfile!.capacityBytes ?? '—'} bytes',
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
                onPressed: c.canRead ? c.read : null,
                child: const Text('Read'),
              ),
              OutlinedButton(
                onPressed: c.canBlankCheck ? c.blankCheck : null,
                child: const Text('Blank check'),
              ),
              FilledButton.tonal(
                onPressed: c.canProgram ? c.requestProgram : null,
                child: const Text('Program'),
              ),
              OutlinedButton(
                onPressed: c.canVerify ? c.verify : null,
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
