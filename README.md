# Mushagaeshi IC Programmer

EPROMなどのICを読み出し・書き込みするDart / Flutterデスクトップアプリケーション。

## 状態

2026-09-16: **0.1.0の初回プロトタイプを作成**。Flutter画面・mock操作とSRAM試験エンジンを実装しました。実機検証は未実施です。
`main`（`7dafc8bfe26dbf4c77467fc95438c7b4f7e8bf57`）から作成した
`release/0.1.0`で開発します。

- 初期対象: macOS 15 / 26、Apple Silicon。対象環境での動作確認は今後実施。
- 初期プログラマー: TL866CS 1台、ZIFソケット接続。
- 初期IC: 実機検証済みのEPROM型番を明示的に登録。現時点で対応確認済みの型番はありません。
- 表示: 読み取り専用HEX / ASCII、選択byteの2進数・10進数、差分表示。SHA-1を左右表示し、不一致はbyte差分と同じあずき色で示します。
- ICテスト: ロジックICは実機検証を条件とする追加候補。SRAMは拡張設計を用意し、TL866CSでは当面無効。
- 初期操作: BIN読込、IC読出し、保存、ブランクチェック、書込み、全領域照合。
- 通信: 同梱する固定版miniproをDartのバックエンドから外部プロセスとして利用。
- 将来: XGecu T56等のバックエンド追加、その後Windows / Linuxへの展開を検討。

## 設計資料

- [設計書](.chatgpt/DESIGN.md): 機能、構成、操作、データ、画面、配布、検証条件
- [minipro同梱ライセンス調査](.chatgpt/MINIPRO_LICENSE_REVIEW.md): 同梱条件とT56データの例外
- [表示・ICテスト追加設計](.chatgpt/VIEWER_AND_IC_TESTS.md): ビューアー仕様とLogic / SRAMの対応方針
- [全件カタログとステータスバー](.chatgpt/CATALOG_AND_STATUS_DESIGN.md): SHA-1、機種・ベンダー・デバイス選択、状態表示
- [決定事項](.chatgpt/DECISIONS.md): 確定した方針と変更手順
- [実装計画](.chatgpt/WORK_PLAN.md): 実装順序、実機評価、リリース条件

姉妹プロジェクトは[Mushagaeshi Binary Editor](https://github.com/hirofumi-iwasaki/musha-bin-editor)。
責務分離と表示方針を揃え、まずはBINファイルで連携します。

## License

本プロジェクトで新規作成するコード・文書は **GPL-3.0-or-later** とします。
[LICENSE](LICENSE)のGPLv3本文は保持します。第三者コード・データ・素材は元の条件と表示を維持します。
依存物の固定版、対応ソース、第三者表示の整備はバイナリー配布前の必須作業です。

## 初回プロトタイプ

アプリは **SIMULATION MODE専用** です。実際のTL866CSやICへ接続・書込みしません。
Connect simulation → Load simulation demo → Blank Check / Program / Verifyで模擬操作を確認できます。
入力BINの閲覧、HEX / ASCII、選択byteの2進・10進表示、8/16 bytes切替、アドレス移動・差分移動を実装しています。

今回の表示は64 MiBを上限とするメモリー保持方式です。ページ読込・バックグラウンドハッシュ、
Save Readoutの画面、コピー操作、古い読出しの専用表示は後続実装です。
実機バックエンド、ロジックIC実行、TL866CSのSRAMピン制御は未実装です。
SRAMのC試験エンジンはアプリと未接続で、独立した模擬メモリー試験で検証します。
App Sandboxはこのプロトタイプでは有効です。公開配布用の署名・公証は未実施です。

開発用SDKはFlutter 3.47.4 / Dart 3.13.3です。SDKをPATHへ設定した環境では:

```sh
flutter pub get
flutter test
flutter analyze
flutter run -d macos
FLUTTER_BIN=flutter zsh tool/build_macos.sh
sh tool/test_sram.sh
```

この環境の既存SDKを使う場合は、`FLUTTER_BIN`へ
`../musha-bin-editor/.tooling/flutter/bin/flutter`の絶対パスを指定してください。
ビルドスクリプトの出力先は `dist/Mushagaeshi IC Programmer.app` です。

miniproの固定版からローカルforkを再現する手順は[SRAM追加のREADME](third_party/minipro/README.md)、
実装状況は[初回実装記録](.chatgpt/IMPLEMENTATION_0.1.0.md)を参照してください。

## カタログと状態表示の更新

固定版miniproの全データベースをオフラインカタログへ取り込みました。
別名を展開した全81,763件を保持し、TL866CS選択時には141ベンダー・14,497件を対象にします。
件数には上流のcustom定義と別名を含み、型番の重複は出典を区別して保持します。
Programmer → Vendor → Deviceの順で選択し、Deviceは全一覧と検索を利用できます。
T56等の機種は将来用の無効な選択肢で、現在選択可能な機種はTL866CSです。
カタログ選択は現在の模擬操作とは別で、選択しただけで実機操作が可能になるわけではありません。

下部ステータスバーは接続状態・処理状態を表示し、動作中はプログラマー・IC・USBに触らないよう警告します。
完了後は動作中警告を解除し結果を表示します。

元データはassets/miniproに保存し、`dart run tool/generate_device_catalog.dart`で再生成できます。
チェックサム表示はSHA-1ですが、上流ファイルの出典・再現性確認用SHA-256は維持します。
