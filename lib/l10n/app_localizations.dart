import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// catalogLoadFailed
  ///
  /// In en, this message translates to:
  /// **'The offline device catalog could not be loaded.'**
  String get catalogLoadFailed;

  /// retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// languageSaveFailed
  ///
  /// In en, this message translates to:
  /// **'The language setting could not be saved. This selection applies until you close the app.'**
  String get languageSaveFailed;

  /// languageLoadFailed
  ///
  /// In en, this message translates to:
  /// **'The saved language setting could not be read. Using the system language.'**
  String get languageLoadFailed;

  /// technicalDetails
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get technicalDetails;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Generic cancel action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @programmer.
  ///
  /// In en, this message translates to:
  /// **'Programmer'**
  String get programmer;

  /// No description provided for @vendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendor;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// No description provided for @openBinButton.
  ///
  /// In en, this message translates to:
  /// **'Open BIN'**
  String get openBinButton;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @blankCheck.
  ///
  /// In en, this message translates to:
  /// **'Blank check'**
  String get blankCheck;

  /// No description provided for @program.
  ///
  /// In en, this message translates to:
  /// **'Program'**
  String get program;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @waitForOperationToFinish.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current operation to finish before closing.'**
  String get waitForOperationToFinish;

  /// No description provided for @programSimulatedIcTitle.
  ///
  /// In en, this message translates to:
  /// **'Program simulated IC?'**
  String get programSimulatedIcTitle;

  /// No description provided for @programIcTitle.
  ///
  /// In en, this message translates to:
  /// **'Program IC?'**
  String get programIcTitle;

  /// Confirmation before a simulated program operation.
  ///
  /// In en, this message translates to:
  /// **'This simulation will write the immutable snapshot {name} ({bytes} bytes), then read it back and verify every byte.\n\nTarget alias: {target}\nCapacity: {capacity} bytes\nSHA-1: {sha1}\n\nNo physical hardware is controlled.'**
  String programSimulationConfirmation(
    String name,
    int bytes,
    String target,
    String capacity,
    String sha1,
  );

  /// Confirmation before a physical program operation.
  ///
  /// In en, this message translates to:
  /// **'This operation will write the immutable snapshot {name} ({bytes} bytes), then read it back and verify every byte.\n\nTarget alias: {target}\nCapacity: {capacity} bytes\nSHA-1: {sha1}'**
  String programConfirmation(
    String name,
    int bytes,
    String target,
    String capacity,
    String sha1,
  );

  /// No description provided for @programSimulation.
  ///
  /// In en, this message translates to:
  /// **'Program simulation'**
  String get programSimulation;

  /// No description provided for @droppedFileCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'The dropped file could not be opened.'**
  String get droppedFileCouldNotBeOpened;

  /// No description provided for @dropFileOnInputBin.
  ///
  /// In en, this message translates to:
  /// **'Drop a file on the Input BIN panel.'**
  String get dropFileOnInputBin;

  /// No description provided for @droppedItemNotReadableFile.
  ///
  /// In en, this message translates to:
  /// **'The dropped item is not a readable file.'**
  String get droppedItemNotReadableFile;

  /// No description provided for @binFileCouldNotBeOpened.
  ///
  /// In en, this message translates to:
  /// **'The BIN file could not be opened.'**
  String get binFileCouldNotBeOpened;

  /// No description provided for @anotherInputFileLoading.
  ///
  /// In en, this message translates to:
  /// **'Another input file is still loading.'**
  String get anotherInputFileLoading;

  /// No description provided for @waitForOperationBeforeOpeningFile.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current operation before opening a file.'**
  String get waitForOperationBeforeOpeningFile;

  /// No description provided for @binFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'BIN files larger than 64 MiB are not supported yet.'**
  String get binFileTooLarge;

  /// No description provided for @selectedDevice.
  ///
  /// In en, this message translates to:
  /// **'the selected device'**
  String get selectedDevice;

  /// Title for a physical operation safety dialog.
  ///
  /// In en, this message translates to:
  /// **'Confirm physical {operation}'**
  String confirmPhysicalOperation(String operation);

  /// Target alias field.
  ///
  /// In en, this message translates to:
  /// **'Target alias: {target}'**
  String targetAlias(String target);

  /// Capacity field.
  ///
  /// In en, this message translates to:
  /// **'Capacity: {capacity} bytes'**
  String capacityBytes(String capacity);

  /// No description provided for @physicalOperationWarning.
  ///
  /// In en, this message translates to:
  /// **'Confirm the IC alias, orientation, socket placement, and any required adapter before continuing. This catalog entry is upstream-defined and is not proof of physical support.'**
  String get physicalOperationWarning;

  /// No description provided for @confirmIcAndSetupChecked.
  ///
  /// In en, this message translates to:
  /// **'I have checked the IC and setup.'**
  String get confirmIcAndSetupChecked;

  /// Starts a named operation.
  ///
  /// In en, this message translates to:
  /// **'Start {operation}'**
  String startOperation(String operation);

  /// Operation phase and its status message.
  ///
  /// In en, this message translates to:
  /// **'{phase}: {message}'**
  String phaseStatus(String phase, String message);

  /// No description provided for @noOperationInProgress.
  ///
  /// In en, this message translates to:
  /// **'No operation in progress.'**
  String get noOperationInProgress;

  /// No description provided for @operationInProgressWarning.
  ///
  /// In en, this message translates to:
  /// **'Operation in progress — do not touch the programmer, IC or USB cable.'**
  String get operationInProgressWarning;

  /// No description provided for @operationInProgressSimulationWarning.
  ///
  /// In en, this message translates to:
  /// **'Operation in progress — do not touch the programmer, IC or USB cable. Simulation only.'**
  String get operationInProgressSimulationWarning;

  /// No description provided for @refreshSimulation.
  ///
  /// In en, this message translates to:
  /// **'Refresh simulation'**
  String get refreshSimulation;

  /// No description provided for @refreshTl866cs.
  ///
  /// In en, this message translates to:
  /// **'Refresh TL866CS'**
  String get refreshTl866cs;

  /// Simulation connection summary.
  ///
  /// In en, this message translates to:
  /// **'Simulation connected · {model} · {firmware}'**
  String simulationConnected(String model, String firmware);

  /// No description provided for @mockProgrammer.
  ///
  /// In en, this message translates to:
  /// **'mock programmer'**
  String get mockProgrammer;

  /// No description provided for @firmwareUnknown.
  ///
  /// In en, this message translates to:
  /// **'firmware unknown'**
  String get firmwareUnknown;

  /// No description provided for @simulationConnectedOperationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Simulation connected · operation in progress'**
  String get simulationConnectedOperationInProgress;

  /// No description provided for @tl866csConnectedOperationInProgress.
  ///
  /// In en, this message translates to:
  /// **'TL866CS connected · operation in progress'**
  String get tl866csConnectedOperationInProgress;

  /// No description provided for @checkingSimulationConnection.
  ///
  /// In en, this message translates to:
  /// **'Checking simulation connection…'**
  String get checkingSimulationConnection;

  /// No description provided for @checkingTl866csConnection.
  ///
  /// In en, this message translates to:
  /// **'Checking TL866CS connection…'**
  String get checkingTl866csConnection;

  /// No description provided for @simulationDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Simulation disconnected'**
  String get simulationDisconnected;

  /// No description provided for @phaseIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get phaseIdle;

  /// No description provided for @phaseAwaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting confirmation'**
  String get phaseAwaitingConfirmation;

  /// No description provided for @phasePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get phasePreparing;

  /// No description provided for @phaseRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get phaseRunning;

  /// No description provided for @phaseReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get phaseReading;

  /// No description provided for @phaseBlankChecking.
  ///
  /// In en, this message translates to:
  /// **'Blank checking'**
  String get phaseBlankChecking;

  /// No description provided for @phaseProgramming.
  ///
  /// In en, this message translates to:
  /// **'Programming'**
  String get phaseProgramming;

  /// No description provided for @phaseReadingBack.
  ///
  /// In en, this message translates to:
  /// **'Reading back'**
  String get phaseReadingBack;

  /// No description provided for @phaseComparing.
  ///
  /// In en, this message translates to:
  /// **'Comparing'**
  String get phaseComparing;

  /// No description provided for @phaseCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get phaseCompleted;

  /// No description provided for @phaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get phaseFailed;

  /// No description provided for @phaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get phaseCancelled;

  /// No description provided for @phaseRecoveryRequired.
  ///
  /// In en, this message translates to:
  /// **'Recovery required'**
  String get phaseRecoveryRequired;

  /// Unavailable future programmer option.
  ///
  /// In en, this message translates to:
  /// **'{programmer} (future)'**
  String futureProgrammer(String programmer);

  /// No description provided for @chooseVendor.
  ///
  /// In en, this message translates to:
  /// **'Choose a vendor'**
  String get chooseVendor;

  /// Selected target and capacity.
  ///
  /// In en, this message translates to:
  /// **'Target: {target} · {capacity} bytes'**
  String targetWithCapacity(String target, String capacity);

  /// No description provided for @unsupportedForAuthorizedHardwareEvaluation.
  ///
  /// In en, this message translates to:
  /// **'Unsupported for authorized hardware evaluation'**
  String get unsupportedForAuthorizedHardwareEvaluation;

  /// No description provided for @hardwareProfileValidated.
  ///
  /// In en, this message translates to:
  /// **'Hardware profile validated'**
  String get hardwareProfileValidated;

  /// No description provided for @hardwareEvaluationNotYetValidated.
  ///
  /// In en, this message translates to:
  /// **'Hardware evaluation · not yet validated on this IC'**
  String get hardwareEvaluationNotYetValidated;

  /// No description provided for @chooseVendorFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a vendor first'**
  String get chooseVendorFirst;

  /// Device selector hint.
  ///
  /// In en, this message translates to:
  /// **'Search all {count} device records'**
  String searchAllDeviceRecords(int count);

  /// No description provided for @showAllDevicesForVendor.
  ///
  /// In en, this message translates to:
  /// **'Show all devices for selected vendor'**
  String get showAllDevicesForVendor;

  /// No description provided for @pinsUnspecified.
  ///
  /// In en, this message translates to:
  /// **'pins unspecified'**
  String get pinsUnspecified;

  /// Catalog device type and pin count.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {pins}'**
  String deviceKindAndPins(String kind, String pins);

  /// No description provided for @deviceTypeEepromMemory.
  ///
  /// In en, this message translates to:
  /// **'EEPROM / memory'**
  String get deviceTypeEepromMemory;

  /// No description provided for @deviceTypeMcuMpu.
  ///
  /// In en, this message translates to:
  /// **'MCU / MPU'**
  String get deviceTypeMcuMpu;

  /// No description provided for @deviceTypePldCpld.
  ///
  /// In en, this message translates to:
  /// **'PLD / CPLD'**
  String get deviceTypePldCpld;

  /// No description provided for @deviceTypeSram.
  ///
  /// In en, this message translates to:
  /// **'SRAM'**
  String get deviceTypeSram;

  /// No description provided for @deviceTypeLogic.
  ///
  /// In en, this message translates to:
  /// **'Logic'**
  String get deviceTypeLogic;

  /// No description provided for @deviceTypeNand.
  ///
  /// In en, this message translates to:
  /// **'NAND'**
  String get deviceTypeNand;

  /// No description provided for @deviceTypeEmmc.
  ///
  /// In en, this message translates to:
  /// **'eMMC'**
  String get deviceTypeEmmc;

  /// No description provided for @deviceTypeVgaHdmi.
  ///
  /// In en, this message translates to:
  /// **'VGA / HDMI'**
  String get deviceTypeVgaHdmi;

  /// No description provided for @deviceTypeUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get deviceTypeUnspecified;

  /// First binary mismatch and total count.
  ///
  /// In en, this message translates to:
  /// **'First mismatch: 0x{address} · {count} difference(s)'**
  String firstMismatch(String address, int count);

  /// No description provided for @viewerJumpToAddress.
  ///
  /// In en, this message translates to:
  /// **'Jump to address'**
  String get viewerJumpToAddress;

  /// No description provided for @viewerHexadecimalAddress.
  ///
  /// In en, this message translates to:
  /// **'Hexadecimal address'**
  String get viewerHexadecimalAddress;

  /// No description provided for @viewerJump.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get viewerJump;

  /// No description provided for @viewerAddressOutsideSnapshot.
  ///
  /// In en, this message translates to:
  /// **'That address is outside this snapshot.'**
  String get viewerAddressOutsideSnapshot;

  /// No description provided for @viewerNoDifferencesFound.
  ///
  /// In en, this message translates to:
  /// **'No differences found.'**
  String get viewerNoDifferencesFound;

  /// No description provided for @viewerInputBin.
  ///
  /// In en, this message translates to:
  /// **'Input BIN'**
  String get viewerInputBin;

  /// No description provided for @viewerIcReadout.
  ///
  /// In en, this message translates to:
  /// **'IC Readout'**
  String get viewerIcReadout;

  /// Column count selector.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String viewerBytesPerRow(int count);

  /// No description provided for @viewerPreviousDifference.
  ///
  /// In en, this message translates to:
  /// **'Previous difference'**
  String get viewerPreviousDifference;

  /// No description provided for @viewerNextDifference.
  ///
  /// In en, this message translates to:
  /// **'Next difference'**
  String get viewerNextDifference;

  /// No description provided for @viewerDropFileToOpen.
  ///
  /// In en, this message translates to:
  /// **'Drop a file here to open'**
  String get viewerDropFileToOpen;

  /// No description provided for @viewerReadIcFromProgrammer.
  ///
  /// In en, this message translates to:
  /// **'Read IC from programmer'**
  String get viewerReadIcFromProgrammer;

  /// No description provided for @viewerInputDropRegion.
  ///
  /// In en, this message translates to:
  /// **'Input BIN drop region'**
  String get viewerInputDropRegion;

  /// No description provided for @viewerReadoutEmptyRegion.
  ///
  /// In en, this message translates to:
  /// **'IC Readout empty region'**
  String get viewerReadoutEmptyRegion;

  /// Empty snapshot summary.
  ///
  /// In en, this message translates to:
  /// **'{title} · no snapshot'**
  String viewerNoSnapshot(String title);

  /// Snapshot summary header.
  ///
  /// In en, this message translates to:
  /// **'{title} · Read only'**
  String viewerReadOnly(String title);

  /// Snapshot name and size.
  ///
  /// In en, this message translates to:
  /// **'{name} · {bytes} bytes'**
  String viewerImageSize(String name, int bytes);

  /// Origin of a stale snapshot.
  ///
  /// In en, this message translates to:
  /// **'{origin} · previous successful readout'**
  String viewerPreviousSuccessfulReadout(String origin);

  /// No description provided for @viewerOriginInputBin.
  ///
  /// In en, this message translates to:
  /// **'Input BIN'**
  String get viewerOriginInputBin;

  /// No description provided for @viewerOriginIcReadoutSnapshot.
  ///
  /// In en, this message translates to:
  /// **'IC readout snapshot'**
  String get viewerOriginIcReadoutSnapshot;

  /// No description provided for @viewerOriginPostWriteVerificationSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Post-write verification snapshot'**
  String get viewerOriginPostWriteVerificationSnapshot;

  /// No description provided for @viewerNoByteSelected.
  ///
  /// In en, this message translates to:
  /// **'No byte selected'**
  String get viewerNoByteSelected;

  /// Accessibility label for selected byte.
  ///
  /// In en, this message translates to:
  /// **'Address {address}, value {hex}, decimal {decimal}, binary {binary}, ASCII {ascii}'**
  String viewerByteSelection(
    String address,
    String hex,
    int decimal,
    String binary,
    String ascii,
  );

  /// No description provided for @viewerChecksumCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get viewerChecksumCalculating;

  /// No description provided for @viewerAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get viewerAddress;

  /// No description provided for @viewerHex.
  ///
  /// In en, this message translates to:
  /// **'HEX'**
  String get viewerHex;

  /// No description provided for @viewerDecimal.
  ///
  /// In en, this message translates to:
  /// **'Decimal'**
  String get viewerDecimal;

  /// No description provided for @viewerBinary.
  ///
  /// In en, this message translates to:
  /// **'Binary'**
  String get viewerBinary;

  /// No description provided for @viewerAscii.
  ///
  /// In en, this message translates to:
  /// **'ASCII'**
  String get viewerAscii;

  /// No description provided for @backendSimulation.
  ///
  /// In en, this message translates to:
  /// **'Simulation backend'**
  String get backendSimulation;

  /// No description provided for @backendNotConnected.
  ///
  /// In en, this message translates to:
  /// **'TL866CS not connected'**
  String get backendNotConnected;

  /// No description provided for @backendConnected.
  ///
  /// In en, this message translates to:
  /// **'TL866CS connected ({identifier})'**
  String backendConnected(Object identifier);

  /// No description provided for @operationAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'Another operation is already running.'**
  String get operationAlreadyRunning;

  /// No description provided for @connectOneProgrammer.
  ///
  /// In en, this message translates to:
  /// **'Connect exactly one programmer first.'**
  String get connectOneProgrammer;

  /// No description provided for @chooseProfile.
  ///
  /// In en, this message translates to:
  /// **'Choose a device profile first.'**
  String get chooseProfile;

  /// No description provided for @profileNoMemoryOperations.
  ///
  /// In en, this message translates to:
  /// **'The selected profile does not support memory operations.'**
  String get profileNoMemoryOperations;

  /// No description provided for @openBin.
  ///
  /// In en, this message translates to:
  /// **'Open a BIN file first.'**
  String get openBin;

  /// No description provided for @inputSizeMismatch.
  ///
  /// In en, this message translates to:
  /// **'The input BIN must exactly match the IC capacity.'**
  String get inputSizeMismatch;

  /// No description provided for @profileOutsideScope.
  ///
  /// In en, this message translates to:
  /// **'This database profile is outside the authorized TL866CS evaluation scope.'**
  String get profileOutsideScope;

  /// No description provided for @waitBeforeReconnect.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current operation before reconnecting.'**
  String get waitBeforeReconnect;

  /// No description provided for @checkingSimulation.
  ///
  /// In en, this message translates to:
  /// **'Looking for the simulation programmer…'**
  String get checkingSimulation;

  /// No description provided for @checkingTl866.
  ///
  /// In en, this message translates to:
  /// **'Checking one TL866CS connection…'**
  String get checkingTl866;

  /// No description provided for @programmerReady.
  ///
  /// In en, this message translates to:
  /// **'{model} ready.'**
  String programmerReady(Object model);

  /// No description provided for @identityCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Programmer identity check failed.'**
  String get identityCheckFailed;

  /// No description provided for @simulationSelected.
  ///
  /// In en, this message translates to:
  /// **'Simulation demo selected. Connect to use the mock programmer.'**
  String get simulationSelected;

  /// No description provided for @realProgrammerSelected.
  ///
  /// In en, this message translates to:
  /// **'TL866CS mode selected. Refresh connection status.'**
  String get realProgrammerSelected;

  /// No description provided for @profileSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected {profile}.'**
  String profileSelected(Object profile);

  /// No description provided for @inputOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened {label} ({count} bytes).'**
  String inputOpened(Object label, int count);

  /// No description provided for @inputTooLarge.
  ///
  /// In en, this message translates to:
  /// **'BIN files larger than 64 MiB are not supported yet.'**
  String get inputTooLarge;

  /// No description provided for @confirmProgram.
  ///
  /// In en, this message translates to:
  /// **'Confirm program to write the immutable input snapshot.'**
  String get confirmProgram;

  /// No description provided for @programCancelled.
  ///
  /// In en, this message translates to:
  /// **'Program cancelled before writing.'**
  String get programCancelled;

  /// No description provided for @operationCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Operation could not start.'**
  String get operationCouldNotStart;

  /// No description provided for @reconnectBeforeOperation.
  ///
  /// In en, this message translates to:
  /// **'Refresh the TL866CS connection before another operation.'**
  String get reconnectBeforeOperation;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading code memory.'**
  String get reading;

  /// No description provided for @blankChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking code memory blank state.'**
  String get blankChecking;

  /// No description provided for @programming.
  ///
  /// In en, this message translates to:
  /// **'Programming immutable input snapshot.'**
  String get programming;

  /// No description provided for @readingBack.
  ///
  /// In en, this message translates to:
  /// **'Reading code memory after write.'**
  String get readingBack;

  /// No description provided for @comparing.
  ///
  /// In en, this message translates to:
  /// **'Comparing immutable input snapshot.'**
  String get comparing;

  /// No description provided for @readSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Read {count} bytes.'**
  String readSucceeded(int count);

  /// No description provided for @blankSucceeded.
  ///
  /// In en, this message translates to:
  /// **'IC code memory is blank.'**
  String get blankSucceeded;

  /// No description provided for @verificationSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Verification passed.'**
  String get verificationSucceeded;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed.'**
  String get verificationFailed;

  /// No description provided for @programSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Programmed and byte-verified {count} bytes.'**
  String programSucceeded(int count);

  /// No description provided for @operationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Operation stopped before the next hardware command.'**
  String get operationCancelled;

  /// No description provided for @identityChanged.
  ///
  /// In en, this message translates to:
  /// **'TL866CS identity changed; refresh before operating.'**
  String get identityChanged;

  /// No description provided for @identityChangedBeforeWrite.
  ///
  /// In en, this message translates to:
  /// **'TL866CS identity changed before writing; no write was started.'**
  String get identityChangedBeforeWrite;

  /// No description provided for @postWriteVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Post-write verification failed.'**
  String get postWriteVerificationFailed;

  /// No description provided for @stopAfterWrite.
  ///
  /// In en, this message translates to:
  /// **'Stop requested after writing began; verify contents before continuing.'**
  String get stopAfterWrite;

  /// No description provided for @technicalFailure.
  ///
  /// In en, this message translates to:
  /// **'Programmer operation failed. See technical details.'**
  String get technicalFailure;

  /// No description provided for @backendUnsupportedProfile.
  ///
  /// In en, this message translates to:
  /// **'This profile is not approved for real TL866CS evaluation.'**
  String get backendUnsupportedProfile;

  /// No description provided for @backendProfileValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'The selected device profile could not be validated by minipro.'**
  String get backendProfileValidationFailed;

  /// No description provided for @backendDiscoveryFailure.
  ///
  /// In en, this message translates to:
  /// **'The TL866CS connection check failed. See technical details.'**
  String get backendDiscoveryFailure;

  /// No description provided for @backendWinUsbSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up the WinUSB driver for TL866CS using the Windows installation instructions in README.md, then reconnect the programmer.'**
  String get backendWinUsbSetup;

  /// No description provided for @backendUsbAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'USB access was denied. Check the OS USB permissions and driver setup, then reconnect the programmer.'**
  String get backendUsbAccessDenied;

  /// No description provided for @backendBusy.
  ///
  /// In en, this message translates to:
  /// **'TL866CS is busy. Close other programmer software, then reconnect it.'**
  String get backendBusy;

  /// No description provided for @backendNotDetected.
  ///
  /// In en, this message translates to:
  /// **'No TL866A/CS programmer was detected.'**
  String get backendNotDetected;

  /// No description provided for @programmerDatabaseSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected the {programmer} device database.'**
  String programmerDatabaseSelected(String programmer);

  /// No description provided for @chooseCatalogDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose a device from the selected vendor and programmer database.'**
  String get chooseCatalogDevice;

  /// No description provided for @unsafeBinProfile.
  ///
  /// In en, this message translates to:
  /// **'{device} cannot be represented as a safe raw-BIN TL866CS profile.'**
  String unsafeBinProfile(String device);

  /// No description provided for @profileEmpiricallyValidated.
  ///
  /// In en, this message translates to:
  /// **'{device} has an empirical validation record.'**
  String profileEmpiricallyValidated(String device);

  /// No description provided for @profileAuthorizedNotValidated.
  ///
  /// In en, this message translates to:
  /// **'{device} is authorized for constrained hardware evaluation; it is not empirically validated.'**
  String profileAuthorizedNotValidated(String device);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
