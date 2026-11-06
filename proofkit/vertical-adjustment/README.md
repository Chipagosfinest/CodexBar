# Saved menubar adjustment evidence

[Final report](REPORT.md) contains the accepted range proof, original native images, exact inputs, and preserved rejected/limited results.

Final inputs: baseline `5614c2736caf037cd5205151194dd036f205f792`, production-only [candidate.patch](candidate.patch) SHA256 `76ec19a7fa42d2038e1207354c1c3e8a75d168308c0d0fe37754f099dd594b80`, and frozen test oracle `07a4330a06c1ca450418b9ce6619100e21dc8fed472ce381d8ab1ffe75cbcf0a`. Final source file SHA256 is `89d2133a662f5835610e48154ae3381e349b86f8bd091660b06ff172f63a8be7`.

The evidence workflow compiles full production App/Core modules on macOS 26. Only `MenuBarUsageTotalTests` and its three unchanged helper sources are selected. The repository test environment scrubber, keychain denial, native process containment, and disposable test HOME retention remain active.

`range_proof.py prepare --expect green` requires a pristine baseline checkout, the exact source-only patch header, unchanged oracle bytes, and the retained genuine range RED witness from run42208591132. It saves complete source/test maps and the full temporary harness patch. `verify --expect green` requires all21 methods passing, all declared bytes unchanged, and no build/setup/expectation failures.

The final workflow deliberately reuses actual range RED instead of rerunning it for a controller-only correction. The corrected controller was independently exercised in isolated local clones through both prepare→transition and direct GREEN preparation; those source-manipulation checks were not called runtime tests.

Only after deterministic GREEN does an optional step append [Render.swift.fragment](Render.swift.fragment), record before/after test hashes, and draw actual renderer outputs on native NSButton surfaces. Its structural verdict is separate from pixel acceptance. The four synthetic panels show0/±3 and0/±5, normal/high-contrast, calm/warning, light/dark, at production widths and fixed22-point heights. They are component fixtures, not installed-App or live-account journeys. Runtime masks additionally exercise±20 and intentional clipping/disappearance.

[inspect_pixels.py](inspect_pixels.py) reads original PNGs without rewriting them and reproduces the ±3 movement and zero-offset comparison. Additional ±5 translated/clipped comparisons are retained with the final artifacts. Prior compiler-only failure, limited unit GREEN with failed native motion, and limited±3 evidence are preserved in results/ and explicitly distinguished in the report.

The workflow triggers only for its declared script, patch, oracle, renderer, and workflow paths on the dedicated proof branch. Documentation publications use a standalone `[skip ci]` commit to preserve completed proof jobs. Required product CI remains separate.
