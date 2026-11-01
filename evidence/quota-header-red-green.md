# Critical cue: frozen header layout regression

Codex review identified a height change when a metric enters the critical tier during an open menu's compatible live update. `MetricRowHeader` used the live critical flag in both its visible and hidden measuring headers.

On the original head `54e543b2c2f3cc970b8afe0ced35818c60c0ee4f`, the new `critical warning preserves header height at narrow widths` test failed: at 220 and 228 points, healthy height was 16 and critical height was 31. Other threshold/exclusion tests passed.

The fix always reserves the glyph's width, sets opacity to zero when healthy, and hides the inactive warning from accessibility. The new test passes across widths 180 through 340 in steps of 8, with the frozen layout title held at 89% while the displayed value is 90%. All four critical-headroom tests and the broader 139-test Swift Testing harness passed; `make check` passed with zero lint violations. Source commit: `2c84493b67dd736df387635fedd790fc940f90ab`.

The refreshed full-card light/dark PNGs are byte-identical to the earlier after-images at the normal card width. The manifest now records the fixed source commit. This is a layout regression test using production SwiftUI through NSHostingController; it does not construct a live NSMenu or load real provider accounts.
