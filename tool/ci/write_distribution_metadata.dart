// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) {
  if (args.length != 3) {
    throw ArgumentError(
      'usage: <distribution-directory> <target> <flutter-bin>',
    );
  }
  final output = Directory(p.absolute(args[0]));
  if (!output.existsSync()) throw ArgumentError.value(output.path, 'directory');

  File('LICENSE').copySync(p.join(output.path, 'LICENSE'));
  final sourceRevision = _run('git', const ['rev-parse', 'HEAD']);
  final sourceUrl = _run('git', const ['remote', 'get-url', 'origin']);
  final sourceDirty = _run('git', const ['status', '--porcelain']).isNotEmpty;
  final flutterVersion = _run(args[2], const ['--version']);
  File(p.join(output.path, 'SOURCE_AND_BUILD.txt'))
      .writeAsStringSync('''Mushagaeshi IC Programmer distribution metadata
Target: ${args[1]}
Source repository: $sourceUrl
Source revision: $sourceRevision
Source worktree: ${sourceDirty ? 'contains local changes; SOURCE/ is authoritative' : 'clean'}
Flutter SDK:
$flutterVersion

SOURCE/ contains this checkout's application, native helper, packaging and
licensing inputs. SOURCE/third_party/native-sources/ contains the pinned,
native dependency sources as archives or expanded trees. The repository
includes the minipro patches and overlay used to build this bundle. SHA256SUMS.txt records regular files except the checksum list itself.

Rebuild from a clean checkout with the pinned Flutter SDK and native tools:
  macOS: FLUTTER_BIN=flutter zsh tool/package_macos.sh
  Windows: tool/build_windows.ps1 -Architecture x64 (or arm64)
  Ubuntu: bash tool/build_linux.sh x64 (or arm64)
The exact native dependency and overlay procedure is in
third_party/NATIVE_REBUILDING.md.
''');

  final licenses = Directory(p.join(output.path, 'THIRD_PARTY_LICENSES'))
    ..createSync();
  final copied = <String>[];
  _copyIfPresent(
    'assets/minipro/LICENSE',
    licenses,
    'minipro-GPL-3.0-or-later.txt',
    copied,
  );
  _copyIfPresent(
    'third_party/libusb/LICENSE',
    licenses,
    'libusb-LGPL-2.1-or-later.txt',
    copied,
  );
  _copyIfPresent(
    'third_party/minipro/README.md',
    licenses,
    'minipro-UPSTREAM_README.md',
    copied,
  );
  _copyIfPresent(
    'third_party/NATIVE_REBUILDING.md',
    licenses,
    'NATIVE_REBUILDING.md',
    copied,
  );

  _copyIfPresent('third_party/ZLIB_LICENSE.txt', licenses, 'zlib-Zlib.txt', copied);

  final packageConfig = File('.dart_tool/package_config.json');
  if (packageConfig.existsSync()) {
    final config =
        jsonDecode(packageConfig.readAsStringSync()) as Map<String, dynamic>;
    final configUri = packageConfig.absolute.uri;
    for (final entry in config['packages'] as List<dynamic>) {
      final data = entry as Map<String, dynamic>;
      final root = configUri.resolve(data['rootUri'] as String);
      if (!root.isScheme('file')) continue;
      final rootDir = Directory.fromUri(root);
      for (final candidate in const ['LICENSE', 'LICENSE.md', 'COPYING']) {
        final license = File(p.join(rootDir.path, candidate));
        if (!license.existsSync()) continue;
        final name = '${data['name']}-$candidate';
        final destination = File(p.join(licenses.path, name));
        if (!destination.existsSync()) {
          license.copySync(destination.path);
          copied.add(name);
        }
        break;
      }
    }
  }
  File(p.join(output.path, 'THIRD_PARTY_NOTICES.txt')).writeAsStringSync(
    '''License and provenance texts for bundled native components and Dart packages
are in THIRD_PARTY_LICENSES/. Flutter and Dart notices remain in the complete
application runtime. pubspec.lock fixes the Dart dependency set.

Included files:
${copied.join('\n')}
''',
  );
}

void _copyIfPresent(
  String source,
  Directory destination,
  String name,
  List<String> copied,
) {
  final input = File(source);
  if (!input.existsSync()) return;
  input.copySync(p.join(destination.path, name));
  copied.add(name);
}

String _run(String executable, List<String> arguments) {
  final result = Process.runSync(
    executable,
    arguments,
    runInShell: Platform.isWindows && executable.toLowerCase().endsWith('.bat'),
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stderr}',
      result.exitCode,
    );
  }
  return result.stdout.toString().trim();
}
