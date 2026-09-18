# v0.3.0 catalog keyboard selection

Date: 2026-09-18

The vendor selector and the full device list opened by its arrow provide the same keyboard navigation on macOS, Windows and Linux. A fresh initial searches from the start of the list. Repeating that initial within 800 ms cycles matching entries and wraps; different characters within the timeout form a case-insensitive prefix. No match leaves the current highlight unchanged. Digits are valid prefixes for IC part numbers. Modified shortcuts are not interpreted as catalog text.

Arrow keys move the highlighted row, Home/End select the first/last row, Enter confirms, and Escape or an outside click cancels. The popup is anchored to its opener and builds only visible list rows. Keyboard movement scrolls the highlighted row into view. Selection is unchanged until confirmation, and the caller rechecks operation locks and catalog membership after the popup returns.

The device text field retains substring search and its own autocomplete keyboard behavior. It does not intercept text entry as list navigation. The arrow always opens the complete current vendor list even when a device is already selected or the text field contains a query.

Verification covers repeated initials and wrapping, prefix timeout, unmatched and modified keys, scroll-to-match in a catalog-sized list, numeric/device selection, Enter/Escape, substring search, and operation locking while a popup is open. Existing localization and programmer safety tests remain part of the regression suite.

## Validation

Static analysis passed and all 79 Flutter tests passed, including six catalog keyboard-selection widget tests. Text-search submission is tested through the platform text-input Done action; popup navigation uses raw keyboard events. Existing controller and minipro safety tests remain passing. Windows/Linux native interactive keyboard behavior has not yet been checked in this task.
