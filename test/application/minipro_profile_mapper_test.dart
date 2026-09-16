import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/application/minipro_profile_mapper.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_catalog.dart';
import 'package:mushagaeshi_ic_programmer/core/models/device_profile.dart';

void main() {
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
}

CatalogDevice _device({
  String database = 'INFOIC',
  String type = '1',
  String? capacity = '8000',
  String? flags = '0',
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
  packageDetails: packageDetails,
);
