# Saved menubar adjustment: verified

The final renderer moves neutral content and warning capsules inside fixed 22-point canvases. Attachment bounds remain fixed, preventing NSCell from cancelling the saved adjustment. Large nudges translate and clip content consistently; fully clipped content is expected at the extremes.

**Final production head:** `22f44fba03118ddfbb88ddb470b960791ad1b09b`. Its source/test bytes independently match the hosted candidate inputs. Required upstream CI for this head is separate from this bounded proof.

| Gate | Actual result |
|---|---|
| Genuine range RED | 21 tests, 80 expected issues; both new range methods failed and all 19 existing controls passed |
| Final GREEN | **21 tests in 1 suite passed**, exit 0, zero issues |
| Native component capture | 1 opt-in render test passed; 4 original PNGs, 48 synthetic states |
| Actual ±3 motion | All foreground and capsule masks moved exactly 3 pixels in both themes |
| Actual ±5 clipping | 24 translated-and-clipped foreground/capsule comparisons: **zero mismatched pixels** |
| Zero appearance | All 8 light/dark state crops were **RGB-pixel-identical** to the prior padded candidate |
| Input integrity | All **1,446 production Swift files** and all **4 selected test/support files** matched the frozen inputs |

## Runtime provenance

- [Genuine RED run 42208591132](https://github.com/Chipagosfinest/CodexBar/actions/runs/42208591132) exercised the prior padded candidate `f967603f05180a8f91489e71810c61ec314db90aa5743da7433bceb131575847` with the strengthened physical oracle. [Original verdict and provenance](results/range-red-transition-controller-failed-42208591132). The subsequent controller transition rejected a correctly production-only patch, so that overall run failed **before GREEN ran**. This is preserved without rewriting its status.
- [Final GREEN run 42210318163](https://github.com/Chipagosfinest/CodexBar/actions/runs/42210318163), controller `f0c71171bb0dfc4f6d035e546e2a7e4d1609d86f`, reused the actual RED witness and ran the final candidate only. No RED test was repeated for the controller correction. [Original artifact 13497839723](https://github.com/Chipagosfinest/CodexBar/actions/runs/42210318163/artifacts/13497839723), [GREEN verdict](results/final-42210318163/verdict.json).

Inputs are baseline `5614c2736caf037cd5205151194dd036f205f792` plus [the production-only candidate patch](candidate.patch), SHA256 `76ec19a7fa42d2038e1207354c1c3e8a75d168308c0d0fe37754f099dd594b80`. Final renderer SHA256: `89d2133a662f5835610e48154ae3381e349b86f8bd091660b06ff172f63a8be7`. Oracle SHA256: `07a4330a06c1ca450418b9ce6619100e21dc8fed472ce381d8ab1ffe75cbcf0a`.

The full production App/Core modules compile; only test-target selection is bounded. All 18 original test bodies and the normal-leading pixel regression remain. The stronger attachment and native-button tests compare actual bitmap masks with independently translated/clipped zero-offset masks at **±3, ±5 and ±20 points, at 1× and 2×**. Positive zero-mask controls prevent an empty rendering from falsely passing. An effective attachment baseline alone is deliberately insufficient.

[Exact provenance](results/final-42210318163/provenance.json), [complete harness patch](results/final-42210318163/test-harness.patch), [all source hashes](results/final-42210318163/expected-production-source-sha256.json), [host environment](results/final-42210318163/environment.txt). Both isolated-clone controller preparation paths were checked before the final publication; those checks were not claimed as Swift runtime tests.

## Inspected native pixels

These are **synthetic production-renderer component fixtures on actual NSButton surfaces**, at production status-item widths and fixed 22-point heights. They are not an installed-App journey or live-account proof. Production template tinting and attributed titles are used; no glyphs were painted over. Each original image visibly identifies its synthetic inputs, baseline SHA and candidate patch SHA.

| Saved offsets | Light | Dark |
|---|---|---|
| 0 / −3 / +3 | [Original PNG](results/final-42210318163/vertical-adjustment-light.png) | [Original PNG](results/final-42210318163/vertical-adjustment-dark.png) |
| 0 / −5 / +5 | [Original PNG](results/final-42210318163/vertical-adjustment-large-light.png) | [Original PNG](results/final-42210318163/vertical-adjustment-large-dark.png) |

All four 700×290 originals were inspected by the proof owner and root. Both normal/high-contrast and calm/warning states move with the saved nudge. Visible clipping in the ±5 panels matches translating the zero mask within the fixed frame; it is not interpreted as a five-point centroid requirement. The ±20 contract is exercised by runtime masks, including disappearance, rather than by a claimed ±20 screenshot.

[±3 motion and zero-RGB comparison](results/final-42210318163/primary-pixel-acceptance.json), [±5 clipping comparisons](results/final-42210318163/large-clipping-acceptance.json), [48 actual render states](results/final-42210318163/states.json), [separate structural render verdict](results/final-42210318163/render-verdict.json). The deterministic oracle remained unchanged before rendering; its proof-only append has separately recorded before/after hashes and a complete [render harness](results/final-42210318163/render-harness.patch).

## Rejected and limited evidence

The initial initializer-order compiler failure was rejected as RED. A later 20-test GREEN failed native pixel acceptance because normal-warning capsules moved only 1/2 pixels for ±3. The padded 21-test candidate fixed ±3 and preserved zero pixels, but remained insufficient for the configured −20…20 range. Those original verdicts, failed/limited captures and hashes remain under [failed native acceptance](results/limited-green-visual-failed-42202916289), [limited small-nudge proof](results/limited-small-offset-42206524467) and [compiler-only attempt](results/compiler-only-42199396599). They do not contribute a false full-range success claim.

Existing environment scrubbing, keychain denial and native process containment remained active. No real account credentials were used. Root separately completed the full product `make check` with zero violations across 3,180 linted files, inspected all originals, and independently matched source, test and image hashes before publishing the product fix. [Curated artifact hashes](results/final-42210318163/file-sha256.json).
