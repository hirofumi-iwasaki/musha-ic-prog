// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:path/path.dart' as p;

/// Absolute locations of the native payload used by the minipro backend.
///
/// The macOS bundle keeps its existing `Contents` layout. Windows and Linux
/// archives place the Flutter executable at their root and keep helpers below
/// `native/` and databases below `resources/minipro/`.
final class NativePayloadLocator {
  NativePayloadLocator({
    required this.resolvedExecutable,
    String? operatingSystem,
  }) : _operatingSystem = operatingSystem ?? Platform.operatingSystem;

  final String resolvedExecutable;
  final String _operatingSystem;

  MiniproBundlePaths locate() {
    final context = _pathContext(_operatingSystem);
    final executable = context.normalize(context.absolute(resolvedExecutable));
    final packageRoot = switch (_operatingSystem) {
      'macos' => context.dirname(context.dirname(executable)),
      'windows' || 'linux' => context.dirname(executable),
      _ => throw UnsupportedError(
        'TL866CS native payload is unavailable on $_operatingSystem.',
      ),
    };
    final isMacos = _operatingSystem == 'macos';
    final helperDirectory = isMacos
        ? context.join(packageRoot, 'MacOS')
        : context.join(packageRoot, 'native');
    final executableName = _operatingSystem == 'windows'
        ? 'minipro.exe'
        : 'minipro';
    final probeName = _operatingSystem == 'windows'
        ? 'tl866_probe.exe'
        : 'tl866_probe';
    final databaseDirectory = isMacos
        ? context.join(packageRoot, 'Resources', 'minipro')
        : context.join(packageRoot, 'resources', 'minipro');
    return MiniproBundlePaths(
      executable: context.join(helperDirectory, executableName),
      probe: context.join(helperDirectory, probeName),
      infoic: context.join(databaseDirectory, 'infoic.xml'),
      logicic: context.join(databaseDirectory, 'logicic.xml'),
    );
  }

  static p.Context _pathContext(String operatingSystem) => p.Context(
    style: operatingSystem == 'windows' ? p.Style.windows : p.Style.posix,
  );
}

/// Kept apart from the locator so tests and callers can supply fixture paths.
final class MiniproBundlePaths {
  const MiniproBundlePaths({
    required this.executable,
    required this.probe,
    required this.infoic,
    required this.logicic,
  });

  factory MiniproBundlePaths.currentApp() =>
      NativePayloadLocator(resolvedExecutable: Platform.resolvedExecutable)
          .locate();

  final String executable;
  final String probe;
  final String infoic;
  final String logicic;

  List<String> get missingFiles => [
    executable,
    probe,
    infoic,
    logicic,
  ].where((path) => !File(path).existsSync()).toList(growable: false);

  bool get isPresent => missingFiles.isEmpty;
}
