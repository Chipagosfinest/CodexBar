# Re-pinned provider proof

Current #4903 head: `14ae7e0e8c4ead511bd7bff6106eb22ac9e10208`. Current #4904 head: `be184c471370047fd2a57a6a2e121653f2b39871`.

Both were checked out into new clean, detached worktrees and built with stock `swift build --product CodexBarCLI`. No compiled products were copied between worktrees. The CLI preflight reports record fresh executable hashes.

## Ollama compatibility

The official latest stable release remains v0.83.0. Re-ran the released-CLI-to-head config proof: all three Auto-source configs (Auto, Manual, Off cookie modes) decode identically, validate without issues, and keep the saved bytes unchanged. This run verifies the released CLI version and current head worktree SHA and records both binary hashes. Results and reproducer are here; invocation is:

```sh
python3 /absolute/evidence/4903-config-upgrade.py /absolute/stable/CodexBarCLI /absolute/current-head/.build/debug/CodexBarCLI /tmp/isolated-upgrade-current
```

`OllamaBalancePluginTests`: eight test functions passed, including the three connectivity-error cases for missing-cookie fallback and the actionable-cookie/cancellation checks. Fixture transport/cooldown tests pass too. This head adds the fallback-error resolver; the former masking defect is fixed in source and these focused tests pass. It remains separate from a live authenticated refresh trace.

Auto routing is still API-first at this head. The route-selection code is unchanged from the earlier snapshot: saved Auto cookies plus an ambient API key can select a different account than browser-first v0.83.0. Manual-cookie accounts stay cookie-scoped. Config compatibility does not resolve that maintainer routing decision.

## ai& validation

`AiAndBalancePluginTests`: seven test functions passed, including the added delayed optional-wallet fixture. Production sources are unchanged between the previous ai& head and this test-only head. No live-provider behavior is inferred from these tests.

## Exact live proof remains blocked

Neither current environment nor CLI config supplies an Ollama or ai& API key. Both current shipped CLIs exit 1 on isolated no-key preflights before an available strategy. These are preflight failures, not live legacy balances, repeated Auto refresh traces, or a real ai& wallet result. An authenticated setup is still needed. Nothing here accesses real accounts, browser cookies or Keychain items.

Focused tests use the stock provider/plugin target, the repository Bash test environment, the CLT testing macro library, and swiftpm-testing-helper; all transports and stores exercised are synthetic. Logs preserve executed assertions and their terminal results. No product source or PR owner-decision text was changed by the proof pass.
