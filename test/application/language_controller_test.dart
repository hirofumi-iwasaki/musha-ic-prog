// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/language_controller.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/settings/language_preferences.dart';

class MemoryPreferences implements LanguagePreferences {
  String? value;
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? gate;
  final writes = <String>[];
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes.add(value);
    await gate?.future;
    if (failWrite) throw StateError('write failed');
    this.value = value;
  }
}

void main() {
  test('system follows only primary language; region and secondary language do not override', () {
    for (final locale in [
      const Locale('ja'),
      const Locale('ja', 'JP'),
      const Locale('ja', 'US'),
    ]) {
      expect(
        resolveAppLocale(AppLanguage.system, [locale]),
        const Locale('ja'),
      );
    }
    for (final locales in <List<Locale>?>[
      null,
      [],
      [const Locale('en', 'JP')],
      [const Locale('fr', 'FR'), const Locale('ja')],
      [const Locale('en'), const Locale('ja')],
      [const Locale('zh', 'CN')],
      [const Locale('C')],
      [const Locale('POSIX')],
    ]) {
      expect(resolveAppLocale(AppLanguage.system, locales), const Locale('en'));
    }
    expect(
      resolveAppLocale(AppLanguage.en, [const Locale('ja')]),
      const Locale('en'),
    );
    expect(
      resolveAppLocale(AppLanguage.ja, [const Locale('en')]),
      const Locale('ja'),
    );
  });

  test(
    'manual selection persists and System is restored after restart',
    () async {
      final store = MemoryPreferences();
      final controller = LanguageController(preferences: store);
      await controller.load();
      expect(controller.selection, AppLanguage.system);
      await controller.select(AppLanguage.ja);
      final restarted = LanguageController(preferences: store);
      await restarted.load();
      expect(restarted.selection, AppLanguage.ja);
      await restarted.select(AppLanguage.system);
      final third = LanguageController(preferences: store);
      await third.load();
      expect(third.selection, AppLanguage.system);
      controller.dispose();
      restarted.dispose();
      third.dispose();
    },
  );

  test(
    'invalid and unreadable preferences fall back without blocking startup',
    () async {
      final store = MemoryPreferences()..value = 'unknown';
      final controller = LanguageController(preferences: store);
      await controller.load();
      expect(controller.selection, AppLanguage.system);
      store.failRead = true;
      await controller.load();
      expect(controller.failure, LanguagePreferenceFailure.load);
      controller.dispose();
    },
  );

  test(
    'failed saving still changes language and the next selection can recover',
    () async {
      final store = MemoryPreferences()..failWrite = true;
      final controller = LanguageController(preferences: store);
      final save = controller.select(AppLanguage.ja);
      expect(controller.selection, AppLanguage.ja);
      await save;
      expect(controller.failure, LanguagePreferenceFailure.save);
      store.failWrite = false;
      await controller.select(AppLanguage.en);
      expect(controller.failure, isNull);
      expect(store.value, 'en');
      controller.dispose();
    },
  );

  test('slow saves are serialized and final choice wins', () async {
    final gate = Completer<void>();
    final store = MemoryPreferences()..gate = gate;
    final controller = LanguageController(preferences: store);
    final first = controller.select(AppLanguage.ja);
    final second = controller.select(AppLanguage.en);
    await Future<void>.delayed(Duration.zero);
    expect(store.writes, ['ja']);
    expect(controller.selection, AppLanguage.en);
    gate.complete();
    await Future.wait([first, second]);
    expect(store.writes, ['ja', 'en']);
    expect(store.value, 'en');
    controller.dispose();
  });

  test('pending save can finish after controller disposal', () async {
    final gate = Completer<void>();
    final store = MemoryPreferences()
      ..gate = gate
      ..failWrite = true;
    final controller = LanguageController(preferences: store);
    final save = controller.select(AppLanguage.ja);
    controller.dispose();
    gate.complete();
    await save;
  });
}
