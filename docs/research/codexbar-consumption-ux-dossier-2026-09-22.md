# CodexBar consumption UX research dossier

**Research date:** 2026-09-22  
**Decision:** establish a coherent visual and language system from the menu-bar glance through the deep usage view and share artifact, without combining measures whose sources do not reconcile.  
**Scope:** local CodexBar implementation, saved Taste material, current direct competitors and adjacent analytics products, provider/gateway accounting contracts, share-story patterns.

## Executive direction

CodexBar should feel like a lively instrument for AI work: one crisp live signal in the menu bar, a highly scannable multi-provider cockpit on click, and a generous analysis canvas when the user chooses to go deeper. Make the numbers feel tangible with a distinctive model-mix ribbon, activity rhythm, pace/projection, and restrained provider colors. Use motion to show a real refresh, burn-rate change, or selection; keep the shell quiet and warm. Make each number's basis inspectable.

The strongest product opportunity is not another pile of equal-weight cards. It is a legible hierarchy across five surfaces that answers, in order: **What limit matters now? What have I used? Where did it go? How trustworthy/current is the record? What can I share?**

### Decisions supported by the evidence

1. Keep plan allowance and observed token activity as separate visual tracks. A percentage remaining cannot be derived from local token counts.
2. Do not call every dollar number “spend.” Use **Provider-reported cost** for an actual metered record and **Estimated API value** (or **List-price equivalent**) for local tokens multiplied by public prices. Name plan-included usage as allowance.
3. Distinguish **model** from **serving provider**. A model family may be known while the actual routed endpoint is not.
4. Put one hero on a share card. The hero can be token volume or a sourced result; period, local scope, coverage, and the cost basis travel with it.
5. Let Overview feel expressive through a single large data composition and useful interaction, not a six-card bento grid. The deep view can carry the table, filters, richer legends, and provenance.
6. Treat updates as a visible state: “Updated just now,” “12 min ago,” or “Stale.” Retain the last good value during a fetch, but do not make it look freshly confirmed.

## How this research was done

- Queried Exa and Parallel separately on current token-tracker products, menu-bar surfaces, provider analytics semantics, Spotify Wrapped stories, and Apple widget constraints; then checked consequential claims against first-party docs/repositories.
- Exa surfaced semantically adjacent products and exact OpenRouter API schemas efficiently. Parallel surfaced a wider set of live product pages, project repositories, recent product claims, and complementary terms. They converged on the same main product examples and the same semantic trap: local/public-price estimates are not equivalent to provider-metered charges or subscription allowance.
- Read CodexBar's local menu/overview, dashboard model, widget and share payload code. Read the Taste notes linked below. Follow-up research lanes separately covered provider accounting and dashboard semantics, desktop tracker UX, and share-story patterns.
- Direct product pages and docs establish what is claimed or exposed. Repository code establishes what CodexBar currently implements. Cross-product design recommendations below are **inferences**, not claims that a particular pattern has been experimentally proven.
- Popularity is a time-sensitive discovery signal. Do not say “trending on GitHub” from total stars alone; GitHub's daily Trending surface was not a durable/API-ranked measure. Keep repository star counts out of product strategy decisions unless refreshed with date and method.

### Search log and how it narrowed

| Pass | Objective | Change to next pass |
|---|---|---|
| 1 | Find menu-bar and local token trackers; identify product surfaces | TokenBar emerged as the closest adjacent macOS comparator. Inspect its own pages/README; search for smaller repos by interaction, not only stars. |
| 2 | Check vendor analytics in OpenRouter, Vercel AI Gateway, Cloudflare AI Gateway | Move from vague “spend” comparisons to per-source accounting fields and actual estimate/billing boundaries. |
| 3 | Check Spotify Wrapped and share-card examples | Separate sequential personal recap mechanics from single-image brag cards; insist that every shareable claim has a source and denominator. |
| 4 | Read CodexBar source and Taste notes | Anchor recommendations to existing surfaces and shared data models; reject proposals that imply a nonexistent independent dashboard or duplicate totals. |

## The current CodexBar surface map

| Surface | Current role and code | Design implication |
|---|---|---|
| Menu-bar status item | `NSStatusItem`, refreshed provider signals and compact title/icon | One provider-specific constraint or a terse provider selector is the glance. Do not place subscription quota and estimated dollars side by side as though they share a denominator. |
| Clicked overview | `NSMenu` with `OverviewSpendSummaryCardView`, inline share action, and provider rows (`StatusItemController+Menu.swift`, `StatusItemController+OverviewSpend.swift`) | This is the quick multi-provider cockpit. The top usage summary currently uses several caption-level qualifiers; reduce the visible text while keeping coverage and provenance one click away. |
| Spend & Usage deep view | A pane in the app's Preferences/settings window (`PreferencesSpendDashboardPane.swift`); it is not currently a full independent dashboard/modal | Make this the analytical canvas: period, filters, trend, model/provider composition, activity grid, and inspectable records. Maintain a clear route back to the menu overview. |
| macOS widgets | WidgetKit usage, history, metric, switcher, and burn-down families (`Sources/CodexBarWidget/`) | Widgets are user-placed and job-specific. Design by widget family/size; do not make the in-app overview pretend to be a Home Screen. |
| Share preview | A separate local window and static image/export flow (`ShareStatsWindowController.swift`, `ShareStatsCardView.swift`, `ShareStatsRenderer.swift`, `ShareStatsPayload.swift`) | Treat preview as a share-artifact studio: choose a story/period, preview, export. Keep local privacy and sanitized payload fields. |

