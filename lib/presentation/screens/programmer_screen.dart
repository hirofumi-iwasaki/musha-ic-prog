// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as paths;

import '../../platform/desktop_host.dart';

import '../../application/controllers/programmer_controller.dart';
import '../../core/models/binary_image.dart';
import '../../core/models/device_catalog.dart';
import '../../core/models/device_profile.dart';
import '../../core/models/operation.dart';
import '../../core/models/programmer.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localize_message.dart';
import '../widgets/binary_viewer.dart';
import '../widgets/language_selector.dart';
import '../widgets/typeahead_selector.dart';

class ProgrammerScreen extends StatefulWidget {
  const ProgrammerScreen({super.key, required this.controller});
  final ProgrammerController controller;

  @override
  State<ProgrammerScreen> createState() => _ProgrammerScreenState();
}

class _DeviceAutocompleteOptions extends StatefulWidget {
  const _DeviceAutocompleteOptions({
    required this.options,
    required this.onSelected,
    required this.secondaryLabelOf,
  });

  final List<CatalogDevice> options;
  final AutocompleteOnSelected<CatalogDevice> onSelected;
  final String Function(CatalogDevice device) secondaryLabelOf;

  @override
  State<_DeviceAutocompleteOptions> createState() =>
      _DeviceAutocompleteOptionsState();
}

class _DeviceAutocompleteOptionsState
    extends State<_DeviceAutocompleteOptions> {
  final _scrollController = ScrollController();
  int _lastHighlighted = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = AutocompleteHighlightedOption.of(context);
    if (highlighted != _lastHighlighted) {
      _lastHighlighted = highlighted;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients || highlighted < 0) {
          return;
        }
        _scrollController.animateTo(
          (highlighted * 72.0)
              .clamp(0.0, _scrollController.position.maxScrollExtent)
              .toDouble(),
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      });
    }
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemExtent: 72,
      itemCount: widget.options.length,
      itemBuilder: (context, index) {
        final device = widget.options[index];
        final selected = index == highlighted;
        return Semantics(
          selected: selected,
          child: ListTile(
            selected: selected,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            selectedColor: Theme.of(context).colorScheme.onSecondaryContainer,
            title: Text(device.label, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              widget.secondaryLabelOf(device),
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => widget.onSelected(device),
          ),
        );
      },
    );
  }
}

