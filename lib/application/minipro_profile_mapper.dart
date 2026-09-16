// SPDX-License-Identifier: GPL-3.0-or-later

import '../core/models/device_catalog.dart';
import '../core/models/device_profile.dart';

/// Builds an evaluation-only description from a selected INFOIC listing.
/// It remains `verified: false`: evaluation authorization does not claim
/// empirical validation of this IC, socket position, or data outcome.
final class MiniproProfileMapper {
  const MiniproProfileMapper._();

  static DeviceProfile? fromTl866Catalog(CatalogDevice device) {
    if (device.database != 'INFOIC' || device.type != '1') return null;
    final capacity = _hex(device.codeMemorySize);
    final flags = _hex(device.flags);
    final package = _package(device.packageDetails);
    if (capacity == null || capacity <= 0 || capacity > 64 * 1024 * 1024) {
      return null;
    }
    // Word-organized and adapter/ICSP profiles need an explicit validation
    // record before they can be represented as a raw BIN code region.
    if (flags == null ||
        flags & 0x00002000 != 0 ||
        flags & 0x80000000 != 0 ||
        package == null) {
      return null;
    }
    return DeviceProfile(
      stableId: 'minipro:${device.id}',
      manufacturer: device.vendor,
      partNumber: device.label,
      packageName: package,
      kind: DeviceKind.memory,
      capacityBytes: capacity,
      socketPlacement: 'Confirm the minipro placement diagram before use.',
      verified: false,
      evaluationAuthorized: true,
      miniproAlias: device.alias,
      miniproDatabase: device.database,
      expectedMiniproPackage: package,
    );
  }

  static int? _hex(String? value) => value == null
      ? null
      : int.tryParse(
          value.startsWith('0x') ? value.substring(2) : value,
          radix: 16,
        );

  static String? _package(String? value) {
    final packed = _hex(value);
    if (packed == null) return null;
    final adapter = packed & 0xff;
    if (packed & 0x80000000 != 0) return null;
    final rawPinCount = (packed & 0x3f000000) >> 24;
    // M1 supports only direct DIP insertion.  The database encodes PLCC
    // package sizes as adapter-like raw values, which must not be inferred.
    if (adapter != 0 || rawPinCount == 0 || rawPinCount > 40) return null;
    return 'DIP$rawPinCount';
  }
}
