# #4881 live header height envelope

Full CodexBar app target built and run from exact refs on a local Mac with the Command Line Tools recipe (see `environment.txt`; macOS 26.5 SDK plus local SwiftUI macro shims). The fixture opens a real `NSMenu` hosting production `UsageMenuCardView` and `MenuCardRefreshMonitor`. A phase file changes the live model while the menu stays open, so the frozen layout model and live model differ as they do in tracking.

- Before: `7dc9174267b5809433dbb326a233f30d3f5cf01d`. After: `44e51249b2afcd7120213a17b61e37b749a3f6a8`. The SHA is visible in each capture.
- Long-title mode: frozen 99%, live 100%. `fixture.swift` picks the first title where the frozen string fits one row at the real card width and the live one does not, measured with production `MetricRowHeader`.
- Threshold mode: 89% to 90% to 89%. Captures are from one open menu.
- `source-integrity.txt` diffs the built `Sources` against the exact after ref: only the entry hook in `plumbing.patch` and the added fixture differ.
- Captures use `screencapture -l` on the fixture's menu window, never a screen region. All data is synthetic. HOME was isolated and Keychain access disabled. No accounts, transports or provider probes.

Not proven: real provider transport, `StatusItemController` routing, or a user clicking the status item. Pointer-driven menu dismissal was not exercised. Appearance is light only.
