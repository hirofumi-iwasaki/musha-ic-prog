// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../minipro_profile_mapper.dart';
import '../../core/models/binary_image.dart';
import '../../core/models/device_catalog.dart';
import '../../core/models/device_profile.dart';
import '../../core/models/operation.dart';
import '../../core/models/programmer.dart';
import '../../core/policies/operation_policy.dart';
import '../../core/ports/programmer_backend.dart';

/// Presentation-facing state holder. Hardware backends remain mock-only in M1.
final class ProgrammerController extends ChangeNotifier {
  ProgrammerController({
    required ProgrammerBackend backend,
    required List<DeviceProfile> profiles,
    DeviceCatalog? catalog,
    this.simulationBackend,
  }) : _backend = backend,
       _realBackend = backend,
       profiles = List.unmodifiable(profiles),
       catalog = catalog ?? DeviceCatalog.empty;

  static const int maxInputBytes = 64 * 1024 * 1024;

  ProgrammerBackend _backend;
  final ProgrammerBackend _realBackend;
  final ProgrammerBackend? simulationBackend;
  final List<DeviceProfile> profiles;
  DeviceCatalog catalog;
  ProgrammerOption selectedProgrammer = ProgrammerOption.tl866cs;
  String? selectedVendor;
  CatalogDevice? selectedDevice;
  ProgrammerConnection? connection;
  DeviceProfile? selectedProfile;
  BinaryImage? inputImage;
  BinaryImage? readoutImage;
  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;
  OperationPhase phase = OperationPhase.idle;
  double? progress;
  String? message;
  String? blockedReason;
  OperationResult? lastResult;
  final List<String> logs = [];

  String? _activeOperationId;
  OperationPlan? _pendingProgram;
  OperationHandle? _activeHandle;
  StreamSubscription<OperationEvent>? _eventSubscription;
  bool _disposed = false;
  bool _isConnecting = false;
  int _connectionEpoch = 0;

  bool get isBusy =>
      _isConnecting ||
      phase == OperationPhase.preparing ||
      phase == OperationPhase.running ||
      phase == OperationPhase.reading ||
      phase == OperationPhase.blankChecking ||
      phase == OperationPhase.programming ||
      phase == OperationPhase.readingBack ||
      phase == OperationPhase.comparing;
  bool get needsProgramConfirmation =>
      phase == OperationPhase.awaitingConfirmation;
  bool get isConnecting => _isConnecting;
  bool get isConnected => connectionStatus == ConnectionStatus.ready;
  bool get usingSimulation => _backend.backendId == 'mock';
  String get backendStatus => usingSimulation
      ? 'Simulation backend'
      : connection == null
      ? 'TL866CS not connected'
      : 'TL866CS connected (${connection!.identifier})';

  /// Only TL866CS is selectable in the current release.
  List<ProgrammerOption> get availableProgrammers => const [
    ProgrammerOption.tl866cs,
  ];
  List<String> get availableVendors => catalog.vendorsFor(selectedProgrammer);
  int get selectedVendorDeviceCount => catalog.deviceCount(
    programmer: selectedProgrammer,
    vendor: selectedVendor,
  );
  bool get canRead => _eligibility(OperationKind.read) == null;
  bool get canBlankCheck => _eligibility(OperationKind.blankCheck) == null;
  bool get canProgram => _eligibility(OperationKind.program) == null;
  bool get canVerify => _eligibility(OperationKind.verify) == null;

  String? disabledReasonFor(OperationKind kind) => _eligibility(kind);

  /// Replaces only browse data; it never grants operation support.
  void replaceCatalog(DeviceCatalog value) {
    if (isBusy || needsProgramConfirmation) return;
    catalog = value;
    if (selectedVendor != null && !availableVendors.contains(selectedVendor)) {
      selectedVendor = null;
      selectedDevice = null;
    }
    final selected = selectedDevice;
    if (selected == null || !_catalogSelectionIsValid(selected)) {
      selectedDevice = null;
      selectedProfile = null;
    } else {
      final replacement = catalog.byId(selected.id);
      selectedDevice = replacement;
      selectedProfile =
          replacement == null || !catalog.isUnambiguousTl866Alias(replacement)
          ? null
          : MiniproProfileMapper.fromTl866Catalog(replacement);
    }
    _safeNotify();
  }

  void selectProgrammer(ProgrammerOption programmer) {
    if (isBusy || needsProgramConfirmation || !programmer.available) return;
    selectedProgrammer = programmer;
    selectedVendor = null;
    selectedDevice = null;
    selectedProfile = null;
    message = usingSimulation
        ? '${programmer.label} database entries are available after switching to TL866CS mode.'
        : '${programmer.label} database selected for constrained hardware evaluation.';
    _safeNotify();
  }

  void selectVendor(String? vendor) {
    if (isBusy || needsProgramConfirmation) return;
    selectedVendor = availableVendors.contains(vendor) ? vendor : null;
    selectedDevice = null;
    selectedProfile = null;
    _safeNotify();
  }

