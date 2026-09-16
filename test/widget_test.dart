// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/controllers/programmer_controller.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/programmers/mock/mock_programmer_backend.dart';
import 'package:mushagaeshi_ic_programmer/main.dart';

void main() {
  testWidgets('shows the safe simulation workspace', (tester) async {
    final controller = ProgrammerController(
      backend: MockProgrammerBackend(),
      profiles: const [mockEpromProfile],
    );
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(MyApp(controller: controller));

    expect(find.text('SIMULATION MODE'), findsNothing);
    expect(find.text('Refresh simulation'), findsOneWidget);
    expect(find.text('Open BIN'), findsOneWidget);
  });
}
