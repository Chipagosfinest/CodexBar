# Cooldown standard-preferences restart proof: VERIFIED

Product: `725fb4fdda831b5cca8bf265d2c066aa8ebc04ca`. Controller: `045c66b06a0216ac49509026937b9caa1c56698b`.
Run: https://github.com/Chipagosfinest/CodexBar/actions/runs/42213014438
Classification: `verified_runtime_persistence`.

The actual CodexBarCLI target was built with a declared early-entry adapter and an append-only DEBUG bridge.
That bridge invokes the unchanged production `recordAttempt(...sharedState)` owner, which falls back to
`UserDefaults.standard`. No TaskLocal/injected preferences or test-state reset was used.
Separate writer/reader processes must agree on nonce profile, timestamp1800000000 and interval300;
public readers must return active/299seconds at t+1 and expired at t+300. Cleanup removes only the two nonce keys.

Binary SHA256: `73dbbb9a2a4db3f3af20602c328c95d72e8e89ca84baacbbbdace0e83225188b`.
Fresh-process read verified: `True`.
Nonce-only cleanup verified: `True`.

Runtime child environment is allowlisted, has no SWIFT_TESTING/XCTest/provider credentials, and HTTP/network
is denied by the macOS sandbox. HOME is disposable but NOT claimed to isolate CFPreferences.

This proves the instrumented CLI persistence owner's synthetic restart behavior only. It does not prove
ordinary provider refresh, login, real credentials, packaged GUI startup, or upgrades.

Raw source/binary hashes, overlay manifest, build log and all three phase receipts/logs accompany this report.
No compiler/setup failure is counted as behavioral proof. No retry is triggered by a timeout.
