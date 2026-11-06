# Packaged synthetic Overview chart proof (not yet executed)

This is a proof-build overlay for exact #4901 product
`c16893bbe515695c74a5c7d594b083ce641c3d20`. It is NOT a proposed product feature.
The product branch and evidence checkout have not been changed by this scaffold.

## What it exercises

A DEBUG CodexBar.app enters the adapter before `CodexBarApp.init`, using the existing
`--menu-layout-proof` early-startup pattern. It creates the real
`StatusItemController`, native `NSStatusItem`, production merged Overview menu, and
production `OverviewSpendSummaryCardView`/`OverviewStackedSpendChart`.
Actual `UsageStore.publishTokenSnapshot` owners receive synthetic history:
yesterday Claude unknown, Codex $0; today Claude $2, Codex $3. The actual controller
builds its dashboard from those store publications. Setup independently asserts
known-day $5, stacks $2/$3, daily shares 40%/60%, and both range shares nil.

These assertions prove the seeded production data path only. Real UI acceptance
requires opening the actual status item and moving the mouse over/off today's
bar; model assertions alone do not establish what the user saw.

## Host overlay and build (proof owner only, after current CI terminates)

1. Create a NEW disposable checkout at the exact product SHA. Do not use the
   product worktree or a dirty source checkout. Copy this scaffold to the host.
2. Run:

   ```sh
   python3 prepare_overlay.py \
     --apply-to-disposable-copy /absolute/disposable/chart-proof-checkout \
     --manifest-output /absolute/evidence/chart-overlay-manifest.json
   ```

   This refuses wrong HEAD/dirty trees (including manifests and build scripts); it adds only
   `Sources/CodexBar/PackagedMenuProof.swift` and one declared early call in
   `CodexbarApp.swift`. Every other source file must hash-identically to product. The manifest also records all tracked inputs before/after, including Package.swift, lockfiles and build scripts.
3. In that disposable checkout, use the existing packaging entry point exactly:

   ```sh
   CODEXBAR_SIGNING=adhoc ./Scripts/package_app.sh debug
   ```

   The script accepts debug/release as its first argument; debug selects bundle
   ID `com.steipete.codexbar.debug`, empty Sparkle feed and no automatic checks.
   Adhoc signing avoids querying signing identities/Keychain. It builds the host
   architecture by default (optional `ARCHES=arm64` is supported) and writes only
   that checkout's `CodexBar.app`; full Xcode/xcodegen is required for WidgetKit.
   Do not install/copy it over another app. Use a clean hosted GUI session with
   no other CodexBar process. The adapter uses DisabledUpdater. Verify DEBUG and
   keep overlay manifest, build log, toolchain versions, bundle Info.plist and
   `shasum -a 256 CodexBar.app/Contents/MacOS/CodexBar`.
4. Launch the proof app executable DIRECTLY with the following child environment
   already present (before any Swift static initialization). Values must name
   new disposable directories owned by this proof run:

   ```text
   SWIFT_TESTING=1
   CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS=1
   CODEXBAR_TEST_CODEX_FILE_ISOLATION=1
   CODEXBAR_TEST_SESSION_FILE_ISOLATION=1
   PACKAGED_CHART_PROOF_PRODUCT_SHA=c16893bbe515695c74a5c7d594b083ce641c3d20
   PACKAGED_CHART_PROOF_ROOT=/absolute/disposable/runtime-root
   PACKAGED_CHART_PROOF_OUTPUT=/absolute/evidence/runtime
   HOME=/absolute/disposable/runtime-root
   CFFIXED_USER_HOME=/absolute/disposable/runtime-root
   XDG_CONFIG_HOME=/absolute/disposable/runtime-root/.config
   CODEXBAR_CONFIG=/absolute/disposable/runtime-root/config.json
   CODEX_HOME=/absolute/disposable/runtime-root/codex
   ```

   Remove `CODEXBAR_ALLOW_TEST_KEYCHAIN_ACCESS`,
   `CODEXBAR_TEST_CODEX_FILE_FIXTURES`, and unrelated provider credential env
   variables from the child environment. Pass only `--packaged-chart-proof`.
   No local app launch was performed when preparing this scaffold.

## Observable acceptance

- Verify `runtime-receipt.json` appears and identifies the exact product SHA,
  synthetic setup and all independent assertions. Both blocked HTTP requests
  and forbidden provider refreshes must remain zero.
- Click status item with accessibility identifier
  `codexbar-packaged-chart-proof`. This is the real controller's merged menu,
  populated through `populateMenu`; no screenshot-only replacement view is used.
- Capture the open Overview showing range shares **Unknown** for both providers.
- Move to today's rightmost chart bar. Capture total **$5**, Claude **40%**,
  Codex **60%**. Move off the chart and capture Unknown range shares again.
- Repeat under light/dark macOS appearance without leaving this proof app. Record
  real pointer actions and screenshots/video with product/overlay identities.
- Do not click provider actions, refresh, account activation, external links or
  Settings. Quit via the existing menu when done; keep raw evidence and receipts.

Menu-refresh work is disabled. Consequently `openMenus.count` is intentionally
zero even during tracking; its production registration is conditional on refresh
being enabled. UI screenshots/tracking behavior, not that count, prove the menu
was open. The receipt explicitly records this limitation.

## Auth/privacy boundaries

- Test safety mode is REQUIRED before SettingsStore static initialization. HOME
  alone does NOT isolate macOS CFPreferences. `SettingsStore.isRunningTests`
  prevents app-group migration/plugin discovery and LaunchAtLogin writes.
- In-memory defaults contain migration-complete/keychain-denied policy BEFORE
  SettingsStore init. Config/token accounts are disposable; credential stores
  return only nil and never access Keychain. `UsageStore.startupBehavior.testing`
  avoids startup provider work, cache hydration, version detection and timers.
- Status/web/agent/session/storage discovery is disabled. Menu refresh is off.
  Provider and cost loaders fail immediately if invoked. A process-local URLProtocol
  rejects every HTTP(S) request; the receipt records any attempted request.
- Only synthetic provider names, quotas, dates and dollar amounts are supplied.
  No real accounts, credential files, cookies, browser applications or sign-in.
- Cost display is enabled to show the seeded chart; automatic cost loading is not.
- This proves a packaged app's real status-item/root-menu journey under a
  proof-only synthetic startup. It does NOT prove ordinary shipping startup,
  live provider retrieval, auth, installation/upgrade, or production cloud sync.

## Current verification / next gate

The Swift adapter has format, syntax-parse and strict-lint checks. The actual
App target still needs a hosted full compile before launch. This machine's local
SDK/toolchain mismatch prevents treating parse as typecheck. In particular the
host must verify protocol conformances, initializer labels and the final root
menu `overviewSpendSummary` assertion. Stop on setup/compiler errors and retain
logs; do not count them as behavioral RED or as UI acceptance.
