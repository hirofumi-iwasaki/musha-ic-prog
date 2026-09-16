import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/controllers/programmer_controller.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/operation.dart';
import 'package:mushagaeshi_ic_programmer/core/models/programmer.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/programmers/mock/mock_programmer_backend.dart';
import 'package:mushagaeshi_ic_programmer/presentation/screens/programmer_screen.dart';

void main() {
  ProgrammerController controller() => ProgrammerController(
    backend: MockProgrammerBackend(),
    profiles: const [mockEpromProfile],
    catalog: DeviceCatalog([
      const CatalogDevice(
        id: 'infoic:0',
        sourceId: 'INFOIC',
        sourceIndex: 0,
        aliasIndex: 0,
        database: 'INFOIC',
        vendor: 'Acme',
        isCustom: false,
        sourceName: '27C256,M27C256',
        alias: '27C256',
        type: '1',
        codeMemorySize: '32768',
        pins: '28',
      ),
    ]),
  );

  testWidgets('catalog selectors and status bar fit a 1000 by 700 workspace', (
    tester,
  ) async {
    final subject = controller();
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      subject.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(home: ProgrammerScreen(controller: subject)),
    );

    expect(find.text('Programmer'), findsOneWidget);
    expect(find.text('Vendor'), findsOneWidget);
    expect(find.text('Device'), findsOneWidget);
    expect(find.text('Simulation disconnected'), findsOneWidget);
    expect(find.textContaining('Idle:'), findsOneWidget);
    expect(tester.takeException(), isNull);

    subject.selectVendor('Acme');
    await tester.pump();
    expect(find.text('Search all 1 device records'), findsOneWidget);

    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(find.text('27C256'), findsOneWidget);
    await tester.tap(find.text('27C256'));
    await tester.pump();
    expect(subject.selectedDevice?.label, '27C256');
  });

  testWidgets(
    'busy status keeps the simulation connected and shows safety text',
    (tester) async {
      final subject = controller();
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        subject.dispose();
      });
      subject.connection = const ProgrammerConnection(
        backendId: 'mock',
        model: 'Mock TL866CS',
        identifier: 'test',
        firmware: 'mock',
        generation: 1,
      );
      subject.connectionStatus = ConnectionStatus.busy;
      subject.phase = OperationPhase.reading;
      subject.message = 'Reading all bytes';

      await tester.pumpWidget(
        MaterialApp(home: ProgrammerScreen(controller: subject)),
      );

      expect(
        find.text('Simulation connected · operation in progress'),
        findsOneWidget,
      );
      expect(find.textContaining('Reading: Reading all bytes'), findsOneWidget);
      expect(
        find.text(
          'Operation in progress — do not touch the programmer, IC or USB cable. Simulation only.',
        ),
        findsOneWidget,
      );

      subject.connectionStatus = ConnectionStatus.ready;
      subject.phase = OperationPhase.succeeded;
      subject.message = 'Read complete';
      subject.notifyListeners();
      await tester.pump();
      expect(
        find.text(
          'Operation in progress — do not touch the programmer, IC or USB cable. Simulation only.',
        ),
        findsNothing,
      );
    },
  );
}
