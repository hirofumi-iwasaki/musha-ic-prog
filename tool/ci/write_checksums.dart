// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('usage: <distribution-directory>');
  final root = p.absolute(args.single);
  final output = File(p.join(root, 'SHA256SUMS.txt'));
  final files = await Directory(root)
      .list(recursive: true, followLinks: false)
      .where((e) => e is File && !p.equals(e.path, output.path))
      .cast<File>()
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  final lines = <String>[];
  for (final file in files) {
    final relative = p
        .relative(file.path, from: root)
        .split(p.separator)
        .join('/');
    if (relative.contains('\n') ||
        relative.contains('\r') ||
        relative.contains('\\')) {
      throw StateError('Unrepresentable checksum path: $relative');
    }
    lines.add('${await sha256.bind(file.openRead()).first}  ./$relative');
  }
  await output.writeAsString('${lines.join('\n')}\n', flush: true);
}
