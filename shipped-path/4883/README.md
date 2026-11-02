# PR 4883 proof through the shipped menu refresh path

Hosted macOS 26 run [41365849206](https://github.com/Chipagosfinest/CodexBar/actions/runs/41365849206). Test run [41355865737](https://github.com/Chipagosfinest/CodexBar/actions/runs/41355865737). All data is synthetic.

## Method

`Scripts/package_app.sh debug` builds the app at head `d7ce5b51b3f6f6651012b7e5a1eb291632f0bbe0` and base `897bff31731bb4b21b105f6e8bf4c32a8a8bf095`. `tracked-source-changes.txt` is empty for both, so no source file was patched.

The driver clicks the status item with a real CGEvent, then sends Command-R to the open menu. `StatusItemController` routes the refresh through `UsageStore` and the provider fetch to `CommandCodeUsageFetcher`, which makes real HTTP requests to a loopback fixture.

Inputs that differ from a default install:

- A synthetic config file with a fake Command Code API key.
- The upstream debug-only `COMMANDCODE_API_URL` loopback override.
- Launch arguments: `-selectedMenuProvider commandcode`, `-refreshFrequency manual`, `-iCloudSyncEnabled NO`, `-debugDisableKeychainAccess YES`, and Sparkle checks off.
- An isolated `HOME`, with `CODEXBAR_DISABLE_KEYCHAIN_ACCESS=1`.

No live accounts were used.

## Observed

| Step | Fixture | Head menu | Base menu | Purple px, head / base |
| --- | --- | --- | --- | --- |
| 1 Success | 200, 89/40 used, 80 left | Purple, 11/60/80 left | Same | 2316 / 2316 |
| 2 First failure | Connection reset | Purple, no error: the consecutive-failure gate hides the first failure | Same | 2316 / 2316 |
| 3 Second failure | Connection reset | Error shown, retained 11/60/80, bars neutral | Error shown, retained 11/60/80, bars purple | 98 / 2316 |
| 4 Recovery | 200, 90/41 used, 79 left | Purple, fresh 10/59/79 | Same | 2272 / 2272 |

The 98 pixels that remain on head in step 3 are the Command Code tab's small indicator line, not the card's bars.

## Tests

`tests/summary.txt` and `tests/excerpt.txt`, from `MenuCardStaleTintTests`:

- Head: exit 0, 5 of 5 pass.
- Head with the production change neutralised (`tests/head-neutralised.patch`): exit 1, 3 tests fail on assertions.
- Base with the PR's test file: exit 1, a compile failure, because the tests name API that base does not have. This is not an assertion failure.

## Limits

- Light appearance and Command Code only.
- Command Code has no supplemental cost section, so that tint is covered by the test `failed quota refresh preserves fresh supplemental cost tint`, not by these captures.
- The config sets Codex to disabled, but a Codex tab still appeared in the menu. The cause was not investigated. The refreshes only reached the fixture with Command Code selected.
- This is a debug build, because the loopback override is debug-only.
