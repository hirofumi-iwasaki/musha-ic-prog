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

/// Optional, user-safe explanation from the most recent discovery attempt.
///
/// Discovery deliberately returns no connection until the backend can prove a
/// single supported programmer is usable. Consumers may use this separate
/// contract to explain an empty result without making every backend expose
/// platform-specific states.
abstract interface class ProgrammerDiscoveryDiagnostics {
  String? get discoveryReason;
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