### Existing strengths worth making visible

- `SpendDashboardModel` separately represents currency groups, providers, models, projects, daily points, token mix, and coverage. It tracks incomplete requests and flags totals that are lower bounds.
- The overview summary already has provider coverage, history coverage, pricing coverage, provenance, and partial-state logic.
- `SpendDashboardSummary` exposes estimated cost, tracked tokens, plan metered amount when available, provider count, input/output/cache/reasoning mix, coverage, and provenance.
- Widget metric copy already distinguishes provider-reported labels and OpenAI API-estimate labels in some cases.
- The share payload is immutable and sanitized; model identities that may leak paths/accounts are reduced to public families. It distinguishes partial tokens/models.

**Design gap:** the current compact overview gives several long qualifiers approximately equal typographic weight while the deep view's data model contains much better explanatory structure. Move detailed proof into a deliberate “Why this number?” disclosure and let the hero carry one plain label, range, and live state.

## Competitor and adjacent-product map

Evidence date: 2026-09-22. Descriptions in this table are official product/repository claims, not independent quality ratings.

| Product | Surface and interaction observed/reported | Useful lesson | Boundary |
|---|---|---|---|
| **CodexBar** | Multi-provider menu-bar limits, reset times, provider cards, WidgetKit usage/history/metric/switcher/burn-down widgets; local spend dashboard and local share export. | Broad provider reach plus quota and spend in one product is differentiated. A shared normalized data model can support many surfaces. | Current Overview is an `NSMenu`, while detailed analytics live in settings. Subscription allowance and local price-derived usage are distinct. |
| **TokenBar** | Native macOS menu bar, local session history across 25+ agents; title options include tokens, cost, throughput, quota. A Liquid Glass popover has app filters and Overview/Models/Monthly/Daily/Hourly/Stats/Agents/3D views, OAuth quota, live sessions, keyboard shortcuts; prior reading is retained when refresh fails. | Closest desktop analogue. Strong surface ladder, local-first story, several meaningful chart lenses, keyboard interaction, a glanceable throughput affordance. Its 3D contribution terrain and spinning cat are memorable because each encodes usage/activity. | It mainly reads coding-agent local logs, unlike CodexBar's provider allowance plus mixed histories. Avoid copying its cat/3D terrain or implying every source is equally observed. Marketing claims need source-specific qualification. |
| **TokenDash** | Menu-bar popover has a large today total, cost/cache-rate signal, one hourly curve, model bars with amount/share, a seven-day strip, quota cards and route to a local web dashboard with date/project/model lenses and a heatmap. Uses stale-while-revalidate during local parsing. | Best compact example of **hero → one chart → one ranked mix → deeper dashboard** and a useful fast-feel data-loading model. | It tracks local sessions, not provider subscription quota as the same measure. Its cost remains an estimate when reconstructed from price data. |
| **Claude HUD** | Claude Code status-line plugin. Native JSON statusline input/output plus transcript JSONL for tools/agents/todos; re-renders after activity with 300ms debounce; configurable Full/Essential/Minimal presets and optional JSON write path. | Gives a useful technical precedent for fast, event-driven, compact status surfaces: local machine-readable input, debounced updates, configurable density. Copy the event boundary and resilient JSON discipline, not a terminal status line's density. | Claude Code context usage is not CodexBar's cross-provider monetary basis. HUD reports a source-specific context signal rather than a full spend ledger. |
| **Tokenomics** | Menu-bar dual rings encode nearest and broader provider limit; the ring has a pace marker; popover includes plan, sync time, refresh; small and medium macOS widgets. | A pace marker can answer “ahead or behind expected burn” without adding prose. Explicit loading, last sync and refresh control matter. | Its per-provider limits differ by source and sometimes are estimated. Do not imply the bar's ideal pace is a guaranteed prediction. |
| **TokenBar / Token Board / TokenStack / tokenjuice family** | Indie products use compact stat summaries, provider/model bars, contribution calendars, limit-as-battery metaphors, and local history; coverage varies substantially. | Contribution/activity views are a strong personal-history metaphor; a simple battery shape reads naturally for remaining quota. Small tools demonstrate varied user mental models that larger dashboards miss. | A grid of three statistic boxes or branded battery colors is not a sufficient CodexBar visual language. Validate each repo's current state before calling it popular or active. |
| **OpenRouter Activity** | Activity dashboard and APIs organize spend, token volume, cache hit rate, latency, request records, grouping by model/provider and more. Request/generation metadata includes model, provider, input/output/reasoning/cache token fields and cost fields. | Question-led analytics: overview for “what changed?”, Explore/grouping for “where did it go?”, request-level drill-down for “why?”. Make model and endpoint/provider separate dimensions. | OpenRouter charge and BYOK upstream/list-price estimates are different amounts. Token totals may be source tokenizer-specific. |
| **Vercel AI Gateway** | Overview includes requests, input/output tokens, spend, TTFT/latency, with request logs, model/provider filters, CSV/JSON exports and budget controls. | One chart per question; put exact request details and export in the drill-down. Model and serving provider are separate, actionable filters. | Gateway spend semantics do not transfer to subscription allowance or local logs. BYOK can sit outside gateway budgets. |
| **Cloudflare AI Gateway** | Analytics include requests, tokens, costs, errors and cached responses over a selected range. Cost can use default public or custom per-request rates; unified billing uses purchased credits. | Add operational quality (errors/cache) when request telemetry supports it; keep configurable rates and billing mode explicit. | Public-rate cost is an estimate; actual provider bills can differ. Only include errors/latency for sources that observe requests. |
| **Spotify Wrapped** | Sequential personalized stories, rankings/changes over time, colorful chapter-specific visual systems, individual share assets and controls around sharing/listening context. | Borrow the story sequence: open with a personal headline, reveal a surprising pattern, explain the evidence, then offer a shareable payoff. Each share asset should be self-contained and legible outside the app. | A year-end campaign's large-scale identity cannot be copied literally. CodexBar should share only first-party observed facts and avoid unsupported population rankings. |
| **FOMO / PNLGen / Token Card** | Finance share cards focus on one outsized number plus a strong position/composition visual and an obvious share/download action. Some generators allow fabricated inputs. | A brag object needs a dominant figure, visual proof, terse context and excellent export affordance. Allow playful voice around a verifiable measure. | P&L cards can prove holdings/returns using market data; token usage cards cannot claim savings, “money burned,” rank, or invoice cost from a list-price estimate. |
| **Tokens 4 Breakfast** | Provider-aware menu-bar spend, per-source freshness indicators, then a full History/Insights window with provider/model/project/session lenses, project bars and model-share chart. | Strong glance-to-canvas pattern and clear per-provider freshness. | Marketed API-equivalent value is not a provider invoice. Indexed `/token-card` route appeared 404 in this pass, so not treated as confirmed shipped UX. |
| **TokenBoard (two unrelated products)** | `token-board.com` has a heatmap and selectable day/session details, then a share card with one dominant total, a few support measures and top-tool composition. `tokenboard.sh` is a separate leaderboard with time-range/metric switches and personal rank/change. | A collectible number plus three proofs and a tight composition key can feel social without filling the card with tiny panels. | Treat leaderboard/demo numbers as staged unless tied to a verified account. Don't confuse the similarly named products. |
| **TokenTracker / TokenStack** | TokenTracker separates four one-job widgets (sparkline, heatmap, top models, limits) and a playful activity pet. TokenStack is currently a CLI forensic report with approximate layer attribution; its dashboard remains roadmap. | Split ambient widget tasks; put deep “what caused it?” analysis behind the main view, and visually separate exact from approximate attribution. | Do not report TokenStack's unshipped dashboard as a real competitor surface. |

