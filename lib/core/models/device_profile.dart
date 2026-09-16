// SPDX-License-Identifier: GPL-3.0-or-later

enum DeviceKind { memory, logic, sram }

enum ErasureMethod { ultraviolet, electrical, none }

/// A deliberately small profile. Production profiles are allowlisted from
/// device validation records, never inferred from a family name.
final class DeviceProfile {
  const DeviceProfile({
    required this.stableId,
    required this.manufacturer,
    required this.partNumber,
    required this.packageName,
    required this.kind,
    required this.capacityBytes,
    required this.socketPlacement,
    this.blankValue = 0xff,
    this.erasureMethod = ErasureMethod.ultraviolet,
    this.verified = false,
    this.evaluationAuthorized = false,
    this.miniproAlias,
    this.miniproDatabase,
    this.expectedMiniproPackage,
  });

  final String stableId;
  final String manufacturer;
  final String partNumber;
  final String packageName;
  final DeviceKind kind;
  final int? capacityBytes;
  final String socketPlacement;
  final int blankValue;
  final ErasureMethod erasureMethod;

  /// Empirical evidence that this exact IC/setup was validated.
  final bool verified;

  /// Explicit authorization for constrained engineering evaluation. This is
  /// deliberately separate from empirical validation and never changes it.
  final bool evaluationAuthorized;

  /// Exact alias supplied to minipro's `-p`; never inferred at execution time.
  final String? miniproAlias;
  final String? miniproDatabase;
  final String? expectedMiniproPackage;

  bool get supportsMemoryOperations =>
      kind == DeviceKind.memory && capacityBytes != null;

  bool get isTl866Executable =>
      (verified || evaluationAuthorized) &&
      miniproDatabase == 'INFOIC' &&
      miniproAlias != null &&
      expectedMiniproPackage != null &&
      supportsMemoryOperations;

  String get displayName => '$manufacturer $partNumber';
}

const mockEpromProfile = DeviceProfile(
  stableId: 'mock-27c256',
  manufacturer: 'Mock',
  partNumber: '27C256',
  packageName: 'DIP-28',
  kind: DeviceKind.memory,
  capacityBytes: 32 * 1024,
  socketPlacement: 'Simulation only — no physical IC placement',
  verified: false,
);
