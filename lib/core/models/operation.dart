// SPDX-License-Identifier: GPL-3.0-or-later

import 'binary_image.dart';
import 'device_profile.dart';
import 'programmer.dart';
import 'ui_message.dart';

enum OperationKind { read, blankCheck, program, verify }

enum OperationPhase {
  idle,
  preparing,
  awaitingConfirmation,
  running,
  reading,
  blankChecking,
  programming,
  readingBack,
  comparing,
  succeeded,
  failed,
  cancelled,
  recoveryRequired,
}

final class OperationPlan {
  const OperationPlan({
    required this.operationId,
    required this.kind,
    required this.connection,
    required this.profile,
    this.input,
  });

  final String operationId;
  final OperationKind kind;
  final ProgrammerConnection connection;
  final DeviceProfile profile;
  final BinaryImage? input;
}

final class OperationEvent {
  const OperationEvent({
    required this.operationId,
    required this.phase,
    this.progress,
    this.message,
    this.uiMessage,
  });

  final String operationId;
  final OperationPhase phase;
  final double? progress;
  final String? message;
  final UiMessage? uiMessage;
}

final class Mismatch {
  const Mismatch({
    required this.address,
    required this.expected,
    required this.actual,
  });

  final int address;
  final int expected;
  final int actual;
}

final class OperationResult {
  const OperationResult({
    required this.operationId,
    required this.phase,
    required this.message,
    this.uiMessage,
    this.technicalDetail,
    this.image,
    this.mismatch,
    this.mismatchCount = 0,
  });

  final String operationId;
  final OperationPhase phase;
  final String message;
  final UiMessage? uiMessage;

  /// Untranslated minipro/OS output, shown only as a technical detail.
  final String? technicalDetail;
  final BinaryImage? image;
  final Mismatch? mismatch;
  final int mismatchCount;

  bool get succeeded => phase == OperationPhase.succeeded;
}