### What is actually shareable

FOMO's first-party guides present profit/loss cards as proof-bearing position summaries. The supplied X example for PNLGen is a user-editable/fabricated card generator, so it is evidence of the social grammar (one hero number, composition, share affordance), not evidence of an achieved return. Spotify demonstrates how to turn a recap into a sequence of personal discoveries rather than a static dashboard screenshot. Token Card projects demonstrate a direct “API-equivalent value” vocabulary, but need a clear “not a bill” boundary.

For CodexBar the honest flex is likely **“I worked with X tokens across Y models/providers this month”**, when the data supports it. “I burned $X” is only safe when it is explicitly a metered charge and the scope is complete; for API-price multiplication, “estimated API value” is the correct less-dramatic label.

## Provider accounting: a vocabulary that survives multiple backends

### Canonical terms

| UI term | Use when | Keep visible |
|---|---|---|
| **Plan allowance** | Provider-reported limit/percentage/reset window | Provider + window + reset; never imply dollars or token units |
| **Observed tokens** | Tokens reported by a provider or parsed from local history | Scope (`local Codex logs`), period, tokenizer/source; tokenizers differ across providers |
| **Provider-reported cost** | Provider/gateway's actual recorded metered amount | Which provider/gateway reported it; currency and coverage |
| **Estimated API value** | Observed token mix × a public/list price catalog | `~`, list price/date or catalog source, “not billed spend” |
| **Credits** | Provider's own credit unit | Preserve credits; convert only when source contract defines an exact conversion |
| **Serving provider** | Actual endpoint that handled a model request is present in telemetry | Leave unknown when routing source does not report it |
| **Model family** | Only model owner/family is inferred from a model slug/name | Don't imply this is the serving endpoint |
| **Coverage** | Records/tokens/cost are missing, unpriced, unmetered, or only partly scanned | State numerator/denominator, last successful update, and incomplete/lower-bound status |

### Cross-provider pitfalls with UI consequences

