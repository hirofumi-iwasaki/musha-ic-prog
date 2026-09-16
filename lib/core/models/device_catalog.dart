// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:collection';
import 'dart:convert';

final class ProgrammerOption {
  const ProgrammerOption({
    required this.id,
    required this.label,
    required this.databaseTypes,
    required this.available,
  });

  static const tl866cs = ProgrammerOption(
    id: 'tl866cs',
    label: 'TL866CS',
    databaseTypes: {'INFOIC', 'LOGIC'},
    available: true,
  );

  static const futureOptions = [
    ProgrammerOption(
      id: 'tl866ii-plus',
      label: 'TL866II+',
      databaseTypes: {'INFOIC2PLUS', 'LOGIC'},
      available: false,
    ),
    ProgrammerOption(
      id: 't76',
      label: 'T76',
      databaseTypes: {'INFOICT76'},
      available: false,
    ),
    ProgrammerOption(
      id: 't48',
      label: 'T48',
      databaseTypes: {'INFOIC2PLUS'},
      available: false,
    ),
    ProgrammerOption(
      id: 't56',
      label: 'T56',
      databaseTypes: {'INFOIC2PLUS'},
      available: false,
    ),
  ];

  final String id;
  final String label;
  final Set<String> databaseTypes;
  final bool available;
}

final class CatalogDevice {
  const CatalogDevice({
    required this.id,
    required this.sourceId,
    required this.sourceIndex,
    required this.aliasIndex,
    required this.database,
    required this.vendor,
    required this.isCustom,
    required this.sourceName,
    required this.alias,
    required this.type,
    this.codeMemorySize,
    this.pins,
    this.flags,
    this.pinMap,
    this.packageDetails,
  });

  final String id;
  final String sourceId;
  final int sourceIndex;
  final int aliasIndex;
  final String database;
  final String vendor;
  final bool isCustom;
  final String sourceName;
  final String alias;
  final String type;
  final String? codeMemorySize;
  final String? pins;

  /// Raw minipro fields retained for future backend-specific matching only.
  final String? flags;
  final String? pinMap;
  final String? packageDetails;

  /// One selectable alias, tied back to its comma-delimited source record.
  String get label => alias.isEmpty ? '(unnamed source record)' : alias;
  String get kindLabel => switch (type) {
    '1' => 'EEPROM / memory',
    '2' => 'MCU / MPU',
    '3' => 'PLD / CPLD',
    '4' => 'SRAM',
    '5' => 'Logic',
    '6' => 'NAND',
    '7' => 'eMMC',
    '8' => 'VGA / HDMI',
    _ => 'Unspecified',
  };

  factory CatalogDevice.fromJsonList(List<Object?> json) {
    if (json.length != 15) {
      throw const FormatException('Malformed catalog record.');
    }
    return CatalogDevice(
      id: json[0]! as String,
      sourceId: json[1]! as String,
      sourceIndex: json[2]! as int,
      aliasIndex: json[3]! as int,
      database: json[4]! as String,
      vendor: json[5]! as String,
      isCustom: json[6]! as bool,
      sourceName: json[7]! as String,
      alias: json[8]! as String,
      type: json[9]! as String,
      codeMemorySize: json[10] as String?,
      pins: json[11] as String?,
      flags: json[12] as String?,
      pinMap: json[13] as String?,
      packageDetails: json[14] as String?,
    );
  }
}

/// A browse-only index of the exact pinned minipro database records.
/// A record listing is not evidence that the app can operate that device.
final class DeviceCatalog {
  DeviceCatalog(List<CatalogDevice> records)
    : records = List.unmodifiable(records),
      _byId = UnmodifiableMapView({for (final item in records) item.id: item});

  factory DeviceCatalog.fromJsonString(String source) {
    final decoded = jsonDecode(source) as Map<String, Object?>;
    if (decoded['schemaVersion'] != 1) {
      throw FormatException('Unsupported device catalog schema.');
    }
    final records = (decoded['records']! as List)
        .map(
          (record) =>
              CatalogDevice.fromJsonList(List<Object?>.from(record as List)),
        )
        .toList(growable: false);
    return DeviceCatalog(records);
  }

  static final empty = DeviceCatalog(const []);

  final List<CatalogDevice> records;
  final Map<String, CatalogDevice> _byId;

  CatalogDevice? byId(String id) => _byId[id];

  bool isUnambiguousTl866Alias(CatalogDevice device) =>
      records
          .where(
            (record) =>
                record.database == 'INFOIC' &&
                record.alias.toLowerCase() == device.alias.toLowerCase(),
          )
          .length ==
      1;

  List<String> vendorsFor(ProgrammerOption programmer) {
    final values =
        records
            .where(
              (record) => programmer.databaseTypes.contains(record.database),
            )
            .map((record) => record.vendor)
            .toSet()
            .toList()
          ..sort();
    return List.unmodifiable(values);
  }

  int deviceCount({
    required ProgrammerOption programmer,
    String? vendor,
    String query = '',
  }) =>
      findDevices(programmer: programmer, vendor: vendor, query: query).length;

  List<CatalogDevice> findDevices({
    required ProgrammerOption programmer,
    String? vendor,
    String query = '',
    int offset = 0,
    int? limit,
  }) {
    final normalized = query.trim().toLowerCase();
    final result =
        records
            .where((record) {
              if (!programmer.databaseTypes.contains(record.database)) {
                return false;
              }
              if (vendor != null && record.vendor != vendor) {
                return false;
              }
              if (normalized.isEmpty) {
                return true;
              }
              return record.label.toLowerCase().contains(normalized) ||
                  record.sourceName.toLowerCase().contains(normalized);
            })
            .toList(growable: false)
          ..sort((left, right) => left.label.compareTo(right.label));
    final start = offset.clamp(0, result.length);
    final end = limit == null
        ? result.length
        : (start + limit).clamp(start, result.length);
    return List.unmodifiable(result.sublist(start, end));
  }
}
