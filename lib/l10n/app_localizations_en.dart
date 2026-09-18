// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get catalogLoadFailed =>
      'The offline device catalog could not be loaded.';

  @override
  String get retry => 'Retry';

  @override
  String get languageSaveFailed =>
      'The language setting could not be saved. This selection applies until you close the app.';

  @override
  String get languageLoadFailed =>
      'The saved language setting could not be read. Using the system language.';

  @override
  String get technicalDetails => 'Technical details';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get programmer => 'Programmer';

  @override
  String get vendor => 'Vendor';

  @override
  String get device => 'Device';

  @override
  String get openBinButton => 'Open BIN';

  @override
  String get read => 'Read';

  @override
  String get blankCheck => 'Blank check';

  @override
  String get program => 'Program';

  @override
  String get verify => 'Verify';

  @override
  String get waitForOperationToFinish =>
      'Wait for the current operation to finish before closing.';

  @override
  String get programSimulatedIcTitle => 'Program simulated IC?';

  @override
  String get programIcTitle => 'Program IC?';

  @override
  String programSimulationConfirmation(
    String name,
    int bytes,
    String target,
    String capacity,
    String sha1,
  ) {
    return 'This simulation will write the immutable snapshot $name ($bytes bytes), then read it back and verify every byte.\n\nTarget alias: $target\nCapacity: $capacity bytes\nSHA-1: $sha1\n\nNo physical hardware is controlled.';
  }

  @override
  String programConfirmation(
    String name,
    int bytes,
    String target,
    String capacity,
    String sha1,
  ) {
    return 'This operation will write the immutable snapshot $name ($bytes bytes), then read it back and verify every byte.\n\nTarget alias: $target\nCapacity: $capacity bytes\nSHA-1: $sha1';
  }

  @override
  String get programSimulation => 'Program simulation';

  @override
  String get droppedFileCouldNotBeOpened =>
      'The dropped file could not be opened.';

  @override
  String get dropFileOnInputBin => 'Drop a file on the Input BIN panel.';

  @override
  String get droppedItemNotReadableFile =>
      'The dropped item is not a readable file.';

  @override
  String get binFileCouldNotBeOpened => 'The BIN file could not be opened.';

  @override
  String get anotherInputFileLoading => 'Another input file is still loading.';

  @override
  String get waitForOperationBeforeOpeningFile =>
      'Wait for the current operation before opening a file.';

  @override
  String get binFileTooLarge =>
      'BIN files larger than 64 MiB are not supported yet.';

  @override
  String get selectedDevice => 'the selected device';

  @override
  String confirmPhysicalOperation(String operation) {
    return 'Confirm physical $operation';
  }

  @override
  String targetAlias(String target) {
    return 'Target alias: $target';
  }

  @override
  String capacityBytes(String capacity) {
    return 'Capacity: $capacity bytes';
  }

  @override
  String get physicalOperationWarning =>
      'Confirm the IC alias, orientation, socket placement, and any required adapter before continuing. This catalog entry is upstream-defined and is not proof of physical support.';

  @override
  String get confirmIcAndSetupChecked => 'I have checked the IC and setup.';

  @override
  String startOperation(String operation) {
    return 'Start $operation';
  }

  @override
  String phaseStatus(String phase, String message) {
    return '$phase: $message';
  }

  @override
  String get noOperationInProgress => 'No operation in progress.';

  @override
  String get operationInProgressWarning =>
      'Operation in progress — do not touch the programmer, IC or USB cable.';

  @override
  String get operationInProgressSimulationWarning =>
      'Operation in progress — do not touch the programmer, IC or USB cable. Simulation only.';

  @override
  String get refreshSimulation => 'Refresh simulation';

  @override
  String get refreshTl866cs => 'Refresh TL866CS';

  @override
  String simulationConnected(String model, String firmware) {
    return 'Simulation connected · $model · $firmware';
  }

  @override
  String get mockProgrammer => 'mock programmer';

  @override
  String get firmwareUnknown => 'firmware unknown';

  @override
  String get simulationConnectedOperationInProgress =>
      'Simulation connected · operation in progress';

  @override
  String get tl866csConnectedOperationInProgress =>
      'TL866CS connected · operation in progress';

  @override
  String get checkingSimulationConnection => 'Checking simulation connection…';

  @override
  String get checkingTl866csConnection => 'Checking TL866CS connection…';

  @override
  String get simulationDisconnected => 'Simulation disconnected';

  @override
  String get phaseIdle => 'Idle';

  @override
  String get phaseAwaitingConfirmation => 'Awaiting confirmation';

  @override
  String get phasePreparing => 'Preparing';

  @override
  String get phaseRunning => 'Running';

  @override
  String get phaseReading => 'Reading';

  @override
  String get phaseBlankChecking => 'Blank checking';

  @override
  String get phaseProgramming => 'Programming';

  @override
  String get phaseReadingBack => 'Reading back';

  @override
  String get phaseComparing => 'Comparing';

  @override
  String get phaseCompleted => 'Completed';

  @override
  String get phaseFailed => 'Failed';

  @override
  String get phaseCancelled => 'Cancelled';

  @override
  String get phaseRecoveryRequired => 'Recovery required';

  @override
  String futureProgrammer(String programmer) {
    return '$programmer (future)';
  }

  @override
  String get chooseVendor => 'Choose a vendor';

  @override
  String targetWithCapacity(String target, String capacity) {
    return 'Target: $target · $capacity bytes';
  }

  @override
  String get unsupportedForAuthorizedHardwareEvaluation =>
      'Unsupported for authorized hardware evaluation';

  @override
  String get hardwareProfileValidated => 'Hardware profile validated';

  @override
  String get hardwareEvaluationNotYetValidated =>
      'Hardware evaluation · not yet validated on this IC';

  @override
  String get chooseVendorFirst => 'Choose a vendor first';

  @override
  String searchAllDeviceRecords(int count) {
    return 'Search all $count device records';
  }

  @override
  String get showAllDevicesForVendor => 'Show all devices for selected vendor';

  @override
  String get pinsUnspecified => 'pins unspecified';

  @override
  String deviceKindAndPins(String kind, String pins) {
    return '$kind · $pins';
  }

  @override
  String get deviceTypeEepromMemory => 'EEPROM / memory';

  @override
  String get deviceTypeMcuMpu => 'MCU / MPU';

  @override
  String get deviceTypePldCpld => 'PLD / CPLD';

  @override
  String get deviceTypeSram => 'SRAM';

  @override
  String get deviceTypeLogic => 'Logic';

  @override
  String get deviceTypeNand => 'NAND';

  @override
  String get deviceTypeEmmc => 'eMMC';

  @override
  String get deviceTypeVgaHdmi => 'VGA / HDMI';

  @override
  String get deviceTypeUnspecified => 'Unspecified';

  @override
  String firstMismatch(String address, int count) {
    return 'First mismatch: 0x$address · $count difference(s)';
  }

  @override
  String get viewerJumpToAddress => 'Jump to address';

  @override
  String get viewerHexadecimalAddress => 'Hexadecimal address';

  @override
  String get viewerJump => 'Jump';

  @override
  String get viewerAddressOutsideSnapshot =>
      'That address is outside this snapshot.';

  @override
  String get viewerNoDifferencesFound => 'No differences found.';

  @override
  String get viewerInputBin => 'Input BIN';

  @override
  String get viewerIcReadout => 'IC Readout';

  @override
  String viewerBytesPerRow(int count) {
    return '$count bytes';
  }

  @override
  String get viewerPreviousDifference => 'Previous difference';

  @override
  String get viewerNextDifference => 'Next difference';

  @override
  String get viewerDropFileToOpen => 'Drop a file here to open';

  @override
  String get viewerReadIcFromProgrammer => 'Read IC from programmer';

  @override
  String get viewerInputDropRegion => 'Input BIN drop region';

  @override
  String get viewerReadoutEmptyRegion => 'IC Readout empty region';

  @override
  String viewerNoSnapshot(String title) {
    return '$title · no snapshot';
  }

  @override
  String viewerReadOnly(String title) {
    return '$title · Read only';
  }

  @override
  String viewerImageSize(String name, int bytes) {
    return '$name · $bytes bytes';
  }

  @override
  String viewerPreviousSuccessfulReadout(String origin) {
    return '$origin · previous successful readout';
  }

  @override
  String get viewerOriginInputBin => 'Input BIN';

  @override
  String get viewerOriginIcReadoutSnapshot => 'IC readout snapshot';

  @override
  String get viewerOriginPostWriteVerificationSnapshot =>
      'Post-write verification snapshot';

  @override
  String get viewerNoByteSelected => 'No byte selected';

  @override
  String viewerByteSelection(
    String address,
    String hex,
    int decimal,
    String binary,
    String ascii,
  ) {
    return 'Address $address, value $hex, decimal $decimal, binary $binary, ASCII $ascii';
  }

  @override
  String get viewerChecksumCalculating => 'Calculating…';

  @override
  String get viewerAddress => 'Address';

  @override
  String get viewerHex => 'HEX';

  @override
  String get viewerDecimal => 'Decimal';

  @override
  String get viewerBinary => 'Binary';

  @override
  String get viewerAscii => 'ASCII';

  @override
  String get backendSimulation => 'Simulation backend';

  @override
  String get backendNotConnected => 'TL866CS not connected';

  @override
  String backendConnected(Object identifier) {
    return 'TL866CS connected ($identifier)';
  }

  @override
  String get operationAlreadyRunning => 'Another operation is already running.';

  @override
  String get connectOneProgrammer => 'Connect exactly one programmer first.';

  @override
  String get chooseProfile => 'Choose a device profile first.';

  @override
  String get profileNoMemoryOperations =>
      'The selected profile does not support memory operations.';

  @override
  String get openBin => 'Open a BIN file first.';

  @override
  String get inputSizeMismatch =>
      'The input BIN must exactly match the IC capacity.';

  @override
  String get profileOutsideScope =>
      'This database profile is outside the authorized TL866CS evaluation scope.';

  @override
  String get waitBeforeReconnect =>
      'Wait for the current operation before reconnecting.';

  @override
  String get checkingSimulation => 'Looking for the simulation programmer…';

  @override
  String get checkingTl866 => 'Checking one TL866CS connection…';

  @override
  String programmerReady(Object model) {
    return '$model ready.';
  }

  @override
  String get identityCheckFailed => 'Programmer identity check failed.';

  @override
  String get simulationSelected =>
      'Simulation demo selected. Connect to use the mock programmer.';

  @override
  String get realProgrammerSelected =>
      'TL866CS mode selected. Refresh connection status.';

  @override
  String profileSelected(Object profile) {
    return 'Selected $profile.';
  }

  @override
  String inputOpened(Object label, int count) {
    return 'Opened $label ($count bytes).';
  }

  @override
  String get inputTooLarge =>
      'BIN files larger than 64 MiB are not supported yet.';

  @override
  String get confirmProgram =>
      'Confirm program to write the immutable input snapshot.';

  @override
  String get programCancelled => 'Program cancelled before writing.';

  @override
  String get operationCouldNotStart => 'Operation could not start.';

  @override
  String get reconnectBeforeOperation =>
      'Refresh the TL866CS connection before another operation.';

  @override
  String get reading => 'Reading code memory.';

  @override
  String get blankChecking => 'Checking code memory blank state.';

  @override
  String get programming => 'Programming immutable input snapshot.';

  @override
  String get readingBack => 'Reading code memory after write.';

  @override
  String get comparing => 'Comparing immutable input snapshot.';

  @override
  String readSucceeded(int count) {
    return 'Read $count bytes.';
  }

  @override
  String get blankSucceeded => 'IC code memory is blank.';

  @override
  String get verificationSucceeded => 'Verification passed.';

  @override
  String get verificationFailed => 'Verification failed.';

  @override
  String programSucceeded(int count) {
    return 'Programmed and byte-verified $count bytes.';
  }

  @override
  String get operationCancelled =>
      'Operation stopped before the next hardware command.';

  @override
  String get identityChanged =>
      'TL866CS identity changed; refresh before operating.';

  @override
  String get identityChangedBeforeWrite =>
      'TL866CS identity changed before writing; no write was started.';

  @override
  String get postWriteVerificationFailed => 'Post-write verification failed.';

  @override
  String get stopAfterWrite =>
      'Stop requested after writing began; verify contents before continuing.';

  @override
  String get technicalFailure =>
      'Programmer operation failed. See technical details.';

  @override
  String get backendUnsupportedProfile =>
      'This profile is not approved for real TL866CS evaluation.';

  @override
  String get backendProfileValidationFailed =>
      'The selected device profile could not be validated by minipro.';

  @override
  String get backendDiscoveryFailure =>
      'The TL866CS connection check failed. See technical details.';

  @override
  String get backendWinUsbSetup =>
      'Set up the WinUSB driver for TL866CS using the Windows installation instructions in README.md, then reconnect the programmer.';

  @override
  String get backendUsbAccessDenied =>
      'USB access was denied. Check the OS USB permissions and driver setup, then reconnect the programmer.';

  @override
  String get backendBusy =>
      'TL866CS is busy. Close other programmer software, then reconnect it.';

  @override
  String get backendNotDetected => 'No TL866A/CS programmer was detected.';

  @override
  String programmerDatabaseSelected(String programmer) {
    return 'Selected the $programmer device database.';
  }

  @override
  String get chooseCatalogDevice =>
      'Choose a device from the selected vendor and programmer database.';

  @override
  String unsafeBinProfile(String device) {
    return '$device cannot be represented as a safe raw-BIN TL866CS profile.';
  }

  @override
  String profileEmpiricallyValidated(String device) {
    return '$device has an empirical validation record.';
  }

  @override
  String profileAuthorizedNotValidated(String device) {
    return '$device is authorized for constrained hardware evaluation; it is not empirically validated.';
  }
}
