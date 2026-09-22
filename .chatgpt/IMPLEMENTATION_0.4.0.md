# v0.4.0 実装・検証記録

2026-09-22。v0.4.0範囲の実装・自動試験完了。mainの09fc312から作成したrelease/0.4.0。
ユーザー承認を受け、[設計](MULTI_PROGRAMMER_0.4.0.md)の順序で実装する。
この版の追加対象はTL866II Plusと、追加承認されたTL866A。T48/T56/T76は後続候補。

## 実機の状況

ユーザーから、TL866II Plus/TL866A/T48/T56/T76は所有していない旨の回答あり。
T76は購入可能だが購入済みではない。今回これらの実機操作は実施しない。
既存のTL866CSの検証結果を別機種の実績に転用しない。

## 実装内容

- モデル記述、機種別USB ID/DB/操作範囲、INFOIC2PLUSのpin_mapビットによるカタログ絞り込み。
- CS/A/II+の共通バックエンド、全USB ID群の複数台検出と実際の機種の確認。
- 操作を実行するminiproプロセス内での期待機種・個体の照合。
- 機種変更時の接続/IC選択解除、入力BIN保持、過去readoutの識別。
- 英日UIの機種名パラメーター化。5配布対象を維持しCI対象ブランチとアプリ版数を更新。

## 検証結果

- Flutter静的解析: 指摘なし。
- Flutter全試験: 110件成功（既存CSの回帰、A/II+機種/カタログ/CLI判定、言語表示、選択切替を含む）。
- native SRAM試験: 成功。引き続き模擬メモリーのみ。
- `tool/test_programmer_guard.sh`: 成功。実際にパッチ適用したmain.cの照合関数をコンパイルし、CS/A/II+一致、機種/serial/firmware不一致、部分的な引数、bootloader、空serialを試験。USB関数は呼び出さない。
- キャッシュのない一時ディレクトリでも同梱アーカイブだけでguard試験に成功。CIのUnix解析・試験ステップへ追加。
- macOS配布アプリ: 0.4.0+5のビルドと署名検証に成功。組み込んだminiproにguard/JSONオプションが存在することも確認。起動による機器問い合わせや新たな実機操作は行っていない。
- Windows/Linux: ビルド・同梱パッチ・manifest・権限設定を更新。今回のGitHub Actions実行と現地ビルドは未実施。main/Releaseへの公開作業も未実施。
- TL866A/TL866II Plus実機: 本体なし、未実施。その他の追加候補も実機未検証。

カタログschema v3にはblank_valueとprotocol_idを保存する。全81,763 aliasesのうち、II+表示対象は19,255（INFOIC2PLUS 18,966 + LOGIC 289）。9,833件が直接DIP・byteメモリーのマッピング条件に合うが、同名aliasの曖昧性や操作直前のCLI整合確認をさらに通す必要があり、この件数は実機対応確認済みの件数ではない。

本体識別の最終方針: OSごとのUSB位置/デバイスインスタンスは発見時の識別に残す。操作プロセス内では、実際に開いたハンドルから得たserial、機種、firmwareを期待値と照合する。これによりWindowsのSetupAPI識別子をlibusbのbus/addressへ無理に変換しない。識別情報が得られない古い/不整合なpayloadは操作不可とする。

## 次の機種へ進む条件

- TL866A: モデル記述・CSとのモデル取り違え拒否・INFOICプロファイルを実装。実機受入試験を別途行う。ICSPは対象外。
- T48: INFOIC2PLUSフィルターは共通基盤を利用可能。操作別のminipro制約と実機での読出し/書込みの確認が必要。
- T56/T76: 外部アルゴリズムの利用者指定・完全性/機種チェック、操作別の実装範囲を追加設計する。同梱権利が未確認のデータは配布しない。
- T76購入後: まずICを挿さず機種/firmware/serial検出を記録し、既知BINのある対応ICで読出し・照合、最後に書込み用ICで書込み/読戻しを検証する。OSごとのUSB導入手順も記録する。

## Release CI correction

The zlib.net URL returned a non-archive response on GitHub runners. Windows/Linux now download the identical zlib 1.3.2 release archive from the upstream madler/zlib GitHub release. The pinned SHA-256 remains unchanged and was independently checked before switching URLs.
