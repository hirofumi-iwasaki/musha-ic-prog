// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/core/models/binary_image.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/operation.dart';
import 'package:mushagaeshi_ic_programmer/core/models/programmer.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/programmers/minipro/minipro_tl866_backend.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/programmers/minipro/process_runner.dart';

final class _FakeProcess implements ExternalProcess {
  _FakeProcess(this.out, {this.err = '', this.code = 0});
  final String out;
  final String err;
  final int code;
  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(out));
  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(err));
  @override
  Future<int> get exitCode async => code;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

final class _FakeRunner implements ProcessRunner {
  _FakeRunner(this.responses);
  final List<_FakeProcess> responses;
  final List<List<String>> calls = [];
  @override
  Future<ExternalProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    calls.add([executable, ...arguments]);
    expect(environment, const {'LC_ALL': 'C', 'LANG': 'C'});
    return responses.removeAt(0);
  }
}

Future<Directory> _bundle() async {
  final root = await Directory.systemTemp.createTemp('minipro-test-');
  for (final name in ['minipro', 'probe', 'infoic.xml', 'logicic.xml']) {
    await File('${root.path}/$name').writeAsString('fixture');
  }
  return root;
}

void main() {
  test(
    'scan accepts exactly one TL866CS with a parsed firmware identity',
    () async {
      final root = await _bundle();
      addTearDown(() => root.delete(recursive: true));
      final runner = _FakeRunner([
        _FakeProcess(
          '{"count":1,"devices":[{"vendorId":"04d8","productId":"e11c","bus":1,"address":2}]}',
        ),
        _FakeProcess('', err: 'tl866a: TL866CS'),
        _FakeProcess('Found TL866CS 03.2.86 (0x256)'),
      ]);
      final backend = MiniproTl866Backend(
        paths: MiniproBundlePaths(
          executable: '${root.path}/minipro',
          probe: '${root.path}/probe',
          infoic: '${root.path}/infoic.xml',
          logicic: '${root.path}/logicic.xml',
        ),
        runner: runner,
      );
      final result = await backend.scan();
      expect(result, hasLength(1));
      expect(result.single.identifier, 'usb-1-2');
      expect(result.single.firmware, '03.2.86 0x256');
      expect(runner.calls, hasLength(3));
      expect(runner.calls[1], contains('-k'));
      expect(
        runner.calls[2],
        containsAll([
          '--infoic',
          '${root.path}/infoic.xml',
          '--logicic',
          '${root.path}/logicic.xml',
          '-V',
        ]),
      );
    },
  );

  test(
    'scan refuses multiple matching USB devices before invoking minipro',
    () async {
      final root = await _bundle();
      addTearDown(() => root.delete(recursive: true));
      final runner = _FakeRunner([
        _FakeProcess(
          '{"count":2,"devices":[{"vendorId":"04d8","productId":"e11c",'
          '"bus":1,"address":2},{"vendorId":"04d8","productId":"e11c",'
          '"bus":1,"address":3}]}',
        ),
      ]);
      final backend = MiniproTl866Backend(
        paths: MiniproBundlePaths(
          executable: '${root.path}/minipro',
          probe: '${root.path}/probe',
          infoic: '${root.path}/infoic.xml',
          logicic: '${root.path}/logicic.xml',
        ),
        runner: runner,
      );
      expect(await backend.scan(), isEmpty);
      expect(backend.discoveryReason, contains('More than one'));
      expect(runner.calls, hasLength(1));
    },
  );

  test('unapproved profile is denied without a minipro device query', () async {
    final root = await _bundle();
    addTearDown(() => root.delete(recursive: true));
    final runner = _FakeRunner([]);
    final backend = MiniproTl866Backend(
      paths: MiniproBundlePaths(
        executable: '${root.path}/minipro',
        probe: '${root.path}/probe',
        infoic: '${root.path}/infoic.xml',
        logicic: '${root.path}/logicic.xml',
      ),
      runner: runner,
    );
    const connection = ProgrammerConnection(
      backendId: 'minipro-tl866cs',
      model: 'TL866CS',
      identifier: 'usb-1-2',
      firmware: '03.2.86 0x256',
      generation: 1,
    );
    const profile = DeviceProfile(
      stableId: 'p',
      manufacturer: 'Test',
      partNumber: 'Test',
      packageName: 'DIP28',
      kind: DeviceKind.memory,
      capacityBytes: 32768,
      socketPlacement: 'test',
      verified: false,
      miniproAlias: 'TEST27',
      miniproDatabase: 'INFOIC',
      expectedMiniproPackage: 'DIP28',
    );
    final caps = await backend.capabilities(connection, profile);
    expect(caps.canRead, isFalse);
    expect(caps.reason, contains('not approved'));
    expect(runner.calls, isEmpty);
  });
  group('native payload locator', () {
    test('preserves the macOS app bundle layout', () {
      final paths = NativePayloadLocator(
        resolvedExecutable: '/Applications/Musha.app/Contents/MacOS/musha',
        operatingSystem: 'macos',
      ).locate();
      expect(
        paths.executable,
        '/Applications/Musha.app/Contents/MacOS/minipro',
      );
      expect(paths.probe, '/Applications/Musha.app/Contents/MacOS/tl866_probe');
      expect(
        paths.infoic,
        '/Applications/Musha.app/Contents/Resources/minipro/infoic.xml',
      );
    });

    test('uses portable Windows and Linux package layouts', () {
      final windows = NativePayloadLocator(
        resolvedExecutable:
            r'C:\Program Files\Musha\mushagaeshi_ic_programmer.exe',
        operatingSystem: 'windows',
      ).locate();
      expect(windows.executable, r'C:\Program Files\Musha\native\minipro.exe');
      expect(windows.probe, r'C:\Program Files\Musha\native\tl866_probe.exe');
      expect(
        windows.logicic,
        r'C:\Program Files\Musha\resources\minipro\logicic.xml',
      );
      final linux = NativePayloadLocator(
        resolvedExecutable: '/opt/musha/mushagaeshi_ic_programmer',
        operatingSystem: 'linux',
      ).locate();
      expect(linux.executable, '/opt/musha/native/minipro');
      expect(linux.probe, '/opt/musha/native/tl866_probe');
    });
  });

  test('scan keeps a Windows SetupAPI identity opaque', () async {
    final root = await _bundle();
    addTearDown(() => root.delete(recursive: true));
    final runner = _FakeRunner([
      _FakeProcess(
        '{"count":1,"devices":[{"vendorId":"04d8","productId":"e11c",'
        '"identity":"\\\\?\\\\usb#vid_04d8&pid_e11c#opaque",'
        '"interfaceReady":true,"driverService":"WinUSB"}]}',
      ),
      _FakeProcess('', err: 'tl866a: TL866CS'),
      _FakeProcess('Found TL866CS 03.2.86 (0x256)'),
    ]);
    final backend = MiniproTl866Backend(
      paths: MiniproBundlePaths(
        executable: '${root.path}/minipro',
        probe: '${root.path}/probe',
        infoic: '${root.path}/infoic.xml',
        logicic: '${root.path}/logicic.xml',
      ),
      runner: runner,
      operatingSystem: 'windows',
    );
    final result = await backend.scan();
    expect(result, hasLength(1));
    expect(result.single.identifier, startsWith('usb-'));
    expect(result.single.identifier, isNot(contains('vid_04d8')));
  });

  test(
    'scan reports a Windows driver readiness problem without minipro',
    () async {
      final root = await _bundle();
      addTearDown(() => root.delete(recursive: true));
      final runner = _FakeRunner([
        _FakeProcess(
          '{"count":1,"devices":[{"vendorId":"04d8","productId":"e11c",'
          '"identity":"opaque","interfaceReady":false,"driverService":"usbccgp"}]}',
        ),
      ]);
      final backend = MiniproTl866Backend(
        paths: MiniproBundlePaths(
          executable: '${root.path}/minipro',
          probe: '${root.path}/probe',
          infoic: '${root.path}/infoic.xml',
          logicic: '${root.path}/logicic.xml',
        ),
        runner: runner,
        operatingSystem: 'windows',
      );
      expect(await backend.scan(), isEmpty);
      expect(backend.discoveryReason, contains('WinUSB'));
      expect(runner.calls, hasLength(1));
    },
  );
  operationContractTests();
}

