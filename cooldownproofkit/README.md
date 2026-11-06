# Built CLI standard-preferences cooldown restart proof (not executed)

Exact product: #5001 `725fb4fdda831b5cca8bf265d2c066aa8ebc04ca`.
All files here are proof-only. No product/evidence checkout was changed, no CLI
was launched, and no local standard preferences were read or written.

## Feasibility and proof boundary

The public coordinator readers (`isInCooldown`, `cooldownRemainingSeconds`) read
its actual shared state and persisted `UserDefaults.standard` fallback. They
compute a profile ID from the supplied absolute CLAUDE_CONFIG_DIR and read scoped
preference values. Their call graph does not load a credential file, query the
Keychain, launch a browser/Claude subprocess, or request a provider endpoint.
`ClaudeConfigPaths.credentialsURL` only composes the supplied absolute path;
profile hashing uses standardizedFileURL.path, not resolving symlinks/file I/O.

No existing shipped CLI command exposes this operation alone. The production
writer is private `recordAttempt`; the public `attempt` path checks for Claude CLI
and may touch real auth. Calling it would violate this proof's constraints.
Therefore the declared overlay adds a DEBUG package-only wrapper IN THE SAME Core
source file, appending only. It calls the unchanged private production writer
with `sharedState`. The wrapper asserts currentStateStorage === sharedState,
persistsCooldown == true, defaults == nil, and !TestProcessSafety.isRunning.
There is NO TaskLocal, injected defaults, testing-state reset, or mocked writer.
The second fresh CLI process calls only public readers.

This is an instrumented built CLI entry invoking the real production persistence
owner. It is NOT an ordinary provider refresh/login, real-credential proof, or
packaged GUI app/upgrade proof. No new API is committed or released.

## Declared overlay and build

Use a fresh hosted disposable checkout at the exact SHA, with no uncommitted or
untracked input. Do not use the product worktree or an active evidence checkout.

```sh
python3 prepare_overlay.py \
  --apply-to-disposable-copy /absolute/disposable/cooldown-checkout \
  --manifest-output /absolute/evidence/overlay-manifest.json
```

Only CLIEntry.swift's early hook and an APPEND to the coordinator are allowed;
PackagedCooldownProof.swift is the only new source. The installer checks append
prefix equality and records hashes of every tracked input before/after, plus
adapter and bridge hashes. Any original Core-line edit is forbidden.

Build on macOS through the repository's real target:

```sh
swift build -c debug --product CodexBarCLI
swift build -c debug --show-bin-path
```

Resolve CodexBarCLI beneath the returned bin path. Preserve compiler/build log,
macOS/toolchain version, target product SHA, overlay manifest, executable SHA256,
and raw phase receipts. Do not classify compiler/setup failure as behavior proof.
Do not compile a substitute Foundation-only executable.

## Three separate real processes

Generate a UUID ONCE, keep it and the same absolute output/profile-base arguments
for all phases, and invoke the SAME freshly built CodexBarCLI executable. Every
invocation exits before ordinary CLI parsing/plugin/provider startup.

```text
CodexBarCLI --packaged-cooldown-proof write UUID /absolute/evidence/runtime /absolute/disposable/profile-base
CodexBarCLI --packaged-cooldown-proof read UUID /absolute/evidence/runtime /absolute/disposable/profile-base
CodexBarCLI --packaged-cooldown-proof cleanup UUID /absolute/evidence/runtime /absolute/disposable/profile-base
```

Run cleanup in the host controller's finally/trap even if read fails. Preserve its
receipt. Do not use resetForTesting, removePersistentDomain, prefix deletion,
cfprefsd termination, or any broad preferences cleanup.

Use a minimal child environment with PATH/system locale only; remove ALL
SWIFT_TESTING, SWIFT_TESTING_ENABLED, TESTING_LIBRARY_VERSION, XCTest* markers,
provider tokens/cookie paths and CLAUDE_CONFIG_DIR/CLAUDE_SECURESTORAGE_CONFIG_DIR.
The adapter asserts !TestProcessSafety.isRunning. In DEBUG, test-mode otherwise
redirects credentialsProfileIdentifier to a shared isolated test URL, invalidating
a UUID-profile proof. No test overrides are installed.

HOME/CFFIXED_USER_HOME may be disposable but are NOT an isolation claim. On macOS
the same executable's standard preference domain can be shared across differing
homes; the proof intentionally uses that REAL standard domain. Each UUID yields
a distinct synthetic profile hash and only TWO nonce-scoped keys. The wrapper
asserts this profile differs from the ambient default so legacy global keys are
never read/migrated/removed. The write phase refuses preexisting nonce keys.

## Required receipts and assertions

- write.json: real production writer persisted fixed nonsecret timestamp
  1800000000 and interval 300; synchronize succeeds; in-memory production reader
  reports cooldown active. Process exits normally.
- read.json: writer PID differs from fresh reader PID; nonce/profile match;
  actual standard persisted timestamp/interval are unchanged; public coordinator
  reports true at t+1, remaining 299, false at t+300. This is restart durability,
  not merely reading a same-process cache.
- cleanup.json: only the two derived nonce keys were removed and confirmed nil.
- The CLI never enters `attempt`, credentials loading, Keychain/browser access or
  provider networking. Only proof receipt files and nonce preference keys are
  written; the synthetic profile directory/credential file is never created or read.

An actual host trace / terminal recording of the three invocations plus receipts
and binary/hash identity is the observable proof. Source assertions alone are not
execution evidence. If process IDs unexpectedly repeat, the proof fails rather
than accepting an ambiguous restart claim; rerunning requires a new UUID and
cleanup of the previous UUID's two keys.

## Current validation

Swift parse/format/lint and Python compilation are static checks only. Full actual
CLI compilation and three-process execution are pending on the hosted proof
owner. No local standard preferences access is authorized or performed here.

## Dedicated hosted execution

This evidence branch owns only `.github/workflows/cooldown-runtime-proof.yml`
and `cooldownproofkit/`. One branch push starts one macos-26 job; do not also
dispatch it. The runtime controller refuses local/nonfork execution, builds the
actual CLI using the pinned Package.resolved, checks unchanged tracked inputs,
and invokes write/read/cleanup with a minimal environment and network-denying
sandbox. Cleanup runs from `finally`. Runtime homes/temp directories are excluded
from artifacts; only declared source, receipts, logs, hashes and REPORT are uploaded.
