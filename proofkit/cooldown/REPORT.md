# Cooldown isolation: verified

[Hosted run 42195208827](https://github.com/Chipagosfinest/CodexBar/actions/runs/42195208827) passed **59 tests in 9 suites**, exit 0, against `20ada8abf0e4e2267aaa8c7cc9cf891cdf866838` plus the exact [candidate patch](candidate.patch), SHA256 `df23345819454907d9eb78526e7808d24757e44c53644a83e89d478c0eab16f3`. Controller: `503d80bab8ff39f81268a753e6a70cba73305dcb`. [Full artifact](https://github.com/Chipagosfinest/CodexBar/actions/runs/42195208827/artifacts/13491809147).

All 1,445 expected production Swift hashes and all 13 selected test/support-file hashes independently match the frozen product worktree. [Verdict](results/verdict.json), [provenance](results/provenance.json), [production map](results/expected-production-source-sha256.json).

The [original baseline CI failure](https://github.com/steipete/CodexBar/actions/runs/42178719099/job/127763212192) ran at `05c210e8df4b7b036cca58672fde9581f7b03dca`; its coordinator and migration-test files are byte-identical to the chosen baseline. The existing eight-suite group failed 44 tests with two issues: migrated scoped timestamp and interval were both nil. [Exact failure excerpts and provenance](results/baseline-ci-red.json).

A separate two-process Foundation probe observed a sibling reading and deleting the writer's synthetic UserDefaults sentinel despite distinct HOME and CFFIXED_USER_HOME values. [Driver](results/DefaultsIsolationProbe.swift), [observations](results/defaults-domain-probe.json). This explains why process HOME separation alone does not isolate this persistence fixture.

The candidate gives the migration fixture an attempt-state-owned in-memory defaults store while exercising real persistence/migration code. The original migration assertions remain; the new nested-owner regression verifies a second store's reset cannot erase the first store's migrated values. Independent review found no blocking issue: all four persistence/load/reset accesses consistently use the owner override, release shared state still uses `.standard`, and the added fixture helper is DEBUG-only.

The hosted test source selection includes the requested eight suites plus Coordinator regressions and unchanged helper files; the full App/Core modules compile. Existing environment scrubbing, keychain denial and native process containment remain active. This establishes synthetic production-module behavior, not a packaged-app journey. Other successful proof runs were preserved.
