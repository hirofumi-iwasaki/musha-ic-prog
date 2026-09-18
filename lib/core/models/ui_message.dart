// SPDX-License-Identifier: GPL-3.0-or-later

/// A presentation-independent, localized-at-the-edge application message.
///
/// [message] remains available beside this value for logs, compatibility and
/// raw tool diagnostics. Never derive this identifier by parsing that text.
enum UiMessageId {
  backendSimulation,
  backendNotConnected,
  backendConnected,
  operationAlreadyRunning,
  connectOneProgrammer,
  chooseProfile,
  profileNoMemoryOperations,
  openBin,
  inputSizeMismatch,
  profileOutsideScope,
  waitBeforeReconnect,
  checkingSimulation,
  checkingTl866,
  programmerReady,
  identityCheckFailed,
  simulationSelected,
  realProgrammerSelected,
  profileSelected,
  inputOpened,
  inputTooLarge,
  confirmProgram,
  programCancelled,
  operationCouldNotStart,
  reconnectBeforeOperation,
  reading,
  blankChecking,
  programming,
  readingBack,
  comparing,
  readSucceeded,
  blankSucceeded,
  verificationSucceeded,
  verificationFailed,
  programSucceeded,
  operationCancelled,
  identityChanged,
  identityChangedBeforeWrite,
  postWriteVerificationFailed,
  stopAfterWrite,
  technicalFailure,
  backendUnsupportedProfile,
  backendProfileValidationFailed,
  backendDiscoveryFailure,
  backendWinUsbSetup,
  backendUsbAccessDenied,
  backendBusy,
  backendNotDetected,
  programmerDatabaseSelected,
  chooseCatalogDevice,
  unsafeBinProfile,
  profileEmpiricallyValidated,
  profileAuthorizedNotValidated,
}

final class UiMessage {
  /// Parameter maps are values supplied by the producer and must be treated as
  /// immutable after construction. Keeping this constructor const makes the
  /// common no-parameter messages allocation-free.
  const UiMessage(this.id, [this.parameters = const {}]);

  final UiMessageId id;
  final Map<String, Object?> parameters;

  Object? operator [](String key) => parameters[key];
}
