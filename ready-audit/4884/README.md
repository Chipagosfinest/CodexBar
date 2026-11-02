# PR 4884 native typography red/green evidence

Product head: `8c311de2545db92f4914629d3f0692a5dbf18acf`.
Main control: `897bff31731bb4b21b105f6e8bf4c32a8a8bf095`.

Native SwiftUI/AppKit measurements on macOS. Source is extracted verbatim from the production `MetricRowHeader` declaration and `MenuHighlightStyle` enum at each commit; the surrounding unrelated views/environment declarations are excluded to keep the target independent of account stores and the full app. Original three PR Swift Testing cases are unmodified on head. SHA256 records cover full original header files and extracted declarations. No Keychain, provider, browser, accounts, or packaged app involved.

| Control | Result |
| --- | --- |
| Head + original tests | 3 tests executed, all pass |
| Main + original tests | Compile failure: main lacks percentText/layoutPercentText; not behavioral red |
| Main + compatible test initializer | 3 tests execute; percentage/countdown width assertions fail; proportional-title test passes |

The compatible initializer joins title and percentage exactly as the pre-change presentation does; assertions and measured values are unchanged. The diff is limited to how the test calls main's existing API. This proves the same numeric-width contract fails on main, while recording the exact-tests API limitation honestly. It does not replace full-target CI or packaged-menu recordings already in the PR.

Reproduce from a CodexBar git checkout on macOS with Swift and Swift Testing installed:

```sh
CODEXBAR_PROOF_REPO="$PWD" python3 /path/to/run-proof.py
```

The script creates tiny independent SwiftPM packages beside itself and asserts executed-test output and assertion-based red. Initial exploratory default-build-system macro failure was rejected; these final receipts use `--build-system native`. No production code or repository worktree was modified.
