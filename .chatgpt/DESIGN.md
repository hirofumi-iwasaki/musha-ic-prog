# Mushagaeshi IC Programmer 0.1.0 設計書

日付: 2026-09-16 / 状態: 設計方針確定、実装・実機検証前

## 1. 目的と前提

EPROM等のICの内容を正確に読み出し、準備したバイナリーを書き込み、照合するデスクトップアプリを作る。
画面はFlutter、操作制御・データ処理はDart。初版はmacOS、最初の実機はTL866CS。
機種固有の処理を画面から分離し、T56などを追加しても共通の操作フローを維持する。

既存の `../musha-bin-editor` のREADME、pubspec、`.chatgpt/ARCHITECTURE.md`、ライセンス方針を参照した。
同プロジェクトの `core / application / infrastructure / presentation` 分離、ChangeNotifierによる画面更新、
表示範囲だけのHEX描画、OSアダプター分離を踏襲する。既存エディター自体は変更しない。

## 2. 0.1.0の範囲

| 項目 | 決定 |
| --- | --- |
| OS / CPU | macOS 15 / 26、Apple Silicon。両OSの実機評価を出荷条件とする |
| 開発言語 | Dart / Flutter。姉妹アプリの固定版Flutter 3.47.4 / Dart 3.13.3を初期基準とし、実装開始時に公式SDKの取得・ビルドを確認 |
| 接続 | TL866CS、USB、同時接続1台、ZIF。複数台・別機種・判別不能なら操作を拒否 |
| IC | 必須対象は並列EPROM。ロジックIC試験は条件付き候補、SRAMは拡張設計のみ。型番・メーカー・パッケージ・電圧・アダプター単位の検証済みリストで制限 |
| ファイル | raw BINのみ。全コード領域、先頭アドレス0、容量完全一致 |
| 機能 | ファイルを開く、ICを読む、読出し保存、ブランクチェック、書込み、照合、HEX差分表示、操作ログ、読み取り専用バイナリー表示 |
| UI | 姉妹アプリに合わせ英語。文字列を集約し将来の日本語化に備える |
| 配布 | 自己完結する.app、直接配布。公開版は署名・公証を行う |

対象外: IC自動判定の保証、ICSP、ファームウェア更新、電圧の手動変更、強制書込み、OTP、
MCU・GAL・ヒューズ・ロックビット、バッチ書込み、複数台制御、部分書込み、Intel HEX / S-record、
アプリ内バイナリー編集、Windows / Linux / Intel Macの初版提供。
EEPROM / Flashの電気的消去は将来追加する。UV EPROMの消去は外部UV消去器で行い、アプリにEraseボタンを出さない。

具体的な初回検証ICは所有実機に合わせて選ぶ。27C256 / 27C512等は候補にすぎず、系列名から対応を推定しない。
同じ容量でも末尾記号やメーカーによって条件が異なるため、完全な刻印とデータシートを確認して登録する。

## 3. アーキテクチャ

```text
Flutter presentation
        ↓
application: ProgrammerController / OperationCoordinator
        ↓
core: 型・操作計画・検証ルール・port（抽象インターフェース）
        ↑
infrastructure: MiniproTl866Backend / MockBackend / FileStore / PlatformServices
        ↓
固定版miniproプロセス → libusb → TL866CS → IC
```

coreはFlutter、dart:io、CLI文字列、OSに依存しない。applicationはcoreのportだけを参照する。
presentationはapplicationの状態を表示し、直接プロセスを起動しない。
mainのcomposition rootで具象実装を注入する。初期は1つのFlutterプロジェクトで管理する。
ChangeNotifierはapplicationの画面向けコントローラーに限定し、操作計画・状態遷移のロジックは純Dartで試験可能にする。

### ディレクトリ案（実装開始時に作成）

```text
lib/
  main.dart
  core/{models,ports,policies}/
  application/{controllers,operations}/
  infrastructure/
    programmers/{minipro,mock}/
    files/
    platform/
  presentation/{screens,widgets}/
assets/device_profiles/          # 実機検証した型番と配置情報
macos/                          # メニュー、保存、終了制御、配布設定
native/                         # 必要となった小さなOS補助処理のみ
third_party/                    # 依存の固定情報、ライセンス、パッチ
tool/                           # ビルド・検証スクリプト
test/{core,application,infrastructure,presentation}/
integration_test/
.chatgpt/
```

### バックエンド境界

以下は契約の設計であり、実装済みAPIではない。

