# Overview sharing proof

Synthetic data only. Captured on disposable macOS CI runners on 2026-09-16.

[Run 35080115429](https://github.com/Chipagosfinest/CodexBar/actions/runs/35080115429), source `63147ed6123a6a3fbc56f8bf490b3ad4ca5fc58b`, passed all 17 `ShareStatsTests`, including PNG/TIFF named-pasteboard round-trip coverage. The actual exported 1200 × 630 image below was visually inspected.

The same run dispatched the actual overview menu action, opened a visible preview, and passed filtered-payload assertions. Capture failed because the hosting view had zero bounds before window layout. It did not reach the Copy Image action. The export image is not proof of clicking Copy Image or an installed desktop widget.

A test-only correction explicitly lays out the window before capture, following [Apple NSWindow.layoutIfNeeded](https://developer.apple.com/documentation/appkit/nswindow/layoutifneeded()), accessed 2026-09-16. It does not assign a manual view size. Corrected native interaction proof is pending.

![Synthetic exported usage image](share-stats.png)
