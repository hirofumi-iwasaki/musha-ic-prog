// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';

import 'application/controllers/programmer_controller.dart';
import 'core/models/device_catalog.dart';
import 'core/models/device_profile.dart';
import 'infrastructure/catalog/minipro_device_catalog_loader.dart';
import 'infrastructure/programmers/minipro/minipro_tl866_backend.dart';
import 'infrastructure/programmers/mock/mock_programmer_backend.dart';
import 'presentation/screens/programmer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final catalog = await MiniproDeviceCatalogLoader().load();
    _run(catalog);
  } catch (error) {
    runApp(CatalogLoadFailureApp(error: error));
  }
}

void _run(DeviceCatalog catalog) {
  final controller = ProgrammerController(
    backend: MiniproTl866Backend(),
    simulationBackend: MockProgrammerBackend(),
    profiles: const [mockEpromProfile],
    catalog: catalog,
  );
  runApp(MyApp(controller: controller));
  unawaited(_connectOnStartup(controller));
}

Future<void> _connectOnStartup(ProgrammerController controller) async {
  await controller.connectProgrammer();
  debugPrint(
    'TL866CS connection scan: ${controller.backendStatus}; ${controller.message}',
  );
}

class CatalogLoadFailureApp extends StatelessWidget {
  const CatalogLoadFailureApp({super.key, required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mushagaeshi IC Programmer',
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The offline device catalog could not be loaded.'),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: main, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.controller});
  final ProgrammerController controller;

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
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mushagaeshi IC Programmer',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315a7d)),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff8ec5ff),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    themeMode: ThemeMode.system,
    home: ProgrammerScreen(controller: widget.controller),
  );
}
