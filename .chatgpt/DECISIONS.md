# 設計決定記録

2026-09-16。以下を0.1.0の実装基準として確定する。未検証項目はWORK_PLAN.mdのゲートで解消し、暗黙に対応済みにしない。

| ID | 決定 | 理由 |
| --- | --- | --- |
| D01 | Dart / Flutter、単一プロジェクト、4層分離 | 姉妹アプリと保守方法を揃える |
| D02 | macOS 15 / 26、Apple Siliconから開始 | 初期の実機・配布検証範囲を限定する |
| D03 | TL866CS 1台・ZIF・検証済みEPROMを必須、Logic試験は条件付き候補 | 型番や電圧の誤推定を防ぐ |
| D04 | 同梱・固定版miniproを外部プロセスで使用 | USB・ICアルゴリズムの再実装を避ける |
| D05 | Backend / Capability / DeviceProfileで機種差を分離 | T56等をUI変更に波及させず追加する |
| D06 | BIN全領域・容量一致、暗黙補完なし | 書き込む内容を一意にする |
| D07 | 非ブランクへの書込み拒否、書込み後全件照合 | 初版の書込み手順を明確にする |
| D08 | UV EPROM消去・ファームウェア更新・電圧変更は対象外 | 初版のIC操作範囲を限定する |
| D09 | 中断保証がない書込みを通常操作から強制停止しない | 中断と安全な終了を区別する |
| D10 | BINファイルでBinary Editorと連携 | 初期から共有パッケージやIPCに依存しない |
| D11 | App Sandbox無効・自己完結.app・直接配布 | USBと同梱プロセスの配布方式を統一する |
| D12 | 新規成果物GPL-3.0-or-later、第三者の条件維持 | 既存GPL本文と姉妹プロジェクトの方針に合わせる |
| D13 | 初期UIは英語、表示文字列を集約 | 姉妹アプリと操作表記を揃える |
| D14 | 読み取り専用HEX / ASCII、選択byteの2進・10進表示を初版必須 | Binary Editorの表示構成を参考にし、編集状態を持ち込まない |
| D15 | logicTest / sramTestを別操作として拡張 | ROM書込みと試験結果・破壊性を区別する |
| D16 | Logicは実機検証条件付き、TL866CSのSRAMは無効 | 調査版の機種別実装差を反映する |

詳細は[表示・ICテスト追加設計](VIEWER_AND_IC_TESTS.md)。D03はユーザーの機能追加依頼に従い拡張した。

## 確定方針と実測値の区別

miniproの採用commit、libusb版、対応IC完全型番、firmware、CLI引数・出力形式、操作タイムアウトは実装M0で固定する実測・依存情報である。
設計完了はこれらの動作保証を意味しない。実機がなければM0の未達項目を明記し、mock実装のみを進められる。

M0で外部プロセス方式の安全性や機種識別を満たせない場合、破壊的操作を無効に保つ。
必要な最小限のnative補助または制御可能なhelper方式への変更を、新しい決定記録に理由・代替案・検証条件とともに記録する。

実装中に新しい根拠が得られたら、決定IDを参照してDESIGN.mdとWORK_PLAN.mdを同時更新する。
対象OS・機種・機能の拡大を未記録で行わない。

## 2026-09-16: fork実装への更新

D17: miniproをforkしSRAM基本テストを追加する。詳細は[実装方針](MINIPRO_FORK_PLAN.md)。
D16の実機未検証時の無効化を維持しつつ、SRAMを独自実装の対象に変更する。

## 初回プロトタイプの配布設定差分

App Sandbox無効化は自動承認レビューにより永続的なセキュリティ制限の緩和として拒否された。
初回のmockプロトタイプはSandboxを有効のまま進める。D11の実機向け配布構成は未適用。
実機用設定を確定するときにSandbox有効で成立する構成を評価し、必要なら変更の明示承認を得る。

## 追加UI仕様

D18: checksum表示はSHA-1、不一致背景はbyte差分と共通のあずき色。
D19: 上流全件をカタログへ掲載し、Programmer→Vendor→Deviceで選択。実機検証は別管理。
D20: 接続・動作状態を下部バーに表示し、動作中は機器に触らないよう警告する。
詳細は[更新仕様](CATALOG_AND_STATUS_DESIGN.md)。

## 実機評価用バックエンドへの切替

D21: future機種をUIの一覧から除外し、現在はTL866CSのみを表示する。内部の将来機種情報は保持する。
D22: ユーザーの実機接続・切替指示に従い、既定を同梱miniproによるTL866CS接続へ変更する。
検証用に上流定義から実行可能と判定したメモリー型番を扱うが、実機検証済みと記録しない。
上流カタログ掲載、実行条件を満たす型番、実機検証済み型番の3つを区別する。
型番・配置・adapterの確認、容量一致、ブランク確認、書込み後の別読出し照合を維持する。
Logic/SRAM/MCU等の未実装操作や曖昧な型番解決を有効化しない。
正式リリースの型番ごとの実機検証ゲートは維持し、今回の切替は開発・実機評価用とする。
D23: D11のSandbox無効化案を置き換え、Sandbox有効・USB権限・子プロセス権限継承で同梱helperを起動する。
本体の識別情報だけを読む接続確認と、ICを選択して電圧を印加するメモリー操作を分ける。

