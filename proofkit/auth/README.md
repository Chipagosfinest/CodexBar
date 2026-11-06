# Account-boundary hosted proof

Product input: `fc2866c6bd25b1e1f27e01d39e8cd31c76ac83f7`.

The isolated macOS 26 job compiles the full production `CodexBar` App module and its normal package dependencies. Only the `CodexBarTests` source list is narrowed, to these five suites:

- `CursorAccountBoundaryTests`
- `CursorCostAccountBoundaryTests`
- `CursorLoginAccountBoundaryTests`
- Existing `CursorLoginRunnerTests`
- Existing `CursorLoginBrowserRoutingTests`

The three boundary test files are copied without import or implementation edits from the product worktree. The existing runner/router test files come directly from the pinned product revision. The finalized nonblank Manual HTTP 401 cost oracle is included in `CursorCostAccountBoundaryTests` (SHA256 `0e8b2f222e0923559adf9164403e0c33f10b9a04ece2d5f5bf323fa469c643c4`), byte-for-byte matching the test-author-approved source.

The production source tree remains unchanged. Browser launching, account selection, session replacement, and network replies use the tests' synthetic injected seams. This proves production-module behavior exercised by those tests, not a live account login, packaged-app interaction, or release-upgrade journey.

The workflow reuses `Scripts/test_fast.sh`, `test_environment.sh`, and the process-containment runner. Its sole script adjustment retains the disposable hosted test HOME until runner teardown, as in the successful dropdown proof. Keychain access is disabled. All production Swift source hashes, exact selected tests and their hashes, environment details, test logs, exit status, verdict, and complete harness patch are uploaded even on failure.

Root authorized publication after review and the finalized HTTP 401 oracle passed locally. An authorized auth-only push to `proof/20261106-review-regressions` triggers `.github/workflows/auth-account-proof.yml`; the companion dropdown workflow ignores these auth paths so successful dropdown jobs are preserved. The only expected runtime success is all five suites passing with zero exit status and unchanged production/test hashes. Compiler or setup failures are failures of proof, never behavioral red.
