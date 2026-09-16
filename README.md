# Mushagaeshi IC Programmer

EPROMなどのICを読み出し・書き込みするDart / Flutterデスクトップアプリケーション。

## 状態

2026-09-16: **0.1.0の実機評価操作を有効化**。Flutter画面・minipro通信・mock操作とSRAM試験エンジンを実装しました。TL866CS本体の認識に成功しました。IC単位の実機検証は未実施です。
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

## 実機評価用プロトタイプ

既定で同梱miniproを使ってTL866CSの接続を確認します。
本体認識とIC操作は別です。Vendor → Deviceで正確な型番を選び、配置確認後にRead / Blank Check / Verifyを実行します。Programには追加の実行確認があります。ユーザー承認により、対象条件を満たすDIP型メモリーの評価操作を有効にしています。実機検証済みを意味しません。
画面のデモ起動ボタンは削除しています。模擬バックエンドは自動テスト用に保持します。
Open BINまたは左側のInput BIN領域へのファイルドロップで読み込みます。拡張子で制限せず、内容をそのままバイト列として扱います。
Input BINとIC Readoutは、未読込時もそれぞれ枠線付きの領域として表示します。
入力BINの閲覧、HEX / ASCII、選択byteの2進・10進表示、8/16 bytes切替、アドレス移動・差分移動を実装しています。

今回の表示は64 MiBを上限とするメモリー保持方式です。ページ読込・バックグラウンドハッシュ、
Save Readoutの画面、コピー操作、古い読出しの専用表示は後続実装です。
実機バックエンドに本体識別とメモリー操作の処理を実装しました。評価操作は有効化済みですが、ICごとの実機試験は別工程です。ロジックIC実行、TL866CSのSRAMピン制御は未実装です。
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

## GitHub Release の macOS 配布物

GitHub Release を公開すると、`macos-15` の Apple Silicon ランナーが Flutter
3.47.4（revision `9584c6713b324636289d067944a46fd6b49df14b`）で解析・テスト・
ビルドを行い、`musha-ic-programmer-macos-arm64.zip` を Release へ追加します。
手動実行では Release を変更せず、同じ ZIP を Actions の成果物として確認できます。

ZIP にはアプリ、GPL/LGPL と Dart 依存物の表示、ビルド来歴、SHA-256 一覧、アプリと
同じ固定版の展開済み minipro/libusb ソース、SRAM overlay と再ビルド用スクリプトを含めます。
現在の CI は ad-hoc 署名です。公開配布前に配布用署名 ID と Apple 公証を別途設定・検証してください。

## 実機接続の確認

TL866CS 1台、firmware 03.2.86 (0x256)を同梱miniproから認識しました。
Sandboxアプリからも起動時の接続確認に成功しています。
検証環境はmacOS 27.0 (26A428) / arm64です。macOS 15 / 26の確認は別途必要です。
ICへの実操作は未実施です。[実機確認記録](.chatgpt/TL866CS_HARDWARE_VALIDATION.md)を参照してください。

ネイティブ依存物の準備は[ビルド手順](third_party/NATIVE_REBUILDING.md)を参照してください。
配布物はApple Silicon向けです。Homebrewのminipro/libusbには依存しません。

## カタログと状態表示の更新

固定版miniproの全データベースをオフラインカタログへ取り込みました。
別名を展開した全81,763件を保持し、TL866CS選択時には141ベンダー・14,497件を対象にします。
件数には上流のcustom定義と別名を含み、型番の重複は出典を区別して保持します。
Programmer → Vendor → Deviceの順で選択し、Deviceは全一覧と検索を利用できます。
現在の機種一覧にはTL866CSだけを表示します。T56等の将来機種は一覧から除外しています。
カタログ掲載と実機検証済みを区別します。型番の選択だけで対応保証を意味するものではありません。

下部ステータスバーは接続状態・処理状態を表示し、動作中はプログラマー・IC・USBに触らないよう警告します。
完了後は動作中警告を解除し結果を表示します。

元データはassets/miniproに保存し、`dart run tool/generate_device_catalog.dart`で再生成できます。
チェックサム表示はSHA-1ですが、上流ファイルの出典・再現性確認用SHA-256は維持します。
