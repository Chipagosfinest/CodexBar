# PR image refresh

Audit date: 2026-11-01. Repository: `steipete/CodexBar`; author: `Chipagosfinest`.

## Scope and evidence

Initial live inventory: 12 open PRs, from `gh pr list -R steipete/CodexBar --author Chipagosfinest --limit 100 --json number,title,body,headRefName,headRefOid,url`. Compared source/image provenance and later review changes. Product PR code, branches, scope and approval status were not changed. Historical upstream-main baselines stay pinned to their original commits.

Uploaded evidence: [immutable asset commit af7405115](https://github.com/Chipagosfinest/CodexBar/tree/af7405115e7b7ec614557c8e86d83ce857d4cbf5/image-refresh-20261101) on the fork's separate `pr-image-refresh-20261101` branch. Includes 35 inspected nonblank PNGs, per-image SHA-256/dimensions/source heads, renderer fixtures/logs and source hashes. 28 images were regenerated from the three PR worktrees; 7 hosted stills were reused because they already exercise the current exact product heads.

Temporary render targets were restored after each run; tracked production sources and Package.swift are clean in all three worktrees. Native proof is synthetic: no live accounts, cookie imports, provider probes or Keychain reads. Offscreen widget renders are explicitly outside WidgetKit. Hosted menu stills show light appearance; older dark after-images were removed instead of being implied current. Installed WidgetKit proof on #4890 is separately labelled.

## Per-PR result

| PR | Audited head | Change / decision |
| --- | --- | --- |
| [#4897](https://github.com/steipete/CodexBar/pull/4897) | `3927a4e72577da2bdb4c5c0fee0077e007d2efc0` | No body screenshots/proof images; native CLI text/table proof only. No change. |
| [#4896](https://github.com/steipete/CodexBar/pull/4896) | `38e10c239bec53eaf706afea99b81400df49083b` | No body screenshots/proof images; native CLI text/table proof only. No change. |
| [#4893](https://github.com/steipete/CodexBar/pull/4893) | `a14a006c7c19eba24b2ae0348efe4cadae62d593` | No body screenshots/proof images; native CLI text/table proof only. No change. |
| [#4890](https://github.com/steipete/CodexBar/pull/4890) | `6f97fb9d7e2ebe9855bbd344b8092395c351d43b` | Retained both installed WidgetKit screenshots: their product provenance and exercised aggregation/transport/widget sources match current head 6f97fb9d7. Opened and verified complete model-list and incomplete chart-fallback pixels, including disclosed notification overlay. Removed superseded offscreen-render links. No capture repeated. |
| [#4889](https://github.com/steipete/CodexBar/pull/4889) | `2e2b001f0da8a1ca606db141f53b4e8188a98359` | Re-rendered priced, unpriced mixed-provider, and partial-history Models states in light/dark (6 PNGs); replaced all 4 embedded after URLs. Unpriced mixed-provider rows correctly withhold token shares/bars; corrected stale token-basis caption. Fixture chart totals normalized to provider totals; intentionally absent daily summaries still display Spend unavailable. |
| [#4888](https://github.com/steipete/CodexBar/pull/4888) | `073d0643a51c7dc5e14f3b3f7f27afa27dda3f47` | Re-rendered 5 card states in both appearances, actual Share AI Usage window and private-pasteboard Copy Image output (14 PNGs). Replaced 10 embedded after/export image URLs and the edge-state directory/pixel-proof links. Shared mark chips and rank formatting match current branch. Export PNGs remain real 1200x630 output. |
| [#4887](https://github.com/steipete/CodexBar/pull/4887) | `23bf4c17e7bc76c87dd0b75bc30f776cbac8333d` | Re-rendered all 3 usage sizes in light/dark and both multi-provider sheets from this PR head (8 PNGs). Replaced 8 stale after URLs. Large widget correctly retains its chart after top-models split; main baselines and current-head review-fix matrix retained. Updated obsolete caption that said the images showed both PRs combined. |
| [#4884](https://github.com/steipete/CodexBar/pull/4884) | `8c311de2545db92f4914629d3f0692a5dbf18acf` | Replaced old after-images with 2 existing current-head hosted native-menu stills: 11 and 88 values. Verified 1,025 source hashes; no mismatch. Existing video remains the timing/countdown proof; stills do not establish temporal stability. |
| [#4883](https://github.com/steipete/CodexBar/pull/4883) | `d7ce5b51b3f6f6651012b7e5a1eb291632f0bbe0` | Replaced old after-images with 3 existing current-head hosted native-menu stills: healthy, failed refresh, recovered. Quota bars become neutral while the fresh cost bar retains colour. Verified 1,025 source hashes; no mismatch. Kept historical main baseline links and recording. |
| [#4882](https://github.com/steipete/CodexBar/pull/4882) | `eeb0e1d65941346a132b69b6a726c11f4541cde7` | No body screenshots/proof images; native CLI text proof and linked cache evidence. No change. |
| [#4881](https://github.com/steipete/CodexBar/pull/4881) | `44e51249b2afcd7120213a17b61e37b749a3f6a8` | Initially replaced old offscreen images with exact-head native-menu stills. A concurrent review-fix session then changed the header and uploaded [new proof](https://github.com/Chipagosfinest/CodexBar/tree/238c1ca91e3ed55be849810a79978239428113ec/proof3/4881). Preserved and inspected all 6 newly linked PNGs, verified raw hashes/nonblank pixels, and compared 1,774 capture-worktree source files with current head: only the documented proof entry hook differs. Corrected the caption: the long-title 100% frame retains glyph/reset text but truncates the title and hides the percentage. No product fix made by this audit. |
| [#4877](https://github.com/steipete/CodexBar/pull/4877) | `a299386b88311cff6051d7d8dcd678a5ca310aab` | No body screenshots/proof images; native CLI text/JSON proof only. No change. |

## Verification

- Local production-view render tests: #4887 one test passed; #4888 three tests passed, including the actual window/private-pasteboard export; #4889 one test passed. No product behavior changes or broad test runs were needed for this evidence-only task.
- Every newly selected PNG opened at readable resolution and checked for sensitive content, blank output and caption/state agreement. Published manifest records pixel statistics and hashes.
- All 29 initially referenced new PNG URLs matched the inspected local image hashes exactly. The later #4881 review proof superseded 2 of these and added 6 independently checked images.
- Initial 54 PNG URLs in the revised bodies, including retained baseline and installed-widget images: HTTP 200, image content type, valid dimensions and nonblank pixel variance.
- All 7 initial edited bodies were read back exactly. Later concurrent changes were preserved: #4881 advanced with new current-head proof (re-audited below), #4882 advanced without images, and #4897 received a non-image status update. This audit left all 5 CLI-only bodies untouched.
- Each body was written using `gh pr edit -R steipete/CodexBar <PR> --body-file <file>`, with a fresh body/head check before writing and exact JSON body readback afterward. Each body write left the product head unchanged.
- Detailed local audit artifacts and body backups: `/tmp/pr-image-refresh/` (ephemeral); durable capture/renderer evidence is in the linked immutable asset commit.

## Ship session: menu5 — verified

The four new PRs use immutable final menu5 assets at [484f7b918](https://github.com/Chipagosfinest/CodexBar/tree/484f7b918452288222bac236281dae8ef94f864d/menu5-ship). Each branch after-image is byte-identical to the final capture from that branch under `/tmp/ship-menu5/final/`; baseline images match the separate main captures. All 19 linked PNGs return HTTP 200, have image content types, match the inspected files by SHA-256 and are nonblank. Of these, 17 are embedded proof/baseline images and 2 are optional combined-context links.

The chart was recaptured after the final dark Claude change: hue 33, chroma 0.09, lightness offset 0 (`#b67263`); light remains chroma 0.11 / offset +0.04. The earlier `f150093bb` upload preceded that last change; current chart URLs correctly use `484f7b918`. Product source at `6283c26c7` matches the recapture entry point. None of the narrow-branch after-proof substitutes the combined redesign branch.

| PR | Current head | Image audit / body change |
| --- | --- | --- |
| [#4899](https://github.com/steipete/CodexBar/pull/4899) | `61b1a59de3bb6b239901229a17471cee4394fd56` | All 4 before/after image URLs match final main/rows captures. Light/dark urgent rows, stale Cursor, signed-out Kimi and footer are visible. Already current; body unchanged. |
| [#4900](https://github.com/steipete/CodexBar/pull/4900) | `c64d91d2fe09168a68048d43d9228b9d154c6e3a` | All 4 embedded proof images match final main/bounded captures. The 3-provider footer is visible; the 8-provider image remains scrollable as disclosed. Converted the combined-integration embedded image into an optional reference link outside this PR head. Scope/dependency text unchanged. |
| [#4901](https://github.com/steipete/CodexBar/pull/4901) | `6283c26c7ca8fefc0a4cba3477ac45ecf3564a45` | All 6 proof images match the final chart/main captures after the last coral change. Opened both selected-day images and the native-menu images. Clarified that the selected-day readout is an offscreen injected selection, not real pointer-hover proof; preserved its existing limitation and all scope/test text. |
| [#4902](https://github.com/steipete/CodexBar/pull/4902) | `c254d8b459b2654be70fbf016c55bf86db2a7815` | All 3 embedded proof images match final main/flyout captures, including the actual full-card submenu in both appearances. Converted the combined-integration embedded image into an optional reference link outside this PR head. Scope, limits and post-rows rebase instructions unchanged. |

The three caption/reference-only updates used `gh pr edit --body-file`, with fresh pre-write body/head checks and exact readback. No source, branch, PR scope, merge order, test result, or approval status changed in this audit.

## Final state

16 open author PRs audited: the original 12 plus all four newly opened ship PRs. Ten bodies edited (7 existing proof refreshes/cleanup, 3 new caption/reference clarifications); #4899 already current; 5 CLI-only bodies left untouched by this audit. All 77 linked PNG URLs across the audit were verified, including the two explicitly optional integration references. Required capture/model evidence is distinguished from real-provider or packaged-app proof. CI and merge readiness are outside this image audit; existing limitations remain in the bodies.
