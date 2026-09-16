// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async' show Completer, unawaited;

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/controllers/programmer_controller.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/operation.dart';
import 'package:mushagaeshi_ic_programmer/core/models/programmer.dart';
import 'package:mushagaeshi_ic_programmer/core/ports/programmer_backend.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/programmers/mock/mock_programmer_backend.dart';

void main() {
  ProgrammerController controller({Duration delay = Duration.zero}) =>
      ProgrammerController(
        backend: MockProgrammerBackend(stepDelay: delay),
        profiles: const [mockEpromProfile],
      );

  test('program requires confirmation then verifies immutable input', () async {
    final subject = controller();
    await subject.connectMock();
    subject.selectProfile(mockEpromProfile);
    final bytes = List<int>.filled(mockEpromProfile.capacityBytes!, 0xa5);
    subject.openBinary(bytes, label: 'pattern.bin');
    bytes[0] = 0;

    subject.requestProgram();
    expect(subject.needsProgramConfirmation, isTrue);
    expect(subject.inputImage!.bytes.first, 0xa5);

    await subject.confirmProgram();
    expect(subject.phase, OperationPhase.succeeded);
    await subject.verify();
    expect(subject.lastResult!.succeeded, isTrue);
    subject.dispose();
  });

  test('oversized input preserves the prior immutable snapshot', () {
    final subject = controller();
    subject.openBinary(const [1, 2, 3], label: 'valid.bin');
    final previous = subject.inputImage;
    subject.openBinary(
      List<int>.filled(ProgrammerController.maxInputBytes + 1, 0),
      label: 'large.bin',
    );

    expect(subject.inputImage, same(previous));
    expect(subject.blockedReason, contains('64 MiB'));
    subject.dispose();
  });

  test('reconnect is refused while an operation is active', () async {
    final subject = controller(delay: const Duration(milliseconds: 15));
    await subject.connectMock();
    subject.selectProfile(mockEpromProfile);
    final pendingRead = subject.read();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await subject.connectMock();

    expect(subject.connectionStatus, ConnectionStatus.busy);
    expect(subject.message, contains('Wait for the current operation'));
    await pendingRead;
    subject.dispose();
  });

  test('a backend startup exception releases the busy state', () async {
    final subject = ProgrammerController(
      backend: _ThrowingMockBackend(),
      profiles: const [mockEpromProfile],
    );
    await subject.connectMock();
    subject.selectProfile(mockEpromProfile);
    await subject.read();

    expect(subject.phase, OperationPhase.failed);
    expect(subject.connectionStatus, ConnectionStatus.ready);
    subject.dispose();
  });

  test(
    'disposing during an operation suppresses late state notifications',
    () async {
      final subject = controller(delay: const Duration(milliseconds: 15));
      await subject.connectMock();
      subject.selectProfile(mockEpromProfile);
      var notifications = 0;
      subject.addListener(() => notifications++);
      unawaited(subject.read());
      await Future<void>.delayed(const Duration(milliseconds: 1));
      subject.dispose();
      final atDisposal = notifications;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(notifications, atDisposal);
    },
  );

  test('catalog browsing cannot retain the mock operation profile', () {
    const listed = CatalogDevice(
      id: 'infoic:INFOIC:0:0',
      sourceId: 'infoic',
      sourceIndex: 0,
      aliasIndex: 0,
      database: 'INFOIC',
      vendor: 'Vendor',
      isCustom: false,
      sourceName: 'Example,Example@DIP',
      alias: 'Example',
      type: '1',
    );
    final subject = ProgrammerController(
      backend: MockProgrammerBackend(),
      profiles: const [mockEpromProfile],
      catalog: DeviceCatalog(const [listed]),
    );
    subject.selectProfile(mockEpromProfile);
    subject.selectVendor('Vendor');
    expect(subject.selectedProfile, isNull);
    subject.selectDevice(listed);
    expect(subject.selectedDevice, same(listed));
    subject.selectProfile(mockEpromProfile);

    expect(subject.selectedDevice, isNull);
    expect(subject.selectedVendor, isNull);
    subject.dispose();
  });

  test('catalog replacement clears an alias that becomes ambiguous', () {
    const selected = CatalogDevice(
      id: 'infoic:0:0',
      sourceId: 'INFOIC:0',
      sourceIndex: 0,
      aliasIndex: 0,
      database: 'INFOIC',
      vendor: 'Vendor',
      isCustom: false,
      sourceName: 'TEST27',
      alias: 'TEST27',
      type: '1',
      codeMemorySize: '4',
      flags: '0',
      packageDetails: '1C000000',
    );
    const duplicate = CatalogDevice(
      id: 'infoic:1:0',
      sourceId: 'INFOIC:1',
      sourceIndex: 1,
      aliasIndex: 0,
      database: 'INFOIC',
      vendor: 'Vendor',
      isCustom: true,
      sourceName: 'TEST27 alternate',
      alias: 'test27',
      type: '1',
      codeMemorySize: '4',
      flags: '0',
      packageDetails: '1C000000',
    );
    final subject = ProgrammerController(
      backend: MockProgrammerBackend(),
      profiles: const [mockEpromProfile],
      catalog: DeviceCatalog(const [selected]),
    );
    subject.selectVendor('Vendor');
    subject.selectDevice(selected);
    expect(subject.selectedProfile, isNotNull);
    subject.replaceCatalog(DeviceCatalog(const [selected, duplicate]));
    expect(subject.selectedProfile, isNull);
    subject.dispose();
  });

  test('only TL866CS is available for selection', () {
    final subject = controller();

    expect(subject.availableProgrammers, [ProgrammerOption.tl866cs]);
    subject.dispose();
  });

  test(
    'connection scan shows an optional backend readiness diagnostic',
    () async {
      final subject = ProgrammerController(
        backend: _DiagnosticScanBackend(),
        profiles: const [mockEpromProfile],
      );

      await subject.connectProgrammer();

      expect(subject.connectionStatus, ConnectionStatus.disconnected);
      expect(subject.connection, isNull);
      expect(subject.blockedReason, 'TL866CS driver is not ready.');
      expect(subject.message, 'TL866CS driver is not ready.');
      subject.dispose();
    },
  );

  test(
    'one scan runs at a time and a mode swap ignores its stale result',
    () async {
      final real = _DeferredScanBackend();
      final subject = ProgrammerController(
        backend: real,
        simulationBackend: MockProgrammerBackend(),
        profiles: const [mockEpromProfile],
      );

      final firstScan = subject.connectProgrammer();
      expect(subject.isConnecting, isTrue);
      await subject.connectProgrammer();
      expect(real.scanCalls, 1);

      subject.useSimulationDemo();
      expect(subject.usingSimulation, isTrue);
      expect(subject.isConnecting, isFalse);
      real.completeScan();
      await firstScan;

      expect(subject.connection, isNull);
      expect(subject.connectionStatus, ConnectionStatus.disconnected);
      subject.dispose();
    },
  );

  test(
    'a physical operation failure clears connection and requires refresh',
    () async {
      final subject = ProgrammerController(
        backend: _FailingPhysicalBackend(),
        profiles: const [_physicalProfile],
      );
      await subject.connectProgrammer();
      subject.selectProfile(_physicalProfile);

      await subject.read();

      expect(subject.phase, OperationPhase.failed);
      expect(subject.connection, isNull);
      expect(subject.connectionStatus, ConnectionStatus.disconnected);
      expect(subject.message, contains('Refresh TL866CS connection'));
      subject.dispose();
    },
  );
}

