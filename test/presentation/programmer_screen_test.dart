import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mushagaeshi_ic_programmer/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/controllers/programmer_controller.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/operation.dart';
import 'package:mushagaeshi_ic_programmer/core/models/programmer.dart';
import 'package:mushagaeshi_ic_programmer/core/ports/programmer_backend.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/programmers/mock/mock_programmer_backend.dart';
import 'package:mushagaeshi_ic_programmer/presentation/screens/programmer_screen.dart';
import 'package:mushagaeshi_ic_programmer/presentation/widgets/binary_viewer.dart';

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
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ProgrammerScreen(controller: subject),
      ),
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
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ProgrammerScreen(controller: subject),
        ),
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

  testWidgets('physical catalog status distinguishes authorized evaluation', (
    tester,
  ) async {
    const eligible = CatalogDevice(
      id: 'eligible',
      sourceId: 'INFOIC',
      sourceIndex: 0,
      aliasIndex: 0,
      database: 'INFOIC',
      vendor: 'Acme',
      isCustom: false,
      sourceName: '27C256',
      alias: '27C256',
      type: '1',
      codeMemorySize: '8000',
      flags: '0',
      packageDetails: '1C000000',
    );
    const unsupported = CatalogDevice(
      id: 'unsupported',
      sourceId: 'INFOIC',
      sourceIndex: 1,
      aliasIndex: 0,
      database: 'INFOIC',
      vendor: 'Acme',
      isCustom: false,
      sourceName: 'SMD',
      alias: 'SMD',
      type: '1',
      codeMemorySize: '8000',
      flags: '0',
      packageDetails: '9C000000',
    );
    final subject = ProgrammerController(
      backend: _PhysicalBackend(),
      profiles: const [mockEpromProfile],
      catalog: DeviceCatalog(const [eligible, unsupported]),
    );
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      subject.dispose();
    });
    subject.selectVendor('Acme');
    subject.selectDevice(eligible);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ProgrammerScreen(controller: subject),
      ),
    );
    expect(
      find.text('Hardware evaluation · not yet validated on this IC'),
      findsOneWidget,
    );

    subject.selectDevice(unsupported);
    await tester.pump();
    expect(
      find.text('Unsupported for authorized hardware evaluation'),
      findsOneWidget,
    );
  });

  testWidgets(
    'native left drop loads one arbitrary-extension input and releases scope',
    (tester) async {
      final subject = controller();
      final file = await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp('drop-test-');
        addTearDown(() => root.delete(recursive: true));
        return File('${root.path}/firmware.rom')..writeAsBytesSync([1, 2, 3]);
      });
      final releases = <String>[];
      const channel = MethodChannel('mushagaeshi/programmer_files');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'releaseDropScope') {
          releases.add(call.arguments as String);
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        subject.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ProgrammerScreen(controller: subject),
        ),
      );
      final viewer = tester.getRect(find.byType(BinaryViewer));
      final point = Offset(viewer.left + viewer.width * .25, viewer.center.dy);
      await _drop(tester, file!.path, point, token: 'left-token');
      await tester.pumpAndSettle();

      expect(subject.inputImage!.bytes, [1, 2, 3]);
      expect(subject.inputImage!.label, 'firmware.rom');
      expect(releases, ['left-token']);
    },
  );

  testWidgets('native right drop leaves input and readout unchanged', (
    tester,
  ) async {
    final subject = controller();
    subject.openBinary(const [7], label: 'existing.bin');
    final file = await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp('drop-test-');
      addTearDown(() => root.delete(recursive: true));
      return File('${root.path}/ignored.any')..writeAsBytesSync([1, 2, 3]);
    });
    const channel = MethodChannel('mushagaeshi/programmer_files');
    final releases = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'releaseDropScope') {
        releases.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      subject.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ProgrammerScreen(controller: subject),
      ),
    );
    final viewer = tester.getRect(find.byType(BinaryViewer));
    final point = Offset(viewer.left + viewer.width * .75, viewer.center.dy);
    await _drop(tester, file!.path, point, token: 'right-token');
    await tester.pumpAndSettle();

    expect(subject.inputImage!.bytes, [7]);
    expect(subject.readoutImage, isNull);
    expect(releases, ['right-token']);
  });

  testWidgets('native input drop is locked while an operation is busy', (
    tester,
  ) async {
    final subject = controller();
    subject.openBinary(const [7], label: 'existing.bin');
    subject.phase = OperationPhase.reading;
    final file = await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp('drop-test-');
      addTearDown(() => root.delete(recursive: true));
      return File('${root.path}/locked.bin')..writeAsBytesSync([1, 2, 3]);
    });
    const channel = MethodChannel('mushagaeshi/programmer_files');
    final releases = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'releaseDropScope') {
        releases.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      subject.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ProgrammerScreen(controller: subject),
      ),
    );
    final viewer = tester.getRect(find.byType(BinaryViewer));
    final point = Offset(viewer.left + viewer.width * .25, viewer.center.dy);
    await _drop(tester, file!.path, point, token: 'busy-token');
    await tester.pumpAndSettle();

    expect(subject.inputImage!.bytes, [7]);
    expect(releases, ['busy-token']);
  });
}

Future<void> _drop(
  WidgetTester tester,
  String path,
  Offset point, {
  required String token,
}) async {
  const codec = StandardMethodCodec();
  await tester.runAsync(
    () => tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'mushagaeshi/programmer_files',
      codec.encodeMethodCall(
        MethodCall('fileDropped', {
          'path': path,
          'x': point.dx,
          'y': point.dy,
          'scopeToken': token,
        }),
      ),
      (_) {},
    ),
  );
}

final class _PhysicalBackend implements ProgrammerBackend {
  @override
  String get backendId => 'physical-test';

  @override
  Future<BackendCapabilities> capabilities(
    ProgrammerConnection connection,
    DeviceProfile profile,
  ) async => const BackendCapabilities();

  @override
  OperationHandle execute(OperationPlan plan) => throw UnimplementedError();

  @override
  Future<List<ProgrammerConnection>> scan() async => const [];
}
