# Cooldown persistence-owner isolation proof

The macOS 26 opt-in workflow compiles intact production App/Core modules from baseline `20ada8abf0e4e2267aaa8c7cc9cf891cdf866838` plus [the complete declared two-file candidate patch](candidate.patch), SHA256 `df23345819454907d9eb78526e7808d24757e44c53644a83e89d478c0eab16f3`.

The original behavioral failure is [baseline CI run 42178719099, job 127763212192](https://github.com/steipete/CodexBar/actions/runs/42178719099/job/127763212192): the existing legacy-profile migration test reported two nil persisted-value assertions. The new helper is unavailable on baseline, so a compiler failure from applying only the new tests would not be behavioral red. This workflow requires actual passing runtime tests against the declared candidate; it does not fabricate a baseline regression run.

Nine suites are selected: delegated refresh Epoch, MCPProfile, ProfileIsolation, Recovery, UnreadableResult and Coordinator; DirectKeychainReadConsent; FetchStrategyAvailability; FetchStrategyProfileRouting. Four unchanged support files are also compiled: TestStores, ZaiTokenStoreTestSupport, CodexCredentialFixtures and ClaudeUsageDetailNoteTests (the last supplies the consent suite's existing model helper). The test filter excludes unrelated support-file tests.

The complete production source map before and after applying the candidate, selected source bytes and hashes, full harness/candidate patches, environment, runtime log and verdict are retained in the artifact. The preparation rejects candidate paths outside the source coordinator and existing profile-isolation test. Source/test hashes must remain unchanged during execution, all nine suites must pass, and the process must exit 0. Setup/compiler failures do not count as a behavioral result.

The existing repository environment scrubber, keychain denial and native process containment remain active. The runner retains only the disposable hosted test HOME until teardown to accommodate Xcode Metal mounts. No real account credentials are used. This is a synthetic production-module regression proof, not an installed-app interaction.

Independent source review found no blocking issue: all four persist/load/reset accesses use their attempt-state-owned override; release shared state retains `.standard`; the new fixture helper is DEBUG-only and its nested TaskLocal scope restores the previous state. The original migration assertions remain intact, with a new nested-store reset regression ensuring one persistence owner cannot erase another's migrated cooldown.

Only cooldown evidence-path changes trigger this job. Auth and completed dropdown proof runs are preserved.
