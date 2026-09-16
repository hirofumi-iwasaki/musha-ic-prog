// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async' show unawaited;

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