- `ProgrammerDiscovery.scan()` → 接続候補（モデル、接続識別子、ファームウェア、使用可否）。
- `ProgrammerBackend.capabilities(connection, profile)` → 読出し・書込み・ブランク・ID・安全な中断等の能力。
- `ProgrammerBackend.execute(OperationPlan)` → `OperationHandle`（events、完了Future、requestCancel）。
- `DeviceCatalog` → 完全一致の型番検索、検証状態、バックエンド固有の型番ID対応。
- `BinaryStore` → 不変スナップショット、範囲読出し、安全な保存。
- `PlatformServices` → ファイル選択、ウィンドウ終了制御、アプリ内多重起動排他、必要なUSB一覧取得。

操作イベントはoperationIdを持ち、段階・進捗・診断・結果を型で表現する。CLIの生出力は画面の状態判定に使わない。
backendが確実な進捗を提供できない段階は不定進捗とし、推測したパーセントを表示しない。
共通APIはread / blankCheck / program / verifyに加え、能力に応じてlogicTest / sramTestを操作種別として扱い、将来のerase等は能力がある場合だけ追加する。
T56をTL866CSの派生クラスにはしない。同じminiproを使用する場合も機種別能力・型番対応・検証セットを分ける。
汎用プラグインの動的ロードは導入せず、バックエンドの静的登録で十分とする。

## 4. 通信方式の決定

初版は **固定版miniproの同梱実行ファイル + Dartの外部プロセスアダプター** を採用する。
既存のICアルゴリズムを利用し、DartでTL866プロトコルや書込みパルス制御を再実装しない。
独自FFIラッパーやJSON常駐デーモンは導入しない。承認済みのSRAM基本試験はminipro fork内のCコードへ追加する。
別プロセスならUIと通信処理を分離できるが、強制終了でICの状態が安全になると仮定してはならない。

採用元はDavidGriffith/miniproを第一候補とし、実装の最初にソースの正確なcommitを固定する。
固定マニフェストにはURL、commit、ソースSHA-256、パッチ、ビルド手順、libusb版、DB版・ハッシュ、実行ファイルの識別情報を記録する。
現時点では版・commitは未選定。動く最新版を暗黙に追従することは禁止する。

CLIは安定した機械APIとは限らない。採用版のhelp・マニュアル・ソースと実機出力を用いて、
操作ごとの引数とstdout/stderrの形式、終了コード、タイムアウト、中断時の解放動作を契約テストに固定する。
この文書では未確認のCLIフラグやUSBのVID/PIDを確定しない。
未知の版、判定不能な出力、不明な型番は操作を拒否し、成功とみなさない。
単に終了コード0だけで書込み成功にせず、別の全領域読出し・比較の成功を必須にする。

- `Process.start`に絶対パスと引数配列を渡す。シェルを介さない。
- リリース版は.app内の同梱バイナリーとDBのみを使い、PATH上のminiproを自動選択しない。
- 実行環境・ロケールを固定し、stdout/stderrは並行して消費。保持ログ量に上限を設ける。
- 操作ごとに専用一時ディレクトリを用意し、生成ファイル名を管理。読出し結果は終了コードと期待容量の両方を確認。
- stderrを診断用に保持しつつ、ユーザーには構造化された原因・対象・復旧方法を表示する。
- USB一覧・モデル識別がCLIだけで確実に行えなければ、OSアダプターの小さな列挙機能を追加する。
  正確な1台識別と、実行時にその1台へ到達することを確認できるまで破壊的操作を有効にしない。

## 5. データモデルと対応IC管理

| 型 | 必須情報 |
| --- | --- |
| ProgrammerConnection | backendId、model、接続識別子、firmware、接続世代 |
| DeviceProfile | IC種別（Logicは容量・メモリー領域を持たない）、schemaVersion、stableId、メーカー、完全型番、package、容量bytes、領域、電圧条件、配置・adapter、消去方式、ID方針 |
| BackendDeviceMapping | backend版、DB識別子、正確な型番文字列、対応操作、検証記録参照 |
| BinaryImage | snapshotId、容量、SHA-1、由来（file/read）、作成日時、読み取り専用データ参照 |
| OperationPlan | operationId、connection世代、profile版、入力snapshot、全領域range、事前条件、確認した対象情報 |
| OperationResult | 成否、到達段階、検証状態、最初の不一致address/expected/actual、処理bytes、診断 |

