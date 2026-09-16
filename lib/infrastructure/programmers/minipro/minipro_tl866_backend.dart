// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/models/binary_image.dart';
import '../../../core/models/device_profile.dart';
import '../../../core/models/operation.dart';
import '../../../core/models/programmer.dart';
import '../../../core/ports/programmer_backend.dart';
import 'native_payload_locator.dart';
import 'process_runner.dart';

export 'native_payload_locator.dart'
    show MiniproBundlePaths, NativePayloadLocator;

/// Real TL866CS adapter. Identity scans enumerate USB only; ZIF actions need
/// either empirical validation or an explicitly authorized evaluation profile.
final class MiniproTl866Backend
    implements ProgrammerBackend, ProgrammerDiscoveryDiagnostics {
  MiniproTl866Backend({
    MiniproBundlePaths? paths,
    ProcessRunner? runner,
    String? operatingSystem,
  }) : _paths = paths ?? MiniproBundlePaths.currentApp(),
       _runner = runner ?? const IoProcessRunner(),
       _operatingSystem = operatingSystem ?? Platform.operatingSystem;

  final MiniproBundlePaths _paths;
  final ProcessRunner _runner;
  final String _operatingSystem;
  int _generation = 0;
  bool _operationActive = false;
  String? _discoveryReason;

  @override
  String? get discoveryReason => _discoveryReason;

  @override
  String get backendId => 'minipro-tl866cs';

  @override
  Future<List<ProgrammerConnection>> scan() async {
    _discoveryReason = null;
    if (!_paths.isPresent) {
      _discoveryReason =
          'TL866CS native payload is incomplete: ${_paths.missingFiles.join(', ')}.';
      return const [];
    }
    try {
      final probe = await _run(_paths.probe, const []);
      if (probe.exitCode != 0) {
        _discoveryReason = _probeFailureReason(probe);
        return const [];
      }
      final decoded = jsonDecode(probe.stdout);
      if (decoded is! Map) {
        _discoveryReason = 'TL866CS discovery helper returned invalid data.';
        return const [];
      }
      final rawDevices = decoded['devices'];
      if (rawDevices is! List ||
          decoded['count'] is! num ||
          (decoded['count'] as num).toInt() != rawDevices.length) {
        _discoveryReason =
            'TL866CS discovery helper returned invalid device data.';
        return const [];
      }
      if (rawDevices.isEmpty) {
        _discoveryReason = _emptyProbeReason(decoded);
        return const [];
      }
      if (rawDevices.length != 1) {
        _discoveryReason = 'More than one TL866A/CS programmer was detected.';
        return const [];
      }
      final item = rawDevices.single;
      if (item is! Map ||
          '${item['vendorId']}'.toLowerCase() != '04d8' ||
          '${item['productId']}'.toLowerCase() != 'e11c') {
        _discoveryReason =
            'TL866CS discovery helper returned an unsupported device.';
        return const [];
      }
      final identifier = _identifierFor(item);
      if (identifier == null) {
        _discoveryReason =
            'TL866CS discovery helper returned no stable device identity.';
        return const [];
      }
      if (item['interfaceReady'] == false) {
        _discoveryReason = _windowsDriverReason(item);
        return const [];
      }
      final presence = await _run(_paths.executable, const ['-k']);
      final presenceText = '${presence.stdout}\n${presence.stderr}';
      if (presence.exitCode != 0 || !presenceText.contains('tl866a: TL866CS')) {
        _discoveryReason = _miniproFailureReason(presence);
        return const [];
      }
      final version = await _run(_paths.executable, [
        '--infoic',
        _paths.infoic,
        '--logicic',
        _paths.logicic,
        '-V',
      ]);
      final versionText = '${version.stdout}\n${version.stderr}';
      final firmware = RegExp(
        r'Found TL866CS\s+([^\s]+)\s+\((0x[0-9a-fA-F]+)\)',
      ).firstMatch(versionText);
      if (version.exitCode != 0 ||
          firmware == null ||
          versionText.toLowerCase().contains('bootloader mode')) {
        _discoveryReason = versionText.toLowerCase().contains('bootloader mode')
            ? 'TL866CS is in bootloader mode; reconnect it normally before use.'
            : _miniproFailureReason(version);
        return const [];
      }
      return [
        ProgrammerConnection(
          backendId: backendId,
          model: 'TL866CS',
          identifier: identifier,
          firmware: '${firmware.group(1)} ${firmware.group(2)}',
          generation: ++_generation,
        ),
      ];
    } on FormatException {
      _discoveryReason = 'TL866CS discovery helper returned invalid JSON.';
      return const [];
    } catch (_) {
      _discoveryReason = 'TL866CS discovery helper could not be started.';
      return const [];
    }
  }

  String? _identifierFor(Map item) {
    if (_operatingSystem == 'windows') {
      final identity = item['identity'];
      if (identity is! String || identity.isEmpty) return null;
      // SetupAPI paths are implementation details. Retain only a stable,
      // opaque token for reconnect checks and never expose bus/address on Windows.
      return 'usb-${sha256.convert(utf8.encode(identity)).toString().substring(0, 16)}';
    }
    final bus = item['bus'];
    final address = item['address'];
    if (bus is! num || address is! num) return null;
    return 'usb-${bus.toInt()}-${address.toInt()}';
  }

  String _emptyProbeReason(Map decoded) {
    final state = '${decoded['reason'] ?? decoded['status'] ?? ''}'
        .toLowerCase();
    if (_operatingSystem == 'windows' &&
        (state.contains('driver') || state.contains('interface'))) {
      return _winusbSetupReason('The WinUSB interface is unavailable.');
    }
    if (state.contains('permission') || state.contains('access')) {
      return _libusbAccessReason();
    }
    return 'No TL866A/CS programmer was detected.';
  }

  String _windowsDriverReason(Map item) {
    final service = item['driverService'];
    final serviceName = service is String ? service.trim() : '';
    final detail = '${item['reason'] ?? ''}'.toLowerCase();
    if (serviceName.isEmpty) {
      return _winusbSetupReason(
        'No USB driver service is bound to this TL866CS.',
      );
    }
    if (serviceName.toLowerCase() != 'winusb') {
      return _winusbSetupReason(
        'TL866CS is using $serviceName rather than WinUSB.',
      );
    }
    if (detail.contains('bindingunsupported')) {
      return _winusbSetupReason('The current WinUSB binding is not usable.');
    }
    return _winusbSetupReason('The WinUSB interface is not ready.');
  }

  String _winusbSetupReason(String detail) =>
      '$detail Follow resources/minipro/WINDOWS_USB_SETUP.md, then reconnect the programmer.';

  String _probeFailureReason(ProcessTranscript probe) {
    final text = '${probe.stderr}\n${probe.stdout}'.toLowerCase();
    if (_isAccessDenied(text)) {
      return _libusbAccessReason();
    }
    if (text.contains('busy') || text.contains('in use')) {
      return 'TL866CS is busy. Close other programmer software, then reconnect it.';
    }
    return 'TL866CS discovery helper failed: ${_diagnosticText(probe)}';
  }

  String _miniproFailureReason(ProcessTranscript result) {
    final text = '${result.stderr}\n${result.stdout}'.toLowerCase();
    if (_isAccessDenied(text)) {
      return _libusbAccessReason();
    }
    if (text.contains('libusb_error_busy') || text.contains('busy')) {
      return 'TL866CS is busy. Close other programmer software, then reconnect it.';
    }
    if (_operatingSystem == 'windows' &&
        (text.contains('libusb_error_no_device') ||
            text.contains('no device'))) {
      return 'TL866CS was disconnected after discovery. Reconnect it, then refresh the connection.';
    }
    if (_operatingSystem == 'windows' &&
        (text.contains('driver') ||
            text.contains('winusb') ||
            text.contains('interface') ||
            text.contains('guid') ||
            text.contains('not supported'))) {
      return _winusbSetupReason(
        'TL866CS does not have a usable WinUSB interface for libusb.',
      );
    }
    return 'TL866CS model and firmware check failed: ${_diagnosticText(result)}';
  }

  String _diagnosticText(ProcessTranscript result) {
    final text = '${result.stderr}\n${result.stdout}'.trim();
    return text.isEmpty ? 'helper exited with ${result.exitCode}.' : text;
  }

  bool _isAccessDenied(String text) =>
      text.contains('libusb_error_access') ||
      text.contains('permission') ||
      text.contains('access denied');

  String _libusbAccessReason() => switch (_operatingSystem) {
    'windows' => 'TL866CS was detected, but libusb access was denied. Check the WinUSB binding in resources/minipro/WINDOWS_USB_SETUP.md, then reconnect it.',
    'linux' => 'TL866CS was detected, but libusb access was denied. Install or reload the TL866 udev rule for the current user, then reconnect it.',
    'macos' => 'TL866CS was detected, but macOS denied USB access. Check the app USB permission and reconnect it.',
    _ => 'TL866CS was detected, but libusb access was denied. Reconnect it and check USB permissions.',
  };

  @override
  Future<BackendCapabilities> capabilities(
    ProgrammerConnection connection,
    DeviceProfile profile,
  ) async {
    if (connection.backendId != backendId || connection.model != 'TL866CS') {
      return const BackendCapabilities(reason: 'A single TL866CS is required.');
    }
    if (!profile.isTl866Executable) {
      return const BackendCapabilities(
        reason: 'This profile is not approved for real TL866CS evaluation.',
      );
    }
    final diagnostic = await _validateProfile(profile);
    if (diagnostic != null) return BackendCapabilities(reason: diagnostic);
    return const BackendCapabilities(
      canRead: true,
      canBlankCheck: true,
      canProgram: true,
      canVerify: true,
    );
  }

  @override
  OperationHandle execute(OperationPlan plan) {
    if (_operationActive) {
      return _RejectedOperationHandle(
        plan,
        'Another TL866CS operation is active.',
      );
    }
    _operationActive = true;
    return _MiniproOperationHandle(this, plan, () => _operationActive = false);
  }

  Future<bool> _sameConnection(ProgrammerConnection expected) async {
    final found = await scan();
    if (found.length != 1) return false;
    final actual = found.single;
    return actual.backendId == expected.backendId &&
        actual.model == expected.model &&
        actual.identifier == expected.identifier &&
        actual.firmware == expected.firmware;
  }

  Future<String?> _validateProfile(DeviceProfile profile) async {
    try {
      final response = await _run(_paths.executable, [
        '-q',
        'tl866a',
        '--infoic',
        _paths.infoic,
        '--logicic',
        _paths.logicic,
        '-d',
        profile.miniproAlias!,
      ]);
      final text = '${response.stdout}\n${response.stderr}';
      final name = RegExp(r'^Name:\s*(.+)$', multiLine: true).firstMatch(text);
      final memory = RegExp(r'Memory:\s*(\d+) Bytes').firstMatch(text);
      final package = RegExp(r'Package:\s*([^\r\n]+)').firstMatch(text);
      final aliases = name?.group(1)?.split(',').map((e) => e.trim()).toSet();
      if (response.exitCode != 0 ||
          aliases == null ||
          !aliases.contains(profile.miniproAlias) ||
          !text.contains('TL866A/CS')) {
        return 'minipro could not resolve the selected device alias.';
      }
      if (memory == null ||
          int.tryParse(memory.group(1)!) != profile.capacityBytes) {
        return 'minipro device capacity does not match the selected profile.';
      }
      if (package == null ||
          package.group(1)!.trim() != profile.expectedMiniproPackage) {
        return 'minipro device package does not match the selected profile.';
      }
      return null;
    } catch (_) {
      return 'minipro device information could not be validated.';
    }
  }

  Future<ProcessTranscript> _run(String executable, List<String> args) async =>
      collectProcess(
        await _runner.start(
          executable,
          args,
          workingDirectory: File(executable).parent.path,
          environment: const {'LC_ALL': 'C', 'LANG': 'C'},
        ),
      );
}