- Subscription plans (Codex, Claude Code) expose time-window allowance. Local token parsing cannot reconstruct provider-specific allowance consumption: model, task, reasoning, tools, cache, and cloud/device scope may affect it.
- OpenRouter response/accounting metadata can have an actual charge to OpenRouter credits and a distinct upstream inference cost for BYOK. Its Activity analytics expose model, provider, request, tokens and latency, but the dimensions are source-specific.
- Vercel gateway logs can tie request cost and timing to a model/provider. BYOK spend may be outside gateway budgets; do not roll that into one “paid” budget number without source evidence.
- Cloudflare's public-price calculation is an estimate. Its custom-cost feature exists because negotiated input/output/cache rates differ; unified billing is another distinct cost lane.
- Input/cache/reasoning fields are not normalized the same way by all APIs. Some providers define reasoning as an inclusive output detail; cached tokens can be an input subset or a separately reported input category. Missing fields mean “not reported,” not zero. Normalize using source contracts before rendering sums.
- OpenRouter's public daily token-rankings documentation explicitly says tokens use each upstream's own tokenizer and are not directly comparable between providers. A cross-provider “tokens” total can still be a convenient workload indicator, but the UI must avoid claiming equal model work per token.

### Safe labels and hierarchy

Use these names in charts/tooltips, rather than bare “cost” and “usage”:

- **Allowance left** · `Weekly · 82% · resets Tue 4:00 PM`
- **Observed tokens** · `34B · local Codex logs · 30d`
- **Estimated API value** · `~$23.4K · list-price equivalent · not billed spend`
- **Provider-reported cost** · `$71.42 · OpenRouter credits · 30d`
- **Coverage** · `43 priced / 5,210 records · 2 sources incomplete`
- **Updated** · `just now`, `12 min ago`, or `stale · last success 2:14 PM`
- **Model mix** (denominator: observed tokens), separately from **Serving-provider mix**.

“Burned” can be the friendly story title for tokens (e.g. **34B tokens burned**), but never for estimated dollars. “Saved,” “value delivered,” and percentile/rank claims require a defensible comparison or reference population and should not be generated from usage alone.

## Design system across five surfaces

### 1. Menu-bar status item: one glance, one live question

**Job:** Can I continue this work, or am I nearing a real limit?

- Show the selected provider's nearest relevant allowance as a compact percent/ring, reset hint, or current provider glyph. An optional user-selected live throughput mode (tokens/min) is a different mode, not a second simultaneous truth.
- Let color encode state (comfortable, approaching, near reset/limit) with an accessible label/icon/shape as backup; do not assign one universal provider color to “cost.”
- If freshness is uncertain, show a subtle stale indication or “—” with retained last-known value in the menu detail. Don't silently reset to zero or show stale as current.
- Tapping opens the anchored overview; keyboard activation and VoiceOver need equivalent semantics. Keep the title stable while values tick to avoid visual jitter.

### 2. Clicked overview popover: compact cockpit, not a compressed dashboard

**Job:** What changed across my enabled providers and what deserves attention now?

Suggested reading order:

1. A crisp top rail: selected **Overview** / provider view and a clear freshness marker/refresh action.
2. A single **Activity & cost** feature with one dominant, correctly named measure, period control, and small composition graph. Separate allowance from history using section labels or tabs.
3. Two to four ranked provider rows with one useful signal each (allowance/reset OR observed activity/cost, based on supported data) and a chevron to expand.
4. One quiet route to **Open Spend & Usage**; share is a contextual menu action or the share window's primary tool, not competing with provider navigation.

Reduce the five simultaneous lines now in `OverviewSpendSummaryCardView`: prefer `~$X API value` (or provider-reported cost) and period as the visual hero, `Y tokens` + `N/M sources` as compact secondary labels, a tiny coverage/freshness indicator, and an explanatory disclosure. If heterogeneous subscription plans have no comparable amount, use separated provider amounts instead of a mathematically attractive but misleading aggregate.

Color: use a neutral AppKit/SwiftUI shell; provider/model colors are consistent data encodings, while one warm accent marks the primary interactive state. Use tints, strokes, and typography—not orange panels—to define focus. Do not fabricate gradients/shadows to add “life.”

### 3. Spend & Usage deep view: one canvas, question-led analysis

**Job:** Which sources/models drove the change, and can I verify the amount?

- Top: range (`24h / 7d / 30d / all`), scope/source selector, freshness, coverage badge, and one headline per *basis* (tokens; estimated API value; provider-reported cost; allowance in its own section).
- Primary visualization: a timeline with clear units and a selectable day/hour. Stacked color only when categories are exclusive and comparable. Provide an unstacked line or token/cost toggle; do not mix costs of different currencies or bases on one scale.
- Composition: toggle **Models** and **Providers**, with denominator explicit (`share of observed tokens` vs `share of reported cost`). Make long tails “Other” in summary while retaining named rows in detail.
- Add a calendar/contribution view as an alternate lens for cadence, and hour-of-day profile when local history supports it. Use it as a purposeful view switch, not a decorative hero.
- Detail table: date/source/model/serving provider; input/cached input/cache write/output/reasoning as supported; provider cost and estimate in separate columns; pricing/coverage status. Explain inclusive fields so reasoning/cache is not double-counted.
- Selecting a mark filters detail; hover/focus exposes exact day, values, model composition and state. Escape clears a selection; keyboard can step data points. Export keeps the same visible range/filter and provenance.
- Empty, loading, partial, stale and failed states must remain distinct. During refresh keep last good value, show “Updating”; if failed, say last success and expose Retry rather than replacing history with zeros.

