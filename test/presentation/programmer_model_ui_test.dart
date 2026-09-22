import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/controllers/programmer_controller.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:mushagaeshi_ic_programmer/core/models/ui_message.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/programmers/minipro/minipro_tl866_backend.dart';
import 'package:mushagaeshi_ic_programmer/l10n/app_localizations.dart';
import 'package:mushagaeshi_ic_programmer/l10n/localize_message.dart';
import 'package:mushagaeshi_ic_programmer/presentation/screens/programmer_screen.dart';

void main() {
  for (final option in [
    ProgrammerOption.tl866a,
    ProgrammerOption.tl866iiPlus,
  ]) {
    testWidgets(
      '${option.label} status uses selected model in both languages',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final cs = MiniproTl866Backend();
        final controller = ProgrammerController(
          backend: cs,
          profiles: const [],
          realBackends: {
            ProgrammerOption.tl866cs.id: cs,
            option.id: MiniproTl866Backend(programmer: option.definition!),
          },
        );
        addTearDown(controller.dispose);
        controller.selectProgrammer(option);
        for (final locale in [const Locale('en'), const Locale('ja')]) {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ProgrammerScreen(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('TL866CS'), findsNothing);
          expect(find.textContaining(option.label), findsWidgets);
          expect(tester.takeException(), isNull);
          final l = AppLocalizations.of(
            tester.element(find.byType(ProgrammerScreen)),
          )!;
          for (final id in [
            UiMessageId.backendNotDetected,
            UiMessageId.backendDiscoveryFailure,
            UiMessageId.backendWinUsbSetup,
            UiMessageId.backendUnsupportedProfile,
            UiMessageId.identityChangedBeforeWrite,
          ]) {
            final text = localizeMessage(
              l,
              UiMessage(id, {'programmer': option.label}),
            );
            expect(text, contains(option.label));
            expect(text, isNot(contains('TL866CS')));
          }
        }
      },
    );
  }
}
