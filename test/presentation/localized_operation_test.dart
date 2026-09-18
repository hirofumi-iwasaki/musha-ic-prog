// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/controllers/programmer_controller.dart';
import 'package:mushagaeshi_ic_programmer/application/language_controller.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/operation.dart';
import 'package:mushagaeshi_ic_programmer/core/models/programmer.dart';
import 'package:mushagaeshi_ic_programmer/core/models/ui_message.dart';
import 'package:mushagaeshi_ic_programmer/core/ports/programmer_backend.dart';
import 'package:mushagaeshi_ic_programmer/main.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    ProgrammerController controller,
    LanguageController language,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MyApp(controller: controller, language: language));
  }

  testWidgets(
    'Japanese program confirmation includes the physical safety warning',
    (tester) async {
      final language = LanguageController();
      await language.select(AppLanguage.ja);
      final controller = ProgrammerController(
        backend: _PhysicalBackend(),
        profiles: const [mockEpromProfile],
      );
      controller.connection = const ProgrammerConnection(
        backendId: 'physical-test',
        model: 'Fixture programmer',
        identifier: 'fixture',
        firmware: 'fixture',
        generation: 1,
      );
      controller.connectionStatus = ConnectionStatus.ready;
      controller.selectedProfile = const DeviceProfile(
        stableId: 'fixture',
        manufacturer: 'Fixture',
        partNumber: '27C256',
        packageName: 'DIP-28',
        kind: DeviceKind.memory,
        capacityBytes: 32768,
        socketPlacement: 'fixture',
        evaluationAuthorized: true,
        miniproAlias: '27C256',
        miniproDatabase: 'INFOIC',
        expectedMiniproPackage: 'DIP28',
      );
      controller.openBinary(
        List<int>.filled(mockEpromProfile.capacityBytes!, 0xff),
        label: 'fixture.bin',
      );

      await pumpApp(tester, controller, language);
      await tester.tap(find.text('書き込み'));
      await tester.pumpAndSettle();

      expect(find.text('書き込みの確認（実機）'), findsOneWidget);
      expect(
        find.text(
          '続行する前に、IC の型番、向き、ソケット上の位置、必要なアダプターを確認してください。カタログへの掲載は、実機での動作を保証するものではありません。',
        ),
        findsOneWidget,
      );
      expect(find.text('IC と接続・配置を確認しました。'), findsOneWidget);
      expect(find.textContaining('Confirm physical'), findsNothing);
      await language.select(AppLanguage.en);
      await tester.pumpAndSettle();
      expect(find.text('Confirm physical Program'), findsOneWidget);
      expect(find.text('I have checked the IC and setup.'), findsOneWidget);
      expect(controller.needsProgramConfirmation, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'typed backend and controller messages retranslate after locale change',
    (tester) async {
      final language = LanguageController();
      await language.select(AppLanguage.ja);
      final controller =
          ProgrammerController(
              backend: _PhysicalBackend(),
              profiles: const [mockEpromProfile],
            )
            ..phase = OperationPhase.idle
            ..message = 'RAW_CONTROLLER_SENTINEL'
            ..uiMessage = const UiMessage(UiMessageId.reading);

      await pumpApp(tester, controller, language);
      expect(find.text('TL866CS は未接続です'), findsOneWidget);
      expect(find.textContaining('コードメモリを読み取り中です。'), findsOneWidget);
      expect(find.text('RAW_CONTROLLER_SENTINEL'), findsNothing);

      await language.select(AppLanguage.en);
      await tester.pumpAndSettle();

      expect(find.text('TL866CS not connected'), findsOneWidget);
      expect(find.textContaining('Reading code memory.'), findsOneWidget);
      expect(find.text('RAW_CONTROLLER_SENTINEL'), findsNothing);
    },
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