## 実機評価の明示承認

D24: 2026-09-16、ユーザーが「有効化OKです」と明示承認した。
承認対象は上流minipro定義を使用する、アダプター不要・40ピン以下のDIP型メモリーの
読出し、ブランク確認、照合、実行確認後の書込み。型番・挿し方の相違によるIC破損や
データ変更の可能性を含む確認を経た。
`evaluationAuthorized`を実測記録の`verified`と分離し、承認だけでverifiedを真にしない。
INFOIC type 1、byte構成、有効容量、非SMD・直接DIP、型番解決が一意という既存条件を維持する。
書込み前ブランク確認、自動消去禁止、書込み後全byte照合、各操作の配置確認を維持する。
この承認は未知のICを自動で操作する指示ではなく、アプリ内の評価操作を有効にする指示である。

## v0.2.0: five-platform portability (2026-09-16)

Accepted implementation baseline: [CROSS_PLATFORM_0.2.0.md](CROSS_PLATFORM_0.2.0.md).

- D25: Five release targets: macOS ARM64, Windows 11 x64/ARM64, Ubuntu 22.04/24.04 x64/ARM64. ARM means native ARM64. Linux distribution baseline follows Binary Editor.
- D26: Keep shared Dart/controller/UI and pinned minipro protocol implementation. Extract payload/discovery/file-drop/window lifecycle adapters; keep macOS sandbox behavior.
- D27 (superseded by D30): Windows uses pinned minipro's existing SetupAPI/WinUSB backend and a Windows discovery probe. Linux/macOS use libusb. Driver GUID/ARM64 binding and Linux udev access are explicit native validation gates.
- D28: Five complete archives named musha-ic-prog-[OS]-[arch], with matching sources/notices; all required builds must pass before release assets are uploaded as a complete set.
- D29: Device eligibility and existing operation safeguards remain unchanged. No T56, physical SRAM/logic feature expansion or binary editing in this portability scope. Per-target hardware evidence is required independently of CI.

These decisions extend the 0.1.0 records; they establish the implementation direction, not completed platform support.

## D30: Windows TL866CS transport correction (2026-09-16)

Pinned `src/usb_win.c` uses legacy vendor IOCTLs for TL866A/CS, not its WinUSB
path. D27's assumption was incorrect; a WinUSB binding alone cannot make that
binary work. Compile pinned `src/usb_nix.c` with libusb 1.0.29 on Windows x64 and
ARM64, bundle the native shared DLL, and use Microsoft's built-in WinUSB driver
with a separate user-approved Zadig assignment. SetupAPI discovery checks USB
VID/PID and the bound service rather than the legacy vendor interface GUID.
Actual MiniPro model/firmware access remains the next readiness check. Preserve
all existing IC operation safeguards and macOS/Linux behavior.

The user requested withdrawal of v0.2.0: the GitHub Release and assets were
deleted; its tag remains unchanged. Corrected branch builds are for validation;
do not republish a Release without a new user instruction. Compilation and
hosted no-device checks must not be reported as physical hardware acceptance.

## D31: Republish corrected v0.2.0

The user explicitly requested publishing v0.2.0 again after the correction.
Move the old tag from `941f6f0fc7c33e768c8ae8c81ef0157710a56413` to the corrected
release commit, publish English release notes titled `v0.2.0`, and rebuild all
five assets from that tag through the release workflow. The earlier withdrawal
record remains historical. This approval is not physical hardware test evidence
and does not request merging PR #2.

## D32: v0.3.0 UI language selection (2026-09-18)

The user approved [LOCALIZATION_0.3.0.md](LOCALIZATION_0.3.0.md) and requested implementation. System mode uses only the primary OS UI language: Japanese for ja, English otherwise. Manual English/Japanese overrides persist per user and switch immediately without replacing the programmer controller. App-owned UI and messages use generated ARB localizations; raw tool diagnostics remain available separately. macOS menus follow the resolved language; OS-owned dialogs may follow OS settings. Windows/Linux setting changes are guaranteed to be re-read after restart, not advertised as live changes. D13's English-only baseline is superseded.

## D33: Catalog keyboard selection

Vendor and full-device dropdowns provide timed case-insensitive prefix navigation, repeated-initial cycling, visible highlight scrolling, explicit Enter confirmation and Escape cancellation. Device text entry retains substring search. Recheck operation locks and catalog membership after popup dismissal. Details: [KEYBOARD_SELECTION_0.3.0.md](KEYBOARD_SELECTION_0.3.0.md).
