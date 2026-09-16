# 初回実装記録

2026-09-16 / release/0.1.0

## 分担

ユーザー指定に従い3つのgpt-5.6-terraへ実装を委譲した。
core_app: macOS scaffold、core/application/mock、ファイル処理。
viewer: 読み取り専用バイナリー表示と模擬操作画面。
sram_fork: minipro fork用C試験エンジン、再現スクリプト、模擬試験。
親エージェントは設計差分保存、コードレビュー、統合検証を担当。

## 実装済み

- macOS Flutterプロジェクト、アプリ名・bundle ID・version 0.1.0+1。
- 4層構成、mock限定controller、入力snapshot、SHA-256、操作排他と確認状態。
- 模擬EPROMのread、blank check、program + readback照合、verify。
- BIN選択とdemoデータ、読み取り専用HEX / ASCII / byte inspector、差分・アドレス移動。
- 64 MiB制限、ファイルアダプターの上限付き読込・一時保存と置換（保存UIは未接続）。
- CのSRAM基本試験エンジン。全領域書込み後に全領域を照合する固定・アドレスパターン。
- 固定miniproソースへ追加を適用するoverlay manifestと再現スクリプト。

## 検証

- 統合Flutter test: 15件成功。
- 担当範囲のFlutter analyze: clean。統合解析・macOS buildの最終結果は下記追記。
- SRAM: clangの警告をエラー扱いにした試験成功。担当がASan / UBSan検査の成功も確認。
- 模擬SRAM試験: 正常、データ線固着、上位アドレス重複、短い応答、未知状態、I/O失敗、中断、開始・終了失敗、NULL report。

## 未完了と設計との差分

M0のTL866CS実機成立確認は未達。実機操作・対応ICのallowlistは有効化していない。
SRAMエンジンはminiproのビルド対象へ追加できるが、CLIルート・実機アダプター・Flutter呼出しは未接続。
minipro全体のコンパイルに必要なpkg-config/libusbが本環境で未導入で、全体ビルドは未検証。
ロジックIC実行、Save Readout画面、コピー、古いreadoutの表示、真のページ読込とバックグラウンドハッシュ、
本番用の終了保留・復旧journal・多重起動排他、配布ライセンス一式と公開署名は後続。
この段階を0.1.0の完成版や実機対応版とは呼ばない。

App Sandbox無効化は自動承認レビューが永続的なセキュリティ制限の緩和として拒否した。
プロトタイプではSandboxを維持し、ユーザー選択ファイルに限定した権限を設定した。
公開・push・リモートfork作成は行っていない。

## 統合検証の最終結果

- Flutter analyze: No issues found。
- Flutter test: 15件すべて成功。
- macOS release build成功。dist/Mushagaeshi IC Programmer.appを作成。
- 生成物はarm64 / x86_64 universal（Flutter既定）。Intel Macの動作保証は未実施。
- codesign --verify --deep --strict成功。公開署名・公証を意味しない。
- アプリを起動し、SIMULATION MODEと初期画面の接続・BIN・表示・操作欄を確認。
  実画面での全操作試験や実機試験は未実施。
- SRAMの再現スクリプトは既存出力・リポジトリ直下・パストラバーサルを拒否し、生成した一時領域で準備する。
- 親がtool/test_sram.shを再実行し全件成功を確認。

ソース変更は未コミット。リモートfork作成・pushは未実施。

## SHA-1・カタログ・ステータスバー更新

ユーザー指示に従い3つのgpt-5.6-terraへハッシュ表示、カタログとcontroller、選択UIと状態バーを分担。
表示用SHA-1へ統一し、左右不一致の文字背景をbyte差分と共通のあずき色にした。
固定XMLの全81,763エントリーを別名展開して保持。TL866CSはINFOIC 14,208 + LOGIC 289 = 14,497件、141ベンダー。
元XMLとコピーのbyte一致を確認し、独立したPython XML読出しでも件数・所属を監査した。
T76の4つの型番でXMLパーサーのタブ正規化差のみを確認。生成データは元のタブを保持する。
カタログ選択時は模擬profileを解除し、demo操作時はカタログ選択を解除して対象の混同を避ける。
Programmer/Vendor/Deviceを連動させ、動作中と確認待ちは変更を禁止。
接続確認中・未接続・接続済み・処理中を区別する下部バーと、動作中の機器操作警告を追加。
この変更でも実機通信を有効化していない。

### 更新後の検証結果

- 全Flutterテスト24件成功（親が最終UI変更後に再実行）。全体静的解析も成功。
- macOS release build成功、dist/Mushagaeshi IC Programmer.app更新。
- 増分ビルドでApp.frameworkの署名不整合が発生したため、ローカルad-hoc署名を再実施する配布処理へ修正。
  埋込みframework→外側アプリの順で署名し、新規stagingで検証後に入れ替える。
  最終distアプリのcodesign --verify --deep --strict成功。Sandboxとユーザー選択ファイル権限は保持。
- 公開署名・公証、実機通信・実機試験は今回も対象外。コード・文書は未コミット、未push。

## 最上段タイトル行削除とチェックポイント

ユーザー指示で画面内のAppBar（Mushagaeshi IC Programmer行）を削除。
ネイティブのウィンドウタイトルは維持し、SIMULATION MODE表示は下部状態欄へ移動。
これまでの設計・Flutter実装・全件カタログ・SRAM fork追加をrelease/0.1.0の初回実装チェックポイントとしてコミットする。
Finderの.DS_Storeは除外し、ビルド成果物・ローカルツールも従来どおりコミット対象外。

タイトル行削除後の画面テストとmacOS再ビルド・署名検査は成功。上流XML/READMEの末尾空白は出典のbyte一致を保つため改変していない。
