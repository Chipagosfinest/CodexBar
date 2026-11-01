# CodexBar v2 redesign PR assets

Screenshot evidence for the v2 redesign PRs (widgets, share card, Usage & Spend Models lens). Not code for upstream.

- `v2/main/`: renders of upstream `main` at `897bff317` (before).
- `v2/widgets/`, `v2/share-card/`, `v2/models/`: renders of each PR head (after). Heads and SHA-256 hashes: `manifest.json`.
- `evidence/`: the Swift Testing proof renderers that produced them. They render production SwiftUI views offscreen
  (`NSHostingView`) with fixed synthetic data; nothing is captured from real accounts, a running app, or a WidgetKit host.
  Widgets are rendered outside WidgetKit; the tinted/accented row uses the repo's `widgetRenderingModeOverride`.
