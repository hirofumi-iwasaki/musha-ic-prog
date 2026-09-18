# v0.3.0 UI localization design

Date: 2026-09-18
Status: user-approved baseline; implementation completed locally, cross-platform interactive acceptance pending.
Branch: `release/0.3.0`, created from merged `main` at `667fc400e89e941c8949e230e46e4fc31026d7b5`.

## Behavior

Provide English and Japanese throughout the application-owned interface. The initial selection is System. Resolve the FIRST OS-provided preferred locale only: `languageCode == 'ja'` selects Japanese; every other language, absent locale, C/POSIX, or unsupported value selects English. Country/region, keyboard layout and time zone do not select the UI language. Japanese with any region selects Japanese. `[fr_FR, ja_JP]` must resolve to English, not Japanese; Flutter's default best-supported-language search does not implement this rule, so use explicit resolution.

Add a visible language dropdown to the top controls, with stable native-language choices `System / システム`, `English`, `日本語`, and a bilingual label `Language / 言語`. Wrap the control row on narrow windows. Choices remain recognizable regardless of the current language. Manual changes update the Flutter UI immediately without reconnecting the programmer or reconstructing the operation controller. Save `system`, `en`, or `ja` in per-user preferences, never in the installation directory; load before the first frame to avoid an English flash. Missing/invalid preferences fall back to System. A storage failure must not prevent startup or the in-memory selection, and should give a localized save-failure notice.

Manual language overrides OS changes until System is selected again. Observe Flutter locale notifications in System mode; restarting the application is the guaranteed way to pick up changed OS settings across all desktop targets. Avoid replacing Flutter's PlatformDispatcher callback directly; use WidgetsBindingObserver/didChangeLocales or MaterialApp's locale resolution callback. Switching language never changes input/readout bytes, chosen IC, confirmation validity, USB state or running operations.

## Platform investigation

Reviewed the actual pinned Flutter engine/framework source at revision `9584c6713b324636289d067944a46fd6b49df14b`, matching current CI, as well as platform documentation. These are source-level findings, not completed tests of the localized application on all operating systems.

| Target | Source of Flutter locale list | Changes during execution and caveats |
| --- | --- | --- |
| macOS ARM64 | `NSLocale.preferredLanguages` in `FlutterEngine.mm:sendUserLocales` | Engine observes `NSCurrentLocaleDidChangeNotification` and sends locales again. OS/app-language changes may require relaunch. Respect the effective app preference reported by macOS, including per-app overrides; test these explicitly. Register en/ja in bundle localization metadata and localize app-owned native menu strings. |
| Windows x64 / ARM64 | `GetThreadPreferredUILanguages(MUI_LANGUAGE_NAME \| MUI_UI_FALLBACK)` in `system_utils.cc`; `SendSystemLocales` during engine startup | UI-language preference/fallback list, not numeric/date regional format or keyboard. Pinned engine source has startup dispatch and no additional production call to `SendSystemLocales`; do not promise live OS-language updates. Relaunch after the required Windows sign-out/restart when changing display language. Both architectures use the same implementation. |
| Linux x64 / ARM64 | `g_get_language_names()` in `fl_engine.cc:setup_locales` | GLib consults LANGUAGE, LC_ALL, LC_MESSAGES, LANG in that order for the first set variable. LANGUAGE can contain ordered colon-separated entries. Flutter initializes locales during engine startup. Desktop launch and shell launch may inherit different environments; changing a terminal variable cannot alter an already running process. Relaunch with the desired session environment; install a Japanese font if absent. Both architectures use the same implementation. |

Do not use `Platform.localeName` as the sole cross-platform decision source; use the Flutter UI locale list. Preserve the existing minipro child-process `LC_ALL=C`/`LANG=C` settings: these stabilize CLI parsing and must not be applied to the parent application's UI environment.

## Implementation structure

- Add `flutter_localizations` and Flutter `gen-l10n` with English/Japanese ARB resources, stable semantic keys, descriptions and typed placeholders. Use English as the catalog template/fallback. Localize Material/Cupertino widget text as well as app text.
- Introduce a small LanguageController (System/English/Japanese) separate from ProgrammerController; persist via the maintained cross-platform shared_preferences API. Serialize writes or otherwise prevent rapid choices from saving out of order. Test with an injected preference store.
- Route both normal startup and catalog-load-failure UI through the same localization shell. Rebuild localized labels from current locale; do not cache already-translated snapshot metadata.
- Translate toolbar controls, vendor/device hints, binary viewer labels and empty states, diff navigation, status bar, tooltips, accessibility labels, file errors, operation phases and all confirmation dialogs/warnings.
- Controller/backend messages currently contain English strings. Introduce typed message identifiers and parameters for app-owned messages and translate at presentation time. Do not match or replace English sentences to infer an error type. Preserve raw minipro/OS diagnostic text as a clearly labeled technical detail with a translated summary.
- Do not translate programmer/device/vendor identifiers, file names, raw binary data, hashes, addresses, CLI tokens or protocol values. Keep hex/ASCII formatting stable across languages.
- Use placeholders for target/capacity/address/count and separate complete sentences for plural/conditional forms; do not concatenate grammar fragments.
- Keep OS-owned file picker chrome under OS control. An in-app override can localize app-supplied picker labels, but cannot promise that every native OS dialog changes immediately. Document this boundary in both READMEs. App-owned macOS menu text requires a native localization path; include it in the acceptance checklist rather than declaring Flutter localization sufficient.
- Advance version to 0.3.0+4 during implementation and retarget the branch-triggered five-platform workflow to release/0.3.0. Do not create a tag or publish a release until requested.