final class _ScriptedRunner implements ProcessRunner {
  _ScriptedRunner(this._respond);
  final Future<_FakeProcess> Function(List<String> arguments) _respond;
  final List<List<String>> calls = [];

  @override
  Future<ExternalProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    expect(environment, const {'LC_ALL': 'C', 'LANG': 'C'});
    calls.add([executable, ...arguments]);
    return _respond(arguments);
  }
}

const _fixtureConnection = ProgrammerConnection(
  backendId: 'minipro-tl866cs',
  model: 'TL866CS',
  identifier: 'usb-1-2',
  firmware: '03.2.86 0x256',
  generation: 1,
);

const _approvedProfile = DeviceProfile(
  stableId: 'test-approved',
  manufacturer: 'Test',
  partNumber: 'TEST27',
  packageName: 'DIP28',
  kind: DeviceKind.memory,
  capacityBytes: 4,
  socketPlacement: 'test',
  verified: false,
  evaluationAuthorized: true,
  miniproAlias: 'TEST27',
  miniproDatabase: 'INFOIC',
  expectedMiniproPackage: 'DIP28',
);

Future<_FakeProcess> _identityOrValidation(
  List<String> args, {
  required List<int> readBytes,
  int blankCode = 0,
  int writeCode = 0,
}) async {
  if (args.isEmpty) {
    return _FakeProcess(
      '{"count":1,"devices":[{"vendorId":"04d8","productId":"e11c","bus":1,"address":2}]}',
    );
  }
  if (args.contains('-k')) return _FakeProcess('', err: 'tl866a: TL866CS');
  if (args.contains('-V')) return _FakeProcess('Found TL866CS 03.2.86 (0x256)');
  if (args.contains('-d')) {
    return _FakeProcess(
      'Name: TEST27\nMemory: 4 Bytes\nPackage: DIP28\nAvailable on: TL866A/CS',
    );
  }
  if (args.contains('-r')) {
    await File(args.last).writeAsBytes(readBytes);
    return _FakeProcess('read');
  }
  if (args.contains('-b')) return _FakeProcess('blank', code: blankCode);
  if (args.contains('-w')) return _FakeProcess('write', code: writeCode);
  throw StateError('Unexpected minipro arguments: $args');
}

