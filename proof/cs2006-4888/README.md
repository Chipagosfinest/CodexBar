# PR 4888: test-only cleanup proof

Product commit before: `073d0643a51c7dc5e14f3b3f7f27afa27dda3f47`.
Product commit after: `10fe499a3726cda7e8fe6867f6be378d80b548d1`.
Only two low-value tests were removed (14 lines); product sources, assets, and workflows are unchanged.

## Real behavior

[Hosted run 41389353923](https://github.com/Chipagosfinest/CodexBar/actions/runs/41389353923) packaged each exact, unmodified product commit on disposable macOS 26 runners. The existing driver installed each app, verified its executable hash, opened Share Usage Snapshot through the real menu, cleared the clipboard, and clicked Copy Image in light and dark appearance. Every runtime assertion passed on both commits: copy feedback appeared and the fresh pasteboard contained a 1200×630 PNG.

The screenshots below were inspected at original resolution. All data is synthetic: local transcripts and loopback provider replies; no real accounts or credentials were used. The screen banner identifies the product SHA and fixture kit. The clipboard PNGs are original, unaltered app exports. Selected screenshots and exports only are published; recordings are not used as evidence here.

| Appearance | Before screenshot | After screenshot | Before original PNG | After original PNG |
| --- | --- | --- | --- | --- |
| Light | [Image copied](before/s3-light-after-copy-screen.png) | [Image copied](after/s3-light-after-copy-screen.png) | [PNG](before/s4-light-clipboard.png) | [PNG](after/s4-light-clipboard.png) |
| Dark | [Image copied](before/s3-dark-after-copy-screen.png) | [Image copied](after/s3-dark-after-copy-screen.png) | [PNG](before/s4-dark-clipboard.png) | [PNG](after/s4-dark-clipboard.png) |

Clipboard PNG byte equality before/after: {"light": true, "dark": true}. No visible change was observed, so the PR body's screenshots were left unchanged.

## Tests and check status

- Before log: all 37 selected tests in four suites passed. Actions marked the enclosing step/job cancelled at its 55-minute deadline; the complete test summary and all runtime artifacts were retained by the always-run upload. This is not represented as a green Actions job.
- After: all 35 selected tests in four suites passed; the Actions job completed successfully.
- [Exact-head upstream CI](https://github.com/steipete/CodexBar/actions/runs/41387040934): green, including full macOS tests, Linux arm64/x64/musl builds, lint, and security. Pre-cleanup upstream CI was also verified green.
- Local repository check recipe (`Scripts/lint.sh lint`, the recipe used by `make check`) passed with existing Python 3.13, bytecode disabled, and SourceKit's framework path set inside the shell. SwiftLint reported zero violations across 3162 files. System `make check` attempts encountered local Python/SourceKit discovery limitations; no repository files were changed to bypass them.

This cleanup removes two tests as explicitly permitted by the review. It introduces no behavioral fix for a meaningful failing-base/passing-head regression. The remaining real-behavior tests and app path pass before and after; no ceremonial replacement assertion was added.

## Reproduction and provenance

`workflow.yml` and `proofkit/` preserve the temporary harness. Push the workflow on a disposable evidence branch, with its trigger adjusted to that branch; it checks out the two pinned product SHAs, runs `ARCHES=arm64 CODEXBAR_SIGNING=adhoc ./Scripts/package_app.sh release`, drives `proofkit/s4888.py`, then runs `source Scripts/test_environment.sh; swift test --no-parallel --filter ShareStats`. No fixture code is compiled into the app. The driver uses synthetic transcripts and loopback TLS replies on a disposable runner, bypassing real provider infrastructure while exercising normal menu, model, renderer, preview, and export code.

The first attempt's wrapper placed a read-only Xcode Metal-toolchain mount inside a temporary build home; Python cleanup failed. The final harness uses direct Swift Testing with repository test isolation. See per-side source/binary hashes, runtime checks, copy results, resolver sampling, and test logs. `SHA256SUMS.json` records file integrity. Temporary proof branches are removed after publication. The maintainer's product decision remains untouched.
