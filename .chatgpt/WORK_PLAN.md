# 0.1.0 実装・検証計画

2026-09-16 / 設計完了、初回実装を開始。進捗は実装記録に追記する。

## 現在の作業場

- リポジトリ: `~/Github/musha-ic-prog`
- 起点main: `7dafc8bfe26dbf4c77467fc95438c7b4f7e8bf57`
- 作業ブランチ: `release/0.1.0`
- 今回の成果: README、DESIGN、DECISIONS、本計画。
- Flutter初回実装を実施。現在の到達点と未完了項目は[実装記録](IMPLEMENTATION_0.1.0.md)を参照。実機操作・公開は未実施。

## M0: 通信・デバイスの成立確認（最優先）

1. minipro upstreamのソースを取得し、TL866CS対応とライセンスを確認。commitとlibusb・DBを固定する。
2. Apple Silicon向けCLIをビルドし、macOSで1台のTL866CSを識別する。
   型番、firmware、USB接続識別と複数台拒否の実現方法を記録する。
3. 手元のEPROMの完全型番とデータシート、容量、電圧、ZIF向き・位置を確認し、最初のDeviceProfileを作る。
4. 読出しを複数回行い一致を確認。既知BINとの照合、ブランク判定を確認する。
5. 書込み試験用ICに既知パターンを書き、全領域の読戻しを別経路または信頼済み手順と比較する。
   非ブランクを拒否する挙動、電源解放、終了コードとエラー出力も記録する。
6. 操作別CLI引数・出力fixture、タイムアウト、中断・切断・終了時の挙動を確認する。
7. 成功条件を満たした組合せだけallowlistに登録し、依存固定マニフェストを保存する。

合格: 型番を取り違えず同一データを読み書きでき、失敗を成功と誤認せず、操作終了時の機器状態を説明できること。
機器や試験用ICが不足する場合はこのゲートを未達のまま残す。書込みを有効化しない。

## M1: Flutter土台とmock

- version `0.1.0+1`、package `mushagaeshi_ic_programmer`、表示名 `Mushagaeshi IC Programmer`。
- SDKを確認・固定しmacOS runnerを生成。bundle IDは `dev.mushagaeshi.mushagaeshiIcProgrammer` を採用する。
- 4層構成、port、モデル、状態遷移、MockBackendを実装。
- mockによる接続、型番選択、BIN読込、容量エラー、読出し、照合結果、書込み確認を画面で確認。
- 各操作の排他と遅れて届くイベントの破棄をテストする。

## M2: 読出し系

- 固定版MiniproTl866Backend、プロセス管理、診断変換、接続判定。
- 読出し・保存・ブランク・Verify、読み取り専用HEX / ASCII、選択byteの2進・10進表示、同期スクロールと差分移動。
- 閲覧用BINの読込と容量一致が必要な書込み入力の適格性を分離。追加設計の表示検証条件を満たす。
- 不変スナップショット、安全な保存、失敗時の前回結果保持。

## M3: 書込み系

- M0合格済みプロファイルのみProgram有効化。
- 実行確認 → 再検査 → blank check → program → readback → byte compare。
- 切断、中断要求、異常終了、アプリ終了保留、未完了journalの復旧表示を実装。
- 書込み失敗後に自動再開しないことを確認する。

## M3b: ICテスト成立確認（条件付き追加）

- [追加設計](VIEWER_AND_IC_TESTS.md)のTestProfile / TestResultと能力判定を実装する場合、mockから検証。
- TL866CSのLogic試験は完全型番・電圧・ベクトル・ライセンス・終了状態を確認し、合格した組合せだけ有効化。
- 現調査版でTL866CSのSRAMは実行拒否。将来の専用実装か別機種の対応検証で追加する。
- ロジック・SRAMともCLI成功だけを「良品」の保証にしない。inconclusiveを区別する。
- この工程が未達の場合、ICテストを製品の対応機能に含めず、EPROMとビューアーの初版を進められる。

## M4: .app同梱とリリース検証

- minipro / libusb / DBをbundle化、arm64と相対参照、署名・公証を確認。
- FlutterやHomebrewがない環境で、別フォルダーへ移動した.appから起動・USB操作・保存を確認。
- 対応ソース、ビルド手順、第三者ライセンス、依存固定情報を配布物に付属。
- macOS 15 / 26の実機試験結果を保存。欠ける場合は正式対応としてリリースしない。

## 受入試験表

