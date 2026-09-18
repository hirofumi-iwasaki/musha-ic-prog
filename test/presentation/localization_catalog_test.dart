// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Japanese catalog covers every English message with identical placeholders',
    () {
      Map<String, dynamic> catalog(String language) => jsonDecode(
        File('lib/l10n/resources/app_$language.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final en = catalog('en');
      final ja = catalog('ja');
      final keys = en.keys.where((k) => !k.startsWith('@')).toSet();
      expect(ja.keys.where((k) => !k.startsWith('@')).toSet(), keys);
      Set<String> placeholders(String value) =>
          RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}')
              .allMatches(value)
              .map((m) => m[1]!)
              .toSet();
      for (final key in keys) {
        expect(ja[key], isA<String>(), reason: key);
        expect((ja[key] as String).trim(), isNotEmpty, reason: key);
        expect(
          placeholders(ja[key] as String),
          placeholders(en[key] as String),
          reason: key,
        );
      }
    },
  );
}