### 4. macOS widgets: let each size do one job

The system owns placement and configuration. Keep widgets readable on translucent/tinted backgrounds and across sizes. Use `WidgetKit` configuration, family-specific information density, and deep links to a relevant CodexBar view.

| Family/job | Content direction |
|---|---|
| Small glance | One provider's primary allowance and reset; or one selected metric like today's observed tokens. Never both at micro type. |
| Medium | Allowance trend or 7/30-day activity with one focal total and small sparkline. |
| Large | Multi-provider activity composition or burn-down with selected period, scale and compact legend. Make provider filter persistent and obvious. |
| Stale/empty | Preserve last snapshot with “Updated …”; show a useful “Open CodexBar to refresh” empty state. |

The saved Taste note already calls for job-scoped widget kinds, user placement, a single configured provider for circular accessories, actions (not mini dashboards) in Control Center, and no second “pretty” spend total. Respect those existing decisions.

### 5. Share window: a personal recap with proof, not a miniature report

Make one exported asset feel authored, expressive and instantly legible. A practical first story:

**Header:** `MY AI MONTH` or `30 DAYS IN TOKENS`  
**Hero:** `34B` / `TOKENS`  
**Composition:** a vivid, well-proportioned model mix ribbon or stacked timeline with 2–3 named families and `Other`  
**Support:** `5 models · 18 active days` if fully covered  
**Proof line:** `Local Codex logs · Sep 1–30 · 92% model coverage`  
**Cost footnote, when valid:** `~$23.4K estimated API value · public prices · not billed spend`

- Offer a small sequence of stories, each with one insight: `Total tokens`, `Model of the month`, `Your rhythm`, `Biggest day`, `Provider mix`. Users select one card to export/share; every image works alone.
- Use a compact period choice and one privacy/scope control (`Local history` / selected sources), with preview updated from one immutable payload. Show provider/model attribution coverage before the user shares.
- Make **Copy image** / **Save image** tactile with immediate success and an undo/retry path. Do not write to pasteboard just by opening the preview. The existing NSMenu code should hand off to the independent window rather than block menu tracking.
- Keep provider/model colors stable across menu, dashboard, and card. A generous color field or animated (preview-only) ribbon may make the card feel alive; use a static export, no runtime imagery generation.
- Avoid random microtype, faux-terminal stamps, barcodes, invented “rank,” public share URLs, and any design flourish that looks like fake evidence.

**Treat the recap deck and exported card as separate artifacts.** Spotify's stories reveal one claim at a time and let each story produce its own card; Cursor's year summary ties a restrained dot field to usage. The live deck can be 5–7 chapters, while the export should carry one hero fact, one expressive data object, at most two proof points, and a readable provenance line.

Candidate chapters: **Scale** (total observed tokens), **Rhythm** (busiest day/activity curve), **Model mix** (only with adequate attribution), **Cost translation** (estimate clearly distinct from charges), **Consistency or provider mix** (choose whichever the data supports). Keep arrow/swipe navigation, replay and direct chapter access. No autoplay. Give users a bounded choice of curated themes and privacy toggles; measured values stay locked. Each card remains self-contained when shared out of context.

### Controls should feel like physical actions, not a wall of pills

The current visual complaint about buttons is not solved by adding more gradients or round rectangles. Use a quiet keyline, clear pressed/selected contrast, a small hover lift, and a short press-in response; vary the treatment by role so the selected period, provider filter, refresh and export aren't all peers. Labels should acknowledge completed action (`Copy` → `Copied`) and recover cleanly after failure (`Save` → retryable error). Preserve visible keyboard focus and reduced-motion behavior. A short settle may follow an actual export; recurring refresh must not replay entrance motion.

The share-deck candidate uses a persistent data object that changes shape through chapters (marks gather into a total, then stretch into a rhythm line or split into model streams). This has a causal relationship to the data. Avoid animating every caption/card independently. On reduced motion, show the final chart and a brief opacity change.

**Treat the recap deck and exported card as separate artifacts.** Spotify's stories reveal one claim at a time and let each story produce its own card; Cursor's year summary ties a restrained dot field to usage. The live deck can be 5–7 chapters, while the export should carry one hero fact, one expressive data object, at most two proof points, and a readable provenance line.

Candidate chapters: **Scale** (total observed tokens), **Rhythm** (busiest day/activity curve), **Model mix** (only with adequate attribution), **Cost translation** (estimate clearly distinct from charges), **Consistency or provider mix** (choose whichever the data supports). Keep arrow/swipe navigation, replay and direct chapter access. No autoplay. Give users a bounded choice of curated themes and privacy toggles; measured values stay locked. Each card remains self-contained when shared out of context.

## Visualization and motion grammar

