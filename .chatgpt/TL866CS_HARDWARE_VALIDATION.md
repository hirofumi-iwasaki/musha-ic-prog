# TL866CS実機接続検証

検証環境: 2026-09-16 / macOS 27.0 (26A428) / arm64。
これは設計対象のmacOS 15 / 26全数での検証を代替しない。

チェックポイント: 987c387 (release/0.1.0)、originへpush済み。
実機対応の追加差分はチェックポイント後の未コミット作業。

USB列挙: MiniPro TL-866 Programmer、VID 04d8 / PID e11c。
この段階ではTL866A/CSを区別しない。

## プロジェクト内CLIの本体識別（成功）

- libusb列挙helper: count=1、bus=1、address=1。
- minipro -k: `tl866a: TL866CS`。
- minipro --version（固定infoic/logicicの明示指定）: `Found TL866CS 03.2.86 (0x256)`。
- minipro 0.7.4 / cae74c0607077d6260b24995f5e4c0d0b66a6a2e。
- bootloader表示・firmware不一致警告なし。
- USB速度: 12Mbps (USB 1.1)。
- IC型番は指定しておらず、ICの読出し・書込み・ID検出・pin check・消去・firmware更新は未実行。
- 本項はプロジェクト内CLIの検証。署名済みSandboxアプリからの確認は別途行う。

## Sandboxアプリからの本体識別（成功）

生成した `dist/Mushagaeshi IC Programmer.app` を起動。
アプリ自身の既定起動経路から署名済みminiproと列挙helperが呼ばれ、次のログを取得した。

```
TL866CS connection scan: TL866CS connected (usb-1-1); TL866CS ready; no IC operation has been performed.
```

App Sandbox、USB権限、ユーザー選択ファイル権限を維持。
子helperはSandboxとinheritのみ。`codesign --verify --deep --strict`成功。
minipro・libusb・列挙helperはarm64。依存はbundle内のlibusbとmacOS標準ライブラリー。
公開署名・公証、macOS 15/26、Intel、別Macでの配布試験は未実施。

## IC操作の有効化について

実機未検証profileを操作可能にする変更は自動承認レビューに拒否された。
`isTl866Executable`のverified条件は今回の実装時に導入されたもの。既存commitの条件であるとは扱わない。
この拒否を回避せず、本体認識と評価用処理の実装・試験を先に完了する。
ユーザーによる評価操作の許可と実機検証済みの記録は別に管理し、許可だけでverified=trueにはしない。

### 操作処理の自動検証

全Flutterテスト42件成功、Flutter analyze成功。実機を呼ばないfake processで、
読出し容量不一致、ブランク不一致時の書込み拒否、不変入力、-e/-w/-c code、
書込み失敗後の復旧要求、読戻し差分件数、書込み開始前の中止、ReadによるVerifyを確認。
操作完了の通知前に一時ファイルの後始末と実行ロックの解除を行う。
未検証profileを拒否するゲートのテストも維持した。

現段階では外部プロセス全体の時間上限・強制終了後の回収を実装していない。
ハードウェア操作中の強制killは行わず、中止要求はコマンド境界で扱う。
ICの実機読出し・書込み、終了保留・復旧journal・多重起動間の排他は後続の検証項目。

## 評価操作の有効化承認

ユーザーから「有効化OKです」と明示承認を受領。
D24に従い、対象の上流定義profileに評価許可を設定する。実機検証済みのフラグはfalseのまま。
未承認profileの拒否と、対象外の型番を除外する条件は保持する。
使用中のIC型番は未確定であり、今回も本体認識以外の実機操作は自動実行しない。

### 評価許可とDB照合の確認

INFOIC内で一意のAMD AM27C256@DIP28をDB照合用の例として使用。
Dart mapperはcapacity32768 / DIP28 / evaluationAuthorized=true / verified=false。
minipro -q tl866a -d（固定XML指定）の情報表示も型番・32768 Bytes・DIP28が一致した。
これはソケットのIC操作ではなく、同梱データベースの解析結果を確認したもの。
この型番のICが挿入されているとは判断していない。

### 有効化後の最終確認

全Flutterテスト44件成功、担当範囲の静的解析成功。
更新したmacOS releaseアプリのビルドとcodesign --verify --deep --strictに成功。
有効化済みアプリを起動し、TL866CS connected (usb-1-1) / readyを再確認した。
ICのRead/Blank/Verify/Programは実行していない。
成果物: dist/Mushagaeshi IC Programmer.app。実機対応・有効化差分は未コミット。

## ユーザーからの27C512読出し成功報告

ユーザーより「実機で27C512を正常に読み込めました」と報告あり。
メーカー・完全な選択alias・比較用既知データは未提供のため、ユーザー報告として保存する。
特定のprofileに実測検証済みフラグを推測で付けない。
