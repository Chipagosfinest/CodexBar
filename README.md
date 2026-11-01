Current three app-PR recordings and review fixes: [proof2](proof2/README.md). The original notes below are historical.

# Native Mac proof, 2026-11-01

Each PR was fetched into its own detached worktree; main was freshly fetched at 897bff317. Native builds ran on Apple Silicon with CLT Swift 6.4. Product source changes were not pushed.

## CLI behavior

- #4877: actual `dashboard --identity redacted --pretty --timeout 45`, main versus head, unavailable then recovered. A synthetic Claude PTY executable supplied parser input. Valid 25% session / 40% weekly quotas retained; head adds a warning only during unavailable breakdown; provider error stays null.
- #4882: actual `usage --provider codex --source oauth --json`, main versus head, recent / 65-day-old / future cache. Synthetic auth and a loopback OAuth response supplied 10%/20% quota. Main attaches all caches; head attaches only recent. Cache, auth, and config hashes remain unchanged. No real provider credentials or transports used.

## Native menu proof boundary

Real app targets build and run with the opt-in `RealBehaviorProof.swift` fixture. The hook runs before normal settings/account/provider startup. It presents the production `UsageMenuCardView.Model.make` and `UsageMenuCardView` inside an actual AppKit NSMenu. It drives quota, failed-refresh, recovery, and numeral transitions through a local phase file. It does not exercise real provider transport, the full StatusItemController, or user-click routing.

**Actual-screen screenshots are pending. The Mac is locked.** No offscreen render or behind-lock window image is substituted for a display screenshot. Runtime receipts prove process/model transitions only.

App builds use `--build-system native --sdk .../MacOSX26.5.sdk` and local Entry/no-op Preview macro plugins to accommodate this CLT-only host. The native build engine copies Vortex assets without requiring actool. Production menu files are unchanged. The attached patches document the temporary entry hook and focused test target; these changes are confined to disposable worktrees.

Tests run the original focused suites in a temporary target with credential/session isolation, dictionary-backed defaults helpers, Swift Testing framework search paths, and `--disable-xctest`. Counts: main 53, #4881 57, #4883 55, #4884 53, #4877 4, #4882 12 (including six cache-age arguments). These are focused local checks, not a claim of a full suite or current CI status.

Identifiers in published text are absent or redacted. The lock-screen image and all synthetic auth files stay local and are excluded from this branch.
