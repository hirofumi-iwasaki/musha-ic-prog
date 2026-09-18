// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/binary_image.dart';
import '../models/device_profile.dart';
import '../models/operation.dart';
import '../models/programmer.dart';
import '../models/ui_message.dart';

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

  static UiMessage? validateUiMessage({
    required OperationKind kind,
    required ProgrammerConnection? connection,
    required DeviceProfile? profile,
    required BinaryImage? input,
    required bool isBusy,
  }) {
    if (isBusy) return const UiMessage(UiMessageId.operationAlreadyRunning);
    if (connection == null) {
      return const UiMessage(UiMessageId.connectOneProgrammer);
    }
    if (profile == null) return const UiMessage(UiMessageId.chooseProfile);
    if (!profile.supportsMemoryOperations) {
      return const UiMessage(UiMessageId.profileNoMemoryOperations);
    }
    if (kind == OperationKind.program || kind == OperationKind.verify) {
      if (input == null) return const UiMessage(UiMessageId.openBin);
      if (input.length != profile.capacityBytes) {
        return const UiMessage(UiMessageId.inputSizeMismatch);
      }
    }
    return null;
  }
}
