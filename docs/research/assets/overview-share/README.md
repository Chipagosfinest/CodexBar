# Overview sharing proof

Synthetic data only. Captured on disposable macOS CI runners on 2026-09-16.

[Run 35080951899](https://github.com/Chipagosfinest/CodexBar/actions/runs/35080951899), source `f73a08a2f`, passed all 17 `ShareStatsTests` and the explicitly selected native menu test. The native test dispatched the real overview action, opened its visible preview, and verified a selected $2 payload excluded a hidden $900 source. Return activated the actual default Copy Image control; the test verified a new clipboard write containing PNG and TIFF, with PNG dimensions 1200 × 630. Clipboard writes occurred only in the disposable CI runner.

The exported image was visually inspected. The two hosting-view captures below were also inspected: they show the filtered card, but **omit the native button row**. They therefore do not establish visible copied feedback. Do not treat a file named `copied` as proof of that label. These are native test-host results, not installed desktop-widget proof.

- [Preview hosting-view capture](overview-share-preview.png)
- [Hosting-view capture after successful clipboard assertions](overview-share-preview-copied.png)

Current source `b7d76395a` additionally checks the actual menu title and preview accessibility labels for Copy Image and Image copied in English/German. [Run 35082637466](https://github.com/Chipagosfinest/CodexBar/actions/runs/35082637466) is pending. Task-local language propagation and native labels must pass before claiming non-English UI proof.

The layout correction follows [Apple NSWindow.layoutIfNeeded](https://developer.apple.com/documentation/appkit/nswindow/layoutifneeded()), accessed 2026-09-16. Accessibility traversal follows [Apple accessibilityChildren](https://developer.apple.com/documentation/AppKit/NSAccessibility-c.protocol/accessibilityChildren) and the repository's existing SwiftUI-node fallback. No manual hosting-view size was assigned.

![Synthetic exported usage image](share-stats.png)
