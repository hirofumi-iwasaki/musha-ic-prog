# Mushagaeshi IC Programmer

[English](README.md) | **日本語**

読み取り専用の16進数ビューアーと比較機能を備えた、デスクトップ向けEPROM・メモリーICプログラマーです。

リポジトリ: [hirofumi-iwasaki/musha-ic-prog](https://github.com/hirofumi-iwasaki/musha-ic-prog)

バージョン0.2.0では、TL866CS用アプリケーションをmacOS ARM64、Windows x64／ARM64、Ubuntu x64／ARM64の5プラットフォームへ拡張しています。各移植版の検証を進めており、CIでのビルド確認と実機でのUSB動作確認は分けて管理しています。Dart／Flutter構成により、今後はXGecu T56などのプログラマー用バックエンドを各OSへ追加できます。ビューアーの表示方法は[Mushagaeshi Binary Editor](https://github.com/hirofumi-iwasaki/musha-bin-editor)を参考にしています。

## v0.2.1のリリース状況

[v0.2.1](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.2.1)では、日本語README全文と言語切り替えリンクを追加し、Windowsの導入手順を拡充しました。ARM64の署名エラーの一時回避と通常再起動後の確認も記載しています。Windows配布物には実行ファイルと同じ場所に両言語のREADMEを同梱し、接続時のメッセージから主READMEを案内します。5プラットフォームすべての対応ソースにも日本語READMEを含めます。プログラマーの操作と、v0.2.0で修正したUSB通信方式は変更していません。

## v0.2.0のリリース状況

再公開した[v0.2.0 Release](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.2.0)には、WindowsでのTL866CS通信の修正が含まれています。同梱のlibusbとMicrosoftのWinUSBドライバーを使用します。Windowsでは初回にドライバーの割り当てが必要で、UbuntuではUSBアクセス権の設定が必要になる場合があります。修正前の配布ファイルを取得している場合は、再公開版へ置き換えてください。

修正後の5プラットフォームのビルドと、Ubuntu 24.04の両CPUでの起動確認は[自動検証](https://github.com/hirofumi-iwasaki/musha-ic-prog/actions/runs/35074949228)に合格しています。自動ビルドの成功は、実機USB動作の確認を意味しません。[実装記録](.chatgpt/IMPLEMENTATION_0.2.0.md)と[Windowsの導入手順](#windows-installation)も参照してください。今回の移植では、対応ICの種類や実機でのSRAM・ロジックIC試験機能は追加していません。

## v0.1.0の検証実績

macOS版のGitHub Actionsビルド、静的解析、テスト、リリースファイルのアップロードは成功しています。ローカルでは配布アプリケーションの署名とチェックサムも確認しました。承認済みの城とEPROMの絵柄をmacOSアプリアイコンに使用しています。

接続したTL866CSで27C512を正常に読み出せたというユーザー報告があります。これは特定の機器・ICについての報告であり、カタログ内のすべてのICや操作を検証したものではありません。条件を満たすDIP型メモリーICで評価用の操作を利用できますが、ロジックIC試験とTL866CSのSRAMピン制御は未実装です。

## 動作要件

- macOS 15以降、Apple Silicon（M1以降）
- 新たな移植先としてWindows 11 x64／ARM64、またはUbuntu 22.04／24.04 LTS x64／ARM64
- IC操作にはUSB接続のTL866CSが必要
- 配布アプリの実行にFlutter、Homebrew、minipro、libusbの別途インストールは不要

開発にはFlutter 3.47.4、Dart 3.13.3、Xcodeを使用しています。macOS 27.0（26A428）とTL866CSファームウェア03.2.86（0x256）で本体への接続を確認しました。macOS 15／26でのGUIと実機の受入確認は、CIのビルド確認とは別に扱っています。

## macOS版の起動

[Releases](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases)から`musha-ic-prog-macos-arm64.zip`をダウンロードして展開し、**Mushagaeshi IC Programmer.app**を開きます。アプリケーションフォルダーへコピーして使用できます。

ローカルでパッケージを作成した場合、アプリは次の場所に生成されます。

```text
dist/Mushagaeshi IC Programmer.app
```

```sh
open 'dist/Mushagaeshi IC Programmer.app'
```

現在はアドホック署名を使用しており、Appleの公証は受けていません。App Sandboxは有効です。

**Open BIN**を選ぶか、左側の**Input BIN**領域へファイルを1つドロップしてください。拡張子の制限はありません。内容はバイト列として読み込み、Intel HEXなどの形式としては解釈しません。IC操作前に正確なベンダーとデバイスを選び、ICの挿し方を確認してください。書込みには追加の確認があります。動作中はプログラマー、IC、USB接続に触れないでください。

<a id="windows-installation"></a>

## Windowsの導入手順

### ダウンロードと展開

1. [v0.2.1](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.2.1)から取得します。Intel／AMD搭載のWindows PCには`musha-ic-prog-windows-x64.zip`、Windows ARM PCやApple Silicon上のParallelsで動かすWindowsには`musha-ic-prog-windows-arm64.zip`を使用してください。
2. 実行前に配布ファイル全体を展開します。`mushagaeshi_ic_programmer.exe`、各DLL、`data/`、`native/`、`resources/`をまとめて保持してください。特に`native/libusb-1.0.dll`は`native/minipro.exe`と同じ場所に必要です。
3. `mushagaeshi_ic_programmer.exe`を開きます。Flutter、MiniPro、libusbを別途インストールする必要はありません。プログラマーを接続しなくてもファイルを閲覧できますが、USB操作には以下のドライバー割り当てが必要です。

Windows通信修正前のv0.2.0を取得している場合は、再公開版へ置き換えてください。以前の実行ファイルは、ドライバー設定だけでは修正されません。このリビジョンから作成するWindows配布物では、実行ファイルと同じ場所に英語版と日本語版のREADMEを同梱します。公開済みの配布物では、`resources/minipro/WINDOWS_USB_SETUP.md`を案内している場合があります。本節がその旧手順に代わるものです。

### TL866CSをWindowsへ接続する

純正MiniProを含む、ほかのプログラマー用ソフトを終了します。TL866CSを1台だけUSB接続してください。

Mac上のParallelsでは、USBデバイスのメニューまたは接続時の確認画面から、**MiniPro TL-866 Programmer**をWindows仮想マシンへ割り当てます。macOS側ではなくWindows側へ接続してください。再起動や抜き差しのあとにアプリが機器を検出できない場合は、この割り当ても確認します。

### ZadigでWinUSBを割り当てる

WinUSBドライバー自体はWindowsに含まれていますが、TL866CSへの初回割り当てが必要な場合があります。この設定には管理者の承認が必要です。通常のアプリ利用では管理者権限は不要です。

1. [Zadig公式サイト](https://zadig.akeo.ie/)から最新版を取得します。ARM64へのWinUSBインストール対応はZadig 2.8で追加されましたが、後述するWindows ARM64の署名制限がなくなるわけではありません。
2. Zadigを起動し、管理者の確認画面を承認します。
3. **Options > List All Devices**を選びます。
4. **MiniPro TL-866 Programmer**、またはTL866CSに該当する項目を選択します。先へ進む前に、**USB IDが`04D8 E11C`であることを確認**してください。キーボード、マウス、ハブなど別のUSB機器を選ばないでください。TL866Aも同じIDを使用しますが、アプリが別途機種を確認し、TL866CSの操作だけを有効にします。
5. 置き換え先のドライバーに**WinUSB**を選び、**Install Driver**または**Replace Driver**を押します。このアプリ用にはlibusbKやlibusb-win32を選ばないでください。
6. インストール成功後、TL866CSを抜き差しし、アプリを開いて接続を更新します。

WinUSBを割り当てると、従来の専用ドライバーを利用する純正MiniProが使えなくなる場合があります。純正ソフトへ戻す場合は、メーカー公式インストーラー、または利用可能であればデバイスマネージャーのドライバーを元に戻す機能で復旧してください。

### Windows ARM64で署名エラーになった場合

WinUSB本体はMicrosoft提供ですが、Windows ARM64ではZadigが生成するドライバーパッケージを拒否する場合があります。画面には**Operation not supported or not implemented**と表示されることがあります。この表示だけでは原因を特定できません。

Zadigで**Options > Advanced Mode**を有効にし、**Options > Log Level > Debug**を選んでインストールログを確認します。今回のアプリ導入時に発生した署名拒否は、次のメッセージで確認できます。

```text
Driver package signer is not trusted by system, and Code Integrity is enforced.
Driver package failed signature validation. Error = 0xE0000243
This version of Windows is refusing to trust the installed certificate.
```

これは[libwdi／ZadigのARM64に関する既知問題](https://github.com/pbatard/libwdi/issues/289)です。アプリがプログラマーと通信する前の段階で発生するため、アプリの再インストールでは解消しません。

このエラーについては、**MacBook Pro M1 MaxのParallels Desktop上で動作するWindows 11 ARM 25H2、OSビルド26200.9457**で、次の一時回避手順によるインストール成功を確認しています。

1. 作業中のファイルを保存します。BitLockerまたはデバイスの暗号化が有効な場合は、起動設定を変更する前に回復キーを用意してください。キーを確認できない場合は、ここで中止します。
2. Windows内のスタートメニューから、**Shiftキーを押しながら「再起動」**を選びます。Parallels側のリセットや一時停止では代用しないでください。
3. **「トラブルシューティング → 詳細オプション → スタートアップ設定 → 再起動」**を選びます。
4. 番号付きの起動メニューで、**7「ドライバー署名の強制を無効にする」**を選びます。数字キーを使えば、Macのファンクションキー割り当ての影響を避けられます。
5. Windows起動後、TL866CSがWindows側へ割り当てられていることを確認します。Zadigを起動し、前述の**`04D8:E11C` → WinUSB**のインストールを行います。インストール完了前に再起動しないでください。
6. インストール後は、7を選ばずにWindowsを通常どおり再起動します。TL866CSをWindows側へ再接続し、アプリで認識を確認します。他の操作へ進む前に、正しいICプロファイルと挿し方で読出しを確認してください。

**この操作は、その起動中だけドライバー署名の強制を弱めます。** 公式Zadigによる対象のWinUSBパッケージの導入に限って利用してください。通常の再起動で署名の強制は元に戻ります。この手順では、テストモードの常時有効化やSecure Boot・メモリ整合性の無効化は行いません。それでも失敗する場合は、さらに保護機能を無効化せず、ログを保存して原因を確認してください。[Microsoftの起動設定手順](https://support.microsoft.com/en-us/windows/experience/startup-boot/windows-startup-settings)と[署名の強制を一時無効化する設定](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/test-signing)も参照してください。

### 通常再起動後の確認

上記のParallels環境では、通常再起動後もアプリが正常に使えたことをユーザーが確認しています。**確認済みの環境では、7を選ぶ操作は初回のドライバー導入時だけで済み、起動のたびに行う必要はありませんでした。** インストール用パッケージの署名検証と、MicrosoftのWinUSBドライバーの読込みは別の段階です。

この報告は、すべてのWindowsビルドや構成での動作を保証するものではありません。Windowsの再インストール、ドライバーの削除、古い仮想マシンスナップショットへの復元、機器やUSB割り当ての変更などにより、再設定が必要になる場合があります。機器が見えなくなった場合は、署名の一時回避をすぐに繰り返すのではなく、まずParallelsのUSB割り当てと使用中のドライバーを確認してください。

### Windowsの接続トラブルを調べる

展開したアプリのフォルダーでPowerShellを開き、次を実行します。

```powershell
.\native\tl866_probe.exe
```

この確認用プログラムは機器情報を読み取るだけで、ICを操作しません。

| 結果 | 確認すること |
| --- | --- |
| `count`が`0` | ケーブル、USB接続、ParallelsでWindows側へ割り当てられているか。 |
| 一致する機器が複数ある | 余分なTL866A／CSを取り外す。 |
| `driverService`が空 | ドライバーの割り当てが完了していません。Zadigの手順を確認する。 |
| `driverService`が`WinUSB`ではない | 別のドライバーが割り当てられています。Zadigの対象機器とドライバーを確認する。 |
| `driverService`が`WinUSB`、`interfaceReady`が`true` | ドライバーの前提条件は満たしていますが、アプリによる機種・ファームウェア確認は別途必要です。接続に失敗する場合は他のプログラマー用ソフトを終了し、再接続する。 |

解消しない場合は、Zadigのバージョンとエラーログ、`winver`で表示されるWindowsのバージョンとOSビルド、実機か仮想マシンか、上記の確認結果を報告してください。7を選んで一時起動した状態でインストールしたかどうかも記載してください。BitLockerの回復キーやその他の認証情報は含めないでください。

## Ubuntuの導入手順

Ubuntu環境のCPUに合った`musha-ic-prog-linux-x64.tar.gz`または`musha-ic-prog-linux-arm64.tar.gz`を[Releases](https://github.com/hirofumi-iwasaki/musha-ic-prog/releases/tag/v0.2.1)から取得します。全体を展開し、展開先の`mushagaeshi_ic_programmer`を実行してください。

ディストリビューションのGTK 3、EGL／OpenGL、LZMA実行時ライブラリー（`libgtk-3-0`、`libegl1`、`libgles2`、`libgl1-mesa-dri`、`liblzma5`）が必要です。USBアクセスが拒否される場合は、同梱の[USBアクセス設定手順](linux/udev/README.md)に従ってください。アプリをrootで実行しないでください。

Linuxでは実機動作成功のユーザー報告がありますが、ディストリビューションの版、CPU構成、確認した操作の詳細は未指定です。前述のWindows ARM64とLinuxの報告は実機での確認結果であり、すべての対象環境、ICプロファイル、書込み操作を検証したものではありません。ファイルビューアーと操作確認の流れは、すべての環境で共通です。

## 主な機能

- 同梱・バージョン固定のminiproとlibusbによるTL866CS検出
- プログラマー、ベンダー、デバイスの選択とデバイス検索
- 固定版miniproの全カタログを収録：81,763の別名、うちTL866CS向けは141ベンダー・14,497エントリー
- 条件を満たすメモリープロファイルでのIC読出し、ブランク確認、比較、確認操作を伴う書込み
- 枠線で分かれた**Input BIN**と**IC Readout**の表示領域
- 読み取り専用の16進数・ASCII表示と、選択バイトの2進数・10進数表示
- 左右のSHA-1表示。不一致はバイト差分と同じあずき色で強調
- 1行8／16バイト、同期スクロール、アドレス移動、差分への移動
- 左側へのファイルのドラッグ＆ドロップ、拡張子を問わないファイル読込み
- 接続・動作状況の表示と、動作中にプログラマーへ触れないための警告

カタログへの掲載は、そのICの実機検証が済んでいることを意味しません。別名や上流のカスタム定義を保持しており、異なる出典の似た名前の項目も含まれます。

## GitHub Actionsによるビルド

**Desktop build and package**ワークフローは、`release/0.2.1`へのpush、プルリクエスト、Release公開、手動実行で動作します。Flutter 3.47.4のリビジョン`9584c6713b324636289d067944a46fd6b49df14b`に固定し、各CPUでネイティブに動作するランナーを使って5種類をビルドします。Ubuntu版は22.04上で作成し、24.04でも画面表示を伴わない起動確認を行います。

| 対象 | 配布ファイル |
| --- | --- |
| macOS ARM64 | `musha-ic-prog-macos-arm64.zip` |
| Windows x64 | `musha-ic-prog-windows-x64.zip` |
| Windows ARM64 | `musha-ic-prog-windows-arm64.zip` |
| Ubuntu x64 | `musha-ic-prog-linux-x64.tar.gz` |
| Ubuntu ARM64 | `musha-ic-prog-linux-arm64.tar.gz` |

各ビルドでは静的解析、テスト、ネイティブ部品のパッケージ化、CPU構成の確認を行います。5種類すべてのパッケージ作成が成功してから、Releaseへのアップロードを実行します。手動実行とブランチのビルドではActionsの成果物のみを生成します。CIでは実機ICを操作せず、GUIや実機の受入確認が完了したとは扱いません。

各配布ファイルには、実行に必要な構成一式、ライセンス・通知、`SOURCE_AND_BUILD.txt`、`SOURCE/`内の対応ソース、`SHA256SUMS.txt`が含まれます。WindowsではOSのWinUSBを使用し、MSYS／Cygwinの実行環境は不要です。UbuntuではGTKデスクトップライブラリーと適切なUSBアクセス権が必要です。アプリがドライバーやアクセスルールを自動インストールすることはありません。

## 開発とパッケージ作成

Flutter 3.47.4をインストールし、リポジトリのルートで実行します。

```sh
flutter pub get
flutter run -d macos
```

ネイティブのプログラマー用部品を含むアプリを作成するには、パッケージ作成スクリプトを使用します。

```sh
FLUTTER_BIN=flutter zsh tool/build_macos.sh
```

配布用ZIP全体を作成する場合：

```sh
FLUTTER_BIN=flutter zsh tool/package_macos.sh
```

`FLUTTER_BIN`にはFlutter実行ファイルの絶対パスも指定できます。スクリプトはバージョンを固定したminiproとlibusbをローカルでビルドし、取得ファイルのハッシュを検証し、Sandboxの権限設定を保持してアプリ全体へ署名します。出力先は`dist/`です。`build/`、`dist/`、`.tooling/`はGit管理の対象外です。

Windowsでは対象CPUのネイティブホスト上のPowerShellから、`tool/build_windows.ps1 -Architecture x64`（ARM64は`arm64`）を使用します。Ubuntuでは対象CPUのUbuntu 22.04ホスト上で、`FLUTTER_BIN=flutter bash tool/build_linux.sh x64`（ARM64は`arm64`）を使用します。前提条件と固定版Flutterの準備方法は[CIワークフロー](.github/workflows/desktop-build.yml)に記載しています。

依存ライブラリーとforkの詳細は、[ネイティブ部品の再ビルド手順](third_party/NATIVE_REBUILDING.md)と[miniproのSRAM拡張](third_party/minipro/README.md)を参照してください。

## 検証

```sh
flutter analyze
flutter test
sh tool/test_sram.sh
```

Flutterのテストでは、コントローラーの動作、プロファイル対応付け、miniproプロセスの扱い、バイナリー比較、ネイティブのドロップ通知を確認します。独立したSRAM試験エンジンは模擬メモリーでテストしており、TL866CSの実機操作には接続されていません。[実機検証記録](.chatgpt/TL866CS_HARDWARE_VALIDATION.md)では、接続確認、ユーザー報告、未完了のIC別検証を区別しています。

## 構成と現在の制限

- `lib/core`：デバイスプロファイル、カタログ、プログラマーモデル
- `lib/infrastructure`：プログラマーのバックエンドとminiproプロセスの実行
- `lib/application`：操作制御と対応プロファイルのマッピング
- `lib/presentation`：デバイス選択、バイナリービューアー、ステータス表示
- `macos/Runner`、`windows/runner`、`linux`：各OSのウィンドウ、ファイルドロップ、連携した終了要求
- `lib/platform`：共通のデスクトップホストインターフェースと動作状況を考慮した終了処理
- `native`：USB接続確認用プログラム
- `third_party`：固定した依存情報、ライセンス、SRAM拡張ソース

ビューアーはデータをメモリー上に保持し、上限は64 MiBです。バイナリー編集、読出し結果の保存UI、コピー、ページ単位の読込みは未実装です。ファイルは同じオフセット同士で比較し、挿入や削除による位置のずれは補正しません。

選択できるプログラマーはTL866CSのみです。T56対応、ロジックICの試験実行、実機SRAM試験は今後の課題です。Windows／Linuxの実機検証はCPU構成ごとに記録します。SRAM試験エンジンは独立した拡張基盤として存在しています。実機操作を利用できることと、そのICで実測検証が済んでいることは分けて管理しています。

## ライセンス

本プロジェクトで作成したコードと文書は、**GNU GPL バージョン3以降（GPL-3.0-or-later）**で公開しています。[LICENSE](LICENSE)を参照してください。第三者のコード、データベース、素材には、それぞれ元のライセンスと通知が適用されます。

配布物には、対応するminipro／libusbのソース、SRAM拡張、再ビルド手順を含みます。依存ライブラリーの取り扱い方針は[miniproライセンス調査](.chatgpt/MINIPRO_LICENSE_REVIEW.md)に記録しています。

設計方針と作業記録は`.chatgpt/`に保存しています。[設計](.chatgpt/DESIGN.md)、[ビューアーとIC試験計画](.chatgpt/VIEWER_AND_IC_TESTS.md)、[決定事項](.chatgpt/DECISIONS.md)を参照してください。
