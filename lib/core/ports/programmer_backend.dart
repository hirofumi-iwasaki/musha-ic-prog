// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/device_profile.dart';
import '../models/operation.dart';
import '../models/programmer.dart';

abstract interface class ProgrammerBackend {
  String get backendId;

  Future<List<ProgrammerConnection>> scan();
  Future<BackendCapabilities> capabilities(
    ProgrammerConnection connection,
    DeviceProfile profile,
  );
  OperationHandle execute(OperationPlan plan);
}

final class BackendCapabilities {
  const BackendCapabilities({
    this.canRead = false,
    this.canBlankCheck = false,
    this.canProgram = false,
    this.canVerify = false,
    this.reason,
  });

  final bool canRead;
  final bool canBlankCheck;
  final bool canProgram;
  final bool canVerify;
  final String? reason;
}

abstract interface class OperationHandle {
  Stream<OperationEvent> get events;
  Future<OperationResult> get completed;
  Future<void> requestCancel();
}
