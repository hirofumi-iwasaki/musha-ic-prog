// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get catalogLoadFailed => 'オフラインのデバイスカタログを読み込めませんでした。';

  @override
  String get retry => '再試行';

  @override
  String get languageSaveFailed => '言語設定を保存できませんでした。今回の選択はアプリを終了するまで有効です。';

  @override
  String get languageLoadFailed => '保存された言語設定を読み込めませんでした。システムの言語を使用します。';

  @override
  String get technicalDetails => '技術情報';

  @override
  String get close => '閉じる';

  @override
  String get cancel => 'キャンセル';

  @override
  String get programmer => 'プログラマー';

  @override
  String get vendor => 'ベンダー';

  @override
  String get device => 'デバイス';

  @override
  String get openBinButton => 'BIN を開く';

  @override
  String get read => '読み取り';

  @override
  String get blankCheck => 'ブランクチェック';

  @override
  String get program => '書き込み';

  @override
  String get verify => '検証';

  @override
  String get waitForOperationToFinish => '現在の操作が完了するまで閉じないでください。';

  @override
  String get programSimulatedIcTitle => 'シミュレートした IC に書き込みますか？';

  @override
  String get programIcTitle => 'IC に書き込みますか？';

  @override
  String programSimulationConfirmation(
    String name,
    int bytes,
    String target,
    String capacity,
    String sha1,
  ) {
    return 'このシミュレーションでは、入力データのスナップショット $name（$bytes バイト）を書き込み、読み戻してすべてのバイトを検証します。\n\n対象デバイス: $target\n容量: $capacity バイト\nSHA-1: $sha1\n\n実機は操作しません。';
  }

  @override
  String programConfirmation(
    String name,
    int bytes,
    String target,
    String capacity,
    String sha1,
  ) {
    return 'この操作では、入力データのスナップショット $name（$bytes バイト）を書き込み、読み戻してすべてのバイトを検証します。\n\n対象デバイス: $target\n容量: $capacity バイト\nSHA-1: $sha1';
  }

  @override
  String get programSimulation => 'シミュレーションに書き込む';

  @override
  String get droppedFileCouldNotBeOpened => 'ドロップしたファイルを開けませんでした。';

  @override
  String get dropFileOnInputBin => '入力 BIN の領域にファイルをドロップしてください。';

  @override
  String get droppedItemNotReadableFile => 'ドロップした項目は読み取り可能なファイルではありません。';

  @override
  String get binFileCouldNotBeOpened => 'BIN ファイルを開けませんでした。';

  @override
  String get anotherInputFileLoading => '別の入力ファイルを読み込み中です。';

  @override
  String get waitForOperationBeforeOpeningFile => '現在の操作が完了してからファイルを開いてください。';

  @override
  String get binFileTooLarge => '64 MiB を超える BIN ファイルはまだサポートされていません。';

  @override
  String get selectedDevice => '選択したデバイス';

  @override
  String confirmPhysicalOperation(String operation) {
    return '$operationの確認（実機）';
  }

  @override
  String targetAlias(String target) {
    return '対象デバイス: $target';
  }

  @override
  String capacityBytes(String capacity) {
    return '容量: $capacity バイト';
  }

  @override
  String get physicalOperationWarning =>
      '続行する前に、IC の型番、向き、ソケット上の位置、必要なアダプターを確認してください。カタログへの掲載は、実機での動作を保証するものではありません。';

  @override
  String get confirmIcAndSetupChecked => 'IC と接続・配置を確認しました。';

  @override
  String startOperation(String operation) {
    return '$operation を開始';
  }

  @override
  String phaseStatus(String phase, String message) {
    return '$phase: $message';
  }

  @override
  String get noOperationInProgress => '実行中の操作はありません。';

  @override
  String get operationInProgressWarning =>
      '操作中です。プログラマー、IC、USB ケーブルに触れないでください。';

  @override
  String get operationInProgressSimulationWarning =>
      '操作中です。プログラマー、IC、USB ケーブルに触れないでください。シミュレーションのみです。';

  @override
  String get refreshSimulation => 'シミュレーションを更新';

  @override
  String get refreshTl866cs => 'TL866CS を更新';

  @override
  String simulationConnected(String model, String firmware) {
    return 'シミュレーション接続済み · $model · $firmware';
  }

  @override
  String get mockProgrammer => '模擬プログラマー';

  @override
  String get firmwareUnknown => 'ファームウェア不明';

  @override
  String get simulationConnectedOperationInProgress => 'シミュレーション接続済み · 操作中';

  @override
  String get tl866csConnectedOperationInProgress => 'TL866CS 接続済み · 操作中';

  @override
  String get checkingSimulationConnection => 'シミュレーション接続を確認中…';

  @override
  String get checkingTl866csConnection => 'TL866CS 接続を確認中…';

  @override
  String get simulationDisconnected => 'シミュレーション切断';

  @override
  String get phaseIdle => '待機中';

  @override
  String get phaseAwaitingConfirmation => '確認待ち';

  @override
  String get phasePreparing => '準備中';

  @override
  String get phaseRunning => '実行中';

  @override
  String get phaseReading => '読み取り中';

  @override
  String get phaseBlankChecking => 'ブランクチェック中';

  @override
  String get phaseProgramming => '書き込み中';

  @override
  String get phaseReadingBack => '読み戻し中';

  @override
  String get phaseComparing => '比較中';

  @override
  String get phaseCompleted => '完了';

  @override
  String get phaseFailed => '失敗';

  @override
  String get phaseCancelled => 'キャンセル済み';

  @override
  String get phaseRecoveryRequired => '復旧が必要';

  @override
  String futureProgrammer(String programmer) {
    return '$programmer（今後対応）';
  }

  @override
  String get chooseVendor => 'ベンダーを選択';

  @override
  String targetWithCapacity(String target, String capacity) {
    return 'ターゲット: $target · $capacity バイト';
  }

  @override
  String get unsupportedForAuthorizedHardwareEvaluation => '許可されたハードウェア評価では未対応';

  @override
  String get hardwareProfileValidated => 'ハードウェアプロファイルを検証済み';

  @override
  String get hardwareEvaluationNotYetValidated => 'ハードウェア評価 · この IC では未検証';

  @override
  String get chooseVendorFirst => '先にベンダーを選択してください。';

  @override
  String searchAllDeviceRecords(int count) {
    return '全 $count 件のデバイスレコードを検索';
  }

  @override
  String get showAllDevicesForVendor => '選択したベンダーの全デバイスを表示';

  @override
  String get pinsUnspecified => 'ピン数未指定';

  @override
  String deviceKindAndPins(String kind, String pins) {
    return '$kind · $pins';
  }

  @override
  String get deviceTypeEepromMemory => 'EEPROM / メモリー';

  @override
  String get deviceTypeMcuMpu => 'MCU / MPU';

  @override
  String get deviceTypePldCpld => 'PLD / CPLD';

  @override
  String get deviceTypeSram => 'SRAM';

  @override
  String get deviceTypeLogic => 'ロジック';

  @override
  String get deviceTypeNand => 'NAND';

  @override
  String get deviceTypeEmmc => 'eMMC';

  @override
  String get deviceTypeVgaHdmi => 'VGA / HDMI';

  @override
  String get deviceTypeUnspecified => '未指定';

  @override
  String firstMismatch(String address, int count) {
    return '最初の不一致: 0x$address · $count 件の差異';
  }

  @override
  String get viewerJumpToAddress => 'アドレスへ移動';

  @override
  String get viewerHexadecimalAddress => '16 進アドレス';

  @override
  String get viewerJump => '移動';

  @override
  String get viewerAddressOutsideSnapshot => 'そのアドレスはこのスナップショットの範囲外です。';

  @override
  String get viewerNoDifferencesFound => '差異は見つかりませんでした。';

  @override
  String get viewerInputBin => '入力 BIN';

  @override
  String get viewerIcReadout => 'IC 読み出し';

  @override
  String viewerBytesPerRow(int count) {
    return '$count バイト';
  }

  @override
  String get viewerPreviousDifference => '前の差異';

  @override
  String get viewerNextDifference => '次の差異';

  @override
  String get viewerDropFileToOpen => 'ここにファイルをドロップして開く';

  @override
  String get viewerReadIcFromProgrammer => 'プログラマーから IC を読み取る';

  @override
  String get viewerInputDropRegion => '入力 BIN のドロップ領域';

  @override
  String get viewerReadoutEmptyRegion => 'IC 読み出しの空の領域';

  @override
  String viewerNoSnapshot(String title) {
    return '$title · スナップショットなし';
  }

  @override
  String viewerReadOnly(String title) {
    return '$title · 読み取り専用';
  }

  @override
  String viewerImageSize(String name, int bytes) {
    return '$name · $bytes バイト';
  }

  @override
  String viewerPreviousSuccessfulReadout(String origin) {
    return '$origin · 直前に成功した読み出し';
  }

  @override
  String get viewerOriginInputBin => '入力 BIN';

  @override
  String get viewerOriginIcReadoutSnapshot => 'IC 読み出しスナップショット';

  @override
  String get viewerOriginPostWriteVerificationSnapshot => '書き込み後検証スナップショット';

  @override
  String get viewerNoByteSelected => 'バイトが選択されていません';

  @override
  String viewerByteSelection(
    String address,
    String hex,
    int decimal,
    String binary,
    String ascii,
  ) {
    return 'アドレス $address、値 $hex、10進数 $decimal、2進数 $binary、ASCII $ascii';
  }

  @override
  String get viewerChecksumCalculating => '計算中…';

  @override
  String get viewerAddress => 'アドレス';

  @override
  String get viewerHex => 'HEX';

  @override
  String get viewerDecimal => '10進数';

  @override
  String get viewerBinary => '2進数';

  @override
  String get viewerAscii => 'ASCII';

  @override
  String get backendSimulation => 'シミュレーション・バックエンド';

  @override
  String get backendNotConnected => 'TL866CS は未接続です';

  @override
  String backendConnected(Object identifier) {
    return 'TL866CS 接続済み（$identifier）';
  }

  @override
  String get operationAlreadyRunning => '別の操作がすでに実行中です。';

  @override
  String get connectOneProgrammer => 'プログラマーを1台だけ接続してください。';

  @override
  String get chooseProfile => '先にデバイスプロファイルを選択してください。';

  @override
  String get profileNoMemoryOperations => '選択したプロファイルはメモリ操作に対応していません。';

  @override
  String get openBin => '先に BIN ファイルを開いてください。';

  @override
  String get inputSizeMismatch => '入力 BIN のサイズは IC 容量と完全に一致している必要があります。';

  @override
  String get profileOutsideScope => 'このデータベースプロファイルは、許可された TL866CS 評価範囲外です。';

  @override
  String get waitBeforeReconnect => '再接続する前に、現在の操作が終わるまで待ってください。';

  @override
  String get checkingSimulation => 'シミュレーション・プログラマーを検索中…';

  @override
  String get checkingTl866 => 'TL866CS が1台接続されているか確認中…';

  @override
  String programmerReady(Object model) {
    return '$model の準備ができました。';
  }

  @override
  String get identityCheckFailed => 'プログラマーの識別確認に失敗しました。';

  @override
  String get simulationSelected => 'シミュレーションデモを選択しました。接続してモックプログラマーを使用してください。';

  @override
  String get realProgrammerSelected => 'TL866CS モードを選択しました。接続状態を更新してください。';

  @override
  String profileSelected(Object profile) {
    return '$profile を選択しました。';
  }

  @override
  String inputOpened(Object label, int count) {
    return '$label を開きました（$count バイト）。';
  }

  @override
  String get inputTooLarge => '64 MiB を超える BIN ファイルはまだ対応していません。';

  @override
  String get confirmProgram => '入力データのスナップショットを書き込む前に、内容を確認してください。';

  @override
  String get programCancelled => '書き込みを開始する前に取り消しました。';

  @override
  String get operationCouldNotStart => '操作を開始できませんでした。';

  @override
  String get reconnectBeforeOperation => '次の操作の前に TL866CS 接続を更新してください。';

  @override
  String get reading => 'コードメモリを読み取り中です。';

  @override
  String get blankChecking => 'コードメモリのブランク状態を確認中です。';

  @override
  String get programming => '入力データのスナップショットを書き込み中です。';

  @override
  String get readingBack => '書き込み後にコードメモリを読み取り中です。';

  @override
  String get comparing => '入力データのスナップショットを比較中です。';

  @override
  String readSucceeded(int count) {
    return '$count バイトを読み取りました。';
  }

  @override
  String get blankSucceeded => 'IC のコードメモリはブランクです。';

  @override
  String get verificationSucceeded => '検証に成功しました。';

  @override
  String get verificationFailed => '検証に失敗しました。';

  @override
  String programSucceeded(int count) {
    return '$count バイトを書き込み、バイト単位で検証しました。';
  }

  @override
  String get operationCancelled => '次のハードウェアコマンドの前に操作を停止しました。';

  @override
  String get identityChanged => 'TL866CS の識別情報が変わりました。操作前に接続を更新してください。';

  @override
  String get identityChangedBeforeWrite =>
      '書き込み前に TL866CS の識別情報が変わりました。書き込みは開始していません。';

  @override
  String get postWriteVerificationFailed => '書き込み後の検証に失敗しました。';

  @override
  String get stopAfterWrite => '書き込み開始後に停止要求がありました。続行前に内容を検証してください。';

  @override
  String get technicalFailure => 'プログラマーの操作に失敗しました。技術情報を確認してください。';

  @override
  String get backendUnsupportedProfile => 'このプロファイルは実機 TL866CS 評価用に承認されていません。';

  @override
  String get backendProfileValidationFailed =>
      '選択したデバイスプロファイルを minipro で検証できませんでした。';

  @override
  String get backendDiscoveryFailure => 'TL866CS の接続確認に失敗しました。技術的な詳細を確認してください。';

  @override
  String get backendWinUsbSetup =>
      'README.ja.md の Windows 導入手順に従って TL866CS に WinUSB ドライバーを設定し、プログラマーを接続し直してください。';

  @override
  String get backendUsbAccessDenied =>
      'USB へのアクセスが拒否されました。OS の USB アクセス権限とドライバー設定を確認し、接続し直してください。';

  @override
  String get backendBusy => 'TL866CS は使用中です。他のプログラマー用ソフトを終了し、接続し直してください。';

  @override
  String get backendNotDetected => 'TL866A/CS プログラマーが見つかりませんでした。';

  @override
  String programmerDatabaseSelected(String programmer) {
    return '$programmer のデバイスデータベースを選択しました。';
  }

  @override
  String get chooseCatalogDevice => '選択したベンダーとプログラマーのデータベースからデバイスを選択してください。';

  @override
  String unsafeBinProfile(String device) {
    return '$device は、安全に操作できる raw-BIN 用 TL866CS プロファイルとして扱えません。';
  }

  @override
  String profileEmpiricallyValidated(String device) {
    return '$device には実機での検証記録があります。';
  }

  @override
  String profileAuthorizedNotValidated(String device) {
    return '$device は制限付きの実機評価が許可されていますが、実機での動作検証は完了していません。';
  }
}
