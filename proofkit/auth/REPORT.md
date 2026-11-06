# Cursor account-boundary and upgrade proof

Verified: the hosted production-module suite passed **45 tests in 5 suites**, with exit status 0 and unchanged production sources. The released v0.83.0 CLI and candidate preserve the same synthetic settings; stable-written persistence/cache bytes remain readable by the candidate.

## Hosted production App/Core modules

- [Successful run 42191715010](https://github.com/Chipagosfinest/CodexBar/actions/runs/42191715010), controller `9ff82ca08fc974cc9848d876c6f7846ab1d59844`, [complete artifact](https://github.com/Chipagosfinest/CodexBar/actions/runs/42191715010/artifacts/13489544396).
- Product base `fc2866c6bd25b1e1f27e01d39e8cd31c76ac83f7`, plus the explicit selected-test bytes recorded in [provenance](results/20261106/hosted-provenance.json). The final product head `ec61c49dd71c3aa6efe33162762ef2164ecfaea1` contains the finalized HTTP 401 test and has no production-source delta from that base.
- Independently compared all **1,445 production Swift file hashes** and all five selected test-file hashes with the final product worktree: zero mismatches. [Source map](results/20261106/hosted-production-source-sha256.json), [verdict](results/20261106/hosted-verdict.json).
- Host: macOS 26.7.2, Xcode 26.6 (17F113), Python 3.15.2. Full production App/Core modules compiled intact; only the test-target source list was bounded. The artifact retains the entire test-harness patch, selected test files, environment and build/test log.

The five passing suites are `CursorAccountBoundaryTests`, `CursorCostAccountBoundaryTests`, `CursorLoginAccountBoundaryTests`, existing `CursorLoginRunnerTests`, and existing `CursorLoginBrowserRoutingTests`.

The production login runner/router controls establish current `https://cursor.com/login` routing, exact browser pinning for candidate loading, explicit account confirmation, stable-ID distinctions despite shared email, chooser cancellation and forged-selection rejection without session replacement, launch/timeout/cancellation preservation, and durable replacement failure handling. They use synthetic injected browser, session and snapshot seams. These are production-module tests, not a real browser sign-in.

The selected credential tests reject both explicitly blank Manual credentials and a nonblank Manual credential receiving HTTP 401 through the actual outer cost loader, despite available synthetic ambient CSV history. The URLProtocol fixture only handles the exact production Cursor endpoint with its unique synthetic credential; endpoint drift fails closed. Final HTTP 401 fixture SHA256: `0e8b2f222e0923559adf9164403e0c33f10b9a04ece2d5f5bf323fa469c643c4`.

## Released CLI settings compatibility

The actual released arm64 v0.83.0 CLI archive matches its owner-published checksum. [Checksum record](results/20261106/released-cli-checksum.json), [release](https://github.com/steipete/CodexBar/releases/tag/v0.83.0).

Released and candidate CLIs each ran `--version`, `config validate --json`, and `config dump --json` in isolated fresh processes against the same synthetic configuration. Every command exited 0, normalized configuration dumps match, and the configuration SHA256 remained unchanged. No provider fetch ran. [Exact commands, binary hashes and redacted output](results/20261106/released-cli-results.json).

## Stable-written persistence and cache compatibility

The [same driver](results/20261106/cache-driver.swift) compiled against actual stable Core plus `CloudSyncPersistence.swift` at `348e2fa8d36ae8e452739ca07a79e83ab9d25e98`, then against candidate Core plus the corresponding unchanged App persistence source. [Pinned source hashes](results/20261106/cache-inputs.json) were independently compared with their Git objects.

The stable encoder created three fleet snapshots and three CLI cache cases. Stable and candidate both loaded those exact original bytes. Account identity, independent 20%/80% windows and timestamps survived; every cache file hash remained unchanged after both reads. [Results and before/after hashes](results/20261106/cache-results.json), [synthetic original files](results/20261106/synthetic-cache).

| Case | Age | Stable cache hit | Candidate cache hit |
|---|---:|---:|---:|
| Recent | 90 seconds | true | true |
| Expired | 7,200 seconds | false | false |
| Future | −3,600 seconds | false | false |

The positive recent-cache hit establishes continued attachment, alongside rejection of expired/future data. Stable inferred a unified weekly pool from the legacy seven-day shape; candidate preserves the separate quota values and stops inferring shared allowance without provider evidence. This is the intended behavior change. CLI cache identity stripping remains its existing privacy contract.

This establishes actual released-CLI settings compatibility and production-source persistence compatibility. It does not establish a packaged stable-App upgrade, CloudKit service interaction, installed-App user journey, or live provider authentication. No offline shipped-CLI cache attachment is claimed. Binaries, home directories and unrelated local files are excluded from this report.

Report payload hashes: [file-sha256.json](results/20261106/file-sha256.json). Reproduction uses the opt-in evidence workflow; product CI remains separate. The completed dropdown regression run is preserved without rerunning it for this auth-only evidence.
