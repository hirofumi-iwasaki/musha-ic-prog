// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/services.dart';

/// Common runner contract. Coordinates are Flutter logical window coordinates;
/// only macOS supplies a security-scope token with a drop.
final class DesktopHost {
  DesktopHost({required this.onFileEvent, required this.canClose});

  final Future<void> Function(MethodCall) onFileEvent;
  final bool Function() canClose;
  static const channel = MethodChannel('mushagaeshi/programmer_files');

  void attach() => channel.setMethodCallHandler((call) async {
    if (call.method == 'closeRequested') return canClose();
    await onFileEvent(call);
    return null;
  });

  Future<void> releaseScope(String token) =>
      channel.invokeMethod<void>('releaseDropScope', token);

  void dispose() => channel.setMethodCallHandler(null);
}
