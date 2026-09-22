import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/controllers/programmer_controller.dart';
import 'package:mushagaeshi_ic_programmer/core/models/binary_image.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/operation.dart';
import 'package:mushagaeshi_ic_programmer/core/models/programmer.dart';
import 'package:mushagaeshi_ic_programmer/core/ports/programmer_backend.dart';

void main() {
  late _ScanBackend cs;
  late _ScanBackend plus;
  late _ScanBackend a;
  late ProgrammerController controller;
  setUp(() {
    cs = _ScanBackend('TL866CS');
    a = _ScanBackend('TL866A');
    plus = _ScanBackend('TL866II Plus');
    controller = ProgrammerController(
      backend: cs,
      profiles: const [],
      realBackends: {
        ProgrammerOption.tl866cs.id: cs,
        ProgrammerOption.tl866a.id: a,
        ProgrammerOption.tl866iiPlus.id: plus,
      },
    );
  });
  tearDown(() => controller.dispose());

  test(
    'switching programmer invalidates target and preserves binary snapshots',
    () async {
      await controller.connectProgrammer();
      controller.openBinary([1, 2], label: 'input');
      controller.readoutImage = BinaryImage(
        bytes: [3, 4],
        origin: BinaryImageOrigin.readout,
        label: 'TL866CS 27C512',
      );
      controller.selectProfile(mockEpromProfile);
      final input = controller.inputImage;
      final readout = controller.readoutImage;
      expect(controller.availableProgrammers, [
        ProgrammerOption.tl866cs,
        ProgrammerOption.tl866a,
        ProgrammerOption.tl866iiPlus,
      ]);
      controller.selectProgrammer(ProgrammerOption.tl866iiPlus);
      expect(controller.connection, isNull);
      expect(controller.connectionStatus, ConnectionStatus.disconnected);
      expect(controller.selectedProfile, isNull);
      expect(controller.inputImage, same(input));
      expect(controller.readoutImage, same(readout));
      expect(controller.readoutIsPreviousTarget, isTrue);
      expect(controller.canRead, isFalse);
      expect(controller.uiMessage!['programmer'], 'TL866II Plus');
      await controller.connectProgrammer();
      expect(cs.scans, 1);
      expect(plus.scans, 1);
      expect(controller.connection!.model, 'TL866II Plus');
      expect(controller.backendStatusMessage['programmer'], 'TL866II Plus');
    },
  );

  test(
    'switching from CS to A clears the old connection and uses A backend',
    () async {
      await controller.connectProgrammer();
      controller.selectProfile(mockEpromProfile);
      controller.selectProgrammer(ProgrammerOption.tl866a);
      expect(controller.connection, isNull);
      expect(controller.selectedProfile, isNull);
      await controller.connectProgrammer();
      expect(controller.connection!.model, 'TL866A');
      expect(a.scans, 1);
      expect(cs.scans, 1);
      expect(controller.backendStatusMessage['programmer'], 'TL866A');
    },
  );

  test('busy and confirmation phases prevent model changes', () {
    for (final phase in [
      OperationPhase.reading,
      OperationPhase.programming,
      OperationPhase.awaitingConfirmation,
    ]) {
      controller.phase = phase;
      controller.selectProgrammer(ProgrammerOption.tl866iiPlus);
      expect(controller.selectedProgrammer, ProgrammerOption.tl866cs);
    }
  });

  test('unsupported and forged programmer choices cannot select a backend', () {
    for (final option in ProgrammerOption.futureOptions) {
      if (option.id == ProgrammerOption.tl866iiPlus.id) continue;
      controller.selectProgrammer(option);
      expect(controller.selectedProgrammer, ProgrammerOption.tl866cs);
    }
    controller.selectProgrammer(
      const ProgrammerOption(
        id: 'fake',
        label: 'Fake',
        databaseTypes: {'INFOIC'},
        available: true,
      ),
    );
    expect(controller.selectedProgrammer, ProgrammerOption.tl866cs);
  });
}

class _ScanBackend implements ProgrammerBackend {
  _ScanBackend(this.model);
  final String model;
  int scans = 0;
  @override
  String get backendId => model;
  @override
  Future<List<ProgrammerConnection>> scan() async {
    scans++;
    return [
      ProgrammerConnection(
        backendId: backendId,
        model: model,
        identifier: model,
        firmware: 'test',
        generation: scans,
      ),
    ];
  }

  @override
  Future<BackendCapabilities> capabilities(
    ProgrammerConnection connection,
    DeviceProfile profile,
  ) async => const BackendCapabilities();
  @override
  OperationHandle execute(OperationPlan plan) => throw UnimplementedError();
}
