// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/minipro_profile_mapper.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/programmer_definition.dart';
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

  test(
    'parser retains minipro blank values and validates their byte range',
    () {
      const source = '''
      <infoic><database type="INFOIC"><manufacturer name="Vendor">
      <ic name="A" type="1" blank_value="0x00"/>
      <ic name="B" type="1"/>
      </manufacturer></database></infoic>
    ''';

      final records = parseMiniproDatabase('fixture', source);
      expect(records.map((record) => record.blankValue), [0x00, 0xff]);
      expect(
        () => parseMiniproDatabase(
          'fixture',
          '<infoic><database type="INFOIC"><manufacturer name="Vendor"><ic name="A" type="1" blank_value="0x100"/></manufacturer></database></infoic>',
        ),
        throwsFormatException,
      );
    },
  );

  test('catalog loader accepts v1, v2, and v3 record encodings', () {
    final v1 = DeviceCatalog.fromJsonString('''
      {"schemaVersion":1,"records":[["id","source",0,0,"INFOIC","Vendor",false,"A","A","1",null,null,null,null,null]]}
    ''');
    final v2 = DeviceCatalog.fromJsonString('''
      {"schemaVersion":2,"records":[["id","source",0,0,"INFOIC","Vendor",false,"A","A","1",null,null,null,null,null,0]]}
    ''');
    final v3 = DeviceCatalog.fromJsonString('''
      {"schemaVersion":3,"records":[["id","source",0,0,"INFOIC","Vendor",false,"A","A","1",null,null,null,null,null,0,"0x01"]]}
    ''');

    expect(v1.records.single.blankValue, isNull);
    expect(v2.records.single.blankValue, 0);
    expect(v3.records.single.protocolId, '0x01');
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
    expect(actual, {
      'INFOICT76': 34607,
      'INFOIC2PLUS': 32659,
      'INFOIC': 14208,
      'LOGIC': 289,
    });
    expect(catalog.deviceCount(programmer: ProgrammerOption.tl866cs), 14497);
    expect(catalog.deviceCount(programmer: ProgrammerOption.tl866a), 14497);
    expect(
      catalog.deviceCount(programmer: ProgrammerOption.tl866iiPlus),
      19255,
    );
  });

  test(
    'pinned INFOIC2PLUS catalog produces TL866II Plus mappable raw profiles',
    () async {
      final catalog = DeviceCatalog.fromJsonString(
        await File('assets/minipro/device_catalog.json').readAsString(),
      );
      final profiles = catalog
          .findDevices(programmer: ProgrammerOption.tl866iiPlus)
          .map(
            (device) => MiniproProfileMapper.fromCatalog(
              device: device,
              programmer: ProgrammerDefinition.tl866iiPlus,
            ),
          )
          .whereType<DeviceProfile>()
          .toList(growable: false);

      expect(profiles, hasLength(9833));
      expect(
        profiles.every(
          (profile) =>
              profile.isExecutableFor(ProgrammerId.tl866iiPlus) &&
              !profile.isExecutableFor(ProgrammerId.tl866cs),
        ),
        isTrue,
      );
    },
  );

  test('INFOIC2PLUS visibility follows its model bits', () {
    final shared = _plusDevice(id: 'shared', pinMap: '00000000');
    final iiOnly = _plusDevice(id: 'ii', pinMap: '20000000');
    final t48Only = _plusDevice(id: 't48', pinMap: '40000000');
    final both = _plusDevice(id: 'both', pinMap: '60000000');
    final catalog = DeviceCatalog([shared, iiOnly, t48Only, both]);

    expect(
      catalog.findDevices(programmer: ProgrammerOption.tl866iiPlus),
      unorderedEquals([both, iiOnly, shared]),
    );
    const t48 = ProgrammerOption(
      id: 't48',
      label: 'T48',
      databaseTypes: {'INFOIC2PLUS'},
      available: false,
      definition: ProgrammerDefinitions.t48,
    );
    expect(
      catalog.findDevices(programmer: t48),
      unorderedEquals([both, shared, t48Only]),
    );
  });

  test('INFOIC2PLUS missing or invalid pin maps are denied', () {
    final missing = _plusDevice(id: 'missing', pinMap: null);
    final invalid = _plusDevice(id: 'invalid', pinMap: 'not-a-number');
    final catalog = DeviceCatalog([missing, invalid]);

    expect(
      catalog.findDevices(programmer: ProgrammerOption.tl866iiPlus),
      isEmpty,
    );
    expect(
      catalog.supportsDefinition(ProgrammerDefinition.tl866iiPlus, missing),
      isFalse,
    );
  });

  test('model-specific catalog masking does not make raw aliases unique', () {
    final ii = _plusDevice(id: 'ii', alias: 'M27', pinMap: '20000000');
    final t48 = _plusDevice(id: 't48', alias: 'm27', pinMap: '40000000');
    final catalog = DeviceCatalog([ii, t48]);

    expect(
      catalog.isUnambiguousAlias(
        ii,
        programmer: ProgrammerDefinition.tl866iiPlus,
      ),
      isFalse,
    );
  });
}

CatalogDevice _plusDevice({
  required String id,
  String alias = '27C256',
  String? pinMap,
}) => CatalogDevice(
  id: id,
  sourceId: id,
  sourceIndex: 0,
  aliasIndex: 0,
  database: 'INFOIC2PLUS',
  vendor: 'Test vendor',
  isCustom: false,
  sourceName: alias,
  alias: alias,
  type: '1',
  pinMap: pinMap,
);

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