## Acceptance tests

1. Resolver: ja, ja_JP, ja_US -> Japanese; en_US, fr_FR, zh_CN, C/POSIX, empty list -> English. `[en_US, ja_JP]` and `[fr_FR, ja_JP]` -> English. Region JP with language en -> English.
2. Manual choice overrides locale, updates existing widgets immediately, survives restart, and System restores current detected language. Corrupt/missing preferences and failed/out-of-order persistence are handled.
3. Locale notifications change System mode only. A language change preserves controller identity, input/readout data, target selection, progress and pending confirmation. Dialog warnings remain complete and correctly localized.
4. Widget tests cover toolbar, status bar, empty/full viewers, operation success/failure, physical-write confirmation and startup catalog failure in both languages. Test minimum window size and increased text scale; no overflow or clipped Japanese warnings.
5. Preserve all existing IC safety and backend tests. Generated resources have matching keys/placeholders and no missing translations.
6. macOS packaged app: Japanese/English preferred language, non-Japanese primary with Japanese secondary, per-app language override, menu and native file picker, manual switch and saved preference.
7. Windows x64 and ARM64: Japanese/English display language independently of regional format and keyboard; relaunch after settings change; manual switch/restart; dialogs.
8. Ubuntu 22.04/24.04 x64 and ARM64: launch with LANGUAGE=ja:en, LANGUAGE=en:ja, LANGUAGE=fr:ja, LANGUAGE unset with LANG=ja_JP.UTF-8, and C locale. Check launch from desktop as well as shell and Japanese font rendering.
9. CI runs resolver/widget/backend tests and builds all five targets; Linux environment tests can run under Xvfb. CI build success alone does not establish interactive OS-language behavior on Windows/macOS. Record real-machine results separately.

## References

- [Flutter internationalization](https://docs.flutter.dev/ui/internationalization)
- [Flutter locale change notifications](https://api.flutter.dev/flutter/dart-ui/PlatformDispatcher/onLocaleChanged.html)
- [Pinned macOS engine](https://github.com/flutter/flutter/blob/9584c6713b324636289d067944a46fd6b49df14b/engine/src/flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine.mm)
- [Pinned Windows language lookup](https://github.com/flutter/flutter/blob/9584c6713b324636289d067944a46fd6b49df14b/engine/src/flutter/shell/platform/windows/system_utils.cc)
- [Pinned Windows engine](https://github.com/flutter/flutter/blob/9584c6713b324636289d067944a46fd6b49df14b/engine/src/flutter/shell/platform/windows/flutter_windows_engine.cc)
- [Pinned Linux engine](https://github.com/flutter/flutter/blob/9584c6713b324636289d067944a46fd6b49df14b/engine/src/flutter/shell/platform/linux/fl_engine.cc)
- [Microsoft GetThreadPreferredUILanguages](https://learn.microsoft.com/en-us/windows/win32/api/winnls/nf-winnls-getthreadpreferreduilanguages)
- [GLib get_language_names](https://docs.gtk.org/glib/func.get_language_names.html)

## Implementation and validation record (2026-09-18)

- Implemented version 0.3.0+4 on release/0.3.0. No new commit, tag, PR or Release is created by this implementation task.
- 164 English/Japanese message keys in `lib/l10n/resources/app_en.arb` and `app_ja.arb`; generated output in `lib/l10n/app_localizations*.dart`. Regenerate with `flutter gen-l10n` (also performed by Flutter dependency/build tooling). `l10n.yaml` is included in matching source packages.
- LanguageController loads shared_preferences before startup, defaults to System, serializes writes and reports load/save failures. LocalizedApp explicitly resolves the current WidgetsBinding platform locale list and observes didChangeLocales. Explicit resolution fixes the tested stale-language case when returning from a manual override to System.
- App-owned operation messages now carry semantic UiMessage values alongside compatibility/debug English text. Raw backend diagnostics are available in the localized Technical details dialog. USB commands, eligibility checks, input snapshots and programming safeguards are preserved.
- Localized both normal and catalog-failure startup UI, viewer metadata, selection/status messages, confirmations and safety warnings. Cached snapshots retain origin enums, not translated labels. Physical-operation dialog labels are resolved inside their builder so open dialogs update when locale changes.
- macOS declares en/ja localizations and receives resolved language over `mushagaeshi/language` / `setLanguage`. Tagged menu items and their submenu titles update together. OS-inserted items and native file-picker chrome remain controlled by macOS.
- Static analysis passed; full regression suite passed 73 tests. Following final text/diagnostic refinements, the focused confirmation/catalog tests (3) and minipro tests (16) passed again. No missing translations were reported.
- macOS ARM64 debug build passed. Interactive checks on this Mac verified Japanese System startup, immediate English/Japanese switching, saved Japanese selection after a normal quit/relaunch, Japanese menu headings and contents, and return to System. The test preference was restored to System and the test app was closed.
- This was a UI test using the development build; no IC read/write operation was performed. Windows x64/ARM64 and Linux x64/ARM64 interactive locale tests remain pending, as do OS-setting changes/per-app-language permutations beyond the local test and full release packaging. The workflow now targets release/0.3.0 but has not been dispatched for these uncommitted changes.
