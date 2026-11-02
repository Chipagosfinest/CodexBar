# PR 4901 accounting regression proof

[Hosted before/after run](https://github.com/Chipagosfinest/CodexBar/actions/runs/41397221320).
Before product: `1d28182bdb63b6a27edcdb91bebf1189a368efea`. After product: `e2d1b1faf970d02bb79bf10366adc51c63594b9d`. Controller: `ab93380d9f878f73f566aefe967ba7b6647e3641`.

The actual debug CodexBar executable is built from each product commit with a temporary early-entry fixture.
The fixture calls the production accounting builder, daily projection and SwiftUI chart, before normal
settings, accounts, providers, network or Keychain initialization. Inputs are synthetic. It fixes November 1,
2026 in UTC and uses a French app-language override for the date projection while macOS uses English. Bar selection is injected
for static comparison; this is not a pointer-interaction recording. The production accessibility strings are
written to JSON and shown beneath each chart; no VoiceOver audio is claimed.

## Run status and teardown boundary

Both test phases and both native screen captures completed. Head passed 99 tests in 6 suites;
baseline failed with 11 expected assertion issues, including attribution, provider qualification and locale.
The raw PNGs and behavior JSON were written successfully before the temporary fixture stalled during
teardown. The run was canceled after retaining those artifacts. `NSApplication.stop` called from a timer
does not stop the event loop; see [Apple's documentation](https://developer.apple.com/documentation/appkit/nsapplication/stop%28_%3A%29).
This is a capture-fixture lifecycle issue, not a product entry-point failure. Full product CI at the exact
head is [green](https://github.com/steipete/CodexBar/actions/runs/41391368168).

Per-phase files preserve the exact captured source. `regenerate/` contains a separate, explicit teardown-only
correction: use normal application termination and bound the parent wait. That correction was not part of
the captured binary and is not claimed as a rerun; it changes neither the view nor the accounting inputs.
The originals, recorded outcomes and product code remain unchanged.

## Before and after

| Case | Before | After |
| --- | --- | --- |
| Provider $2, models $3 + $1 | high $1.50 + fast $0.50 | no model attribution; one standard-shade $2 block |
| Known Claude subtotal plus unpriced requests | exact provider accessibility amount | lower-bound marker retained |
| Known Claude subtotal plus excluded requests | excluded-request qualifier absent | incomplete marker retained |
| Reconciled Codex subtotal plus unpriced routing row | priced high-tier $2 retained | priced high-tier $2 retained |
| Dates | English month names | French app dates |

[Before screen](base/screen.png) · [After screen](head/screen.png).
Raw `behavior.json`, test logs, test exit codes, binary hashes and complete plumbing patches accompany both.
The original screenshots were visually inspected at full resolution before publication; no account values or
personal data were used. The entry and renderer bypass normal fetching/menu-controller startup. Earlier PR
proof separately exercises real pointer movement in the packaged app.

## Accounting intent

Commit `8870914082` and [PR 2643](https://github.com/steipete/CodexBar/pull/2643) retain directly priced Codex
rows beside unpriced routing rows only when priced costs reconcile with the daily stored subtotal. They
continue to fail closed for malformed and inconsistent detail. The chart now uses that shared owner and
keeps the provider amount as an unclassified block instead of rescaling rejected model costs.

## Reproduction and provenance

`regenerate/` preserves the workflow, app fixture and new regression tests, with the documented teardown-only correction. Restore those files on a
temporary proof branch and adjust its push-trigger branch name to rerun. The workflow checks out immutable
product SHAs, copies the same regression tests to both versions, selects the five accounting/chart suites
plus the static provider-architecture test, and uses the existing contained test launcher. It retains the
synthetic test home until disposable-runner teardown: Xcode mounts a read-only Metal toolchain there, and
Python TemporaryDirectory cleanup otherwise fails after passing tests. The complete harness patch is saved.
Full upstream PR CI retains its complete inventory. No permanent workflow/manifest/launcher edits enter the PR.

The baseline must fail the new assertions and pass the architecture gate. Head must pass every selected test.
The app phase adds only the opt-in fixture and entry hook; `fixture.patch` records all tracked deviations,
while `OverviewAccountingProof.swift` records the newly added source. The three changed production files
are unchanged from the respective product commits; `product-source-sha256.json` records their hashes.
`binary-sha256.txt` hashes the exact executable invoked for each capture. Generated file hashes follow in
`SHA256SUMS`; all screenshots and logs remain raw.

The maintainer presentation decision remains outside this contributor fix.
