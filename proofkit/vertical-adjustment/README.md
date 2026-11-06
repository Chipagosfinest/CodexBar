# Saved attachment alignment: baseline proof

This baseline-only macOS 26 run compiles the actual production App/Core modules at `5614c2736caf037cd5205151194dd036f205f792`, replacing only the selected `MenuBarUsageTotalTests.swift` with the test-author's frozen oracle, SHA256 `70c3f3129087d9c41663b964a22527a70324b51a90f189db266c57d4ca348c23`.

The new test, `saved vertical adjustment moves every total attachment equally`, covers high contrast on/off and warning on/off, each at saved offsets −3 and +3. It compares actual NSTextAttachment effective baseline (bounds origin plus attributed baseline offset) with the zero-offset output, checks the expected attachment counts, and preserves width and accessibility labels. The ordinary calm template-image path remains a control. Either bounds or baseline attributes may implement the intended adjustment.

The full existing suite runs, with unchanged TestStores, ZaiTokenStoreTestSupport and CodexCredentialFixtures support files. All original tests must pass and the added regression must fail through actual runtime expectations. The harness understands parameterized Swift Testing summaries. Compiler/setup failures do not count as RED. Production source bytes must remain unchanged and selected test bytes must match their declared hashes.

The artifact retains all production Swift hashes, selected test files/hashes, complete harness patch, environment, logs, exit status and verdict. Existing environment scrubbing, keychain denial and process containment remain active; the disposable hosted HOME is retained only for Xcode Metal mounts. This is a synthetic native AppKit component test, not an installed-app screenshot or live-account journey.

This workflow triggers only for its script, frozen test or workflow changes. Prior auth/cache, cooldown and dropdown proof jobs are preserved. A source candidate and GREEN are intentionally deferred until actual RED.

The supplemental test `saved vertical adjustment moves the actual normal contrast leading pixels` measures alpha-weighted pixel centroids at 1×/2×, for normal calm/warning states at ±3 points. An independently drawn translated rectangle calibrates bitmap orientation and point conversion. Both new tests must fail through actual expectations in baseline RED; all original controls must pass.

First attempt42199396599 was compiler-only: the test helper placed `verticalAdjustment` before required `now`. No tests ran and it is explicitly rejected as RED. Original artifact13493033693 and frozen349 test bytes remain preserved, with [verdict/provenance/classification](results/compiler-only-42199396599). This retry corrects only that argument ordering and adds the new pixel oracle; original attachment assertions are unchanged. The actual initializer at baseline was inspected: `now` precedes `verticalAdjustment`. No production source changed.
