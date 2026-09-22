# v0.4.0: TL866II Plus対応・複数機種への拡張設計

2026-09-22作成の設計基準。設計後にユーザー承認を受け実装へ進んだ。現在の実装内容・試験結果・実機未検証の範囲は[実装記録](IMPLEMENTATION_0.4.0.md)を参照。
作業ブランチ: `release/0.4.0`。起点は最新 `origin/main` の `09fc312`（PR #4マージ済み）。

## 1. 結論と範囲

v0.4.0は既存TL866CSを維持し、TL866AとTL866II Plus（minipro名: TL866II+）を追加する。
5配布対象（macOS ARM64、Windows x64/ARM64、Linux x64/ARM64）は維持する。
機種別の設定・対応判定を共通バックエンドから分離し、次の機種追加を同じ経路で行えるようにする。
T48/T56/T76は調査対象であり、この版で自動的に有効化しない。未対応のfuture項目はUIに表示しない。

初期の操作範囲は既存と同じ読み取り、ブランクチェック、書込み、照合。直接ZIFに挿す、byte単位のBINとして扱えるDIPメモリーを対象にする。
ICSP、専用アダプター、word編成、MCU設定領域、PLD、NAND/eMMC、電圧手動変更、ファームウェア更新は拡張しない。
ロジック/SRAMは機種対応とは別の機能として扱い、この版では有効化しない。
機種名が対応一覧にあること、カタログ掲載、操作実装、実機検証済みの4つを区別する。

## 2. 調査の根拠

同梱miniproの固定ソースは `cae74c0607077d6260b24995f5e4c0d0b66a6a2e`。
リポジトリの `third_party/minipro/source/` にあるアーカイブと、それを展開した `.tooling/minipro-sram/src/` を調査した。
上流masterも2026-09-22に参照したが、固定版を置き換えていない。READMEの機種一覧だけではなく固定版の実装とCLI表示を根拠とする。

- `src/main.c`: `-Q`はTL866A/CS、TL866II+、T48（mostly complete）、T56/T76（experimental）を列挙。`-k`は実際の機種を問い合わせる。`-q tl866ii -d <alias>`で機種用のIC情報を参照できる。
- `src/usb_nix.c`・`udev/60-minipro.rules`: A/CSは `04d8:e11c`、II+/T48/T56は共通で `a466:0a53`、T76は `a466:1a86`。
- `src/database.c`: II+/T48/T56は `INFOIC2PLUS`、T76は `INFOICT76`。共有DBの機種限定情報は `flags`ではなく`pin_map`の上位ビットにある。
- `src/tl866iiplus.c`: II+の通信・ロジック試験実装が既存。新しいUSBプロトコルをDartで再実装する必要はない。
- `src/t76.c`・`src/database.c`: T76にも外部ビットストリーム処理がある。

参照URL（上流の変更可能なページ。実装時は上記固定版を優先）:

- https://gitlab.com/DavidGriffith/minipro/-/raw/master/README.md
- https://gitlab.com/DavidGriffith/minipro/-/raw/master/src/main.c
- https://gitlab.com/DavidGriffith/minipro/-/raw/master/src/minipro.h
- https://gitlab.com/DavidGriffith/minipro/-/raw/master/udev/60-minipro.rules
- https://gitlab.com/DavidGriffith/minipro/-/issues/294 （T48の進捗。未完了項目があり、過去のチェックリストを全機能保証に使わない）

## 3. 現行コードとの差分

| 対象 | 現状 | 変更方針 |
| --- | --- | --- |
| `core/models/device_catalog.dart` | CSのみ選択可。II+はfuture定義 | 型付き機種IDと機種記述を導入しCS/A/II+を提供 |
| `application/controllers/programmer_controller.dart` | CS前提の接続と文言 | 選択機種からバックエンド設定・DB・状態メッセージを解決 |
| `infrastructure/programmers/minipro/minipro_tl866_backend.dart` | backendId、USB ID、正規表現、`-q tl866a`が固定 | `MiniproBackend`と機種別記述に分離。処理の複製はしない |
| `application/minipro_profile_mapper.dart` | INFOICのみ | 選択機種・DB・機種限定ビットからプロファイル生成 |
| `core/models/device_profile.dart` | `isTl866Executable`がINFOIC限定 | 機種×プロファイル×操作を判定するポリシーへ移す |
| `native/tl866_probe.c`、Windows版 | A/CSだけを列挙 | miniproが開ける全USB ID群を副作用なしで列挙 |
| `linux/udev/60-mushagaeshi-tl866.rules` | A/CSだけ許可 | II+共有IDのルールを追加。権限付与とアプリ対応を区別 |
| `lib/l10n/`、画面 | CS専用の文言が多数 | 機種名を引数にする英日メッセージへ整理 |
| build/package・CI | 5対象に固定miniproを同梱 | 対象数維持、変更後のprobeと必要なパッチを全対象へ同梱 |