final class _MiniproOperationHandle implements OperationHandle {
  _MiniproOperationHandle(this._backend, this._plan, this._onFinished) {
    unawaited(_run());
  }

  final MiniproTl866Backend _backend;
  final OperationPlan _plan;
  final void Function() _onFinished;
  final StreamController<OperationEvent> _events = StreamController.broadcast();
  final Completer<OperationResult> _result = Completer();
  OperationResult? _outcome;
  bool _cancelRequested = false;
  bool _writeStarted = false;
  bool _released = false;

  @override
  Stream<OperationEvent> get events => _events.stream;
  @override
  Future<OperationResult> get completed => _result.future;

  @override
  Future<void> requestCancel() async {
    // Never interrupt a live minipro subprocess: safe mid-command behaviour is
    // unproven. Cancellation takes effect before the next hardware command.
    _cancelRequested = true;
  }

  Future<void> _run() async {
    Directory? temp;
    try {
      if (!await _backend._sameConnection(_plan.connection)) {
        return _finishFailure(
          'TL866CS identity changed; refresh before operating.',
        );
      }
      final capabilities = await _backend.capabilities(
        _plan.connection,
        _plan.profile,
      );
      if (!_hasCapability(capabilities)) {
        return _finishFailure(capabilities.reason!);
      }
      temp = await Directory.systemTemp.createTemp('mushagaeshi-minipro-');
      switch (_plan.kind) {
        case OperationKind.read:
          _emit(OperationPhase.reading, 'Reading code memory.');
          final image = await _readImage(
            temp,
            'read.bin',
            BinaryImageOrigin.readout,
          );
          _finishSuccess('Read ${image.length} bytes.', image: image);
        case OperationKind.blankCheck:
          _emit(
            OperationPhase.blankChecking,
            'Checking code memory blank state.',
          );
          final result = await _command(const ['-b']);
          result.exitCode == 0
              ? _finishSuccess('IC code memory is blank.')
              : _finishFailure(_diagnostic(result));
        case OperationKind.verify:
          final expected = _plan.input!.bytes;
          _emit(
            OperationPhase.reading,
            'Reading code memory for verification.',
          );
          final image = await _readImage(
            temp,
            'verify.bin',
            BinaryImageOrigin.readout,
          );
          _emit(
            OperationPhase.comparing,
            'Comparing immutable input snapshot.',
          );
          final mismatch = _firstMismatch(expected, image.bytes);
          final mismatchCount = _mismatchCount(expected, image.bytes);
          mismatch == null
              ? _finishSuccess('Verification passed.', image: image)
              : _finishFailure(
                  'Verification failed.',
                  image: image,
                  mismatch: mismatch,
                  mismatchCount: mismatchCount,
                );
        case OperationKind.program:
          final input = await _writeInput(temp);
          _emit(
            OperationPhase.blankChecking,
            'Checking code memory blank state.',
          );
          final blank = await _command(const ['-b']);
          if (blank.exitCode != 0) return _finishFailure(_diagnostic(blank));
          if (!await _backend._sameConnection(_plan.connection)) {
            return _finishRecovery(
              'TL866CS identity changed before writing; no write was started.',
            );
          }
          _emit(
            OperationPhase.programming,
            'Programming immutable input snapshot.',
          );
          if (_cancelRequested) throw const _CancellationRequested();
          _writeStarted = true;
          final write = await _command(['-e', '-w', input.path]);
          if (write.exitCode != 0) return _finishRecovery(_diagnostic(write));
          _emit(OperationPhase.readingBack, 'Reading code memory after write.');
          final image = await _readImage(
            temp,
            'readback.bin',
            BinaryImageOrigin.postWriteVerification,
          );
          final mismatch = _firstMismatch(_plan.input!.bytes, image.bytes);
          if (mismatch != null) {
            return _finishRecovery(
              'Post-write verification failed.',
              image: image,
              mismatch: mismatch,
              mismatchCount: _mismatchCount(_plan.input!.bytes, image.bytes),
            );
          }
          _finishSuccess(
            'Programmed and byte-verified ${image.length} bytes.',
            image: image,
          );
      }
    } on _CancellationRequested {
      _writeStarted
          ? _finishRecovery(
              'Stop requested after writing began; verify contents before continuing.',
            )
          : _finishCancelled();
    } catch (error) {
      _writeStarted
          ? _finishRecovery('minipro write operation failed: $error')
          : _finishFailure('minipro operation failed: $error');
    } finally {
      try {
        if (temp != null && await temp.exists()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {
        // A cleanup failure must not leave the caller awaiting forever.
      }
      _release();
      final outcome = _outcome;
      if (outcome != null && !_result.isCompleted) {
        _result.complete(outcome);
      }
    }
  }

  bool _hasCapability(BackendCapabilities caps) => switch (_plan.kind) {
    OperationKind.read => caps.canRead,
    OperationKind.blankCheck => caps.canBlankCheck,
    OperationKind.program => caps.canProgram,
    OperationKind.verify => caps.canVerify,
  };

  Future<File> _writeInput(Directory temp) async {
    final file = File('${temp.path}/input.bin');
    await file.writeAsBytes(_plan.input!.bytes, flush: true);
    return file;
  }

  Future<BinaryImage> _readImage(
    Directory temp,
    String name,
    BinaryImageOrigin origin,
  ) async {
    final output = File('${temp.path}/$name');
    final result = await _command(['-r', output.path]);
    if (result.exitCode != 0) throw StateError(_diagnostic(result));
    if (!await output.exists()) {
      throw StateError('minipro did not create a readback file.');
    }
    final length = await output.length();
    if (length != _plan.profile.capacityBytes) {
      throw StateError('Readback size did not match the selected profile.');
    }
    final bytes = await output.readAsBytes();
    if (bytes.length != length) {
      throw StateError('Readback file changed while it was read.');
    }
    return BinaryImage(
      bytes: bytes,
      origin: origin,
      label: '${_plan.profile.partNumber} readout',
    );
  }

  Future<ProcessTranscript> _command(List<String> action) async {
    if (_cancelRequested) throw const _CancellationRequested();
    final args = [
      '--infoic',
      _backend._paths.infoic,
      '--logicic',
      _backend._paths.logicic,
      '-p',
      _plan.profile.miniproAlias!,
      '-c',
      'code',
      ...action,
    ];
    final result = await _backend._run(_backend._paths.executable, args);
    if (_cancelRequested) throw const _CancellationRequested();
    return result;
  }

  String _diagnostic(ProcessTranscript result) {
    final text = '${result.stderr}\n${result.stdout}'.trim();
    return text.isEmpty ? 'minipro exited with ${result.exitCode}.' : text;
  }

  Mismatch? _firstMismatch(Uint8List expected, Uint8List actual) {
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) {
        return Mismatch(address: i, expected: expected[i], actual: actual[i]);
      }
    }
    return null;
  }

