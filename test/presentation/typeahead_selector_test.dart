// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/controllers/programmer_controller.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/operation.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/programmers/mock/mock_programmer_backend.dart';
import 'package:mushagaeshi_ic_programmer/l10n/app_localizations.dart';
import 'package:mushagaeshi_ic_programmer/presentation/screens/programmer_screen.dart';

void main() {
  CatalogDevice device(String vendor, String name, int index) => CatalogDevice(
    id: '$vendor:$index',
    sourceId: 'INFOIC',
    sourceIndex: index,
    aliasIndex: 0,
    database: 'INFOIC',
    vendor: vendor,
    isCustom: false,
    sourceName: name,
    alias: name,
    type: '1',
    codeMemorySize: '8000',
    pins: '28',
  );
  ProgrammerController makeController() {
    var index = 0;
    return ProgrammerController(
      backend: MockProgrammerBackend(),
      profiles: const [mockEpromProfile],
      catalog: DeviceCatalog([
        for (final vendor in ['ACME', 'FAIRCHILD', 'FUJITSU', 'ZILOG'])
          for (final name in [
            '27C010',
            '27C020',
            '27C512',
            ...List.generate(220, (i) => 'A${i.toString().padLeft(3, '0')}'),
            'FA100',
            'FB200',
            'Z900',
          ])
            device(vendor, name, index++),
      ]),
    );
  }

  Future<void> pump(WidgetTester tester, ProgrammerController c) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      c.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ProgrammerScreen(controller: c),
      ),
    );
  }

  Future<void> key(
    WidgetTester tester,
    LogicalKeyboardKey key, [
    String? character,
  ]) async {
    await tester.sendKeyEvent(key, character: character);
    await tester.pumpAndSettle();
  }

  testWidgets('vendor repeated initial cycles and wraps; only Enter commits', (
    tester,
  ) async {
    final c = makeController();
    await pump(tester, c);
    await tester.tap(find.byKey(const ValueKey('vendor-selector')));
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.keyF, 'f');
    expect(c.selectedVendor, isNull);
    await key(tester, LogicalKeyboardKey.keyF, 'F');
    await key(tester, LogicalKeyboardKey.enter);
    expect(c.selectedVendor, 'FUJITSU');
    await tester.tap(find.byKey(const ValueKey('vendor-selector')));
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.keyF, 'f');
    await key(tester, LogicalKeyboardKey.keyF, 'f');
    await key(tester, LogicalKeyboardKey.keyF, 'f');
    await key(tester, LogicalKeyboardKey.enter);
    expect(c.selectedVendor, 'FAIRCHILD');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'prefix, timeout, unmatched input and Escape preserve selection',
    (tester) async {
      final c = makeController()..selectVendor('ACME');
      await pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('vendor-selector')));
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.keyF, 'f');
      await key(tester, LogicalKeyboardKey.keyU, 'u');
      await key(tester, LogicalKeyboardKey.enter);
      expect(c.selectedVendor, 'FUJITSU');
      await tester.tap(find.byKey(const ValueKey('vendor-selector')));
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.keyF, 'f');
      await key(tester, LogicalKeyboardKey.keyU, 'u');
      await tester.pump(const Duration(seconds: 1));
      await key(tester, LogicalKeyboardKey.keyF, 'f');
      await key(tester, LogicalKeyboardKey.enter);
      expect(c.selectedVendor, 'FAIRCHILD');
      await tester.tap(find.byKey(const ValueKey('vendor-selector')));
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.keyZ, 'z');
      await key(tester, LogicalKeyboardKey.keyQ, 'q');
      await key(tester, LogicalKeyboardKey.escape);
      expect(c.selectedVendor, 'FAIRCHILD');
      expect(find.byKey(const ValueKey('typeahead-popup')), findsNothing);
    },
  );

  testWidgets(
    'unmatched letters and modified shortcuts do not move highlight',
    (tester) async {
      final c = makeController();
      await pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('vendor-selector')));
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.keyF, 'f');
      await key(tester, LogicalKeyboardKey.keyQ, 'q');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ, character: 'z');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.enter);
      expect(c.selectedVendor, 'FAIRCHILD');
    },
  );

  testWidgets(
    'device dropdown navigates full list and scrolls distant matches into view',
    (tester) async {
      final c = makeController()..selectVendor('FAIRCHILD');
      await pump(tester, c);
      await tester.tap(find.byKey(const ValueKey('device-dropdown')));
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.keyF, 'f');
      expect(find.text('FA100').hitTestable(), findsOneWidget);
      expect(c.selectedDevice, isNull);
      await key(tester, LogicalKeyboardKey.keyF, 'f');
      await key(tester, LogicalKeyboardKey.enter);
      expect(c.selectedDevice?.label, 'FB200');
      await tester.tap(find.byKey(const ValueKey('device-dropdown')));
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.home);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.enter);
      expect(c.selectedDevice?.label, '27C020');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'device text search still filters by substring and Enter selects',
    (tester) async {
      final c = makeController()..selectVendor('FAIRCHILD');
      await pump(tester, c);
      await tester.enterText(find.byType(EditableText), 'C51');
      await tester.pumpAndSettle();
      expect(find.text('27C512'), findsOneWidget);
      // Text fields receive the platform Enter/Done action through the text input channel.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(c.selectedDevice?.label, '27C512');
    },
  );

  testWidgets('device popup cancellation and busy state cannot change device', (
    tester,
  ) async {
    final c = makeController()..selectVendor('FAIRCHILD');
    final initial = c.findCatalogDevices(query: '27C010').first;
    c.selectDevice(initial);
    await pump(tester, c);
    await tester.tap(find.byKey(const ValueKey('device-dropdown')));
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.end);
    await key(tester, LogicalKeyboardKey.escape);
    expect(c.selectedDevice, initial);
    await tester.tap(find.byKey(const ValueKey('device-dropdown')));
    await tester.pumpAndSettle();
    c.phase = OperationPhase.reading;
    c.notifyListeners();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.end);
    await key(tester, LogicalKeyboardKey.enter);
    expect(c.selectedDevice, initial);
    expect(tester.takeException(), isNull);
  });
}
