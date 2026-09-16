# minipro同梱ライセンス調査

調査日: 2026-09-16
対象: https://gitlab.com/DavidGriffith/minipro
確認commit: `cae74c0607077d6260b24995f5e4c0d0b66a6a2e`
これは調査対象revisionであり、製品に採用する版の決定ではない。

## 結論

minipro本体とinfoic.xmlはGPL-3.0-or-laterの表示を確認した。
GPL条件を満たしてmacOSアプリに同梱・再配布できる。
本アプリもGPL-3.0-or-laterとする現在の方針と整合する。
外部プロセス方式でもminipro自体の配布義務はなくならない。

## 一次資料の確認結果

- `LICENSE`: GPLv3本文。
- `src/minipro.h`、`src/database.c`: GPL version 3 or any later versionの明示。
- `infoic.xml`: ファイル先頭に同じGPL-3.0-or-laterの明示。
- `debian/copyright`: パッケージのGPL-3+表示。
- `README.md`: 一部のロジックIC試験コード・データはMITライセンスの他プロジェクト由来と記載。
  個別の第三者表示を残す必要がある。単一のGPL表示だけで第三者表示を省略しない。
- `Makefile`: libusbとzlibへの依存を確認。
- `README.md`: T56のFPGA bitstream（algorithm）は公式XGecuソフトウェア由来であり、著作権上の理由でリポジトリに含められないと明記。

固定revisionの確認先:
https://gitlab.com/DavidGriffith/minipro/-/tree/cae74c0607077d6260b24995f5e4c0d0b66a6a2e

## このプロジェクトの配布方法

1. `.app`に固定版minipro実行ファイル、必要なDB・依存ライブラリーを同梱する。
2. GPL本文、元の著作権・無保証表示、第三者ライセンスを配布物に含め、About / Licensesから確認できるようにする。
3. 同じリリースのダウンロードページに、バイナリーに正確に対応するソースアーカイブを置く。
   本アプリ、minipro、同梱するlibusb等の必要なソース、DB、変更パッチ、ビルド・導入スクリプトを含める。
   上流トップページへのリンクだけで済ませない。利用者が再ビルドできる資料を維持する。
4. miniproを改変した場合は変更内容・日付を明示し、そのソースも提供する。
5. GPLで認められる改変・再配布を禁止する追加規約は設けない。
6. 同梱版のlibusbのLGPL条件とzlib等の条件を確認する。ライブラリーの改変・再リンクが可能なソースと手順を提供する。
   署名付き配布とは別に、利用者が改変版をローカルビルド・署名して実行する手順も用意する。

GPL第4〜6条、特にオンライン配布の第6条(d)を基準にする。
ソースの同時ダウンロードを強制する必要はないが、対応ソースを取得できる場所の明示と提供継続は配布者の責任となる。

## T56関連データの扱い

T56用のXGecu由来アルゴリズムデータをminipro本体と同じGPLだとみなさない。
0.1.0はTL866CSを対象とし、T56用algorithm.xmlやメーカーのソフト・firmwareを同梱しない。
将来T56を追加する際は、権利者から再配布許諾を確認するか、ユーザーが適法に取得したデータの取込み方式を検討する。
自動ダウンロード機能が上流に存在することは、当アプリの再配布許諾の根拠にはしない。

## 残る確認

今回確認したのは公開ソースのライセンス表示と配布条件であり、全ファイルの権利由来の監査ではない。
採用版確定後に同梱ファイル一覧と個別表示、依存物、ビルド成果物を照合して最終確認する。
ライセンス上の同梱可否と、実機の安全性・対応型番の確認は別のゲートである。

## 参照

- GPLv3本文（OSI掲載）: https://opensource.org/license/gpl-3.0
- minipro README: https://gitlab.com/DavidGriffith/minipro/-/raw/master/README.md
- libusb COPYING: https://raw.githubusercontent.com/libusb/libusb/master/COPYING
