# Footer native-highlight regression proof

The candidate passed both actual App/Core regressions on Intel macOS: **2 tests in 1 suite, zero issues**, after 14.148 seconds. This proves the bounded controller/delegate contract; it does **not** claim an actual pointer-driven native menu journey. Separate native App UI acceptance remains pending.

- [GREEN run42239701154](https://github.com/Chipagosfinest/CodexBar/actions/runs/42239701154), controller `1f0de2e8003e58452eb912616870a9a36af994cf`, artifact13515855950. Original regression passed7.282s; native-highlight regression passed6.863s. Full actual App/Core build completed732.45s. [Raw log](results/42239701154/green/tests.log), [unchanged verdict](results/42239701154/green/verdict.json).
- [Baseline run42237102523](https://github.com/Chipagosfinest/CodexBar/actions/runs/42237102523), controller `2b593a0865d851605f98d93bd447df98c56cec65`, **workflow FAILED**. Actual build succeeded; original regression passed; new regression failed with exactly3 issues: missing nested callback, same captured card, same captured view. [Original false verdict](results/42239701154/original/red/verdict.json) and [raw log](results/42239701154/original/red/tests.log) remain byte-for-byte unchanged. The classifier additionally demanded a fresh-cache fingerprint failure; that assertion passed because a warm cache does not establish visible card replacement. A [separate corrected classification](results/42239701154/corrected-baseline-classification.json) requires precisely the3 observed failures, original control PASS, exact2-test/1-suite summary, and no infrastructure error. No tests/assertions changed and no baseline runtime rerun occurred.
- [Earlier ARM capacity run42234411509](https://github.com/Chipagosfinest/CodexBar/actions/runs/42234411509) failed to acquire a runner: zero steps/tests, no behavioral evidence. [Original capacity metadata](results/42239701154/prior-arm-capacity/CLASSIFICATION.json). The finite fallback and GREEN evidence apply to **x86_64 macOS26.6.1/Xcode26.6**, not ARM or all architectures.

Exact product baseline is `e8a0cca51036fa8f30362a0710754d812ace34a3`. GREEN uses only the declared23-line production delta in `StatusItemController+UserPlugins.swift`, including disabled-plugin eligibility. All4,405 compiled-input map entries match the actual baseline run except that single source file; all1,446 production source hashes and the same6 selected test hashes were preserved/compared. Actual App/Core modules remain intact, with bounded test selection and declared containment harness changes. Synthetic JS returns42 with zero provider requests; no real accounts or local UI launch.

Frozen hashes:

- Candidate source: `9792aa446f3edd603aa0445ee1c5085b765707a6c62281d5e224086073759524`.
- Regression test: `65125fe154fe846983ae550a6beff83d58860d0c7e90558f00c6b79631243281`.
- Production patch: `574c1c7468735d813b979c1ff2c83963807df36ebee2a5caa229adf28ab3f961`.
- Original artifact ZIP: `53cb100d6fd0d596521bafb7a865a81cc91afcbe0f01aa05af448b0fc5ff1e74` (download/hash pinned; archive itself omitted from this minimal report).
- Original raw log: `a31f5b49c65b31f8838d99b6a91138ac9e5e042b4185a6907ded943d86cff9e2`.
- GREEN raw log: `0d73b236903dc0cbb897480bce9bfb4d4562efda394ed0bd8ba75372dd180eeb`.

[Independent hash receipt](results/42239701154/independent-hash-receipt.json), [source/input comparison](results/42239701154/green/input-comparison.json), [full tracked-input map](results/42239701154/green/expected-tracked-input-sha256.json), [production-source map](results/42239701154/green/expected-production-source-sha256.json), [test provenance](results/42239701154/green/provenance.json), [production patch](results/42239701154/green/candidate-production.patch), [artifact-file hashes](results/42239701154/file-sha256.json). Original selected test bytes and harness patches are retained alongside raw logs; no compiled products are published.
