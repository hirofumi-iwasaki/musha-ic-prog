// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:collection';
import 'dart:convert';

import 'programmer_definition.dart';

final class ProgrammerOption {
  const ProgrammerOption({
    required this.id,
    required this.label,
    required this.databaseTypes,
    required this.available,
    this.definition,
  });

  static const tl866cs = ProgrammerOption(
    id: 'tl866cs',
    label: 'TL866CS',
    databaseTypes: {'INFOIC', 'LOGIC'},
    available: true,
    definition: ProgrammerDefinitions.tl866cs,
  );

  static const tl866a = ProgrammerOption(
    id: 'tl866a',
    label: 'TL866A',
    databaseTypes: {'INFOIC', 'LOGIC'},
    available: true,
    definition: ProgrammerDefinitions.tl866a,
  );

  static const tl866iiPlus = ProgrammerOption(
    id: 'tl866ii-plus',
    label: 'TL866II Plus',
    databaseTypes: {'INFOIC2PLUS', 'LOGIC'},
    available: true,
    definition: ProgrammerDefinitions.tl866iiPlus,
  );

  static const futureOptions = [
    ProgrammerOption(
      id: 't76',
      label: 'T76',
      databaseTypes: {'INFOICT76'},
      available: false,
      definition: ProgrammerDefinitions.t76,
    ),
    ProgrammerOption(
      id: 't48',
      label: 'T48',
      databaseTypes: {'INFOIC2PLUS'},
      available: false,
      definition: ProgrammerDefinitions.t48,
    ),
    ProgrammerOption(
      id: 't56',
      label: 'T56',
      databaseTypes: {'INFOIC2PLUS'},
      available: false,
      definition: ProgrammerDefinitions.t56,
    ),
  ];

  final String id;
  final String label;
  final Set<String> databaseTypes;
  final bool available;

  /// Null for legacy or caller-defined options which have no typed model.
  final ProgrammerDefinition? definition;
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
    this.blankValue,
    this.protocolId,
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

  /// The exact blank byte supplied by minipro's database, when catalog schema
  /// v2 or later provides it. Legacy v1 assets are readable with null here.
  final int? blankValue;

  /// Raw minipro protocol ID. Its high bit marks custom protocols.
  final String? protocolId;

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
    if (json.length != 15 && json.length != 16 && json.length != 17) {
      throw const FormatException('Malformed catalog record.');
    }
    final blankValue = json.length >= 16 ? json[15] as int? : null;
    final protocolId = json.length == 17 ? json[16] as String? : null;
    if (blankValue != null && (blankValue < 0 || blankValue > 0xff)) {
      throw const FormatException('Invalid catalog blank value.');
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
      blankValue: blankValue,
      protocolId: protocolId,
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
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion != 1 && schemaVersion != 2 && schemaVersion != 3) {
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

  /// Retained for TL866CS callers while migration moves to [isUnambiguousAlias].
  bool isUnambiguousTl866Alias(CatalogDevice device) =>
      isUnambiguousAlias(device, programmer: ProgrammerDefinitions.tl866cs);

  bool isUnambiguousAlias(
    CatalogDevice device, {
    required ProgrammerDefinition programmer,
  }) =>
      records
          .where(
            (record) =>
                // minipro resolves aliases within the raw database before it
                // applies any INFOIC2PLUS model bits. A masked-out duplicate
                // could therefore load a different descriptor than the one
                // presented here, so it must still make this alias unsafe.
                record.database == device.database &&
                record.alias.toLowerCase() == device.alias.toLowerCase(),
          )
          .length ==
      1;

  /// Whether this exact catalog record is visible for [programmer].
  bool supportsDevice(ProgrammerOption programmer, CatalogDevice device) {
    final definition = programmer.definition;
    return definition == null
        ? programmer.databaseTypes.contains(device.database)
        : supportsDefinition(definition, device);
  }

  /// Applies model-specific shared-database eligibility rules.
  bool supportsDefinition(
    ProgrammerDefinition definition,
    CatalogDevice device,
  ) {
    if (!definition.databaseTypes.contains(device.database)) return false;
    if (device.database != 'INFOIC2PLUS') return true;
    final selectedBit = definition.infoic2PlusPinMapBit;
    final pinMap = _hex(device.pinMap);
    // INFOIC2PLUS records without a valid model mask are unsafe to infer.
    if (selectedBit == null || pinMap == null) return false;
    final restrictions = pinMap & infoic2PlusModelMask;
    return restrictions == 0 || restrictions & selectedBit != 0;
  }

  List<String> vendorsFor(ProgrammerOption programmer) {
    final values =
        records
            .where((record) => supportsDevice(programmer, record))
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
              if (!supportsDevice(programmer, record)) {
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

  static int? _hex(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.startsWith('0x') || value.startsWith('0X')
        ? value.substring(2)
        : value;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) return null;
    return int.tryParse(normalized, radix: 16);
  }
}