上流DBの全件をそのまま「対応IC」として表示しない。初版UIで選べる範囲はユーザー指示により上流の全件へ拡大する。カタログ掲載と実機検証済みを区別し、操作の可否は別に判定する。
電圧やアルゴリズムは上流の確認済み型番定義に従い、ユーザーが任意に上書きできない。
ID読出しは型番で許可される場合だけ実行する。旧EPROMにはID非対応もあるため、無条件のID検出をしない。
ID不一致は停止。ID非対応では型番・向き・配置の手動確認を必須にする。

## 6. 操作フローと失敗時の扱い

状態: `idle → preparing → awaitingConfirmation → running → succeeded / failed / cancelled / recoveryRequired`。
running内はblankChecking / programming / readingBack / comparing等の段階を持つ。
接続状態は別にdisconnected / ready / busy / unknownで保持し、切断で実行中操作を無言でidleに戻さない。
すべての操作を一列に直列化する。操作中の型番変更・ファイル差替え・二重実行を禁止する。
古いoperationIdや接続世代のイベントは捨てる。多重起動も排他し、他アプリによるUSB占有はbusyとして失敗させる。

### 読出しと保存

接続と型番、ソケット配置を確認 → 全領域読出し → 容量検証 → 不変スナップショット作成 → HEX表示。
途中読出しや容量不一致は正常なイメージとして採用しない。前回の成功結果を上書きしない。
保存はユーザーの選択先と同じファイルシステムに一時ファイルを書き、flush後に置換する。
キャンセル・失敗時に既存ファイルを壊さず、既存ファイルへの上書きは確認する。

### 書込み

1. 正確な型番、接続1台、firmware、allowlist、配置と電圧条件、容量一致を検査する。
2. 入力をアプリ管理の不変スナップショットへ取り込みSHA-1を計算する。元ファイル変更で書込み内容が変わらないようにする。
3. 型番、配置図、容量、ファイル名・ハッシュを表示し、ICに不可逆な変更を行う実行確認を得る。
4. 接続世代と条件を再検査し、プロファイルで定義したブランク値による全領域ブランクチェックを行う。
   非ブランクなら停止。0.1.0では既存内容への追記・強制書込み・自動消去を行わない。
5. 同一スナップショットを書き込む。上流の安全チェックを無効化するオプションは使用しない。
6. 全領域を別途読み戻し、入力とbyte単位で比較する。全件一致でのみ成功とする。
   ハッシュ表示は補助であり、ハッシュ一致だけを照合の実装としない。

0.1.0では短いファイルを暗黙に0xFFで埋めず、大きいファイルを切り捨てない。容量不一致は入力段階で説明して停止する。
単独Verifyも入力とIC全領域を比較する。表示は最初の不一致と総不一致数、選択範囲の詳細を扱い、全不一致をメモリーにためない。

### 中断・切断・終了

事前処理は中断可能。ハードウェア操作の中断可否は採用バックエンドを実機検証して決める。
安全な中断が確認できない書込み中は「現在の処理完了後に停止」とし、通常のCancelからプロセスを強制終了しない。
その場合も書込み後の照合は省略せず、終端まで結果を追跡する。
タイムアウトや切断、プロセス異常終了では `recoveryRequired` とし、IC内容不明・取り外し前の機器確認が必要と表示する。
自動再書込み・自動リトライをしない。再接続で状態を再取得し、新しい操作としてのみ再開する。
タイムアウトは操作種別とプロファイルから設定し、無応答待ちを無期限にしない。
プロセスを終了させる必要がある障害処理と「正常に中断できた」を区別する。
ウィンドウ終了要求は操作完了まで保留する。OS終了・停電まで阻止できるとは保証しない。
未完了操作の小さなjournalを残し、次回起動時に未完了を伝える。成功として復元しない。

## 7. 画面

メイン画面は上部に接続モデル・状態、左にメーカー／型番検索とIC仕様・ソケット配置、
中央に入力BINと読出し結果のHEX表示、下部に操作バーと進捗・結果を置く。
詳細ログは折りたたみ式とし、通常操作に通信オプションを露出しない。

操作: Open BIN / Read / Save Readout / Blank Check / Program / Verify。
接続、型番、入力、実行状態、能力から有効・無効を決め、無効理由を表示する。
エラー時は型番、失敗段階、原因、次の操作を表示。未接続・非対応・占有・権限不足・不一致を区別する。
色だけに依存せず文字と記号を併用し、キーボード移動・VoiceOverラベルを備える。

HEX表示は仮想化し、CPU負荷のある比較・ハッシュはisolateで処理する。
巨大なbyte列の反復コピーを避け、ページキャッシュを上限付きで持つ。
既存エディターの部品を移植する場合は元revisionと表示を記録する。共有パッケージへの抽出は実際に再利用が必要になってから行う。
初版ではBINの保存・読込で連携し、自動起動や独自IPCには依存しない。

