// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

enum BinaryImageOrigin { file, readout, postWriteVerification }

/// An application-owned byte snapshot. Callers never receive its mutable store.
final class BinaryImage {
  BinaryImage({
    required List<int> bytes,
    required this.origin,
    required this.label,
    DateTime? createdAt,
  }) : _bytes = Uint8List.fromList(bytes),
       createdAt = createdAt ?? DateTime.now().toUtc(),
       snapshotId = _newSnapshotId(),
       sha1 = crypto.sha1.convert(bytes).toString();

  final Uint8List _bytes;
  final String snapshotId;
  final String sha1;
  final BinaryImageOrigin origin;
  final String label;
  final DateTime createdAt;

  int get length => _bytes.length;

  /// A defensive copy for rendering or export.
  Uint8List get bytes => Uint8List.fromList(_bytes);

  Uint8List readRange(int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > _bytes.length) {
      throw RangeError.range(offset + length, 0, _bytes.length, 'range end');
    }
    return Uint8List.fromList(_bytes.sublist(offset, offset + length));
  }

  static int _nextId = 0;
  static String _newSnapshotId() =>
      'snapshot-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
}
