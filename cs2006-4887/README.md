# PR 4887: small widget keeps its low quota

Synthetic data only: a local fixture answers provider hosts and no real account is used.

| Run | Product | Kit | Package run |
| --- | --- | --- | --- |
| [Before](https://github.com/Chipagosfinest/CodexBar/actions/runs/41393837064) | `23bf4c17e7bc76c87dd0b75bc30f776cbac8333d` | `81eb5f8d1` | `41370581783` |
| [After](https://github.com/Chipagosfinest/CodexBar/actions/runs/41393792189) | `51bed06f81baafe73a963eecd299f391cefc8233` | `ec14e8470` | `41387845616` |

Both runs use the same test code and fixture; the kit commits differ only in which package they select. PR head `ad40a7d7a` changes only `WidgetLowQuotaInkTests.swift` after `51bed06f8`.

Both runs conclude **failure** because the final pager step fails on both heads. See `*-ui-test-errors.txt`. Whether that is the harness or the product is not established. It is not caused by this change.

`*-small-tile-tree.txt` is the installed tile's accessibility tree. `regression-*.log` are local Swift Testing runs; `no-vision` forces text recognition off, matching the CI Mac. `render/` holds offscreen renders of the production views from `51bed06f8`.
