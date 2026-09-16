// SPDX-License-Identifier: GPL-3.0-or-later

enum DeviceKind { eprom, logic, sram }

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
  final bool verified;

  bool get supportsMemoryOperations =>
      kind == DeviceKind.eprom && capacityBytes != null;

  String get displayName => '$manufacturer $partNumber';
}

const mockEpromProfile = DeviceProfile(
  stableId: 'mock-27c256',
  manufacturer: 'Mock',
  partNumber: '27C256',
  packageName: 'DIP-28',
  kind: DeviceKind.eprom,
  capacityBytes: 32 * 1024,
  socketPlacement: 'Simulation only — no physical IC placement',
  verified: false,
);
