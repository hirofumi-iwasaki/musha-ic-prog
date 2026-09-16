// SPDX-License-Identifier: GPL-3.0-or-later

enum ConnectionStatus { disconnected, ready, busy, unknown }

final class ProgrammerConnection {
  const ProgrammerConnection({
    required this.backendId,
    required this.model,
    required this.identifier,
    required this.firmware,
    required this.generation,
  });

  final String backendId;
  final String model;
  final String identifier;
  final String firmware;
  final int generation;
}
