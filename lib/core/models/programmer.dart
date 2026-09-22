// SPDX-License-Identifier: GPL-3.0-or-later

enum ConnectionStatus { disconnected, ready, busy, unknown }

final class ProgrammerConnection {
  const ProgrammerConnection({
    required this.backendId,
    required this.model,
    required this.identifier,
    required this.firmware,
    required this.generation,
    this.sameHandleIdentity,
  });

  final String backendId;
  final String model;
  final String identifier;
  final String firmware;
  final int generation;

  /// Opaque identity returned by MiniPro after opening the USB handle. It is
  /// supplied back to the native command guard and is never presented as a
  /// user-facing USB location.
  final String? sameHandleIdentity;
}
