# Cursor private CLI cache regression proof

Immutable baseline: `ec61c49dd71c3aa6efe33162762ef2164ecfaea1`. Full four-file candidate delta: [candidate.patch](candidate.patch), SHA256 `be191b9907d86b00916c2a3b5c6d07658c295748c21c655d74b20e18e85fbeee`.

Two isolated macOS 26 matrix jobs compile the full production App/Core/CLI modules. RED applies only the two test-file hunks and runs CursorAccountBoundaryTests plus the entire CLIUsageCacheTests suite. It requires actual runtime failures in both the unified private-cache evidence test and the production CLI renderer test; setup/compiler failures do not count. GREEN applies all four hunks and runs the original five auth suites plus the complete CLI cache suite. It requires all six suites passing and exit 0.

The production CLI renderer fixture writes and reloads the private disk cache, then invokes the real `CLIRenderer` for both independent and unified allowances. No imports, production flow or renderer implementation are replaced. The original auth controls remain unchanged outside the declared test additions. Production source maps, selected tests and hashes, complete harness and candidate patches, logs and verdict are retained. Every input hash must remain unchanged during tests.

Independent review found no blocking issue: only Cursor cache entries retain the explicit pool classification, after the existing pool-shape validator accepts it; private cache identity stays stripped. The descriptor permits missing identity for that explicit non-identifying evidence while rejecting an explicitly conflicting provider. Legacy weekly shapes and non-Cursor cache entries do not gain classification. Generic scoping and authentication/cookie-source behavior are unchanged.

The existing scrubber, keychain denial and native process containment remain active. This is a synthetic disk-cache-to-production-renderer proof, not an installed CLI process using a real locked keychain or live provider. Prior auth, cooldown and dropdown proof runs are preserved.