  void selectDevice(CatalogDevice? device) {
    if (isBusy || needsProgramConfirmation) return;
    if (device != null && !_catalogSelectionIsValid(device)) {
      message =
          'Choose a device from the selected vendor and programmer database.';
      _safeNotify();
      return;
    }
    selectedDevice = device;
    selectedProfile = device == null || !catalog.isUnambiguousTl866Alias(device)
        ? null
        : MiniproProfileMapper.fromTl866Catalog(device);
    if (device != null) {
      message = selectedProfile == null
          ? '${device.label} cannot be represented as a safe raw-BIN TL866CS profile.'
          : selectedProfile!.verified
          ? '${device.label} has an empirical validation record.'
          : '${device.label} is authorized for constrained hardware evaluation; it is not empirically validated.';
    }
    _safeNotify();
  }

  List<CatalogDevice> findCatalogDevices({
    String query = '',
    int offset = 0,
    int? limit,
  }) => catalog.findDevices(
    programmer: selectedProgrammer,
    vendor: selectedVendor,
    query: query,
    offset: offset,
    limit: limit,
  );

  Future<void> connectProgrammer() async {
    if (_isConnecting) return;
    if (isBusy || needsProgramConfirmation) {
      blockedReason = 'Wait for the current operation before reconnecting.';
      message = blockedReason;
      _safeNotify();
      return;
    }
    final epoch = ++_connectionEpoch;
    final backend = _backend;
    _isConnecting = true;
    _resetTransientState();
    connection = null;
    connectionStatus = ConnectionStatus.unknown;
    message = usingSimulation
        ? 'Looking for the simulation programmer…'
        : 'Checking one TL866CS connection…';
    _safeNotify();
    try {
      final found = await backend.scan();
      if (_disposed || epoch != _connectionEpoch || backend != _backend) return;
      if (found.length != 1) {
        connectionStatus = ConnectionStatus.disconnected;
        blockedReason = 'Exactly one programmer must be connected.';
        message = blockedReason;
      } else {
        connection = found.single;
        connectionStatus = ConnectionStatus.ready;
        message = usingSimulation
            ? '${connection!.model} ready (simulation only).'
            : '${connection!.model} ready; no IC operation has been performed.';
        _log(message!);
      }
    } catch (_) {
      if (!_disposed && epoch == _connectionEpoch && backend == _backend) {
        connectionStatus = ConnectionStatus.disconnected;
        message = 'Programmer identity check failed.';
      }
    } finally {
      if (!_disposed && epoch == _connectionEpoch && backend == _backend) {
        _isConnecting = false;
        _safeNotify();
      }
    }
  }

  /// Retained for existing demo and test callers.
  Future<void> connectMock() => connectProgrammer();

  void useSimulationDemo() {
    final simulation = simulationBackend;
    if (simulation == null || _operationIsBusy || needsProgramConfirmation) {
      return;
    }
    _backend = simulation;
    _invalidateConnectionScan();
    selectedVendor = null;
    selectedDevice = null;
    selectedProfile = mockEpromProfile;
    connectionStatus = ConnectionStatus.disconnected;
    message = 'Simulation demo selected. Connect to use the mock programmer.';
    _safeNotify();
  }

  void useRealProgrammer() {
    if (_operationIsBusy || needsProgramConfirmation) return;
    _backend = _realBackend;
    _invalidateConnectionScan();
    selectedProfile = null;
    connectionStatus = ConnectionStatus.disconnected;
    message = 'TL866CS mode selected. Refresh connection status.';
    _safeNotify();
  }

  void selectProfile(DeviceProfile? profile) {
    if (isBusy || needsProgramConfirmation) return;
    selectedProfile = profile;
    if (profile != null) {
      selectedVendor = null;
      selectedDevice = null;
    }
    blockedReason = null;
    message = profile == null
        ? 'Choose a device profile.'
        : 'Selected ${profile.displayName}.';
    _safeNotify();
  }

  /// Takes ownership of a copy and refuses files too large for this M1 viewer.
  void openBinary(List<int> bytes, {required String label}) {
    if (isBusy || needsProgramConfirmation) return;
    if (bytes.length > maxInputBytes) {
      blockedReason = 'BIN files larger than 64 MiB are not supported yet.';
      message = blockedReason;
    } else {
      inputImage = BinaryImage(
        bytes: bytes,
        origin: BinaryImageOrigin.file,
        label: label,
      );
      blockedReason = null;
      message = 'Opened $label (${inputImage!.length} bytes).';
      _log(message!);
    }
    _safeNotify();
  }

  void openBinaryImage(BinaryImage image) =>
      openBinary(image.bytes, label: image.label);

  Future<void> read() => _start(OperationKind.read);
  Future<void> blankCheck() => _start(OperationKind.blankCheck);
  Future<void> verify() => _start(OperationKind.verify);

