// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:xml/xml.dart';

const _sourceRoot = 'assets/minipro';
const _outputPath = 'assets/minipro/device_catalog.json';
const _upstreamCommit = 'cae74c0607077d6260b24995f5e4c0d0b66a6a2e';

Future<void> main(List<String> arguments) async {
  final sources = <CatalogSource>[];
  final records = <CatalogRecord>[];
  for (final source in const [
    ('infoic', 'infoic.xml', 'GPL-3.0-or-later (minipro database)'),
    (
      'logicic',
      'logicic.xml',
      'GPL-3.0-or-later (minipro database; README notes MIT-origin logic test data)',
    ),
  ]) {
    final file = File('$_sourceRoot/${source.$2}');
    final text = await file.readAsString();
    sources.add(
      CatalogSource(
        id: source.$1,
        path: file.path,
        sha256: crypto.sha256.convert(utf8.encode(text)).toString(),
        license: source.$3,
      ),
    );
    records.addAll(parseMiniproDatabase(source.$1, text));
  }
  records.sort((left, right) => left.id.compareTo(right.id));
  final payload = <String, Object>{
    'schemaVersion': 1,
    'provenance': <String, Object>{
      'generator': 'tool/generate_device_catalog.dart',
      'upstreamCommit': _upstreamCommit,
      'normalization': 'XML comments are stripped before strict XML parsing; source assets remain unchanged.',
      'sources': [for (final source in sources) source.toJson()],
    },
    'records': [for (final record in records) record.toJson()],
  };
  final output = File(_outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString('${const JsonEncoder().convert(payload)}\n');
  stdout.writeln(
    'Wrote ${records.length} alias-expanded selectable records to $_outputPath',
  );
  if (arguments.contains('--report')) {
    final tl866cs = records
        .where(
          (record) => record.database == 'INFOIC' || record.database == 'LOGIC',
        )
        .toList(growable: false);
    stdout.writeln(
      'TL866CS: ${tl866cs.length} selectable aliases across ${tl866cs.map((record) => record.vendor).toSet().length} vendors.',
    );
  }
}

/// Parses only after strict XML validation. The pinned minipro INFOIC source
/// contains an invalid comment token, so comments are normalized first while
/// the original, hashed XML remains bundled unchanged.
List<CatalogRecord> parseMiniproDatabase(String sourceId, String xml) {
  final commentFree = xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  final document = XmlDocument.parse(commentFree);
  var sourceIndex = 0;
  final records = <CatalogRecord>[];
  for (final databaseElement in document.findAllElements('database')) {
    final database = databaseElement.getAttribute('type');
    if (database == null || database.isEmpty) {
      throw FormatException('Database without a type in $sourceId.');
    }
    for (final owner in databaseElement.childElements.where(
      (element) =>
          element.name.local == 'manufacturer' ||
          element.name.local == 'custom',
    )) {
      final vendor = owner.getAttribute('name') ?? '';
      final isCustom = owner.name.local == 'custom';
      for (final ic in owner.findElements('ic')) {
        final recordNumber = sourceIndex++;
        final rawName = ic.getAttribute('name') ?? '';
        final aliases = rawName
            .split(',')
            .map((alias) => alias.trim())
            .where((alias) => alias.isNotEmpty)
            .toList(growable: false);
        final selectableAliases = aliases.isEmpty ? const [''] : aliases;
        for (
          var aliasIndex = 0;
          aliasIndex < selectableAliases.length;
          aliasIndex++
        ) {
          records.add(
            CatalogRecord(
              id: '$sourceId:$database:$recordNumber:$aliasIndex',
              sourceId: sourceId,
              sourceIndex: recordNumber,
              aliasIndex: aliasIndex,
              database: database,
              vendor: vendor,
              isCustom: isCustom,
              rawName: rawName,
              alias: selectableAliases[aliasIndex],
              type: ic.getAttribute('type') ?? '',
              codeMemorySize: ic.getAttribute('code_memory_size'),
              pins: ic.getAttribute('pins'),
            flags: ic.getAttribute('flags'),
            pinMap: ic.getAttribute('pin_map'),
            packageDetails: ic.getAttribute('package_details'),
            ),
          );
        }
      }
    }
  }
  return records;
}

final class CatalogSource {
  const CatalogSource({
    required this.id,
    required this.path,
    required this.sha256,
    required this.license,
  });

  final String id;
  final String path;
  final String sha256;
  final String license;

  Map<String, String> toJson() => {
    'id': id,
    'path': path,
    'sha256': sha256,
    'license': license,
  };
}

final class CatalogRecord {
  const CatalogRecord({
    required this.id,
    required this.sourceId,
    required this.sourceIndex,
    required this.aliasIndex,
    required this.database,
    required this.vendor,
    required this.isCustom,
    required this.rawName,
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
  final String rawName;
  final String alias;
  final String type;
  final String? codeMemorySize;
  final String? pins;
  final String? flags;
  final String? pinMap;
  final String? packageDetails;

  /// Positional encoding keeps the full alias-expanded catalog practical as an
  /// offline Flutter asset. Field order is defined by schemaVersion 1.
  List<Object?> toJson() => [
    id,
    sourceId,
    sourceIndex,
    aliasIndex,
    database,
    vendor,
    isCustom,
    rawName,
    alias,
    type,
    codeMemorySize,
    pins,
    flags,
    pinMap,
    packageDetails,
  ];
}
