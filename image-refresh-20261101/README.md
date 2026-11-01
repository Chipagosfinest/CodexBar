# PR image refresh — 2026-11-01

Every image was opened and inspected, then checked for nonblank pixels. See `manifest.json` for full product heads, dimensions, SHA-256 and evidence limits. No product PR code or scope was changed.

- 4887, 4888, 4889: rendered from each PR's own current worktree, with tracked production sources unchanged before and after. `renderer/` and `render.log` are retained. The synthetic-data banner wraps static view renders; the real share window and Copy Image exports preserve their production framing/1200×630 size and use only the synthetic payload.
- 4889: mixed-provider unpriced state correctly withholds token shares. Fixture daily cost stacks were normalized to their own provider totals so the chart and KPI agree. The intentionally absent daily-summary fixture still shows Spend unavailable; this is not a product failure.
- 4881, 4883, 4884: existing actual-screen hosted captures were already made against the current product heads. Reused those stills rather than recapturing identical behavior. Independently recomputed all 1,025 recorded production-source hashes per head: zero mismatches. Full capture plumbing and fixture are included, including the documented Swift compiler workaround. See the PR's existing hosted recording for temporal behavior. These captures are light appearance; no dark capture is implied.
- Source branch boundaries: none of these images come from the combined redesign/menu5 branch. New ship-session menu5 PRs have separate branch-specific proof.

Regeneration: run the retained `render.sh <PR>` after adapting its temporary workspace paths; it swaps only the temporary test target and restores Package.swift on exit. Requires the local CLT-only macro shims described by the script. No live account, cookie, or Keychain reads.
