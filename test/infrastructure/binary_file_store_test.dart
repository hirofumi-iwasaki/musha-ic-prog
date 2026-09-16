// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/core/models/binary_image.dart';
import 'package:mushagaeshi_ic_programmer/infrastructure/files/binary_file_store.dart';

void main() {
  test(
    'save does not use or overwrite a predictable adjacent temp name',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mushagaeshi-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File('${directory.path}/readout.bin');
      final colliding = File('${target.path}.mushagaeshi-tmp');
      await colliding.writeAsBytes(const [0x99]);
      final image = BinaryImage(
        bytes: const [0x41, 0x42],
        origin: BinaryImageOrigin.readout,
        label: 'readout.bin',
      );

      await const BinaryFileStore().save(image, target.path);

      expect(await target.readAsBytes(), equals(<int>[0x41, 0x42]));
      expect(await colliding.readAsBytes(), equals(<int>[0x99]));
    },
  );

  test('load enforces the maximum while streaming', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mushagaeshi-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/large.bin');
    await source.writeAsBytes(const [1, 2, 3]);

    await expectLater(
      const BinaryFileStore(maximumBytes: 2).load(source.path),
      throwsA(isA<BinaryFileSizeException>()),
    );
  });

  test('a failed replacement leaves the existing destination intact', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mushagaeshi-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final existingDirectory = Directory('${directory.path}/existing');
    await existingDirectory.create();
    final image = BinaryImage(
      bytes: const [0x41],
      origin: BinaryImageOrigin.readout,
      label: 'readout.bin',
    );

    await expectLater(
      const BinaryFileStore().save(image, existingDirectory.path),
      throwsA(isA<FileSystemException>()),
    );
    expect(await existingDirectory.exists(), isTrue);
  });
}