const _physicalProfile = DeviceProfile(
  stableId: 'physical-test',
  manufacturer: 'Test',
  partNumber: '27C256',
  packageName: 'DIP-28',
  kind: DeviceKind.memory,
  capacityBytes: 32 * 1024,
  socketPlacement: 'Validated test fixture',
  verified: false,
  evaluationAuthorized: true,
  miniproAlias: '27C256',
  miniproDatabase: 'INFOIC',
  expectedMiniproPackage: 'DIP28',
);

final class _DeferredScanBackend implements ProgrammerBackend {
  final Completer<List<ProgrammerConnection>> _scan = Completer();
  int scanCalls = 0;

  @override
  String get backendId => 'physical-test';

  @override
  Future<List<ProgrammerConnection>> scan() {
    scanCalls++;
    return _scan.future;
  }

  void completeScan() => _scan.complete(const [
    ProgrammerConnection(
      backendId: 'physical-test',
      model: 'TL866CS',
      identifier: 'stale',
      firmware: 'test',
      generation: 1,
    ),
  ]);

  @override
  Future<BackendCapabilities> capabilities(
    ProgrammerConnection connection,
    DeviceProfile profile,
  ) async => const BackendCapabilities();

  @override
  OperationHandle execute(OperationPlan plan) => throw UnimplementedError();
}

final class _DiagnosticScanBackend
    implements ProgrammerBackend, ProgrammerDiscoveryDiagnostics {
  @override
  String get backendId => 'physical-test';

  @override
  String get discoveryReason => 'TL866CS driver is not ready.';

  @override
  Future<List<ProgrammerConnection>> scan() async => const [];

  @override
  Future<BackendCapabilities> capabilities(
    ProgrammerConnection connection,
    DeviceProfile profile,
  ) async => const BackendCapabilities();

  @override
  OperationHandle execute(OperationPlan plan) => throw UnimplementedError();
}

final class _FailingPhysicalBackend implements ProgrammerBackend {
  @override
  String get backendId => 'physical-test';

  @override
  Future<List<ProgrammerConnection>> scan() async => const [
    ProgrammerConnection(
      backendId: 'physical-test',
      model: 'TL866CS',
      identifier: 'test',
      firmware: 'test',
      generation: 1,
    ),
  ];

  @override
  Future<BackendCapabilities> capabilities(
    ProgrammerConnection connection,
    DeviceProfile profile,
  ) async => const BackendCapabilities(canRead: true);

  @override
  OperationHandle execute(OperationPlan plan) =>
      _FailedHandle(plan.operationId);
}

final class _FailedHandle implements OperationHandle {
  const _FailedHandle(this._operationId);

  final String _operationId;

  @override
  Stream<OperationEvent> get events => const Stream.empty();

  @override
  Future<OperationResult> get completed async => OperationResult(
    operationId: _operationId,
    phase: OperationPhase.failed,
    message: 'Transport response was incomplete.',
  );

  @override
  Future<void> requestCancel() async {}
}

final class _ThrowingMockBackend implements ProgrammerBackend {
  @override
  String get backendId => 'mock';

  @override
  Future<BackendCapabilities> capabilities(
    ProgrammerConnection connection,
    DeviceProfile profile,
  ) async => const BackendCapabilities(canRead: true);

  @override
  OperationHandle execute(OperationPlan plan) =>
      throw StateError('not available');

  @override
  Future<List<ProgrammerConnection>> scan() async => const [
    ProgrammerConnection(
      backendId: 'mock',
      model: 'throwing mock',
      identifier: 'test',
      firmware: 'test',
      generation: 1,
    ),
  ];
}
