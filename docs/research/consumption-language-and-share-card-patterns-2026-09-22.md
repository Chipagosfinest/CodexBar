# Consumption language and share-card patterns

Research snapshot: 2026-09-22 (direct browser captures and a supplied X post/follow-up reviewed through 2026-09-23 UTC).

## Product decision

CodexBar should treat consumption as three related but distinct facts:

1. **Observed usage**: locally recorded tokens, requests, sessions, and the period/source coverage.
2. **Estimated API value**: token-derived public list-price equivalent; useful for comparison, not a subscription invoice.
3. **Provider-reported cost**: a metered value surfaced by a provider. It is not a bill or receipt unless the source actually proves that.

Subscription quota remains its own concept: remaining percentage and reset time describe plan capacity, not historical consumption or dollars. When cost sources are incomplete or mixed, show the basis and coverage next to the value. Model and provider should remain separate dimensions because a model can be served by different providers and provider totals do not identify model mix.

The share image now leads with one token total, uses model colors only in a proportional mix ribbon, keeps cost secondary with provenance, and states that its source is local usage logs through a specific date. Partial model coverage says “Known model mix.” This avoids implying the known models account for all tracked tokens.

## Reference findings

| Product/reference | Observed pattern | CodexBar takeaway |
| --- | --- | --- |
| OpenRouter activity dashboard | Quiet dark frame; large KPI figures with small trend cues; a single model-colored stacked chart; compact legend; chart exploration leads to logs. | Put color in the measured series. Pair share and absolute volume. Keep overview glanceable and let the user open records for audit. [Activity Dashboard](https://openrouter.ai/blog/announcements/activity-dashboard/) · [Activity docs](https://openrouter.ai/docs/guides/features/activity) |
| Vercel AI Gateway observability | Separate charts for spend, requests, token breakdown, and cache; model and provider are separate groupings. Public leaderboard card uses one headline and a dominant chart with a compact legend. | Don’t compress unlike measures into one unlabeled “usage” score. Use the same model/provider vocabulary in overview and detail. [Observability](https://vercel.com/docs/ai-gateway/observability-and-spend/observability) · [Logs](https://vercel.com/docs/ai-gateway/observability-and-spend/logs) · [Leaderboards](https://vercel.com/docs/ai-gateway/leaderboards) |
| Cloudflare AI Gateway | Separate request, token, cost, error, and cache analytics; cost docs qualify their amount as estimated and direct users to provider billing controls. | Keep cost basis adjacent to the value and make provider billing the authority for charges. [Analytics](https://developers.cloudflare.com/ai-gateway/observability/analytics/) · [Costs](https://developers.cloudflare.com/ai-gateway/observability/costs/) |
| FOMO share PNL | One oversized return value, entry/exit proof, an expressive mascot, and a clear download/share action. | A share artifact needs one focal result and an emotional carrier; CodexBar can get energy from its real model mix, without borrowing trading gain semantics or inventing a mascot. [FOMO PNL cards](https://docs.onfomo.com/trading/pnl-cards) |
| Tokens 4 Breakfast Token Card | One oversized token-derived API-rate amount; selectable metric/period; explicit “fun number, not a bill” qualification. | Let people choose the hero metric later, but say whether a dollar number is estimated and never call it spend without its basis. [Token Card](https://www.tokens4breakfast.app/token-card) |
| TokenBoard | Large token total with activity counts, estimate, and provider bars in repeated equal blocks. | Useful labels, but its block grid confirms the visual failure mode Alec called out; prefer one continuous quantitative object and fewer values. [TokenBoard](https://token-board.com/en) |
| Token Stack | Compact all-time total and activity squares; separates agent mix and explicitly avoids merging incomparable provider data. | Preserve source-specific comparability; do not fabricate a unified provider/model total where inputs do not support it. [Token Stack](https://github.com/sukoji/token-stack) |
| Binance PNL cards | Distinguishes live data from static snapshots, offers hiding amounts, and links to source trade. | Provenance and privacy are product features. CodexBar can identify its local snapshot and period without implying external verification. [Binance Square PNL cards](https://www.binance.com/en/square/post/23876712519849) |
| Spotify Wrapped | A sequence of personalized data stories, each with its own share card; ranking movement and listening milestones add narrative. The 2025 creative direction calls it a “visual mixtape,” with bold but reduced color and imagery. | The bigger opportunity is a CodexBar recap made from short chapters, each centered on one substantiated insight, with each chapter shareable. A single static card can be the overview chapter; don’t cram the whole recap into one infographic. [2025 experience](https://newsroom.spotify.com/2025-12-03/2025-wrapped-user-experience/) · [Visual direction](https://newsroom.spotify.com/2025-12-03/wrapped-marketing-campaign/) · [How stories are calculated](https://newsroom.spotify.com/2025-12-03/how-your-wrapped-is-made/) |

Direct visual captures were inspected locally for OpenRouter, Vercel, FOMO, Tokens 4 Breakfast, TokenBoard, Token Stack, and TokenPocket. OpenRouter and Vercel were the clearest references for model mix and analytics language; FOMO and PNLGen were useful only for share hierarchy/action priority.

Spotify Wrapped points to a different product layer from an analytics chart: a sequence of evidence-backed personal stories, not a denser dashboard. CodexBar has possible story chapters in its existing data—usage footprint, top model/provider, mix, activity rhythm, and cost basis—but should only reveal chapters when the selected providers' coverage supports them. Do not invent peer percentiles, personality classes, streaks, or “savings” from missing or incomparable data. The underlying usage dashboard can remain precise and inspectable while a recap presents one legible insight per screen/card.

## Supplied X seed coverage ledger

Seed: [0xTria on X](https://x.com/0xTria/status/2097357439276392817). X’s direct page was not readable during the scan, so its media and thread context were retrieved through public mirrors and inspected as screenshots/video.

- Seed post and attached clip: inspected. The clip demos PNLGen, an editable P&L card generator, not verified FOMO account data.
- Replies: zero visible at scan.
- Quote posts: one visible; its media/reply context was not retrievable in this pass.
- Author follow-up: [0xTria follow-up](https://x.com/0xTria/status/2097752138130882595) inspected. The author says they fabricated a $101K Axiom card without the token address and expected people to believe it.
- Interpretation: polish can make unsupported numbers persuasive. CodexBar share images should stay data-bound and label their source, period, and estimated cost basis. Do not use “verified,” “audited,” decorative hashes, or account-like claims without a real verification system.

## Changes applied in this PR

- Replaced the orange hero panel and boxed provider/model rows with a quieter navy surface, one oversized tracked-token figure, restrained cost context, and one provider-colored model-mix ribbon.
- Limited the legend to the leading models, aggregated remaining known models as “Other models,” and labels partial coverage “Known model mix.” Percentages are relative to model token totals actually present.
- Carried `CostProvenance` into the immutable share payload so a cost can say list-price estimate, provider reported, mixed basis, or unknown. The share still says local usage logs and its latest included date.
- Kept actions outside the exported image. The artifact remains a local snapshot; no account identity is added.

## Cross-surface vocabulary to preserve

- **Quota widget:** “X% left” + reset time. This is subscription capacity.
- **Usage overview:** token count + period and source/history coverage; cost line with “List-price equivalent,” “Plan metered,” or “Metered and list-price” as applicable.
- **Detailed dashboard / CLI:** retain priced/unpriced/unmetered/estimated coverage and allow drilldown to daily/model/provider records.
- **Share image:** token total first; model composition second; cost amount with provenance; local source and through-date visible.

## Limits

This review used public docs, public screenshots, and public X mirrors rather than authenticated account dashboards. The X quote scan was partial as noted above. Market examples establish useful presentation patterns, not proof that their numbers or source records are accurate.