## 4. モデル・機能判定

`ProgrammerDefinition`に、機種ID、表示名、backend kind、USB ID群、minipro機種名、DB、ZIFピン数、必要外部データ、実装可能操作をまとめる。
機能判定は `backend implementation ∩ programmer ∩ device profile ∩ operation validation` とし、単一のavailableフラグだけで書込みを許可しない。
`ProgrammerConnection`は選択と独立した実機機種ID、firmware、接続識別子、世代を持つ。
実機検証記録は機種・IC完全型番・firmware・OS・アダプター・操作をキーにする。CSの検証済みフラグをII+へ引き継がない。
新しいバックエンド（minipro非対応機器）も既存の`ProgrammerBackend`ポートを実装し、ビューアーや操作状態管理を共有できる形を維持する。

## 5. 接続検出・取り違え防止

1. probeは記述子/Windowsデバイスノードの読み取りだけで全ID群を列挙する。ZIF操作は行わない。Windowsはdriver serviceとinterface readinessも返す。
2. v0.4.0は複数機器の同時利用を対象外とする。選択機種だけを数えず、miniproが開ける全ID群の合計が1台の場合のみ進める。CS+II+やII++T48も拒否する。
3. 1台なら`-k`等の本体問い合わせで機種を確定し、firmware・通常モード・選択機種との一致を確認する。II+/T48/T56共有IDをII+と推定しない。未対応機種、bootloader、未知応答は操作を無効化する。
4. 操作直前と書込み前に再検査。選択変更/切断時に世代を更新し、古い非同期応答を破棄する。
5. 重要: `-q`はDB選択用であり、特定USB機器を固定して開く指定ではない。固定版`usb_open`は複数ID群を順に探索する。別プロセスで事前検査しただけでは、検査後の差し替えを完全には防げない。
6. 実装時に既存forkへ最小限の期待機種・接続識別チェックを追加する。実際に開いた同一ハンドルで、ZIF通電/IC操作前に期待機種・識別・firmwareを照合して不一致なら終了する。既存チェックで同等保証がある箇所は再利用する。識別子はUnixのbus/address/portとWindowsのdevice instance/USB location等の対応を調査し、同じ物理機器へ結び付ける。実現できない経路は対応済みにしない。
7. probe結果・実機問い合わせ・操作プロセスの検証を別責務にする。文字列一致だけを機種安全性の根拠にせず、可能ならこの狭いチェックにversion付きJSONを用いる。CLI全体のJSON化は不要。

## 6. ICカタログ

II+はINFOIC2PLUSを参照する。既存カタログには`pinMap`の生値が保存済み。
固定版での機種マスクはII+ `0x20000000`、T48 `0x40000000`、T56 `0x10000000`。
これらが全て0なら3機種共通、いずれか設定されていれば対応ビットのある機種だけに表示する。欠落/不正値は実行可能扱いにしない。
絞り込み後のベンダー一覧を作り、重複aliasはDB/元レコードIDと結び付けて管理する。機種変更時は別DBの同名ICへ自動転用せず、デバイス選択を解除する。
カタログ掲載だけでは実行許可しない。byte編成、直接DIP、容量上限、アダプター不要など既存制約を維持し、機種別にpackage/voltage/flagsの意味を確認する。
実行前に対象の`-q`を使った`-d`出力のalias、容量、package、Available onを照合する。II+では表示が`TL866II`となることも固定版fixtureで扱う。
プロファイルごとの読取/書込可能性、消去方式、blank値も確認し、全メモリーをUV EPROM/0xffと無条件に扱わない。

## 7. UIとOS

