# Independent terminal validation — verified

[Hosted run](https://github.com/Chipagosfinest/CodexBar/actions/runs/42213014438)
completed successfully, attempt1. Artifact13499883105 was downloaded and independently checked.

- Exact product725fb4fdda831b5cca8bf265d2c066aa8ebc04ca; controller045c66b06a0216ac49509026937b9caa1c56698b.
- Actual CodexBarCLI target built with locked dependencies in129.516seconds, exit0.
- Writer PID4444, fresh reader4445, cleanup4446; all three native CLI processes exited0.
- Both persistence values1800000000/300 match across process boundary. Public coordinator reads return active/299seconds at t+1 and false at expiry.
- All receipts confirm real production shared storage, UserDefaults.standard fallback, no TaskLocal/injected defaults, TestProcessSafety false.
- UUID-derived profile hash independently recomputed from the declared synthetic absolute path. The two cleaned keys match that exact profile; cleanup code checks both nil after removal and synchronize. No broad reset is used.
- Host before/after hashes for ALL4401tracked inputs exactly match independently prepared local maps;4399remain unchanged. The only modified files are the declared CLI early hook and append-only Core bridge; the only added source is the adapter.
- Original product Core bytes concatenated with the downloaded bridge independently reproduce the recorded post-overlay Core hash. Existing production lines are unchanged.
- The uploaded adapter hash and overlay manifest hash independently match metadata. Runtime child has allowlisted environment, no SWIFT_TESTING/XCTest/provider credentials, and a network-denying sandbox.
- Xcode26.6/Swift6.3.3, macOS26.6.2 arm64. No provider, login or GUI path was entered. Local standard preferences were never accessed.

## Exact evidence

[REPORT](REPORT.md), [result metadata](result.json), [write receipt](runtime/write.json),
[read receipt](runtime/read.json), [cleanup receipt](runtime/cleanup.json),
[full overlay/source/build-input hashes](overlay-manifest.json), [declared patch](declared-overlay.diff),
[actual CLI build log](build.log), [toolchain](toolchain.txt).

The recorded actual executable SHA256 is
`73dbbb9a2a4db3f3af20602c328c95d72e8e89ca84baacbbbdace0e83225188b`.
The host hashed the real built executable; its bytes were not uploaded. Independent artifact validation therefore
checks the recorded binary hash/provenance, not a second local hash of executable bytes.

This proves the instrumented built CLI early entry's actual production cooldown persistence owner across fresh
processes using synthetic nonce keys. It does not establish an ordinary provider refresh, real credentials,
GUI app startup, or stable-release upgrade. No new run or retry was started for publication.
