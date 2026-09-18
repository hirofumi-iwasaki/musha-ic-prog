// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/controllers/programmer_controller.dart';
import 'package:mushagaeshi_ic_programmer/application/language_controller.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/operation.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/programmers/mock/mock_programmer_backend.dart';
import 'package:mushagaeshi_ic_programmer/main.dart';
import 'package:mushagaeshi_ic_programmer/presentation/screens/programmer_screen.dart';
import 'package:mushagaeshi_ic_programmer/l10n/app_localizations.dart';

void main() {
  Future<void> size(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.binding.platformDispatcher.clearLocalesTestValue();
    });
  }

  ProgrammerController programmer() => ProgrammerController(
    backend: MockProgrammerBackend(),
    profiles: const [mockEpromProfile],
  );
  String locale(WidgetTester tester) =>
      Localizations.localeOf(tester.element(find.byType(ProgrammerScreen)))
          .languageCode;

  testWidgets(
    'system primary locale controls UI and live notifications respect manual override',
    (tester) async {
      await size(tester);
      final language = LanguageController();
      tester.binding.platformDispatcher.localesTestValue = [
        const Locale('fr'),
        const Locale('ja'),
      ];
      await tester.pumpWidget(
        MyApp(controller: programmer(), language: language),
      );
      expect(locale(tester), 'en');
      expect(find.text('Drop a file here to open'), findsOneWidget);
      tester.binding.platformDispatcher.localesTestValue = [
        const Locale('ja', 'JP'),
      ];
      await tester.pumpAndSettle();
      expect(locale(tester), 'ja');
      expect(find.text('Drop a file here to open'), findsNothing);
      await language.select(AppLanguage.en);
      await tester.pumpAndSettle();
      expect(locale(tester), 'en');
      tester.binding.platformDispatcher.localesTestValue = [
        const Locale('ja', 'US'),
      ];
      await tester.pumpAndSettle();
      expect(locale(tester), 'en');
      await language.select(AppLanguage.system);
      await tester.pumpAndSettle();
      expect(locale(tester), 'ja');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dropdown switches during an operation without replacing input or controller state',
    (tester) async {
      await size(tester);
      final subject = programmer();
      subject.openBinary([0, 255, 65], label: 'fixture.rom');
      final input = subject.inputImage;
      final profile = subject.selectedProfile;
      subject.phase = OperationPhase.reading;
      final language = LanguageController();
      await tester.pumpWidget(MyApp(controller: subject, language: language));
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('日本語').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(language.selection, AppLanguage.ja);
      expect(locale(tester), 'ja');
      expect(identical(subject.inputImage, input), isTrue);
      expect(identical(subject.selectedProfile, profile), isTrue);
      expect(subject.inputImage!.bytes, [0, 255, 65]);
      expect(subject.phase, OperationPhase.reading);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog failure is localized and language can be switched', (
    tester,
  ) async {
    await size(tester);
    final language = LanguageController();
    await language.select(AppLanguage.ja);
    await tester.pumpWidget(
      CatalogLoadFailureApp(error: StateError('fixture'), language: language),
    );
    expect(find.text('オフラインのデバイスカタログを読み込めませんでした。'), findsOneWidget);
    expect(find.text('再試行'), findsOneWidget);
    await language.select(AppLanguage.en);
    await tester.pumpAndSettle();
    expect(
      find.text('The offline device catalog could not be loaded.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'both locales render at larger text scale without layout exceptions',
    (tester) async {
      await size(tester);
      final language = LanguageController();
      tester.binding.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
      );
      await tester.pumpWidget(
        MyApp(controller: programmer(), language: language),
      );
      for (final selection in [AppLanguage.en, AppLanguage.ja]) {
        await language.select(selection);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(ProgrammerScreen));
        expect(AppLocalizations.of(context), isNotNull);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
