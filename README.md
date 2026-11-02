# PR 4902: storage-only flyout refresh

Synthetic data only. No provider requests, account identities, credentials, balances, or personal paths.

## Observed behavior

The local harness opens the production `OverviewProviderDetailMenu` with `NSMenu.popUp`, publishes a synthetic storage total change from 1,048,576 to 2,097,152 bytes while it remains open, then calls production `refreshHostedSubviewMenu`. The provider is unavailable with a fixed synthetic error; the usage-card model is asserted unchanged.

| Code | Initial card | After storage-only update | Card rebuilt |
| --- | --- | --- | --- |
| Before: 0ff1e04c1043ebb549dd0df28f34884141fd3b90 | Storage: 1 MB | Storage: 1 MB (stale) | false |
| After: 67126de6c3ca751742e0fc1c3f9fcc0b7a4fc833 | Storage: 1 MB | Storage: 2 MB | true |

`before/` and `after/` contain captures of the actual production hosted card view during native menu tracking, taken with AppKit `cacheDisplay(in:to:)`. These are **view renders, not desktop screenshots or packaged-app proof**. The harness sets a white capture background so transparent pixels remain readable. Each of the four images was inspected; only synthetic Claude text and storage totals appear. The captures show the card content, not the surrounding menu chrome or physical pointer interaction.

## Regression

`an open flyout refreshes when only storage presentation changes` verifies absent-to-present storage, a changed total, and hiding storage while the provider card model remains unchanged. Each transition must refresh the captured card. A second refresh with unchanged inputs must retain it.

Before: exactly three expected `refreshed !== previous` failures; all six existing flyout tests pass. After: all seven flyout tests pass. The additional local proof method returns immediately unless `STORAGE_PROOF_OUT` is set.

## Reproduction and local limitations

`Harness.swift` is the checked-in test suite plus one local-only native popup proof method. A disposable mirror replaces the normal XCTest-containing test target with a Swift Testing target depending on CodexBar and CodexBarCore. It includes TestStores.swift, ZaiTokenStoreTestSupport.swift, and, for the related suites, StatusMenuHostedSubmenuRefreshTests.swift, StatusMenuCodexCostHistoryRefreshTests.swift and UsageStorePlanUtilizationTestSupport.swift.

Run the same harness against the before and after HostedSubmenus production files. Source `Scripts/test_environment.sh` in Bash with `GIT_CONFIG_COUNT` unset (its secret-key scrub removes inherited GIT_CONFIG_KEY entries). Use isolated synthetic settings; no live provider probes.

```bash
CB_CMD=test ./clt-build.sh -j 4 --filter OverviewProviderFlyoutTests
STORAGE_PROOF_OUT=/tmp/storage-proof CB_CMD=test ./clt-build.sh -j 4 --filter 'synthetic open storage flyout proof'
```

The Mac has Command Line Tools but no full Xcode. Plain `swift build -j 4` was attempted and failed because `actool` requires Xcode. The disposable harness uses `--build-system native`, the installed macOS 26.5 SDK and existing local SwiftUI Entry/Preview macro shims (`clt-build.sh`). Thus local runs establish this production refresh path, not a standard release package. Standard native build/full test coverage is delegated to PR CI.

Plain `make check` encountered local Python/SourceKit setup failures. The unchanged check command is rerun with an installed Python 3.13, `PYTHONDONTWRITEBYTECODE=1`, and `XCODE_DEFAULT_TOOLCHAIN_OVERRIDE=/Library/Developer/CommandLineTools`. No repository tooling was changed.

Validation completed: 23 tests in three suites passed (22 regression tests plus the gated local proof method); `make check` passed, including SwiftFormat, strict SwiftLint (3161 files), portable, locale, JS/TS, packaging and containment checks.
