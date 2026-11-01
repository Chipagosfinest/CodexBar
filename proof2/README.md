# Running native CodexBar menus — proof2

All three full CodexBar app targets were built and run at these final product heads. Actual desktop recordings were captured with `screencapture -v` on hosted macOS 15.8.2/Aqua, Xcode 26.3, Swift 6.2.4. The local Mac was locked; its black/lock-screen captures are excluded.

| PR | Product head | Actual-screen recording | Observed state changes | Focused tests |
| --- | --- | --- | --- | --- |
| #4881 | `7dc9174267b5809433dbb326a233f30d3f5cf01d` | [MP4](hosted/4881/screen.mp4) · [original MOV](hosted/4881/screen.mov) · [frame](hosted/4881/cover.png) | 89% orange →90% red + warning →89% orange, warning clears. | 6 passed; healthy title width and critical-safe frozen-height sweep. |
| #4883 | `d7ce5b51b3f6f6651012b7e5a1eb291632f0bbe0` | [MP4](hosted/4883/screen.mp4) · [original MOV](hosted/4883/screen.mov) · [frame](hosted/4883/cover.png) | Success → refreshing → failed retaining 89/40/20 → recovery. Quota neutral on failure, fresh cost bar stays orange. | 5 passed; fresh cost tint + stale quota/recovery red/green regression. |
| #4884 | `8c311de2545db92f4914629d3f0692a5dbf18acf` | [MP4](hosted/4884/screen.mp4) · [original MOV](hosted/4884/screen.mov) · [frame](hosted/4884/cover.png) | 11→88→11 values and real wall-clock 2m→1m reset tick. | 56 passed, including 3 native typography sizing tests. |

The full build SHA is visible in every recording. Every selected state frame and transcoded MP4 was inspected; no personal data is present. All data is synthetic. The MP4s preserve dimensions and playback speed, with no cuts or overlays; original MOVs and hashes are retained.

## Product fixes

- #4881 removes the invisible healthy glyph width. Hidden critical-safe measurement preserves the frozen native-menu height while healthy visible text uses the full width; compact headers reserve no glyph space.
- #4883 keeps provider color for independently fresh cost/detail data and limits neutral stale tint to retained quota rows.
- #4884 applies tabular digits to numeric Text instead of entire sections/rows, preserving normal title/hint/error typography.

## Provenance and boundaries

[Successful capture run 41323494918](https://github.com/Chipagosfinest/CodexBar/actions/runs/41323494918), immutable workflow/source commit `ac7409079e18e81ac1436088d4b2f68970dc365e`. Attempt 1 produced #4881/#4883; attempt 2 retried only #4884 after a screen-encoder failure. All final capture jobs succeeded and the app stayed running. Temporary workflow removed in cleanup commit `0038bc14b955032485eb49f81a76395d559ce851`; product PR workflows were never changed.

The temporary opt-in entry executes before normal accounts/settings/transports and renders the production UsageMenuCardView.Model.make and UsageMenuCardView in an actual NSMenu, using production MenuCardRefreshMonitor and its manual-refresh freeze/end path. A local phase file injects synthetic inputs. The countdown uses a fixed expiry and elapsed wall-clock time, not an accelerated clock. This proves the observed synthetic menu journey, not real provider transport or full StatusItemController/user-click routing.

The older hosted compiler times out on a pre-existing plugin fingerprint array concatenation. A proof-only explicit `[String]` local decomposes the same expression in that unused function; it is outside the fixture entry path and does not alter menu code. Each folder includes the complete entry/compiler plumbing patch, fixture source/hash, build log, environment, executable hash, runtime/capture receipts, and media hashes. Root independently checked all 1,025 menu/core file SHA256s per build against the corresponding product head.

Final product heads also built and ran locally with the CLT-only Swift 6.4/native SwiftPM/macOS 26.5 SDK workaround. Product tracked source/manifest restored clean in proof worktrees. No real accounts, credentials, personal screen contents, or provider/Keychain probes were used.

Pinned formatting and strict lint pass. Local `make check` hits an unchanged packaged-launch fixture assertion (`ambient-home/Library`), also reproduced from the untouched root checkout; see `unchanged-check-fixture.txt`. The PR comments link current exact-head CI separately; these recordings and local tests do not imply CI completion.