表示機能の必須仕様、ロジックICとSRAMの調査結果・拡張契約は[追加設計](VIEWER_AND_IC_TESTS.md)を参照。
ビューアーはHEX / ASCIIと選択byteの2進数・10進数を表示し、編集操作を持たない。

## 8. macOSと将来のOS対応

初版はMac App Store外へ直接配布し、App Sandboxは無効を設計基準とする。
姉妹アプリのentitlementsをそのままコピーしない。USB・同梱プロセス・DB参照・署名を実機で確認する。
.appにminipro、必要なlibusb、DBを含め、利用者のHomebrewやFlutterに依存させない。
ライブラリーの参照先をbundle内へ向け、各native binaryのarm64、署名、公証、移動後起動を検証する。
開発用ad-hoc署名は公開配布とは別扱いとする。

Windowsは将来バックエンドのビルドとUSBドライバー選択・配布を検証する。ドライバーを無断で置換しない。
Linuxはディストリビューション、libusb依存、udev権限を検証し、通常のアプリ実行にrootを要求しない構成を目指す。
共通のDart操作契約は維持するが、miniproが全OSで同じように動くことを未検証のまま保証しない。
OS追加とプログラマー追加は独立した作業として扱う。

## 9. 品質・配布条件

MockBackendは実機なしで正常系・切断・不一致・遅延・古いイベント・異常終了を再現する。
UIやCIのmock成功をTL866CS動作確認として扱わない。
単体テストでは容量境界、allowlist、ID方針、排他、不変入力、状態遷移、失敗後の結果保持を検証する。
CLI契約テストでは固定版の出力fixture、未知出力、終了コード、欠損ファイル、stderr大量出力、中断を検証する。
実機試験の具体的な合格条件と出荷ゲートはWORK_PLAN.mdを正本とする。

本プロジェクトの新規成果物はGPL-3.0-or-later。既存LICENSE本文は保持する。
配布するminipro・libusb・DB・Flutter依存物ごとに採用版の条件を確認し、元の表示を維持する。
対応ソース、パッチ、ビルド手順、第三者表示を配布物に対応づける。
T56などで別途必要になるアルゴリズムデータは、入手可能であることだけで再配布可能と判断しない。

## 10. 根拠と検証の限界

2026-09-16参照。以下は設計の参考であり、本アプリの実機検証結果ではない。

- minipro upstream: https://gitlab.com/DavidGriffith/minipro — TL866系制御の公開プロジェクト。
- TL866CSに言及するupstreamマニュアル（過去revision）: https://gitlab.com/DavidGriffith/minipro/-/blob/d04163c8f34d879afd25b97a60d2ff03f054c710/man/minipro.1
- libusb公式: https://libusb.info/ — USB通信のOS共通ライブラリー。
- libusb OS情報: https://github.com/libusb/libusb/wiki — OSごとの制約の確認先。
- Flutter OS連携: https://docs.flutter.dev/platform-integration/platform-channels
- Flutter FFI: https://docs.flutter.dev/platform-integration/bind-native-code — 将来の選択肢。初版では不採用。

追補: upstreamのソース取得とライセンス表示の確認を実施した。詳細は[同梱ライセンス調査](MINIPRO_LICENSE_REVIEW.md)。
最新CLI仕様・完全な対応表・firmware条件の実機検証は未実施。
実装M0で取得したソースと実機を根拠に固定する。プロトコルや安全なキャンセルの実証は今回の設計作業に含まない。

追補: [minipro forkとSRAM実装方針](MINIPRO_FORK_PLAN.md)を採用する。

追補: [全件カタログ・SHA-1・ステータスバー更新](CATALOG_AND_STATUS_DESIGN.md)を採用する。表示用ハッシュはSHA-1へ変更し、旧SHA-256指定を置き換える。

## 2026-09-16 実機評価への移行

[決定事項D21–D23](DECISIONS.md)を追補として適用する。future機種のUI表示を削除。
既定バックエンドをTL866CS実機へ切り替え、mockは明示したデモで使用する。
正式対応型番のallowlistと、開発段階で実行条件を満たした上流型番の評価を区別する。
実機未検証の型番をverifiedとして扱わない。
Sandboxは有効のままUSB権限を付け、アプリ内の固定helper・DBを使用する。
実装・実測の詳細は[実装記録](IMPLEMENTATION_0.1.0.md)へ追記する。
