// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:path/path.dart' as p;

/// Copy reproducible project inputs, including not-yet-committed local work.
/// Never follow a symlink into an SDK, cache, or developer directory.
void main(List<String> args) {
  if (args.length != 1) throw ArgumentError('usage: <distribution-directory>');
  final root = Directory.current.absolute.path;
  final destination = p.join(p.absolute(args.single), 'SOURCE');
  if (p.isWithin(destination, root) || p.equals(destination, root)) {
    throw ArgumentError('Source output must not contain the repository');
  }
  const inputs = [
    'LICENSE',
    'README.md',
    'README.ja.md',
    'pubspec.yaml',
    'pubspec.lock',
    'l10n.yaml',
    'analysis_options.yaml',
    '.gitignore',
    '.gitattributes',
    '.github',
    '.chatgpt',
    'lib',
    'native',
    'assets',
    'tool',
    'third_party',
    'test',
    'macos',
    'windows',
    'linux',
  ];
  const excluded = {
    'ephemeral',
    'Pods',
    '.symlinks',
    'xcuserdata',
    '.dart_tool',
    'build',
    'dist',
    '.git',
    '.DS_Store',
  };
  void copy(String source, String target) {
    if (excluded.contains(p.basename(source))) return;
    switch (FileSystemEntity.typeSync(source, followLinks: false)) {
      case FileSystemEntityType.directory:
        Directory(target).createSync(recursive: true);
        for (final entry in Directory(source).listSync(followLinks: false)) {
          copy(entry.path, p.join(target, p.basename(entry.path)));
        }
      case FileSystemEntityType.file:
        Directory(p.dirname(target)).createSync(recursive: true);
        File(source).copySync(target);
      case FileSystemEntityType.link:
        throw StateError('Unexpected source symlink: $source');
      default:
        break;
    }
  }

  for (final item in inputs) {
    copy(p.join(root, item), p.join(destination, item));
  }
}
