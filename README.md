# CodexBar design PR screenshots

Synthetic fixtures rendered from production `UsageMenuCardView` through `NSHostingView`, using a fixed date, en_US_POSIX locale, English strings, and light/dark appearances. Single cards are 310 points wide; the tabular-digit comparison contains three cards. PNGs are 1x offscreen renders.

`manifest.json` records source commits, dimensions and content hashes. `main` is the before-state; the other folders are individual branch after-states. The email is a fixture, dev@example.com. No live provider probes, browser cookies, or Keychain reads were used.

The local machine has Command Line Tools rather than full Xcode. Rendering used the macOS 26.5 SDK plus local @Entry and no-op #Preview macro shims. Production Swift sources were unchanged; a temporary Swift Testing target compiled selected existing suites and the renderer. The copied testSettingsStore helper defaults to InMemoryUserDefaults, preventing Foundation defaults search-domain fallback. Full macOS XCTest is verified separately by each PR's CI.

The renderer source is in `evidence/RedesignProofTests.swift`. To reproduce with full Xcode, use a new disposable worktree at the corresponding source SHA, copy the renderer into `Tests/CodexBarTests`, source `Scripts/test_environment.sh`, and run `CODEXBAR_DISABLE_KEYCHAIN_ACCESS=1 CODEXBAR_REDESIGN_PROOF_DIR=/tmp/codexbar-proof swift test --filter RedesignProofTests`. No renderer or images are added to the PR branches.

These images demonstrate fixture-driven SwiftUI rendering. Still frames do not establish live update timing, live-account freshness, or interaction in an open NSMenu.
