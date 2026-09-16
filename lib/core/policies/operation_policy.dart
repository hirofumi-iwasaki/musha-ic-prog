// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/binary_image.dart';
import '../models/device_profile.dart';
import '../models/operation.dart';
import '../models/programmer.dart';

final class OperationPolicy {
  const OperationPolicy._();

  static String? validate({
    required OperationKind kind,
    required ProgrammerConnection? connection,
    required DeviceProfile? profile,
    required BinaryImage? input,
    required bool isBusy,
  }) {
    if (isBusy) return 'Another operation is already running.';
    if (connection == null) return 'Connect exactly one programmer first.';
    if (profile == null) return 'Choose a device profile first.';
    if (!profile.supportsMemoryOperations) {
      return 'The selected profile does not support memory operations.';
    }
    if (kind == OperationKind.program || kind == OperationKind.verify) {
      if (input == null) return 'Open a BIN file first.';
      if (input.length != profile.capacityBytes) {
        return 'The input BIN must exactly match the IC capacity.';
      }
    }
    return null;
  }
}