| 分類 | 条件 | 合格基準 |
| --- | --- | --- |
| 接続 | 未接続、別機種、複数台、占有 | 誤った機器へ操作せず理由を表示 |
| 型番 | 未登録、ID不一致、ID非対応 | 未登録・不一致は停止、非対応IDへ検出電圧をかけない |
| 入力 | 0 byte、容量-1、容量、容量+1、元ファイル変更 | 容量一致のみ受理、確認したsnapshotが不変 |
| 読出し | 既知ICを繰返し読出し、途中切断 | 正常時byte一致、部分結果を成功として保存しない |
| 保存 | 既存ファイル、権限不足、容量不足、取消 | 失敗で既存データを失わない |
| ブランク | blank / nonblank | profileの定義通り判定しnonblankのProgramを拒否 |
| 書込み | 検証済み消去済みICと既知パターン | 読戻し全byte一致でのみ成功 |
| 照合 | 先頭・中間・末尾の不一致 | address、expected、actualと件数が正しい |
| 障害 | 切断、タイムアウト、CLI異常・未知出力 | 成功扱いせず必要時recoveryRequired |
| 排他 | 連打、別ウィンドウ・多重起動、古いイベント | 操作が重ならず前の結果が混入しない |
| 終了 | 書込み中のCancel・終了、次回起動 | 未完了を成功にせず、終了方針通りに扱う |
| 配布 | macOS 15 / 26、依存未導入、移動した.app | 起動・認識・全操作、署名・公証を確認 |

実機ログにOS、CPU、アプリrevision、backend / DB版、TL866CS firmware、IC完全型番、adapter、入力hash、結果を残す。
危険な誤挿入・過電圧を試験するのではなく、型番不一致等はmockや安全な検証手順で拒否を確認する。

## 自動検証

実装後は変更に応じてDart単体テスト、CLI fixture契約テスト、Flutter widgetテストを実施し、
CIでformat確認、analyze、test、macOS release buildを行う。
実機試験はCIのmock試験とは別のチェックリストとして記録する。
初回実装の検証結果は[実装記録](IMPLEMENTATION_0.1.0.md)へ記録する。

## 0.1.0後

1. 検証済みEPROM型番追加、EEPROM / Flashの消去仕様と専用操作フロー追加。
2. T56等: バックエンド能力、接続判定、必要データの条件、機種別profileと実機試験を追加。
3. Windows / Linux: OSアダプター、USBドライバー・権限、パッケージ、CIと実機試験を追加。
4. 実需要に応じてHEX形式、部分操作、編集部品の共通化を検討。

## 実装開始の追補

[MINIPRO_FORK_PLAN.md](MINIPRO_FORK_PLAN.md)に従いC試験エンジン、mock操作、Flutter表示を並行実装する。
実機依存M0は未達のまま記録し、通信なしで検証できる実装を進める。

## 実機接続開始

ユーザーがTL866CSをMacへ接続し、実機動作への切替を指示。
future表示削除のcommit/push完了後にD21–D23に従い、同梱helper、USB接続、
メモリー操作、実機UIを実装する。本体識別の合格とICごとの読出し・書込み合格は別記録とする。
IC型番が未確定の間は本体識別のみ実行する。M0のIC試験・配布対象OS全数確認は別途残る。

## v0.2.0 implementation baseline

Branch `release/0.2.0` starts at merged main `2754f879d1cdf2b71d7ac92c2fddeb94ce89b57b`.
Accepted design and detailed gates: [CROSS_PLATFORM_0.2.0.md](CROSS_PLATFORM_0.2.0.md).

- [x] Create branch from updated main; inspect Binary Editor and pinned minipro source.
- [x] Define five-platform matrix, USB/driver approach, packaging and acceptance gates.
- [ ] P0: All native helpers compile and offline checks pass; physical Windows WinUSB/libusb validation remains pending.
- [x] P1: Shared platform contracts and automated macOS regression (analysis, tests and package build).
- [ ] P2: Native runners, icons and all five bundles are complete; clean consumer desktop acceptance remains pending.
- [ ] P3: USB discovery/permission/model readiness on each target.
- [ ] P4: Per-target UI and approved IC read/verify/write acceptance.
- [ ] P5: Same-commit five-artifact workflow and English documentation are implemented and CI passed; physical acceptance and a future public release remain pending.

Implementation and automated build validation are complete at version `0.2.0+2`. Native Windows and Linux runners, shared platform contracts, packaging scripts and the five-target Actions matrix are implemented. Follow the [implementation record](IMPLEMENTATION_0.2.0.md) for build evidence and outstanding hardware gates. The initial v0.2.0 Release was subsequently published and withdrawn after the Windows transport issue (D30); its tag is retained.

Automated result: [run 35069146880](https://github.com/hirofumi-iwasaki/musha-ic-prog/actions/runs/35069146880), implementation commit `e383f61`, all five builds plus both Ubuntu 24.04 runtime checks passed. P3/P4 are deliberately not marked complete by CI results.

Windows transport correction D30: [run 35074949228](https://github.com/hirofumi-iwasaki/musha-ic-prog/actions/runs/35074949228)
passed all five corrected builds and both Ubuntu 24.04 checks at `543ce2e`.
WinUSB/libusb physical acceptance remains open. The withdrawn Release is not
republished; Windows evaluation artifacts include the one-time setup guide.
