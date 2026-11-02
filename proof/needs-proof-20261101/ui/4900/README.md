# PR 4900 — actual hover names, More action and overflow navigation

Product `818e1e73784f20053912e8a7f59d677c9494e852`; controller `1995eff73794254af76a7136783287b5a6bd2cdf`.

[Successful actual-app run](https://github.com/Chipagosfinest/CodexBar/actions/runs/41375203027) · [controller/workflow source](https://github.com/Chipagosfinest/CodexBar/tree/1995eff73794254af76a7136783287b5a6bd2cdf) · package run `41370526426`.

Fresh unmodified packaged app, synthetic replies and configuration. The first case has eight enabled provider tabs plus Overview and three selected Overview providers. The actual pointer hovered Claude's logo and the native tooltip appeared. All nine switcher names are retained in the recorded accessibility/help fields. More opens a submenu containing About; activating that actual item opens the app's About settings pane. All 11 capture checks passed, and the installed app hash matches the package. Tracked product source delta is empty.

A separate synthetic all-account roster exceeds twelve rows. After scrolling the real menu, More(7) opens the overflow list. Clicking Kimi Code · Synthetic Account10 closes the menu; the next open selects the Kimi tab. The app writes mergedMenuLastSelectedWasOverview=false and selectedMenuProvider=kimi. The actual selected tab and persisted navigation agree.

**Scope:** these synthetic accounts have no successful usage fetch. The selected Kimi page shows HTTP404 from the fixture. This establishes provider-tab navigation, not a working account fetch, selection of that particular stored account, every non-top-level plugin case, or integration with #4899's later compact-line path. It also does not prove every eight-provider Overview roster fits. Those product/integration questions remain separate.

Six original-resolution screenshots were inspected. A native external panel identifies synthetic data and the full product SHA in every screen. No account data is real and no Keychain prompts are used. DNS verification is preflight/sampled, not absolute containment. Only inspected PNGs/logs are published; no movie claim is made.

While the package artifact remains available, reproduce this exact controller with:

```sh
gh run rerun 41375203027 -R Chipagosfinest/CodexBar
```
