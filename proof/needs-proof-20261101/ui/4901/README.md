# PR 4901 — actual pointer hover, daily shares, exit clearing

Product `1d28182bdb63b6a27edcdb91bebf1189a368efea`; controller `d9814598cac76531fd9fc03e0f2e2b7e208b8c24`.

[Successful packaged-app run](https://github.com/Chipagosfinest/CodexBar/actions/runs/41375155466) · [controller/workflow source](https://github.com/Chipagosfinest/CodexBar/tree/d9814598cac76531fd9fc03e0f2e2b7e208b8c24) · package run `41370526426`.

The fresh unmodified app ran with synthetic provider replies and local transcripts. The menu was opened by a real status-item click; the controller moved the real pointer over three distinct chart bars and then outside the chart. Selection state was not injected. All 11 capture checks passed and the installed app binary matches its package hash. Source tracked delta is empty.

| Actual pointer state | Readout | Claude / Codex legend |
| --- | --- | --- |
| At rest | Today $13.33 | 58% / 42% (range) |
| Oct 21 bar | Oct 21: $13.79 | 33% / 67% |
| Oct 27 bar | Oct 27: $15.17 | 70% / 30% |
| Nov 1 bar | Nov 1: $14.71 | 58% / 42% |
| Outside chart | Today $13.33 | 58% / 42% (range) |

All five original-resolution screenshots were inspected. Pointer position, selected date/total and displayed legend agree with the actual accessibility readouts and input sequence. The Nov 1 split happens to equal the range split; exit clearing is visible in the date returning to Today. The first two hovered days independently show changed shares. Each screen has a visible native synthetic/full-product-SHA banner outside the app.

Only these inspected PNGs and supporting logs are published, with no recording claim. Inputs are fabricated; this does not establish live account/provider accounting, partial/unpriced/locale edge states, palette accessibility or approval of the maintainer's chart/effort design. Those broader source/product questions remain separate. DNS verification is preflight and sampled, not absolute containment.

While the package artifact exists, reproduce the exact controller with:

```sh
gh run rerun 41375155466 -R Chipagosfinest/CodexBar
```
