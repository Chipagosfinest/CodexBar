# Combined widget verification — 2026-11-05

Product commit: [`d150480f4`](https://github.com/Chipagosfinest/CodexBar/commit/d150480f436ae023a98753e734a97f6cf49b184c), combining #4887 at `1b3e19e0d` and #4890 at `47ba951f7`.

The conflict resolution preserves the presentation branch's single header, quota hero, secondary lanes and cost metrics, then adds the model strip before the history-chart fallback. The two public PR branches remain concern-scoped. This branch is the tested integration recipe when both proposals are selected.

`WidgetCombinedModelsRenderTests` first failed on an explicit first-side conflict baseline: four sparse/dense light/dark cases, eight missing-model-name/share issues; the quota assertions passed. The same oracle passed after the minimal layout resolution. The controlled before images show this deliberately incomplete merge baseline, not a defect claim against either standalone PR.

81 tests in 8 impacted widget suites passed. `make check` exited 0 with zero violations in 3,169 files. Inspected all 21 current renders: four combined model cases; English/German/Arabic in small, medium and large families; six/ten-account overflow in light/dark medium/large tiles. The dense model tile retains the 39% headline, 70% weekly quota, red 8% scoped quota, both cost metrics and 60%/40% model rows.

These are offscreen renders of production components with synthetic data. Installed WidgetKit, pager/pointer/keyboard interactions and live refresh remain separate gates. No full interaction or merge-ready claim is made here.

See [manifest](manifest.json) for PNG hashes.
