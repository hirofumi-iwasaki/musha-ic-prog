// SPDX-License-Identifier: GPL-3.0-or-later

import '../core/models/device_catalog.dart';
import '../core/models/device_profile.dart';
import '../core/models/programmer_definition.dart';

/// Builds an evaluation-only description from a selected INFOIC listing.
/// It remains `verified: false`: evaluation authorization does not claim
/// empirical validation of this IC, socket position, or data outcome.
final class MiniproProfileMapper {
  const MiniproProfileMapper._();

  static DeviceProfile? fromCatalog({
    required CatalogDevice device,
    required ProgrammerDefinition programmer,
  }) {
    final isInfoic2Plus = device.database == 'INFOIC2PLUS';
    // Legacy INFOIC catalog assets predate these fields. INFOIC2PLUS support
    // must never infer them: its only supported catalog is schema v3+.
    if ((isInfoic2Plus &&
            (device.protocolId == null || device.blankValue == null)) ||
        (device.blankValue != null &&
            (device.blankValue! < 0 || device.blankValue! > 0xff))) {
      return null;
    }
    if ((device.database != 'INFOIC' && device.database != 'INFOIC2PLUS') ||
        !programmer.databaseTypes.contains(device.database) ||
        device.type != '1' ||
        !_modelAllowsDevice(device, programmer)) {
      return null;
    }
    final capacity = _hex(device.codeMemorySize);
    final flags = _hex(device.flags);
    final protocolId = _hex(device.protocolId);
    final package = _package(device.packageDetails);
    if (capacity == null || capacity <= 0 || capacity > 64 * 1024 * 1024) {
      return null;
    }
    // Word-organized and adapter/ICSP profiles need an explicit validation
    // record before they can be represented as a raw BIN code region.
    if (flags == null ||
        (device.protocolId != null && protocolId == null) ||
        flags & 0x00002000 != 0 ||
        flags & 0x80000000 != 0 ||
        !_isDirectZifProgramming(flags) ||
        _isCustomProtocol(protocolId) ||
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
      // The database records whether minipro can issue an erase command, but
      // not whether the part is UV- or electrically erasable. Do not assert a
      // physical erase method for a catalog-derived evaluation profile.
      erasureMethod: flags & 0x00000010 != 0
          ? ErasureMethod.electrical
          : ErasureMethod.none,
      blankValue: device.blankValue ?? 0xff,
      verified: false,
      evaluationAuthorized: true,
      miniproAlias: device.alias,
      miniproDatabase: device.database,
      expectedMiniproPackage: package,
      eligibleProgrammers: {programmer.id},
    );
  }

  /// Compatibility wrapper for the original TL866CS-only mapper API.
  static DeviceProfile? fromTl866Catalog(CatalogDevice device) =>
      fromCatalog(device: device, programmer: ProgrammerDefinitions.tl866cs);

  static bool _modelAllowsDevice(
    CatalogDevice device,
    ProgrammerDefinition programmer,
  ) {
    if (device.database != 'INFOIC2PLUS') return true;
    final selectedBit = programmer.infoic2PlusPinMapBit;
    final pinMap = _hex(device.pinMap);
    if (selectedBit == null || pinMap == null) return false;
    final restrictions = pinMap & infoic2PlusModelMask;
    return restrictions == 0 || restrictions & selectedBit != 0;
  }

  static bool _isDirectZifProgramming(int flags) {
    // minipro's MP_SUPPORTED_PROGRAMMING field: 0=ZIF, 1=ZIF/ICSP,
    // 2=ICSP-only. The remaining encoding is not defined by the pinned
    // source and is denied rather than inferred.
    final programmingSupport = (flags & 0x00300000) >> 20;
    return programmingSupport == 0 || programmingSupport == 1;
  }

  static bool _isCustomProtocol(int? protocolId) =>
      protocolId != null && protocolId & 0x80000000 != 0;

  static int? _hex(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.startsWith('0x') || value.startsWith('0X')
        ? value.substring(2)
        : value;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) return null;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null || parsed > 0xffffffff ? null : parsed;
  }

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
