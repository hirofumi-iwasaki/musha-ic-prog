// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import '../../core/models/binary_image.dart';

/// File-system adapter. UI file selection deliberately stays outside this class.
final class BinaryFileStore {
  const BinaryFileStore({this.maximumBytes = 64 * 1024 * 1024});

  final int maximumBytes;

  Future<BinaryImage> load(String path) async {
    final file = File(path);
    final bytes = <int>[];
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > maximumBytes) {
        throw BinaryFileSizeException(
          bytes.length + chunk.length,
          maximumBytes,
        );
      }
      bytes.addAll(chunk);
    }
    return BinaryImage(
      bytes: bytes,
      origin: BinaryImageOrigin.file,
      label: file.uri.pathSegments.isEmpty ? path : file.uri.pathSegments.last,
    );
  }

  /// Writes beside the destination and replaces only after the temporary file
  /// has been flushed. The caller owns overwrite confirmation.
  Future<void> save(BinaryImage image, String path) async {
    final destination = File(path);
    final tempDirectory = await destination.parent.createTemp('.mushagaeshi-');
    final temp = File('${tempDirectory.path}/image.bin');
    try {
      await temp.writeAsBytes(image.bytes, flush: true);
      await temp.rename(destination.path);
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }
}

final class BinaryFileSizeException implements Exception {
  const BinaryFileSizeException(this.actualBytes, this.maximumBytes);

  final int actualBytes;
  final int maximumBytes;

  @override
  String toString() =>
      'Binary is $actualBytes bytes; limit is $maximumBytes bytes.';
}
