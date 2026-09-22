import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/minipro_profile_mapper.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';
import 'package:mushagaeshi_ic_programmer/core/models/programmer_definition.dart';

void main() {
  test('TL866A uses INFOIC without inheriting CS validation', () {
    final profile = MiniproProfileMapper.fromCatalog(
      device: _device(),
      programmer: ProgrammerDefinition.tl866a,
    )!;
    expect(profile.isExecutableFor(ProgrammerId.tl866a), isTrue);
    expect(profile.isExecutableFor(ProgrammerId.tl866cs), isFalse);
    expect(profile.verified, isFalse);
    expect(
      MiniproProfileMapper.fromCatalog(
        device: _device(database: 'INFOIC2PLUS', pinMap: '0'),
        programmer: ProgrammerDefinition.tl866a,
      ),
      isNull,
    );
    expect(
      MiniproProfileMapper.fromCatalog(
        device: _device(flags: '00200000'),
        programmer: ProgrammerDefinition.tl866a,
      ),
      isNull,
    );
  });

  test(
    'maps byte-organized INFOIC type-1 direct DIP profiles up to 40 pins',
    () {
      final profile = MiniproProfileMapper.fromTl866Catalog(
        _device(capacity: '8000', flags: '0', packageDetails: '1C000000'),
      );

      expect(profile, isNotNull);
      expect(profile!.kind, DeviceKind.memory);
      expect(profile.capacityBytes, 0x8000);
      expect(profile.miniproAlias, '27C256');
      expect(profile.expectedMiniproPackage, 'DIP28');
      expect(profile.erasureMethod, ErasureMethod.none);
      expect(profile.blankValue, 0xff);
      expect(profile.verified, isFalse);
      expect(profile.evaluationAuthorized, isTrue);
      expect(profile.isTl866Executable, isTrue);
    },
  );

  test('excludes word-organized profiles marked by the 0x2000 flag', () {
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(flags: '00002000')),
      isNull,
    );
  });

  test('excludes ICSP-only and undefined programming-support encodings', () {
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(flags: '00200000')),
      isNull,
    );
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(flags: '00300000')),
      isNull,
    );
  });

  test('excludes legacy high-bit flags and custom protocols', () {
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(flags: '80000000')),
      isNull,
    );
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(protocolId: '80000001')),
      isNull,
    );
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(protocolId: '100000000')),
      isNull,
    );
  });

  test('uses catalog blank byte and flags electrical erase capability', () {
    final profile = MiniproProfileMapper.fromTl866Catalog(
      _device(flags: '10', blankValue: 0x00),
    );

    expect(profile, isNotNull);
    expect(profile!.blankValue, 0x00);
    expect(profile.erasureMethod, ErasureMethod.electrical);
  });

  test('excludes adapter and non-direct packages', () {
    expect(
      MiniproProfileMapper.fromTl866Catalog(
        _device(packageDetails: '1C000001'),
      ),
      isNull,
    );
    expect(
      MiniproProfileMapper.fromTl866Catalog(
        _device(packageDetails: '30000000'),
      ),
      isNull,
    );
  });

  test(
    'excludes encoded SMD and PLCC packages even when their pin count fits',
    () {
      expect(
        MiniproProfileMapper.fromTl866Catalog(
          _device(packageDetails: '9C000000'),
        ),
        isNull,
      );
      expect(
        MiniproProfileMapper.fromTl866Catalog(
          _device(packageDetails: '38000000'),
        ),
        isNull,
      );
    },
  );

  test('excludes non-INFOIC and non-memory records', () {
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(database: 'LOGIC')),
      isNull,
    );
    expect(MiniproProfileMapper.fromTl866Catalog(_device(type: '4')), isNull);
  });

  test('excludes absent, zero, and oversized code capacity', () {
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(capacity: null)),
      isNull,
    );
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(capacity: '0')),
      isNull,
    );
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(capacity: '4000001')),
      isNull,
    );
  });

  test('maps a shared INFOIC2PLUS profile only for the selected model', () {
    final profile = MiniproProfileMapper.fromCatalog(
      device: _device(database: 'INFOIC2PLUS', pinMap: '00000000'),
      programmer: ProgrammerDefinition.tl866iiPlus,
    );

    expect(profile, isNotNull);
    expect(profile!.eligibleProgrammers, {ProgrammerId.tl866iiPlus});
    expect(profile.isExecutableFor(ProgrammerId.tl866iiPlus), isTrue);
    expect(profile.isExecutableFor(ProgrammerId.tl866cs), isFalse);
    expect(profile.isTl866Executable, isFalse);
  });

  test('requires INFOIC2PLUS blank and protocol metadata', () {
    expect(
      MiniproProfileMapper.fromCatalog(
        device: _device(
          database: 'INFOIC2PLUS',
          pinMap: '00000000',
          blankValue: null,
        ),
        programmer: ProgrammerDefinition.tl866iiPlus,
      ),
      isNull,
    );
    expect(
      MiniproProfileMapper.fromCatalog(
        device: _device(
          database: 'INFOIC2PLUS',
          pinMap: '00000000',
          protocolId: null,
        ),
        programmer: ProgrammerDefinition.tl866iiPlus,
      ),
      isNull,
    );
  });

  test('rejects manually constructed out-of-range blank metadata', () {
    expect(
      MiniproProfileMapper.fromTl866Catalog(_device(blankValue: 0x100)),
      isNull,
    );
  });

  test(
    'excludes INFOIC2PLUS records with another model bit or bad pin map',
    () {
      expect(
        MiniproProfileMapper.fromCatalog(
          device: _device(database: 'INFOIC2PLUS', pinMap: '40000000'),
          programmer: ProgrammerDefinition.tl866iiPlus,
        ),
        isNull,
      );
      expect(
        MiniproProfileMapper.fromCatalog(
          device: _device(database: 'INFOIC2PLUS', pinMap: null),
          programmer: ProgrammerDefinition.tl866iiPlus,
        ),
        isNull,
      );
      expect(
        MiniproProfileMapper.fromCatalog(
          device: _device(database: 'INFOIC2PLUS', pinMap: 'oops'),
          programmer: ProgrammerDefinition.tl866iiPlus,
        ),
        isNull,
      );
    },
  );
}

CatalogDevice _device({
  String database = 'INFOIC',
  String type = '1',
  String? capacity = '8000',
  String? flags = '0',
  String? pinMap,
  int? blankValue = 0xff,
  String? protocolId = '0x01',
  String? packageDetails = '1C000000',
}) => CatalogDevice(
  id: 'infoic:0',
  sourceId: 'INFOIC',
  sourceIndex: 0,
  aliasIndex: 0,
  database: database,
  vendor: 'Test vendor',
  isCustom: false,
  sourceName: '27C256',
  alias: '27C256',
  type: type,
  codeMemorySize: capacity,
  flags: flags,
  pinMap: pinMap,
  blankValue: blankValue,
  protocolId: protocolId,
  packageDetails: packageDetails,
);
