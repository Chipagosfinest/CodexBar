# Grok turn-parser verification — 2026-11-05

Fix: [`e3e61ea81`](https://github.com/Chipagosfinest/CodexBar/commit/e3e61ea819180f50c9d3ac44452dbb7654f6c20a), on top of maintainer head `7ac9f12d0` for PR #4944.

The turn loop now uses the existing `CostUsageScanner.dateFromTimestamp` parser after an explicit string guard. Its RFC3339 fast path and synchronized historical fallback reuse the established timestamp implementation instead of constructing a formatter per turn. The maintainer's authoritative-turn regression and synthetic fixture edits are preserved.

The [host-local acceptance benchmark](GrokTurnParsingPerformanceTests.swift) builds one synthetic 10,000-turn `usage.json` and invokes the real scanner. Its unchanged rule requires the complete scan to finish within ten direct cached timestamp-parsing passes, while returning exactly 70,000 tokens and one session.

| Run | Complete scan | Cached-parser reference | Result |
| --- | --- | --- | --- |
| Before | 2.862215s | 0.042322s | Throughput assertion failed; totals correct |
| After | 0.103855s | 0.035933s | Same oracle passed; totals correct |

This is one Debug host-local synthetic comparison, not a universal speed guarantee or portable CI time deadline. The benchmark was removed from shipping test sources after the pass; its source and measured result remain here. No real provider, credentials, account files or clipboard were accessed for these measurements.

Final correctness verification: **248 tests in 32 Grok/timestamp suites passed**, including the maintainer's new authoritative-window regression. `make check`: **0 violations in 3,165 files**. Public current-head CI is a separate gate.

[Structured result and benchmark-source hash](result.json).