  /// Moves to an explicit confirmation state. No bytes are changed here.
  void requestProgram() {
    final reason = _eligibility(OperationKind.program);
    if (reason != null) {
      blockedReason = reason;
      message = reason;
      _safeNotify();
      return;
    }
    _pendingProgram = _newPlan(OperationKind.program);
    phase = OperationPhase.awaitingConfirmation;
    message = 'Confirm program to write the immutable input snapshot.';
    _safeNotify();
  }

  Future<void> confirmProgram() async {
    final plan = _pendingProgram;
    if (plan == null || phase != OperationPhase.awaitingConfirmation) return;
    _pendingProgram = null;
    await _execute(plan);
  }

  void cancelProgramConfirmation() {
    if (!needsProgramConfirmation) return;
    _pendingProgram = null;
    phase = OperationPhase.cancelled;
    message = 'Program cancelled before writing.';
    _safeNotify();
  }

  Future<void> cancelActiveOperation() async {
    final handle = _activeHandle;
    if (handle != null) await handle.requestCancel();
  }

  Future<void> _start(OperationKind kind) async {
    final reason = _eligibility(kind);
    if (reason != null) {
      blockedReason = reason;
      message = reason;
      _safeNotify();
      return;
    }
    await _execute(_newPlan(kind));
  }

  OperationPlan _newPlan(OperationKind kind) => OperationPlan(
    operationId: 'operation-${DateTime.now().microsecondsSinceEpoch}',
    kind: kind,
    connection: connection!,
    profile: selectedProfile!,
    input: inputImage,
  );

  Future<void> _execute(OperationPlan plan) async {
    _activeOperationId = plan.operationId;
    phase = OperationPhase.preparing;
    progress = 0;
    blockedReason = null;
    lastResult = null;
    connectionStatus = ConnectionStatus.busy;
    _safeNotify();
    var reconnectRequired = false;
    try {
      _activeHandle = _backend.execute(plan);
      _eventSubscription = _activeHandle!.events.listen(_onEvent);
      final result = await _activeHandle!.completed;
      if (_activeOperationId != result.operationId || _disposed) return;
      phase = result.phase;
      progress = result.succeeded ? 1 : null;
      message = result.message;
      lastResult = result;
      if (result.image != null) readoutImage = result.image;
      reconnectRequired =
          !usingSimulation &&
          (result.phase == OperationPhase.failed ||
              result.phase == OperationPhase.recoveryRequired);
      _log(result.message);
    } catch (error) {
      if (!_disposed && _activeOperationId == plan.operationId) {
        phase = OperationPhase.failed;
        progress = null;
        message = 'Operation could not start: $error';
        lastResult = OperationResult(
          operationId: plan.operationId,
          phase: OperationPhase.failed,
          message: message!,
        );
        _log(message!);
        reconnectRequired = !usingSimulation;
      }
    } finally {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      if (_activeOperationId == plan.operationId) {
        _activeHandle = null;
        _activeOperationId = null;
        if (!_disposed) {
          if (reconnectRequired) {
            connection = null;
            connectionStatus = ConnectionStatus.disconnected;
            message =
                '${message ?? 'Physical operation failed.'} Refresh TL866CS connection before another operation.';
            blockedReason = message;
          } else {
            connectionStatus = ConnectionStatus.ready;
          }
        }
      }
      _safeNotify();
    }
  }

  void _onEvent(OperationEvent event) {
    if (event.operationId != _activeOperationId) return;
    phase = event.phase;
    progress = event.progress;
    message = event.message;
    _safeNotify();
  }

  String? _eligibility(OperationKind kind) {
    final profile = selectedProfile;
    if (!usingSimulation && profile != null && !profile.isTl866Executable) {
      return 'This database profile is outside the authorized TL866CS evaluation scope.';
    }
    return OperationPolicy.validate(
      kind: kind,
      connection: connection,
      profile: profile,
      input: inputImage,
      isBusy: isBusy || needsProgramConfirmation,
    );
  }

  bool get _operationIsBusy =>
      phase == OperationPhase.preparing ||
      phase == OperationPhase.running ||
      phase == OperationPhase.reading ||
      phase == OperationPhase.blankChecking ||
      phase == OperationPhase.programming ||
      phase == OperationPhase.readingBack ||
      phase == OperationPhase.comparing;

  void _invalidateConnectionScan() {
    _connectionEpoch++;
    _isConnecting = false;
    connection = null;
  }

  bool _catalogSelectionIsValid(CatalogDevice device) {
    final stored = catalog.byId(device.id);
    return stored != null &&
        selectedProgrammer.databaseTypes.contains(stored.database) &&
        stored.vendor == selectedVendor;
  }

  void _resetTransientState() {
    phase = OperationPhase.idle;
    progress = null;
    blockedReason = null;
    lastResult = null;
  }

  void _log(String entry) {
    logs.add('${DateTime.now().toUtc().toIso8601String()} $entry');
    if (logs.length > 200) logs.removeAt(0);
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionEpoch++;
    unawaited(_activeHandle?.requestCancel());
    unawaited(_eventSubscription?.cancel());
    super.dispose();
  }
}
