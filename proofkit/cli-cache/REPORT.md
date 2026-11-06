# Cursor private cache: runtime RED → GREEN

The baseline loses explicit unified-pool evidence when writing the private CLI cache, causing the actual CLI renderer to display `Total: 20% left` instead of `Weekly: 20% left`. The candidate preserves the non-identifying classification for valid Cursor entries while continuing to redact identity and reject classification for other providers.

| Evidence | Actual result |
|---|---|
| Baseline runtime, new tests only | **25 tests / 2 suites, 6 expected issues**: four Core classification/label assertions and two production CLI renderer assertions |
| Candidate runtime | **64 tests / 6 suites passed**, exit 0, zero issues |
| Overall GitHub run | **FAILURE**, because the RED job's original classifier rejected Swift Testing's parameterized-test summary grammar |

[Authoritative run 42196687231](https://github.com/Chipagosfinest/CodexBar/actions/runs/42196687231), controller `31c038d9ac6ba467469b3ff9b0dd3cbe753b8070`. Base: `ec61c49dd71c3aa6efe33162762ef2164ecfaea1`. Candidate: [exact four-file patch](candidate.patch), SHA256 `be191b9907d86b00916c2a3b5c6d07658c295748c21c655d74b20e18e85fbeee`.

## Original RED and transparent reclassification

[Original RED job 127821671364](https://github.com/Chipagosfinest/CodexBar/actions/runs/42196687231/job/127821671364) exited the test process with 1 after actual expectation failures. Production sources remained baseline bytes. The job then failed its classifier: it expected `Test "name" failed`, while the renderer's two-argument fixture emitted `Test "name" with 2 test cases failed`.

The original [hosted verdict](results/red-verdict.json) is preserved, including its `behavioral_red: false`. Original unmodified log and verdict bytes remain in [artifact 13493111597](https://github.com/Chipagosfinest/CodexBar/actions/runs/42196687231/artifacts/13493111597), with the artifact's configured 14-day retention. A [separate local classification](results/red-reclassified-verdict.json) includes both original input SHA256s, all six exact multiline assertions, the exact failed runtime summary and explanation. [Reclassification script](classify_retained_red.py). This script reads retained output only; no product test was rerun and no GitHub status was rewritten. The future workflow classifier now accepts the parameterized summary grammar.

The expected Core assertions show the cached explicit flag becoming false and the Weekly label/shared pool becoming nil. The actual renderer's unified fixture fails both the required Weekly label and forbidden Total label. Its independent-allowance counterpart passes. Legacy-cache and non-Cursor cache controls pass. There was no compiler/setup failure in this RED.

## Candidate GREEN and provenance

[GREEN job 127821670921](https://github.com/Chipagosfinest/CodexBar/actions/runs/42196687231/job/127821670921) succeeded with 64 tests in 6 suites. [Hosted verdict](results/green-verdict.json), [complete artifact 13492148579](https://github.com/Chipagosfinest/CodexBar/actions/runs/42196687231/artifacts/13492148579).

The full App, Core and CLI modules compile intact. The five existing auth suites remain in the GREEN selection, alongside the entire `CLIUsageCacheTests` suite and new Core cache cases. The tests use actual production private-cache disk writes/loads, provider scoping, and `CLIRenderer` for unified and independent allowances. Imports, renderer implementation and authentication/cookie-selection flows were not replaced.

Independently compared **all 1,445 production Swift hashes** for each job with its declared baseline/candidate input, plus **all six selected test-file hashes** with the frozen product worktree: zero mismatches. [RED provenance](results/red-provenance.json), [GREEN provenance](results/green-provenance.json), [RED source map](results/red-expected-production-source-sha256.json), [GREEN source map](results/green-expected-production-source-sha256.json). Complete harness and candidate patches and original logs are in each artifact.

Independent source review found no blocking issue. Cache construction and decoding retain classification only for Cursor after validating the shared-pool contract. Missing identity is permitted for explicit classification because the private cache intentionally removes identity; an explicitly conflicting provider remains rejected. Legacy weekly shapes and non-Cursor entries cannot establish the flag. Generic `.scoped` behavior and account-source selection remain unchanged.

This proves synthetic disk-cache-to-production-renderer behavior with environment scrubbing, keychain denial and native process containment. It does not claim an installed CLI process reached fallback through a real locked keychain or authenticated a live account. The earlier auth/upgrade report remains bound to its own revisions.

Two accidental redundant own runs were verified and cancelled: cooldown `42196685620` at controller `31c038d9a`, and cache `42196803309` at controller `6006f3e02`. Neither contributes evidence. Successful cooldown `42195208827` and prior auth/dropdown proofs are preserved. No further product runtime was launched to correct this classifier.