| Question | Visualization | Interaction | Constraint |
|---|---|---|---|
| “Am I near a quota?” | Ring/arc or horizontal remaining band plus reset | Tap opens provider's allowance details; pace indicator is optional | Percent denominator and time window are provider-specific |
| “How much local activity?” | Hero count + sparkline/calendar heatmap | Select day to filter model/detail table | State whether days are scanned and distinguish zero from missing |
| “Which models?” | Ranked bars or proportional ribbon | Click a model to scope timeline/details | Label denominator; color maps model identity consistently |
| “Which provider served it?” | Separate ranked bars/stack | Filter by actual serving provider | Show unknown separately; don't infer route from owner |
| “Why did estimated value move?” | Input/output/cache breakdown plus price provenance | Expand row/tooltip to inspect catalog version/rates | Price estimate and billed amount must never be on a shared unlabeled axis |
| “Am I on pace?” | Actual burn line + projected remaining runway | Change pace window; inspect inputs/range | Projection must name baseline and avoid false certainty |
| “When am I most active?” | Hour-of-week matrix or hourly rhythm | Hover/focus for local date/time and value | Use local timezone; only where timestamp coverage is adequate |

Motion follows a real event: new snapshot, actual quota delta, selected interval, chart-to-detail filter, or successful export. Entrance motion fires once. Every chart respects reduced motion and keyboard focus. A tiny numerical roll/slot transition is for a changed count, not a permanently animating status badge. Keep sub-300ms-ish microfeedback as a design target, but benchmark on device; Claude HUD's 300ms debounced render is one implementation precedent, not a CodexBar timing requirement.

## Product-by-pattern scorecard

| Pattern | Seen in | Recommendation | Exception / risk |
|---|---|---|---|
| One glanceable active limit | CodexBar, TokenBar, Tokenomics, tokenjuice | **Adopt** in menu-bar status | Users can select throughput or tokens mode if it does not imply quota |
| Distinct lenses (overview/model/day/hour/detail) | TokenBar, OpenRouter, Vercel | **Adopt** in deep view, with Overview still compact | Don't transplant 7 tabs into a 300pt menu |
| Actual vs estimated accounting | OpenRouter, Cloudflare, provider docs | **Must adopt everywhere** | Existing partial/lower-bound flags need visible status |
| Model vs provider axes | OpenRouter, Vercel, Cloudflare | **Must preserve** | Provider unknown is a useful state; do not “repair” it with inference |
| Pace or projection | Tokenomics, TokenBar | **Experiment in a quota/overview detail** | Needs adequate interval/reset data; label projection source |
| Contribution calendar | TokenBar, local-history trackers, Wrapped yearly recap | **Use as a secondary history lens** | Avoid making an intense 3D chart the primary surface |
| Expressive single-hero share card | Spotify, FOMO, Token Card | **Adopt the visual hierarchy** | CodexBar needs stronger evidence line and estimate disclaimer than P&L cards |
| Lots of equal-weight mini stat cards | Generic token boards and some dashboards | **Avoid for share and top-of-popover** | Deep analytics can use metric switches instead of duplicated cards |
| Real-time update signal | Claude HUD JSON/statusline, gateways, TokenBar | **Adopt freshness/progress state** | Local scan/data source update cadence is not necessarily millisecond-level |

## Concrete next design sprint

### Now: settle the information contract

1. Specify one `ConsumptionMeasure` presentation contract derived from current `CostProvenance`, coverage, source kind and update time. It must render actual, estimated, allowance, credits, partial/lower-bound, unknown and stale without recomputing totals in view code.
2. Sketch three structural alternatives for the overview and deep view: **instrument panel** (one large activity signal + provider rows), **editorial recap** (short narrative/insight + composition), and **dense analyst canvas** (trend + collapsible detail). Explicitly decide whether the status item shows a coarse state or a selected allowance number; make the menu overview status/orientation, not an unbounded dashboard. Keep the existing CodexBar AppKit frame and tokens; compare with real data and a 300pt-width capture.
3. Redesign the share card around one token-volume hero and a composition ribbon. Use the current local account payload privately; do not encode a fake provider/model breakdown. Put `not billed spend` beside any API-price equivalent.
4. Prototype a light/dark system palette and data-color map. Test contrast and color-vision clarity; do not assign provider brand colors to categories such as “estimated” or “actual”—use badges/shapes for provenance.

### Next: add trust and pace

5. Add source-by-source freshness and coverage drill-down; stale snapshots retain value while changing state.
6. Add actual-vs-ideal pace to supported quota windows and burn-down widgets; projection is optional where reset/interval data makes it meaningful.
7. Add model/provider/rhythm lenses plus keyboard, VoiceOver, reduced-motion, partial and unavailable states.

### Later: personalized recap

8. Add opt-in monthly/annual share chapters only for facts that are fully defined: active days, top model by observed tokens, busiest day, provider/model mix. Do not create a ranking against all users without a defensible reference cohort.
9. Consider small build-time-authored visual motifs (e.g. a repeatable token stream/constellation) only after typography and data geometry work; no paid generation at runtime.

## Taste synthesis

This research agrees with, and adds evidence to, existing Taste decisions; it does not supersede them:

- `Taste/Collections/CodexBar Glance Surfaces — Five Native Visualizations.md`: WidgetKit is OS-placed, widgets are job-scoped, Control Center is for actions, in-app board is the only CodexBar-owned drag/reorder surface, and one measure catalog must serve Overview/widget/deep view/share.
- `Taste/Collections/UI and Product Pattern Library.md`: one focal object; what → why now → evidence/state → next action; state-bearing cards include source/time/confidence nearby; preserve the same object while switching lens; avoid equal-weight grids, generic gradient/blur/shadow hierarchy, too many primary actions, and technical costume.
- `Taste/Collections/PayOS — Playful Product Objects in a Serious Frame.md`: lively product-native color can coexist with a calm shell. Borrow the principle—professional frame, animated/data-rich object—not PayOS's palette or card design.
- `Taste/Collections/Interaction and Motion.md` and `Micro-Design — Functional Ephemera and Anti-Slop Aesthetic.md`: specify trigger, before/after, focus/cancel/failure/reduced-motion; all texture and provenance marks must be real and useful.

## Risks and unresolved research

- **Tokenizer comparability:** summing tokens across provider-local logs is useful for workload scale but not a standardized unit of equivalent work. Keep source and label clear; test whether a provider-separated hero is more trustworthy than an aggregate for audiences who compare models.
- **Model attribution:** current account preview indicated incomplete model attribution. A composition chart should either show explicit coverage or be omitted from the hero card.
- **Provider price drift:** a local estimate can change when catalog prices update without new activity. Store/display price snapshot date in detail and explain this to the user.
- **Live data cadence:** Claude HUD's event-driven local JSON contract can update on each interaction; CodexBar's multi-source refresh includes provider/network and filesystem scans. Do not promise millisecond freshness unless a source publishes that cadence and an on-device test proves it.
- **Status-item number vs state:** a model critique noted that provenance and coverage cannot fit beside a precise number in a status glyph. Other shipped trackers do show one selected quota/activity number. Test both a coarse state signal and a selected allowance number before picking one; never put a cost estimate in a glyph without room for its meaning.
- **Overview vs analysis job:** keep NSMenu as a short status/orientation funnel and reserve long-range filters/model/provider/project/session dimensions for Preferences. If coverage cannot be shown legibly, do not make the number the popover hero.
- **Competitive visual evidence:** the TokenBar official demo/README provides product-reported screenshots and behavior. A full current interactive install was not performed; screenshots and marketing copy should not be treated as usability testing.
- **GitHub “trending”:** no static star ranking was used as evidence of trend. Refresh GitHub Trending with a date window or use release/activity history before making adoption claims.
- **OpenRouter Activity evolution:** current analytics dashboard/API is changing rapidly; check its first-party docs and API schema immediately before any integration decision.

## Sources (checked 2026-09-22 unless noted)

### CodexBar code and local taste

