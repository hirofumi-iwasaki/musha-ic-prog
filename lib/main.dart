// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';

import 'application/controllers/programmer_controller.dart';
import 'application/language_controller.dart';
import 'infrastructure/settings/language_preferences.dart';
import 'l10n/app_localizations.dart';
import 'presentation/localized_app.dart';
import 'presentation/widgets/language_selector.dart';
import 'core/models/device_catalog.dart';
import 'core/models/device_profile.dart';
import 'infrastructure/catalog/minipro_device_catalog_loader.dart';
import 'infrastructure/programmers/minipro/minipro_tl866_backend.dart';
import 'infrastructure/programmers/mock/mock_programmer_backend.dart';
import 'presentation/screens/programmer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final language = LanguageController(preferences: SharedLanguagePreferences());
  await language.load();
  try {
    final catalog = await MiniproDeviceCatalogLoader().load();
    _run(catalog, language);
  } catch (error) {
    runApp(CatalogLoadFailureApp(error: error, language: language));
  }
}

void _run(DeviceCatalog catalog, LanguageController language) {
  final controller = ProgrammerController(
    backend: MiniproTl866Backend(),
    simulationBackend: MockProgrammerBackend(),
    profiles: const [mockEpromProfile],
    catalog: catalog,
  );
  runApp(MyApp(controller: controller, language: language));
  unawaited(_connectOnStartup(controller));
}

Future<void> _connectOnStartup(ProgrammerController controller) async {
  await controller.connectProgrammer();
  debugPrint(
    'TL866CS connection scan: ${controller.backendStatus}; ${controller.message}',
  );
}

class CatalogLoadFailureApp extends StatelessWidget {
  const CatalogLoadFailureApp({super.key, required this.error, this.language});
  final Object error;
  final LanguageController? language;

  @override
  Widget build(BuildContext context) => LocalizedApp(
    language: language,
    home: Builder(
      builder: (context) {
        final l = AppLocalizations.of(context)!;
        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LanguageSelector(),
                  const SizedBox(height: 24),
                  Text(l.catalogLoadFailed),
                  const SizedBox(height: 12),
                  Text(l.technicalDetails),
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: main, child: Text(l.retry)),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.controller, this.language});
  final ProgrammerController controller;
  final LanguageController? language;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocalizedApp(
    language: widget.language,
    home: ProgrammerScreen(controller: widget.controller),
  );
}
