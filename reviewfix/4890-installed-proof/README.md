# PR 4890 installed WidgetKit proof

Product: `6f97fb9d7e2ebe9855bbd344b8092395c351d43b`. Package build: `4b871d2777a370888e109a62490af063c7dec902`. UI controller: `f7382a1ea7640c0cbb310ed4063cf9e4c5bae44c`.

[Full app/extension package build](https://github.com/Chipagosfinest/CodexBar/actions/runs/41346842491) · [Successful installed-host run](https://github.com/Chipagosfinest/CodexBar/actions/runs/41349033025).

The full debug app and nested WidgetKit extension were built using `Scripts/package_app.sh debug`, installed in `/Applications` on a disposable hosted macOS runner, signature-verified, and registered with LaunchServices/pluginkit. XCTest used the real system widget gallery to install a Switcher and resize it to systemLarge (360x360). Both test stages executed one passing test, with zero failures.

The temporary entry point bypasses live provider fetching and normal UsageStore startup/publication. It calls the unchanged production `UsageStore.widgetTopModels`, creates synthetic provider entries, then uses production `WidgetSnapshotStore.save/load`, the real entitled app-group container, selection store and `WidgetCenter.reloadAllTimelines`. Production extension timeline providers and views are unchanged. No NSHostingView renderer is used for these screenshots.

| State | Daily tokens / cost | Incomplete requests | Decoded models | Host result |
| --- | --- | --- | --- | --- |
| Complete | 100 / $10 | 0 | 2: alpha 80%, beta 20% | Model shares |
| Incomplete | 100 / $10 | 1 | 0 (`topModels == nil`) | 14-day chart |

All 14 days retain matching model/day totals. The incomplete fixture changes only incomplete-request metadata on the final day. After the complete capture, the runner shell changes the fixture input; the original running app's timer computes and publishes the incomplete snapshot. The installed widget stays in place. The workflow independently asserts both transport reports before the second host test.

The images were opened at original resolution and reconciled with both JSON reports. They show synthetic usage and default disposable-runner system widgets; no personal account details, credentials, IPs or private endpoints were present. A runner background-activity notification overlaps part of the header, while model rows, chart, totals and provenance banner remain visible. `provenance.json` records narrow per-image claims.

`installed-binary-hashes.txt` matches `binary-hashes.txt` from the package build. `provenance.json` also verifies the aggregation, snapshot transport and widget sources byte-for-byte against the product SHA. Full temporary deltas are in `package-fixture.patch` and `ui-controller.patch`; they are separate from the product PR.

Rebuild and reproduce (no accounts required):

```sh
gh workflow run widget-desktop-smoke.yml -R Chipagosfinest/CodexBar --ref proof/pr4890-installed
```

While the saved package artifact exists, a UI-only repeat uses `-f package_run=41346842491`. These are fixture-driven captures, not byte-deterministic goldens.

The regression red/green excerpts are from a CLT-only isolated oracle compiling the exact production aggregation/ranking/checked-sum bodies with inert report containers (15 tests). The positive incomplete-count cases fail before the guard and pass after it; nil/zero remain accepted. Full product test coverage is provided by PR CI. Local `make check` passed, including strict lint across 3161 Swift files.

The maintainer/Alec decision about replacing the large Usage chart remains open. This proof does not decide product direction.
