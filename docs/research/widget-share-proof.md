# Widget share layout proof

Observed 2026-09-16 PT in [macOS proof run 35077951215](https://github.com/Chipagosfinest/CodexBar/actions/runs/35077951215), source `e880687f9dd4ee2ebe262eeb72f54a042eef72c3`. All usage values are synthetic.

Three route tests passed, including data-free URL validation, rejection of unsupported destinations/data, and queued cold-launch delivery. One explicit native XCTest rendered nine production layouts with zero failures. Usage, History, and Switcher bodies use the same family-specific content called by this renderer; the test does not attempt to overwrite WidgetKit's read-only family environment.

The native host simulates 16-point margins around 160 × 160, 360 × 160, and 360 × 380 canvases. The dense fixture includes two quota rows, code-review usage, and three Switcher providers. All nine images were visually inspected. Compact chip labels stay on one line; “Clau…” is intentional truncation with the full provider name exposed to accessibility. No share control or usage row is visibly clipped.

| Layout | Native capture |
| --- | --- |
| Compact Small | [PNG](../../.github/pr-proof/widget-share/share-overview-compact-small.png) |
| History Large | [PNG](../../.github/pr-proof/widget-share/share-overview-history-large.png) |
| History Medium | [PNG](../../.github/pr-proof/widget-share/share-overview-history-medium.png) |
| Switcher Large | [PNG](../../.github/pr-proof/widget-share/share-overview-switcher-large.png) |
| Switcher Medium | [PNG](../../.github/pr-proof/widget-share/share-overview-switcher-medium.png) |
| Switcher Small | [PNG](../../.github/pr-proof/widget-share/share-overview-switcher-small.png) |
| Usage Large | [PNG](../../.github/pr-proof/widget-share/share-overview-usage-large.png) |
| Usage Medium | [PNG](../../.github/pr-proof/widget-share/share-overview-usage-medium.png) |
| Usage Small | [PNG](../../.github/pr-proof/widget-share/share-overview-usage-small.png) |

These captures verify production layout content in an NSHostingView. They do not verify an installed WidgetKit container, wallpaper-dependent rendering, system-supplied margins, or an actual desktop click into a warm/cold app. Those installed-runtime checks remain outstanding, along with the prerequisite menu-sharing PR #3677 and current-head CI.

The URL contains no account, provider, usage, spend, callback, or file data. Opening the preview does not upload or copy an image; Copy Image remains an explicit action in the app.