  int _mismatchCount(Uint8List expected, Uint8List actual) {
    var count = 0;
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) count++;
    }
    return count;
  }

  void _emit(OperationPhase phase, String message) => _events.add(
    OperationEvent(
      operationId: _plan.operationId,
      phase: phase,
      message: message,
    ),
  );
  void _finishSuccess(String message, {BinaryImage? image}) => _finish(
    OperationResult(
      operationId: _plan.operationId,
      phase: OperationPhase.succeeded,
      message: message,
      image: image,
    ),
  );
  void _finishFailure(
    String message, {
    BinaryImage? image,
    Mismatch? mismatch,
    int mismatchCount = 0,
  }) => _finish(
    OperationResult(
      operationId: _plan.operationId,
      phase: OperationPhase.failed,
      message: message,
      image: image,
      mismatch: mismatch,
      mismatchCount: mismatchCount,
    ),
  );
  void _finishRecovery(
    String message, {
    BinaryImage? image,
    Mismatch? mismatch,
    int mismatchCount = 0,
  }) => _finish(
    OperationResult(
      operationId: _plan.operationId,
      phase: OperationPhase.recoveryRequired,
      message: message,
      image: image,
      mismatch: mismatch,
      mismatchCount: mismatchCount,
    ),
  );
  void _finishCancelled() => _finish(
    OperationResult(
      operationId: _plan.operationId,
      phase: OperationPhase.cancelled,
      message: 'Operation stopped before the next hardware command.',
    ),
  );
  void _finish(OperationResult value) {
    _outcome ??= value;
    unawaited(_events.close());
  }

  void _release() {
    if (_released) return;
    _released = true;
    _onFinished();
  }
}

final class _CancellationRequested implements Exception {
  const _CancellationRequested();
}

final class _RejectedOperationHandle implements OperationHandle {
  _RejectedOperationHandle(OperationPlan plan, String message)
    : _completed = Future.value(
        OperationResult(
          operationId: plan.operationId,
          phase: OperationPhase.failed,
          message: message,
        ),
      );
  final Future<OperationResult> _completed;
  @override
  Future<OperationResult> get completed => _completed;
  @override
  Stream<OperationEvent> get events => const Stream.empty();
  @override
  Future<void> requestCancel() async {}
}
