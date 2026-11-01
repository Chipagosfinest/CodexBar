# Provider proof boundary — 2026-11-01

This evidence does **not** clear either PR's live-provider proof request.

## #4903 — persisted configuration compatibility

Product head `11935aee6ec16fe23595dbddaada349562218547`, branch `fix/ollama-official-balance`. `swift build --product CodexBarCLI` passed from its own worktree. Built executable SHA-256 is recorded in the preflight output.

Downloaded the official released `CodexBarCLI-v0.83.0-macos-arm64.tar.gz` and verified the published SHA-256 sidecar (`shasum -a 256 -c`). Released source tag: `4a626ffedca0543e9a8e04542cb6be9e9417dd7f`.

The released CLI writes three isolated configs with Auto source and Auto, Manual and Off cookie modes. The freshly built head CLI and stable CLI decode to equal normalized JSON; head validation reports no issues; saved bytes stay unchanged in all three cases. `4903-upgrade-results.json` contains observed hashes and assertions. Reproduce with:

```sh
python3 4903-config-upgrade.py /absolute/stable/CodexBarCLI /absolute/head/CodexBarCLI /tmp/isolated-upgrade
```

Only synthetic settings and a synthetic cookie are used. No real config, browser, defaults domain, Keychain, provider account or credential is accessed.

### Account continuity is unresolved

`4903-routing.swift` calls the production descriptor's resolver with a synthetic ambient API key and each cookie mode. Compile it from the PR worktree:

```sh
swiftc -parse-as-library -I .build/debug -Xcc -fmodule-map-file=.build/out/Intermediates.noindex/GeneratedModuleMaps/CQuickJS.modulemap -L .build/debug -lCodexBarCore 4903-routing.swift -o /tmp/4903-routing
/tmp/4903-routing
```

Observed at head: Auto cookies resolve `ollama.api -> ollama.web`; Manual resolves `ollama.web`; Off resolves `ollama.api`. The released v0.83.0 descriptor resolves Auto plus key as `ollama.web -> ollama.api` (source inspection, not a baseline runtime claim). Therefore an existing Auto user can select a different account after upgrade if key and browser accounts differ. Decode compatibility alone cannot clear this risk. The maintainer routing decision and reviewed API-error/no-cookie fallback defect remain unresolved.

Latest review also asks for shipped-CLI legacy balances and repeated Auto refresh request traces proving cooldown and failure fallback. Neither environment nor CLI config contains an Ollama API key. The isolated preflight exits 1 before any available strategy. It is not live balance/cooldown proof. A real authenticated setup is still needed.

## #4904 — missing authenticated provider setup

Product head `a18f3fcd2788afc832ad64f2d9458cf6774f6ed9`, branch `feat/aiand-settled-balance`. `swift build --product CodexBarCLI` passed from its own worktree. The review asks for the shipped CLI/app against the real provider, so no additional injected-transport harness is offered as a substitute. Neither environment nor CLI config contains an ai& API key. The isolated no-key preflight exits 1 before any available strategy. A real authenticated setup is still needed.
