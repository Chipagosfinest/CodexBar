# Native Overview overflow refresh: verified synthetic App journey

[Hosted run 42247247540](https://github.com/Chipagosfinest/CodexBar/actions/runs/42247247540) succeeded on controller `48507b40216fefa2f49bf205553d5652c7aa4b8e`. Independent review of the original screens and decoded recording accepted the visible plugin **5% plus prior error → 42% with error cleared**, while the parent Overview and More remained open through the observed transition.

The actual App was reused byte-for-byte from build 42242259960, artifact 13516399711. This UI-only run did not compile the App or reuse a build directory. It verified all tracked/source input maps, every bundle file and strict codesign before launch.

## Exact candidate and evidence

- Production candidate: `596da7694d01b9c403b4c9c5f9fcaaba6426610c`; production source equivalence is exact base `e8a0cca51036fa8f30362a0710754d812ace34a3` plus frozen patch SHA256 `574c1c7468735d813b979c1ff2c83963807df36ebee2a5caa229adf28ab3f961`.
- Changed production `StatusItemController+UserPlugins.swift` SHA256: `9792aa446f3edd603aa0445ee1c5085b765707a6c62281d5e224086073759524`.
- Instrumented DEBUG App executable SHA256: `cdcb62d6e2e6601b8322c2714cac5730c16bc9eb7d07d0b1d6ea7556c38b4c12`; proof adapter SHA256 `b28f1d2f9ec8c8f4309b23a25b5e2f83e503ada0b6d3d6da1449a4da9fec0eac`.
- Independent verification: all 4,404 clean-base tracked inputs matched (seven symlinks dereferenced consistently with the installer), all 110 hosted artifact checksums matched, and all four original archive/input digests and complete bundle verdict matched the original build.

[Original before screen](results/42247247540/1-before-screen.png), [after screen](results/42247247540/2-after-screen.png), [still-open screen](results/42247247540/3-still-open-screen.png), and [original continuous recording](results/42247247540/continuous-screen.mov) are unmodified. [Root's separate acceptance](results/42247247540/ROOT_ACCEPTANCE.json) supplements the unchanged automated verdict; it does not rewrite it.

## Owner and native observations

The nonce-triggered fixture uses the real plugin loader/store refresh and production menu refresh owner. The adapter binds the baseline card/view to the actually open More window immediately before refresh. After owned completion, the actual baseline-More rebuild callback was observed once; store 42/error nil, fresh cache fingerprint, replacement card/view, and replacement view attached to the original More window all passed. Original native root/More CG window IDs 115/116 remained visible through recorder exit. Zero first-party refreshes, plugin transport requests and HTTP requests were recorded.

The repaired pre-refresh navigation reacquired actual scoped AX More after native scrolling; it posted one hover at the fresh center. It never clicked Refresh, reopened the menu, or altered the production result. Fourteen pure hover controls, including the recorded stale930→fresh906 geometry, passed before the UI attempt. Existing native capture comparisons retained all 936 samples and original tolerance.

## Limits preserved

More tracking notification counters were **0/0 throughout**, including the baseline. No child tracking notification was observed; these counters do not prove positive child lifecycle coverage. The observed continuity claim rests on original media, same native window visibility checks and actual view/window attachment, not an inferred nonzero More epoch. Root tracking counters were 1/0.

The original native recording is 1920×1080, 40.000seconds with 42 sparse decoded frames; its last changed frame at 13.901667seconds is held through the container's end. No interpolated or fabricated end frame is included. Recorder PID 12295 exited 0 after 68.540seconds, within the predeclared 85-second bound. Root inspected the decoded frames covering opening, refresh and held-open result; this proves that bounded observed journey, not continuous high-frame-rate lifecycle telemetry.

This is a hosted **Intel/x64 synthetic DEBUG early-entry** proof with in-memory settings/accounts, a fixed synthetic plugin and OS network denial. It does not prove ordinary shipping startup, live provider authentication, ARM behavior, or upgrade compatibility. Prior failed runs remain failures with their original classifications; this report does not relabel them.

[Raw receipts, original media, input maps and checksums](results/42247247540/) are retained without App ZIPs or compiled products. `artifact-sha256.json` is the original full hosted manifest (including omitted build artifacts); `PUBLICATION_SHA256.json` covers exactly the published evidence files. The independent validation's earlier `rootManualAcceptancePending:true` is preserved as historical metadata; the separate later `ROOT_ACCEPTANCE.json` records acceptance.
