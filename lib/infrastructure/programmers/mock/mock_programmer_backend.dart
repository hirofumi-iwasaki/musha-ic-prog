// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import '../../../core/models/binary_image.dart';
import '../../../core/models/device_profile.dart';
import '../../../core/models/operation.dart';
import '../../../core/models/programmer.dart';
import '../../../core/ports/programmer_backend.dart';

/// A deterministic in-memory programmer for the prototype and automated tests.
/// It never enumerates USB or invokes a process.
final class MockProgrammerBackend implements ProgrammerBackend {
  MockProgrammerBackend({this.stepDelay = const Duration(milliseconds: 20)});

  final Duration stepDelay;
  Uint8List? _memory;
  final int _generation = 1;

  @override
  String get backendId => 'mock';

  @override
  Future<List<ProgrammerConnection>> scan() async => [
    ProgrammerConnection(
      backendId: backendId,
      model: 'Mock TL866CS',
      identifier: 'mock-programmer-1',
      firmware: 'mock-0.1',
      generation: _generation,
    ),
  ];

  @override
  Future<BackendCapabilities> capabilities(
    ProgrammerConnection connection,
    DeviceProfile profile,
  ) async => BackendCapabilities(
    canRead: profile.supportsMemoryOperations,
    canBlankCheck: profile.supportsMemoryOperations,
    canProgram: profile.supportsMemoryOperations,
    canVerify: profile.supportsMemoryOperations,
    reason: profile.supportsMemoryOperations
        ? null
        : 'Mock supports EPROM only.',
  );

  @override
  OperationHandle execute(OperationPlan plan) {
    final handle = _MockOperationHandle(plan.operationId, stepDelay);
    unawaited(_run(plan, handle));
    return handle;
  }

  Future<void> _run(OperationPlan plan, _MockOperationHandle handle) async {
    try {
      final size = plan.profile.capacityBytes!;
      _memory ??= Uint8List(size)..fillRange(0, size, plan.profile.blankValue);
      if (_memory!.length != size) {
        _memory = Uint8List(size)..fillRange(0, size, plan.profile.blankValue);
      }
      await handle.emit(
        OperationPhase.preparing,
        0,
        'Preparing mock operation',
      );
      if (handle.cancelled) return handle.finishCancelled();
      switch (plan.kind) {
        case OperationKind.read:
          await handle.emit(OperationPhase.reading, .5, 'Reading all bytes');
          if (handle.cancelled) return handle.finishCancelled();
          final image = BinaryImage(
            bytes: _memory!,
            origin: BinaryImageOrigin.readout,
            label: '${plan.profile.partNumber} readout',
          );
          return handle.finishSuccess(
            'Read ${image.length} bytes.',
            image: image,
          );
        case OperationKind.blankCheck:
          await handle.emit(
            OperationPhase.blankChecking,
            .5,
            'Checking blank state',
          );
          final mismatch = _firstNonBlank(_memory!, plan.profile.blankValue);
          if (mismatch == null) return handle.finishSuccess('IC is blank.');
          return handle.finishFailure(
            'IC is not blank at address 0x${mismatch.address.toRadixString(16)}.',
            mismatch: mismatch,
            mismatchCount: 1,
          );
        case OperationKind.program:
          await handle.emit(
            OperationPhase.blankChecking,
            .2,
            'Checking blank state',
          );
          final nonBlank = _firstNonBlank(_memory!, plan.profile.blankValue);
          if (nonBlank != null) {
            return handle.finishFailure(
              'Program stopped: IC is not blank.',
              mismatch: nonBlank,
            );
          }
          await handle.emit(
            OperationPhase.programming,
            .55,
            'Programming input snapshot',
          );
          if (handle.cancelled) return handle.finishCancelled();
          _memory = plan.input!.bytes;
          await handle.emit(
            OperationPhase.readingBack,
            .75,
            'Reading back programmed data',
          );
          await handle.emit(
            OperationPhase.comparing,
            .9,
            'Comparing all bytes',
          );
          return handle.finishSuccess(
            'Programmed and verified all $size bytes.',
          );
        case OperationKind.verify:
          await handle.emit(
            OperationPhase.readingBack,
            .5,
            'Reading IC for verification',
          );
          await handle.emit(
            OperationPhase.comparing,
            .8,
            'Comparing all bytes',
          );
          final mismatch = _firstMismatch(plan.input!.bytes, _memory!);
          if (mismatch != null) {
            return handle.finishFailure(
              'Verification failed at address 0x${mismatch.address.toRadixString(16)}.',
              mismatch: mismatch,
              mismatchCount: 1,
            );
          }
          return handle.finishSuccess(
            'Verification passed for all $size bytes.',
          );
      }
    } catch (error) {
      handle.finishFailure('Mock backend error: $error');
    }
  }

  Mismatch? _firstNonBlank(Uint8List bytes, int blankValue) {
    for (var index = 0; index < bytes.length; index++) {
      if (bytes[index] != blankValue) {
        return Mismatch(
          address: index,
          expected: blankValue,
          actual: bytes[index],
        );
      }
    }
    return null;
  }

  Mismatch? _firstMismatch(Uint8List expected, Uint8List actual) {
    for (var index = 0; index < expected.length; index++) {
      if (expected[index] != actual[index]) {
        return Mismatch(
          address: index,
          expected: expected[index],
          actual: actual[index],
        );
      }
    }
    return null;
  }
}

final class _MockOperationHandle implements OperationHandle {
  _MockOperationHandle(this._operationId, this._stepDelay);

  final String _operationId;
  final Duration _stepDelay;
  final StreamController<OperationEvent> _events = StreamController.broadcast();
  final Completer<OperationResult> _result = Completer();
  bool cancelled = false;

  @override
  Stream<OperationEvent> get events => _events.stream;

  @override
  Future<OperationResult> get completed => _result.future;

  @override
  Future<void> requestCancel() async => cancelled = true;

  Future<void> emit(
    OperationPhase phase,
    double progress,
    String message,
  ) async {
    _events.add(
      OperationEvent(
        operationId: _operationId,
        phase: phase,
        progress: progress,
        message: message,
      ),
    );
    await Future<void>.delayed(_stepDelay);
  }

  void finishSuccess(String message, {BinaryImage? image}) => _finish(
    OperationResult(
      operationId: _operationId,
      phase: OperationPhase.succeeded,
      message: message,
      image: image,
    ),
  );

  void finishFailure(
    String message, {
    Mismatch? mismatch,
    int mismatchCount = 0,
  }) => _finish(
    OperationResult(
      operationId: _operationId,
      phase: OperationPhase.failed,
      message: message,
      mismatch: mismatch,
      mismatchCount: mismatchCount,
    ),
  );

  void finishCancelled() => _finish(
    OperationResult(
      operationId: _operationId,
      phase: OperationPhase.cancelled,
      message: 'Operation cancelled.',
    ),
  );

  void _finish(OperationResult result) {
    if (!_result.isCompleted) _result.complete(result);
    unawaited(_events.close());
  }
}