Future<OperationResult> _executeScripted(
  Directory root,
  OperationKind kind,
  _ScriptedRunner runner, {
  List<int>? input,
}) async {
  final backend = MiniproTl866Backend(
    paths: MiniproBundlePaths(
      executable: '${root.path}/minipro',
      probe: '${root.path}/probe',
      infoic: '${root.path}/infoic.xml',
      logicic: '${root.path}/logicic.xml',
    ),
    runner: runner,
  );
  final snapshot = input == null
      ? null
      : BinaryImage(
          bytes: input,
          origin: BinaryImageOrigin.file,
          label: 'input.bin',
        );
  return backend
      .execute(
        OperationPlan(
          operationId: 'test-${kind.name}',
          kind: kind,
          connection: _fixtureConnection,
          profile: _approvedProfile,
          input: snapshot,
        ),
      )
      .completed;
}

void operationContractTests() {
  test('read accepts exact size and rejects partial output', () async {
    final root = await _bundle();
    addTearDown(() => root.delete(recursive: true));
    final ok = _ScriptedRunner(
      (args) => _identityOrValidation(args, readBytes: [1, 2, 3, 4]),
    );
    final result = await _executeScripted(root, OperationKind.read, ok);
    expect(result.succeeded, isTrue);
    expect(result.image!.bytes, [1, 2, 3, 4]);
    final partial = _ScriptedRunner(
      (args) => _identityOrValidation(args, readBytes: [1, 2, 3]),
    );
    final failure = await _executeScripted(root, OperationKind.read, partial);
    expect(failure.phase, OperationPhase.failed);
    expect(failure.message, contains('size'));
  });

  test('program does not write after a failed blank check', () async {
    final root = await _bundle();
    addTearDown(() => root.delete(recursive: true));
    final runner = _ScriptedRunner(
      (args) =>
          _identityOrValidation(args, readBytes: [1, 2, 3, 4], blankCode: 1),
    );
    final result = await _executeScripted(
      root,
      OperationKind.program,
      runner,
      input: [1, 2, 3, 4],
    );
    expect(result.phase, OperationPhase.failed);
    expect(runner.calls.where((call) => call.contains('-w')), isEmpty);
  });

  test(
    'program writes immutable input with code flags and returns readback',
    () async {
      final root = await _bundle();
      addTearDown(() => root.delete(recursive: true));
      final bytes = [1, 2, 3, 4];
      List<int>? written;
      final runner = _ScriptedRunner((args) async {
        if (args.contains('-w')) written = await File(args.last).readAsBytes();
        return _identityOrValidation(args, readBytes: [1, 2, 3, 4]);
      });
      final future = _executeScripted(
        root,
        OperationKind.program,
        runner,
        input: bytes,
      );
      bytes[0] = 9;
      final result = await future;
      expect(result.succeeded, isTrue);
      expect(result.image!.origin, BinaryImageOrigin.postWriteVerification);
      final write = runner.calls.singleWhere((call) => call.contains('-w'));
      expect(write, containsAll(['-e', '-w', '-c', 'code']));
      expect(written, [1, 2, 3, 4]);
      expect(await File(write.last).exists(), isFalse);
    },
  );

  test('write failure and readback differences require recovery', () async {
    final root = await _bundle();
    addTearDown(() => root.delete(recursive: true));
    final writeFailure = _ScriptedRunner(
      (args) =>
          _identityOrValidation(args, readBytes: [1, 2, 3, 4], writeCode: 1),
    );
    final failed = await _executeScripted(
      root,
      OperationKind.program,
      writeFailure,
      input: [1, 2, 3, 4],
    );
    expect(failed.phase, OperationPhase.recoveryRequired);
    final mismatch = _ScriptedRunner(
      (args) => _identityOrValidation(args, readBytes: [1, 9, 3, 8]),
    );
    final differed = await _executeScripted(
      root,
      OperationKind.program,
      mismatch,
      input: [1, 2, 3, 4],
    );
    expect(differed.phase, OperationPhase.recoveryRequired);
    expect(differed.mismatchCount, 2);
    expect(differed.image!.bytes, [1, 9, 3, 8]);
  });

  test('cancellation before writing does not start a write command', () async {
    final root = await _bundle();
    addTearDown(() => root.delete(recursive: true));
    final holdPreWriteScan = Completer<void>();
    var probes = 0;
    final runner = _ScriptedRunner((args) async {
      if (args.isEmpty && ++probes == 2) await holdPreWriteScan.future;
      return _identityOrValidation(args, readBytes: [1, 2, 3, 4]);
    });
    final backend = MiniproTl866Backend(
      paths: MiniproBundlePaths(
        executable: '${root.path}/minipro',
        probe: '${root.path}/probe',
        infoic: '${root.path}/infoic.xml',
        logicic: '${root.path}/logicic.xml',
      ),
      runner: runner,
    );
    final handle = backend.execute(
      OperationPlan(
        operationId: 'cancel-before-write',
        kind: OperationKind.program,
        connection: _fixtureConnection,
        profile: _approvedProfile,
        input: BinaryImage(
          bytes: [1, 2, 3, 4],
          origin: BinaryImageOrigin.file,
          label: 'input.bin',
        ),
      ),
    );
    while (probes < 2) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await handle.requestCancel();
    holdPreWriteScan.complete();
    final result = await handle.completed;
    expect(result.phase, OperationPhase.cancelled);
    expect(runner.calls.where((call) => call.contains('-w')), isEmpty);
  });

  test(
    'verify reads and compares bytes without minipro verify switch',
    () async {
      final root = await _bundle();
      addTearDown(() => root.delete(recursive: true));
      final runner = _ScriptedRunner(
        (args) => _identityOrValidation(args, readBytes: [1, 9, 3, 8]),
      );
      final result = await _executeScripted(
        root,
        OperationKind.verify,
        runner,
        input: [1, 2, 3, 4],
      );
      expect(result.phase, OperationPhase.failed);
      expect(result.mismatchCount, 2);
      expect(runner.calls.where((call) => call.contains('-m')), isEmpty);
      expect(runner.calls.where((call) => call.contains('-r')), hasLength(1));
    },
  );
}
