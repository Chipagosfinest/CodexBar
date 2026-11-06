# Review regression RED proof

This isolated evidence workflow tests three immutable product revisions on a standard `macos-26` runner. It does not edit any public PR workflow or production source and does not claim a packaged-app journey.

| Case | Product | Expected regression |
| --- | --- | --- |
| Core | `b3e44381197a743c88a5f82d9008848e8a578b44` | Source-specific freshness changes compact row status/caption incorrectly. |
| Chart | `cf6efdea76161eb3061e0b954d8150231181149f` | Known daily Claude spend disappears when its range cost is unavailable. |
| Footer | `13185f0888b8e60ad22f72d66767f23601d7b960` | A refreshed plugin's captured overflow card is not replaced. |

Each job records its product/controller SHAs, all production Swift source hashes, bounded selected test hashes and complete harness patch. `Scripts/test_fast.sh`, the environment scrubber and existing process containment remain in use. Only test-target source selection, copied regression tests and retention of the disposable test HOME differ; the last avoids deleting an Xcode-mounted Metal toolchain before runner teardown.

The verifier requires the named runtime test to start and to produce its expected `Expectation failed` payload. A compilation failure, fixture guard failure, timeout or missing test is not accepted as behavioral red. Core also requires the existing `MenuCardStaleTintTests` controls to pass. This branch is preparation-only until the lead reviews and authorizes publication. A push to its exact branch triggers the workflow; no dispatch event is configured.

## Execution history

The lead authorized and published controller `2e33cc55035de29098c65513c40e0fbcffc96410`. [Initial run 42184089088](https://github.com/Chipagosfinest/CodexBar/actions/runs/42184089088) reproduced the core and chart regressions through runtime assertions with production sources unchanged. Those successful RED artifacts are retained; they are not rerun by the current matrix.

The initial footer job was a compilation failure, not behavioral red: selecting the full existing plugin test suite pulled in unrelated screenshot and summary-test dependencies. The current matrix retries only that footer case. Its proof-only namespace shell preserves the original `@Suite(.serialized) UserProviderPluginTests` declaration, while the actual regression and existing `UserProviderPluginTestSupport.swift` helpers remain unchanged. The shell substitutes no fixture, refresh, or menu behavior. Public test inventories and workflows are unchanged.