class _ProgrammerScreenState extends State<ProgrammerScreen> {
  ViewerImage? _inputView;
  ViewerImage? _readoutView;
  String? _inputSnapshotId;
  String? _readoutSnapshotId;
  bool _programDialogOpen = false;
  bool _isLoadingInput = false;
  final GlobalKey _inputDropRegionKey = GlobalKey();
  final GlobalKey _vendorSelectorKey = GlobalKey();
  final GlobalKey _deviceSelectorKey = GlobalKey();
  late final DesktopHost _desktopHost;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refreshSnapshots);
    _desktopHost = DesktopHost(
      onFileEvent: _onNativeDrop,
      canClose: () {
        if (widget.controller.isBusy ||
            widget.controller.needsProgramConfirmation) {
          _showFileError(
            AppLocalizations.of(context)!.waitForOperationToFinish,
          );
          return false;
        }
        return true;
      },
    )..attach();
    _refreshSnapshots();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshSnapshots);
    _desktopHost.dispose();
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
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          scrollable: true,
          title: Text(
            _isSimulation(c)
                ? l10n.programSimulatedIcTitle
                : l10n.programIcTitle,
          ),
          content: Text(
            _isSimulation(c)
                ? l10n.programSimulationConfirmation(
                    input?.label ?? '—',
                    input?.length ?? 0,
                    _targetLabel(c, profile),
                    profile?.capacityBytes?.toString() ?? '—',
                    input?.sha1 ?? '—',
                  )
                : l10n.programConfirmation(
                    input?.label ?? '—',
                    input?.length ?? 0,
                    _targetLabel(c, profile),
                    profile?.capacityBytes?.toString() ?? '—',
                    input?.sha1 ?? '—',
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                _isSimulation(c) ? l10n.programSimulation : l10n.program,
              ),
            ),
          ],
        );
      },
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
      origin: _origin(image.origin),
      sha1: image.sha1,
      capturedAt: image.createdAt,
      stale: false,
    );
  }

  ViewerImageOrigin _origin(BinaryImageOrigin origin) => switch (origin) {
    BinaryImageOrigin.file => ViewerImageOrigin.file,
    BinaryImageOrigin.readout => ViewerImageOrigin.readout,
    BinaryImageOrigin.postWriteVerification =>
      ViewerImageOrigin.postWriteVerification,
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
            : AppLocalizations.of(context)!.droppedFileCouldNotBeOpened,
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
        _showFileError(
          AppLocalizations.of(context)!.droppedFileCouldNotBeOpened,
        );
        return;
      }
      if (!_isInputDropAt(
        Offset(
          (arguments['x'] as num).toDouble(),
          (arguments['y'] as num).toDouble(),
        ),
      )) {
        _showFileError(AppLocalizations.of(context)!.dropFileOnInputBin);
        return;
      }
      await _loadInputPath(arguments['path'] as String);
    } finally {
      if (token != null) {
        await _desktopHost.releaseScope(token);
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
    final l10n = AppLocalizations.of(context)!;
    try {
      final entityType = await FileSystemEntity.type(path, followLinks: true);
      if (entityType != FileSystemEntityType.file) {
        _showFileError(l10n.droppedItemNotReadableFile);
        return;
      }
      final file = File(path);
      await _loadInput(
        label: label ?? paths.basename(path),
        length: file.length,
        readBytes: file.readAsBytes,
      );
    } catch (_) {
      _showFileError(l10n.binFileCouldNotBeOpened);
    }
  }

  Future<void> _loadInput({
    required String label,
    required Future<int> Function() length,
    required Future<List<int>> Function() readBytes,
  }) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingInput) {
      _showFileError(l10n.anotherInputFileLoading);
      return;
    }
    if (widget.controller.isBusy ||
        widget.controller.needsProgramConfirmation) {
      _showFileError(l10n.waitForOperationBeforeOpeningFile);
      return;
    }
    _isLoadingInput = true;
    try {
      final fileLength = await length();
      if (fileLength > ProgrammerController.maxInputBytes) {
        _showFileError(l10n.binFileTooLarge);
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
      _showFileError(l10n.binFileCouldNotBeOpened);
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
      c.selectedDevice?.label ??
      profile?.displayName ??
      AppLocalizations.of(context)!.selectedDevice;

  Future<void> _startOperation(
    ProgrammerController c,
    OperationKind kind,
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
        builder: (context, setDialogState) {
          final l10n = AppLocalizations.of(context)!;
          final operationName = switch (kind) {
            OperationKind.read => l10n.read,
            OperationKind.blankCheck => l10n.blankCheck,
            OperationKind.program => l10n.program,
            OperationKind.verify => l10n.verify,
          };
          return AlertDialog(
            scrollable: true,
            title: Text(l10n.confirmPhysicalOperation(operationName)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.targetAlias(_targetLabel(c, c.selectedProfile))),
                Text(
                  l10n.capacityBytes(
                    c.selectedProfile?.capacityBytes?.toString() ?? '—',
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.physicalOperationWarning),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: acknowledged,
                  onChanged: (value) =>
                      setDialogState(() => acknowledged = value ?? false),
                  title: Text(l10n.confirmIcAndSetupChecked),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: acknowledged
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text(l10n.startOperation(operationName)),
              ),
            ],
          );
        },
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

  Widget _bottomStatusBar(ProgrammerController c) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: c.connectionStatus == ConnectionStatus.disconnected
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  Text(
                    l10n.phaseStatus(
                      _phaseLabel(c.phase),
                      c.uiMessage == null
                          ? (c.message ?? l10n.noOperationInProgress)
                          : localizeMessage(l10n, c.uiMessage!),
                    ),
                    style: TextStyle(
                      color:
                          c.connectionStatus == ConnectionStatus.disconnected ||
                              c.phase == OperationPhase.failed ||
                              c.phase == OperationPhase.recoveryRequired
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  if (c.technicalDetail?.isNotEmpty == true)
                    TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            AppLocalizations.of(context)!.technicalDetails,
                          ),
                          content: SingleChildScrollView(
                            child: SelectableText(c.technicalDetail ?? ''),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(AppLocalizations.of(context)!.close),
                            ),
                          ],
                        ),
                      ),
                      child: Text(l10n.technicalDetails),
                    ),
                  if (c.isBusy)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        c.usingSimulation
                            ? l10n.operationInProgressSimulationWarning
                            : l10n.operationInProgressWarning,
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
                c.usingSimulation
                    ? l10n.refreshSimulation
                    : l10n.refreshTl866cs,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  String _connectionLabel(ProgrammerController c) =>
      switch (c.connectionStatus) {
        ConnectionStatus.ready =>
          c.usingSimulation
              ? AppLocalizations.of(context)!.simulationConnected(
                  c.connection?.model ??
                      AppLocalizations.of(context)!.mockProgrammer,
                  c.connection?.firmware ??
                      AppLocalizations.of(context)!.firmwareUnknown,
                )
              : localizeMessage(
                  AppLocalizations.of(context)!,
                  c.backendStatusMessage,
                ),
        ConnectionStatus.busy =>
          c.usingSimulation
              ? AppLocalizations.of(context)!
                    .simulationConnectedOperationInProgress
              : AppLocalizations.of(context)!
                    .tl866csConnectedOperationInProgress,
        ConnectionStatus.unknown =>
          c.usingSimulation
              ? AppLocalizations.of(context)!.checkingSimulationConnection
              : AppLocalizations.of(context)!.checkingTl866csConnection,
        ConnectionStatus.disconnected =>
          c.usingSimulation
              ? AppLocalizations.of(context)!.simulationDisconnected
              : localizeMessage(
                  AppLocalizations.of(context)!,
                  c.backendStatusMessage,
                ),
      };

  String _phaseLabel(OperationPhase phase) => switch (phase) {
    OperationPhase.idle => AppLocalizations.of(context)!.phaseIdle,
    OperationPhase.awaitingConfirmation => AppLocalizations.of(
      context,
    )!.phaseAwaitingConfirmation,
    OperationPhase.preparing => AppLocalizations.of(context)!.phasePreparing,
    OperationPhase.running => AppLocalizations.of(context)!.phaseRunning,
    OperationPhase.reading => AppLocalizations.of(context)!.phaseReading,
    OperationPhase.blankChecking => AppLocalizations.of(
      context,
    )!.phaseBlankChecking,
    OperationPhase.programming => AppLocalizations.of(
      context,
    )!.phaseProgramming,
    OperationPhase.readingBack => AppLocalizations.of(
      context,
    )!.phaseReadingBack,
    OperationPhase.comparing => AppLocalizations.of(context)!.phaseComparing,
    OperationPhase.succeeded => AppLocalizations.of(context)!.phaseCompleted,
    OperationPhase.failed => AppLocalizations.of(context)!.phaseFailed,
    OperationPhase.cancelled => AppLocalizations.of(context)!.phaseCancelled,
    OperationPhase.recoveryRequired => AppLocalizations.of(
      context,
    )!.phaseRecoveryRequired,
  };

  Widget _setupCard(ProgrammerController c) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const LanguageSelector(),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<ProgrammerOption>(
                initialValue: c.selectedProgrammer,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.programmer),
                items: c.availableProgrammers
                    .map(
                      (programmer) => DropdownMenuItem(
                        value: programmer,
                        enabled: programmer.available,
                        child: Text(
                          programmer.available
                              ? programmer.label
                              : l10n.futureProgrammer(programmer.label),
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
            SizedBox(width: 220, child: _vendorSelector(c)),
            SizedBox(width: 300, child: _catalogDeviceSelector(c)),
            if (c.selectedDevice != null && !c.usingSimulation)
              Text(
                _hardwareEvaluationLabel(c.selectedProfile),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            if (c.selectedProfile != null)
              Text(
                l10n.targetWithCapacity(
                  c.selectedProfile!.displayName,
                  c.selectedProfile!.capacityBytes?.toString() ?? '—',
                ),
              ),
            if (c.blockedReason != null &&
                c.connectionStatus != ConnectionStatus.disconnected)
              Text(
                c.blockedUiMessage == null
                    ? c.blockedReason!
                    : localizeMessage(l10n, c.blockedUiMessage!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }

  String _hardwareEvaluationLabel(DeviceProfile? profile) {
    if (profile?.isTl866Executable != true) {
      return AppLocalizations.of(context)!
          .unsupportedForAuthorizedHardwareEvaluation;
    }
    if (profile!.verified) {
      return AppLocalizations.of(context)!.hardwareProfileValidated;
    }
    return AppLocalizations.of(context)!.hardwareEvaluationNotYetValidated;
  }

  Widget _vendorSelector(ProgrammerController c) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = !c.isBusy && !c.needsProgramConfirmation;
    return Semantics(
      key: const ValueKey('vendor-selector'),
      button: true,
      child: InkWell(
        key: _vendorSelectorKey,
        onTap: enabled ? () => _openVendorSelector(c) : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.vendor,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            c.selectedVendor ?? l10n.chooseVendor,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Future<void> _openVendorSelector(ProgrammerController c) async {
    if (c.isBusy || c.needsProgramConfirmation) return;
    final programmer = c.selectedProgrammer;
    final vendors = c.availableVendors;
    final selected = await showTypeaheadSelector<String>(
      context: context,
      title: AppLocalizations.of(context)!.vendor,
      options: vendors,
      labelOf: (vendor) => vendor,
      initialValue: c.selectedVendor,
      anchor: _renderBox(_vendorSelectorKey),
    );
    if (!mounted ||
        selected == null ||
        c.isBusy ||
        c.needsProgramConfirmation ||
        c.selectedProgrammer != programmer ||
        !c.availableVendors.contains(selected)) {
      return;
    }
    c.selectVendor(selected);
  }

  RenderBox? _renderBox(GlobalKey key) =>
      key.currentContext?.findRenderObject() as RenderBox?;

  Widget _catalogDeviceSelector(ProgrammerController c) => KeyedSubtree(
    key: _deviceSelectorKey,
    child: Autocomplete<CatalogDevice>(
      key: ValueKey('${c.selectedVendor}:${c.selectedDevice?.id}'),
      displayStringForOption: (device) => device.label,
      initialValue: TextEditingValue(text: c.selectedDevice?.label ?? ''),
      optionsBuilder: (value) {
        if (c.selectedVendor == null) {
          return const Iterable<CatalogDevice>.empty();
        }
        return c.findCatalogDevices(query: value.text, limit: null);
      },
      onSelected: (device) {
        if (!c.isBusy && !c.needsProgramConfirmation) c.selectDevice(device);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onFieldSubmitted: (_) => onSubmitted(),
          enabled:
              !c.isBusy &&
              !c.needsProgramConfirmation &&
              c.selectedVendor != null,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.device,
            hintText: c.selectedVendor == null
                ? AppLocalizations.of(context)!.chooseVendorFirst
                : AppLocalizations.of(context)!
                      .searchAllDeviceRecords(c.selectedVendorDeviceCount),
            suffixIcon: KeyedSubtree(
              key: const ValueKey('device-dropdown'),
              child: IconButton(
                tooltip: AppLocalizations.of(context)!.showAllDevicesForVendor,
                onPressed:
                    c.selectedVendor == null ||
                        c.isBusy ||
                        c.needsProgramConfirmation
                    ? null
                    : () => _openDeviceSelector(c),
                icon: const Icon(Icons.arrow_drop_down),
              ),
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
            child: _DeviceAutocompleteOptions(
              options: options.toList(growable: false),
              onSelected: onSelected,
              secondaryLabelOf: (device) =>
                  AppLocalizations.of(context)!.deviceKindAndPins(
                    _deviceKindLabel(device),
                    device.pins?.toString() ??
                        AppLocalizations.of(context)!.pinsUnspecified,
                  ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _openDeviceSelector(ProgrammerController c) async {
    final vendor = c.selectedVendor;
    if (vendor == null || c.isBusy || c.needsProgramConfirmation) return;
    final devices = c.findCatalogDevices(query: '', limit: null);
    final selected = await showTypeaheadSelector<CatalogDevice>(
      context: context,
      title: AppLocalizations.of(context)!.device,
      options: devices,
      labelOf: (device) => device.label,
      secondaryLabelOf: (device) =>
          AppLocalizations.of(context)!.deviceKindAndPins(
            _deviceKindLabel(device),
            device.pins?.toString() ??
                AppLocalizations.of(context)!.pinsUnspecified,
          ),
      initialValue: c.selectedDevice,
      anchor: _renderBox(_deviceSelectorKey),
    );
    if (!mounted ||
        selected == null ||
        c.isBusy ||
        c.needsProgramConfirmation ||
        c.selectedVendor != vendor ||
        !c
            .findCatalogDevices(query: '', limit: null)
            .any((device) => device.id == selected.id)) {
      return;
    }
    c.selectDevice(selected);
  }

  String _deviceKindLabel(CatalogDevice device) {
    final l10n = AppLocalizations.of(context)!;
    return switch (device.type) {
      '1' => l10n.deviceTypeEepromMemory,
      '2' => l10n.deviceTypeMcuMpu,
      '3' => l10n.deviceTypePldCpld,
      '4' => l10n.deviceTypeSram,
      '5' => l10n.deviceTypeLogic,
      '6' => l10n.deviceTypeNand,
      '7' => l10n.deviceTypeEmmc,
      '8' => l10n.deviceTypeVgaHdmi,
      _ => l10n.deviceTypeUnspecified,
    };
  }

  Widget _operations(ProgrammerController c) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
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
                      ? () => _startOperation(c, OperationKind.read, c.read)
                      : null,
                  child: Text(l10n.read),
                ),
                OutlinedButton(
                  onPressed: c.canBlankCheck
                      ? () => _startOperation(
                          c,
                          OperationKind.blankCheck,
                          c.blankCheck,
                        )
                      : null,
                  child: Text(l10n.blankCheck),
                ),
                FilledButton.tonal(
                  onPressed: c.canProgram
                      ? () => _startOperation(
                          c,
                          OperationKind.program,
                          () async => c.requestProgram(),
                        )
                      : null,
                  child: Text(l10n.program),
                ),
                OutlinedButton(
                  onPressed: c.canVerify
                      ? () => _startOperation(c, OperationKind.verify, c.verify)
                      : null,
                  child: Text(l10n.verify),
                ),
                if (c.isBusy)
                  TextButton(
                    onPressed: c.cancelActiveOperation,
                    child: Text(l10n.cancel),
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
                  l10n.firstMismatch(
                    c.lastResult!.mismatch!.address
                        .toRadixString(16)
                        .toUpperCase(),
                    c.lastResult!.mismatchCount,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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
