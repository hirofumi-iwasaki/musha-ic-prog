// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/core/models/binary_image.dart';

void main() {
  test('keeps an immutable copy of input bytes', () {
    final source = <int>[0x41, 0x42];
    final image = BinaryImage(
      bytes: source,
      origin: BinaryImageOrigin.file,
      label: 'input.bin',
    );

    source[0] = 0x00;
    final rendered = image.bytes;
    rendered[1] = 0x00;

    expect(image.bytes, equals(<int>[0x41, 0x42]));
    expect(image.readRange(0, 2), equals(<int>[0x41, 0x42]));
    expect(image.sha1, '06d945942aa26a61be18c3e22bf19bbca8dd2b5d');
  });

  test('uses the standard SHA-1 digest for an empty snapshot', () {
    final image = BinaryImage(
      bytes: const [],
      origin: BinaryImageOrigin.file,
      label: 'empty.bin',
    );

    expect(image.sha1, 'da39a3ee5e6b4b0d3255bfef95601890afd80709');
  });
}