プログラマー選択はTL866CS、TL866A、TL866II Plusの3項目。作業中/書込み確認中は変更不可。
機種変更時は接続・デバイス選択を無効化して再検出する。入力BINは維持し、既存readoutは採取元機種/ICを保持した過去データとして表示する。
ステータス、再接続ボタン、確認ダイアログ、技術詳細は実際の対象機種を表示し、既存の英日切替とキーボード選択を維持する。

- macOS: 同梱libusb方式を継続。専用ドライバーの追加を前提にしないが、II+のUSBアクセス・パッケージ起動は実機で検証する。
- Windows: x64/ARM64とも同梱libusb + WinUSBを継続。II+は`a466:0a53`へのバインドが必要で、CS用に導入した設定だけでは代用できない。共有IDからT48/T56の接続も検出し、モデル確認で拒否できるようにする。READMEのARM64導入手順を対象機種に合わせて更新する。
- Linux: 既存uaccess/0660/plugdev方針で共有IDを追加。T76は今回新しいアクセス権を付与する必要はないが、複数台検出の対象には含める。

## 8. 他機種への対応可能性

| 機種 | 根拠・難点 | 方針 |
| --- | --- | --- |
| TL866A | 固定miniproに実装済み。CSとUSB ID/DB共通だが実機モデルは異なる | 追加承認により今回実装。INFOIC/LOGICを使用しCSとは本体識別を分離。ICSPは対象外 |
| T48 | 実装済み。CLIはmostly complete。II+とDB/USB ID共通だが機種限定項目あり | 次の有力候補。操作別の欠落と実機検証が必要 |
| T56 | 実装済みだがexperimental。外部FPGAアルゴリズムが必要 | 後続版。利用者指定の外部データと必要アルゴリズム検査を設計 |
| T76 | 固定版に実装・専用DBあり。experimental、外部ビットストリーム処理あり | 後続版。T56と同様の外部データ管理に加え専用操作を評価 |
| その他のメーカー/USBプログラマー | 今回調べたminiproには汎用的な対応経路を確認していない | 機種名ごとにプロトコル/公開SDK/ライセンスを別途調査し、別backendとして追加 |

上流READMEはT56用アルゴリズムを著作権上同梱できないと明記している。miniproのGPLだけで外部データの再配布を許可されたとは扱わない。
T76も同梱権利を確認できていないため、T56/T76の外部データを自動ダウンロード・同梱する方針にはしない。必要データの形式/機種/完全性検査と利用者指定の保存先を用意する案とする。
ロジック試験はII+の既存実装を利用できる可能性が高い。一方SRAMは保持通電・ピン制御アダプターが別途必要であり、既存の純粋Cパターン試験の成功を実機対応としない。

## 9. 実装順序と完了条件

1. 機種記述・対応ポリシー・共有DBフィルターの導入。CSの挙動を回帰テストで維持。
2. 両probe・本体識別・同一ハンドル検証。複数機種/未知機種/切断/モデル取り違えをfixtureとnative試験で拒否できること。
3. II+用プロファイル・CLI検査・UI英日文言・選択遷移を実装。
4. II+実機でまず識別と既知BINの読取り一致、ブランク判定を確認。書込み用ICは完全型番/電圧/配置を確認してから書込み・読戻し一致を検証。
5. 接続変更、busy、途中切断、キャンセル、言語/機種変更競合の試験。書込み途中の中断は成功扱いにせず再接続/再確認を要求。
6. 5対象CI、Linux権限ルール、Windowsドライバー未導入/誤バインド、Unicodeパス、macOS配布署名を検証。Ubuntu 24.04起動試験も維持。
7. README英日、対応機種表、操作別実機記録、minipro差分と対応ソースを更新。配布版は`0.4.0+5`、CIのpush対象は`release/0.4.0`へ実装時に更新する。

自動試験は共有DBマスク0/各bit/複合bit/不正値、同名alias、選択機種不一致、CS+II+同時接続、共有IDのT48誤接続、FW/bootloader、差し替え、旧応答破棄を必須とする。
既存80テストとnative SRAM試験を維持し、新しい機種判定テストを追加する。
CIビルド成功と実機試験は別に記録する。II+実機の有無、firmware、試験IC、Windows/Linuxでの実機試験範囲は未確認であり、実装着手後のハードウェア検証時に確認する。