- `Sources/CodexBar/StatusItemController+Menu.swift` — merged Overview, source scope, inline spend summary, provider rows.
- `Sources/CodexBar/StatusItemController+OverviewSpend.swift` — summary fields, partial/coverage/provenance and share handoff.
- `Sources/CodexBar/SpendDashboardModel.swift`, `SpendDashboardSummary.swift`, `SpendDashboardController.swift` — normalized data, lower-bound flags and deeper view model.
- `Sources/CodexBar/PreferencesSpendDashboardPane.swift` — current detailed usage pane.
- `Sources/CodexBarWidget/CodexBarWidgetViews.swift`, `BurnDownWidgetViews.swift`, `WidgetTilePlan.swift` — OS widget families/jobs.
- `Sources/CodexBar/ShareStatsPayload.swift`, `ShareStatsCardView.swift`, `ShareStatsWindowController.swift`, `ShareStatsRenderer.swift` — local share payload, preview and export.
- Taste notes listed in [Taste synthesis](#taste-synthesis), from Alec's local Taste vault.

### First-party product and data sources

- TokenBar product: https://tokenbar.nyanako.com/ ; repo: https://github.com/Nanako0129/TokenBar
- TokenDash repo: https://github.com/zhangferry/tokendash ; popover capture: https://github.com/zhangferry/tokendash/blob/main/resources/product_menu.png ; dashboard capture: https://github.com/zhangferry/tokendash/blob/main/resources/product_screenshoot.png
- CodexBar product: https://codexbar.app/ ; repo: https://github.com/steipete/CodexBar
- Claude HUD repo (JSON statusline, transcript parsing, debounce/config): https://github.com/jarrodwatts/claude-hud
- Tokenomics repo (menu rings, pace, widgets, refresh): https://github.com/rob-stout/Tokenomics
- Token juice repo (battery metaphor and data sources): https://github.com/kendrick-na/tokenjuice
- Tokens 4 Breakfast site: https://www.tokens4breakfast.app/ ; source captures: https://github.com/onekapisch/Tokens4Breakfast-daily/blob/main/docs/menubar.png and https://github.com/onekapisch/Tokens4Breakfast-daily/blob/main/docs/insights.png
- Token Board share-card product: https://token-board.com/en ; separate OSS leaderboard: https://tokenboard.sh/ and https://github.com/angelafeliciaa/tokenboard
- TokenTracker repo and widget capture: https://github.com/xiufengsun/TokenTracker and https://github.com/xiufengsun/TokenTracker/blob/main/docs/screenshots/widgets-overview.png
- TokenStack repo (CLI shipped; dashboard roadmap): https://github.com/allenwu-blip/tokenstack
- OpenRouter Activity announcement: https://openrouter.ai/blog/announcements/activity-dashboard/
- OpenRouter usage accounting: https://openrouter.ai/docs/cookbook/administration/usage-accounting
- OpenRouter request/generation schema: https://openrouter.ai/docs/api/api-reference/generations/get-request-&-usage-metadata-for-a-generation
- OpenRouter grouped activity schema: https://openrouter.ai/docs/api/api-reference/analytics/get-user-activity-grouped-by-endpoint
- OpenRouter tokenizer caveat / ranking schema: https://openrouter.ai/docs/api/api-reference/datasets/daily-token-totals-for-top-50-models
- Vercel AI Gateway observability: https://vercel.com/docs/ai-gateway/observability-and-spend/observability
- Vercel AI Gateway logs: https://vercel.com/docs/ai-gateway/observability-and-spend/logs
- Vercel AI Gateway budgets: https://vercel.com/docs/ai-gateway/observability-and-spend/budgets
- Cloudflare AI Gateway analytics: https://developers.cloudflare.com/ai-gateway/observability/analytics/
- Cloudflare AI Gateway costs: https://developers.cloudflare.com/ai-gateway/observability/costs/
- Cloudflare custom costs: https://developers.cloudflare.com/ai-gateway/configuration/custom-costs/
- Cloudflare unified billing: https://developers.cloudflare.com/ai-gateway/features/unified-billing/
- OpenAI Codex plan/pricing: https://learn.chatgpt.com/docs/pricing
- OpenAI token pricing: https://developers.openai.com/api/docs/pricing
- OpenAI token counting: https://developers.openai.com/api/docs/guides/token-counting
- Anthropic Claude Code cost semantics: https://code.claude.com/docs/en/costs
- Anthropic usage and cost API: https://platform.claude.com/docs/en/manage-claude/usage-cost-api
- Google Gemini API pricing: https://ai.google.dev/gemini-api/docs/pricing
- Cursor usage limits: https://prod.cursor.com/help/models-and-usage/usage-limits
- Spotify Wrapped experience (2025-12-03): https://newsroom.spotify.com/2025-12-03/2025-wrapped-user-experience/
- Spotify Wrapped methodology (2025-12-03): https://newsroom.spotify.com/2025-12-03/how-your-wrapped-is-made/
- Spotify Wrapped media kit and share-card sample: https://newsroom.spotify.com/media-kit/2025-wrapped-media-kit/ ; https://storage.googleapis.com/pr-newsroom-wp/1/2025/12/09141992-ShareCards-1024x576.png
- Spotify animation and personalized-story engineering: https://engineering.atspotify.com/2024/1/exploring-the-animation-landscape-of-2023-wrapped ; https://engineering.atspotify.com/2026/3/inside-the-archive-2025-wrapped
- Cursor Year in Code: https://cursor.com/2025 ; original exported-card examples: https://forum.cursor.com/t/view-your-year-2025-in-cursor/146960
- Tokenleak wrapped deck: https://github.com/ya-nsh/tokenleak and https://github.com/ya-nsh/tokenleak/blob/main/docs/wrapped-card.png
- Community recap examples: https://github.com/jarrodwatts/ccwrapped/blob/main/og-preview.png ; https://github.com/lucas-amberg/claude-wrapped/blob/main/apps/cli/docs/sample-combined.png ; https://github.com/HaokaiDing/tokology/blob/main/assets/demo.png ; https://github.com/PeiGuagua/ccwrapped/blob/main/docs/sample-horizontal.png
- FOMO P&L guide: https://fomo.family/guide
- PNLGen (user-editable social-card generator; not evidence of real account results): https://pnlgen.com/
- Token Card project: https://tokens4breakfast.com/token-card
- Apple configurable widgets: https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget
- Apple widget interactivity: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities

### Research-provider coverage

- Exa: semantic discovery found TokenBar's own detailed feature page and OpenRouter schema endpoints; useful for direct product/docs specificity.
- Parallel: wider discovery found additional menu-bar tools and the OpenRouter Activity dashboard announcement; useful for discovering new terms and current product surface changes.
- Agreement: local first-party tracker patterns converge on a single glance metric plus deeper selectable lenses; provider docs converge on separating model/provider, quota/allowance, token volume and costs.
- Differences: Exa returned more structured API field detail; Parallel surfaced a broader independent market set. Neither is treated as ground truth. Primary links above carry the factual claims.
- Apify/social sampling was not used; popularity and social reception remain unquantified. OpenRouter sent the same evidence packet to reviewers for critique only: Kimi K3 `gen-1790144021-wkPc0X6RBWjhbKDFuscS` completed and challenged the status-item/overview caveat budget; Claude Opus 5 `gen-1790144033-JUiQHOnSj8zxYMdJEEmU` was truncated after raising per-surface disclosure concerns; Muse Spark 1.3 was blocked by an 18+ attestation gate. No account setting was changed. Model output is not evidence.
