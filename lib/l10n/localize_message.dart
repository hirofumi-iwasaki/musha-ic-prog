// SPDX-License-Identifier: GPL-3.0-or-later

import 'app_localizations.dart';
import '../core/models/ui_message.dart';

/// Resolves app-owned semantic messages at the presentation boundary.
/// Raw minipro and operating-system diagnostics intentionally bypass this
/// resolver and remain technical details.
String localizeMessage(AppLocalizations l10n, UiMessage message) {
  final p = message.parameters;
  switch (message.id) {
    case UiMessageId.backendSimulation:
      return l10n.backendSimulation;
    case UiMessageId.backendNotConnected:
      return l10n.backendNotConnected;
    case UiMessageId.backendConnected:
      return l10n.backendConnected('${p['identifier'] ?? ''}');
    case UiMessageId.operationAlreadyRunning:
      return l10n.operationAlreadyRunning;
    case UiMessageId.connectOneProgrammer:
      return l10n.connectOneProgrammer;
    case UiMessageId.chooseProfile:
      return l10n.chooseProfile;
    case UiMessageId.profileNoMemoryOperations:
      return l10n.profileNoMemoryOperations;
    case UiMessageId.openBin:
      return l10n.openBin;
    case UiMessageId.inputSizeMismatch:
      return l10n.inputSizeMismatch;
    case UiMessageId.profileOutsideScope:
      return l10n.profileOutsideScope;
    case UiMessageId.waitBeforeReconnect:
      return l10n.waitBeforeReconnect;
    case UiMessageId.checkingSimulation:
      return l10n.checkingSimulation;
    case UiMessageId.checkingTl866:
      return l10n.checkingTl866;
    case UiMessageId.programmerReady:
      return l10n.programmerReady('${p['model'] ?? ''}');
    case UiMessageId.identityCheckFailed:
      return l10n.identityCheckFailed;
    case UiMessageId.simulationSelected:
      return l10n.simulationSelected;
    case UiMessageId.realProgrammerSelected:
      return l10n.realProgrammerSelected;
    case UiMessageId.profileSelected:
      return l10n.profileSelected('${p['profile'] ?? ''}');
    case UiMessageId.inputOpened:
      return l10n.inputOpened(
        '${p['label'] ?? ''}',
        (p['count'] as num?)?.toInt() ?? 0,
      );
    case UiMessageId.inputTooLarge:
      return l10n.inputTooLarge;
    case UiMessageId.confirmProgram:
      return l10n.confirmProgram;
    case UiMessageId.programCancelled:
      return l10n.programCancelled;
    case UiMessageId.operationCouldNotStart:
      return l10n.operationCouldNotStart;
    case UiMessageId.reconnectBeforeOperation:
      return l10n.reconnectBeforeOperation;
    case UiMessageId.reading:
      return l10n.reading;
    case UiMessageId.blankChecking:
      return l10n.blankChecking;
    case UiMessageId.programming:
      return l10n.programming;
    case UiMessageId.readingBack:
      return l10n.readingBack;
    case UiMessageId.comparing:
      return l10n.comparing;
    case UiMessageId.readSucceeded:
      return l10n.readSucceeded((p['count'] as num?)?.toInt() ?? 0);
    case UiMessageId.blankSucceeded:
      return l10n.blankSucceeded;
    case UiMessageId.verificationSucceeded:
      return l10n.verificationSucceeded;
    case UiMessageId.verificationFailed:
      return l10n.verificationFailed;
    case UiMessageId.programSucceeded:
      return l10n.programSucceeded((p['count'] as num?)?.toInt() ?? 0);
    case UiMessageId.operationCancelled:
      return l10n.operationCancelled;
    case UiMessageId.identityChanged:
      return l10n.identityChanged;
    case UiMessageId.identityChangedBeforeWrite:
      return l10n.identityChangedBeforeWrite;
    case UiMessageId.postWriteVerificationFailed:
      return l10n.postWriteVerificationFailed;
    case UiMessageId.stopAfterWrite:
      return l10n.stopAfterWrite;
    case UiMessageId.technicalFailure:
      return l10n.technicalFailure;
    case UiMessageId.backendUnsupportedProfile:
      return l10n.backendUnsupportedProfile;
    case UiMessageId.backendProfileValidationFailed:
      return l10n.backendProfileValidationFailed;
    case UiMessageId.backendDiscoveryFailure:
      return l10n.backendDiscoveryFailure;
    case UiMessageId.backendWinUsbSetup:
      return l10n.backendWinUsbSetup;
    case UiMessageId.backendUsbAccessDenied:
      return l10n.backendUsbAccessDenied;
    case UiMessageId.backendBusy:
      return l10n.backendBusy;
    case UiMessageId.backendNotDetected:
      return l10n.backendNotDetected;
    case UiMessageId.programmerDatabaseSelected:
      return l10n.programmerDatabaseSelected('${p['programmer'] ?? ''}');
    case UiMessageId.chooseCatalogDevice:
      return l10n.chooseCatalogDevice;
    case UiMessageId.unsafeBinProfile:
      return l10n.unsafeBinProfile('${p['device'] ?? ''}');
    case UiMessageId.profileEmpiricallyValidated:
      return l10n.profileEmpiricallyValidated('${p['device'] ?? ''}');
    case UiMessageId.profileAuthorizedNotValidated:
      return l10n.profileAuthorizedNotValidated('${p['device'] ?? ''}');
  }
}
