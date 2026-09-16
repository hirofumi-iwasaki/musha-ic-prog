// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:xml/xml.dart';

import '../../tool/generate_device_catalog.dart' show parseMiniproDatabase;

void main() {
  test('parser expands comma aliases with stable source and alias indexes', () {
    const source = '''
      <!-- XML comments are deliberately normalized before strict parsing. -->
      <infoic><database type="INFOIC"><manufacturer name="Vendor">
      <ic name="A, B" type="1"/><ic type="1"/>
      </manufacturer></database></infoic>
    ''';

    final records = parseMiniproDatabase('fixture', source);

    expect(records.map((record) => record.id), [
      'fixture:INFOIC:0:0',
      'fixture:INFOIC:0:1',
      'fixture:INFOIC:1:0',
    ]);
    expect(records.map((record) => record.alias), ['A', 'B', '']);
  });

  test('malformed XML attributes are rejected before catalog generation', () {
    expect(
      () => parseMiniproDatabase(
        'fixture',
        '<infoic><database type="INFOIC"><manufacturer name="bad><ic name="A"/></manufacturer></database></infoic>',
      ),
      throwsA(isA<XmlParserException>()),
    );
  });

  test('generated catalog matches independent strict source counts', () async {
    final infoic = await File('assets/minipro/infoic.xml').readAsString();
    final logic = await File('assets/minipro/logicic.xml').readAsString();
    final expected = <String, int>{
      ..._independentAliasCounts(infoic),
      ..._independentAliasCounts(logic),
    };
    final catalog = DeviceCatalog.fromJsonString(
      await File('assets/minipro/device_catalog.json').readAsString(),
    );
    final actual = <String, int>{};
    for (final record in catalog.records) {
      actual.update(record.database, (count) => count + 1, ifAbsent: () => 1);
    }

    expect(catalog.records, hasLength(81763));
    expect(actual, expected);
    expect(catalog.deviceCount(programmer: ProgrammerOption.tl866cs), 14497);
  });
}

Map<String, int> _independentAliasCounts(String xml) {
  final document = XmlDocument.parse(
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ''),
  );
  final counts = <String, int>{};
  for (final database in document.findAllElements('database')) {
    final type = database.getAttribute('type')!;
    var aliases = 0;
    for (final owner in database.childElements.where(
      (element) =>
          element.name.local == 'manufacturer' ||
          element.name.local == 'custom',
    )) {
      for (final ic in owner.findElements('ic')) {
        final names = (ic.getAttribute('name') ?? '')
            .split(',')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty);
        aliases += names.isEmpty ? 1 : names.length;
      }
    }
    counts[type] = (counts[type] ?? 0) + aliases;
  }
  return counts;
}
