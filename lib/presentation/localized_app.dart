// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/language_controller.dart';
import '../l10n/app_localizations.dart';
import 'widgets/language_selector.dart';

/// Application root; owns the supplied (preloaded) language controller.
class LocalizedApp extends StatefulWidget {
  const LocalizedApp({super.key, required this.home, this.language});
  final Widget home;
  final LanguageController? language;
  @override
  State<LocalizedApp> createState() => _LocalizedAppState();
}

class _LocalizedAppState extends State<LocalizedApp>
    with WidgetsBindingObserver {
  late final LanguageController language =
      widget.language ?? LanguageController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (language.selection == AppLanguage.system) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LanguageScope(
    controller: language,
    child: ListenableBuilder(
      listenable: language,
      builder: (context, _) => MaterialApp(
        title: 'Mushagaeshi IC Programmer',
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: resolveAppLocale(
          language.selection,
          WidgetsBinding.instance.platformDispatcher.locales,
        ),
        localeListResolutionCallback: (_, supported) => resolveAppLocale(
          language.selection,
          WidgetsBinding.instance.platformDispatcher.locales,
        ),
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
        builder: (context, child) => _NativeMenuLanguage(
          child: Column(
            children: [
              if (language.failure != null)
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        language.failure == LanguagePreferenceFailure.load
                            ? AppLocalizations.of(context)!.languageLoadFailed
                            : AppLocalizations.of(context)!.languageSaveFailed,
                      ),
                    ),
                  ),
                ),
              Expanded(child: child!),
            ],
          ),
        ),
        home: widget.home,
      ),
    ),
  );
}

class _NativeMenuLanguage extends StatefulWidget {
  const _NativeMenuLanguage({required this.child});
  final Widget child;
  @override
  State<_NativeMenuLanguage> createState() => _NativeMenuLanguageState();
}

class _NativeMenuLanguageState extends State<_NativeMenuLanguage> {
  String? _last;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = Localizations.localeOf(context).languageCode;
    if (_last != code) {
      _last = code;
      if (Platform.isMacOS) unawaited(_update(code));
    }
  }

  Future<void> _update(String code) async {
    try {
      await const MethodChannel('mushagaeshi/language')
          .invokeMethod<void>('setLanguage', code);
    } on MissingPluginException {
      // Widget tests and older development runners have no native menu bridge.
    } on PlatformException catch (error) {
      debugPrint('Native menu localization failed: ${error.code}');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
