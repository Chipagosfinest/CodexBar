# Packaged Overview overflow plugin refresh proof (NOT executed)

Target #4900 exact `e8a0cca51036fa8f30362a0710754d812ace34a3`.
This scratch scaffold is never a shipped feature. It does not modify the product
or evidence worktree and has not been built, installed, or launched locally.

## Path and controlled data

The adapter follows the existing DEBUG early-entry pattern, before ordinary
CodexBarApp initialization. It builds the real StatusItemController/system status
item/root merged Overview menu with 14 synthetic Claude token accounts, two
synthetic quota snapshots, and one non-top-level plugin. The plugin is pushed into
the real `overviewOverflow` More submenu. The initial captured plugin card has
usedPercent 5 and `Synthetic prior refresh failure`; Show Used is explicitly true
so the card displays 5%, not its 95% remaining complement.

A fixed, declared JavaScript file is the ONLY discovered user plugin. Its entire
fetchUsage body returns `{ primary: { usedPercent: 42 } }`; no network, shell,
filesystem or arbitrary externally supplied JS runs. The production
UserProviderPluginLoader uses a dedicated providers directory, cache and rejecting
transport, and the production approval store accepts only this fixture binding.
Settings initialization in required test-safety mode skips real plugin discovery.

After the host captures the root and overflow card OPEN, an explicit nonce file
initiates `store.refreshUserPlugin(fixtureID)` and then the production
`refreshOpenMenusAfterUserPluginRefresh` completion path. The real guarded menu
rebuild scheduler is enabled; it is not replaced with a synchronous view swap.
The adapter independently requires store 42/error nil, no transport call, replaced
nested menu item AND view, fresh production cache fingerprint, same open root and
same root tracking epoch. Every phase is timestamped in runtime-receipt.json.

Those checks bind source state to the actual replaced captured view. They DO NOT
prove the OS continued showing the overflow card. Continuous native UI evidence
must demonstrate More/card remains visible and updates WITHOUT closing/reopening.
If AppKit closes the child on parent rebuilding, report that observation as a
failure/limitation; do not claim a model-level replacement was visible acceptance.

## Host preparation/build

1. Wait until the current proof job is terminal. Use a NEW clean disposable
   checkout at the exact product SHA. Never use the product or active evidence
   checkout. Full Xcode/xcodegen and a clean hosted GUI session are needed.
2. Copy this scratch directory to the host and run:

   ```sh
   python3 prepare_overlay.py \
     --apply-to-disposable-copy /absolute/disposable/footer-checkout \
     --manifest-output /absolute/evidence/footer-overlay-manifest.json
   ```

   Full git status (including manifests/scripts/untracked files) must be clean.
   The installer adds only PackagedFooterProof.swift to the real App source
   target and one declared early entry call in CodexbarApp.swift. It records
   hashes for all tracked inputs and all source files before/after. Every
   production source file other than the declared entry hook stays identical.
3. In the disposable copy:

   ```sh
   CODEXBAR_SIGNING=adhoc ./Scripts/package_app.sh debug
   ```

   This supported script creates that checkout's CodexBar.app with debug bundle
   ID `com.steipete.codexbar.debug`, empty Sparkle feed/no update checks. Adhoc
   signing avoids signing-identity Keychain discovery. Do not install or overwrite
   the user's app. Preserve logs, Info.plist, actual binary SHA, overlay manifest.
4. Launch that app's executable directly with `--packaged-footer-proof` and a
   minimal sanitized child environment. Before ANY Swift static initialization:

   ```text
   SWIFT_TESTING=1
   CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS=1
   CODEXBAR_TEST_CODEX_FILE_ISOLATION=1
   CODEXBAR_TEST_SESSION_FILE_ISOLATION=1
   PACKAGED_FOOTER_PROOF_PRODUCT_SHA=e8a0cca51036fa8f30362a0710754d812ace34a3
   PACKAGED_FOOTER_PROOF_NONCE=<new UUID>
   PACKAGED_FOOTER_PROOF_ROOT=/absolute/disposable/footer-runtime
   PACKAGED_FOOTER_PROOF_OUTPUT=/absolute/evidence/footer-runtime
   HOME=/absolute/disposable/footer-runtime
   CFFIXED_USER_HOME=/absolute/disposable/footer-runtime
   XDG_CONFIG_HOME=/absolute/disposable/footer-runtime/.config
   CODEXBAR_CONFIG=/absolute/disposable/footer-runtime/config.json
   CODEX_HOME=/absolute/disposable/footer-runtime/codex
   ```

   Remove allow-Keychain/test credential fixture overrides and ALL provider
   credentials/cookie env variables. HOME alone is not macOS CFPreferences
   isolation; required test mode and in-memory defaults are the actual boundary.

## Actual UI acceptance sequence

- Wait for `ready-initial-5-error` receipt; no blocked HTTP or first-party refresh
  is allowed. Click actual status item identifier `codexbar-packaged-footer-proof`.
- Keep actual Overview root OPEN, open More/overflow, show Synthetic Overflow Meter.
  Capture 5% and the synthetic error. Record the pointer/native menu, not a static
  replacement view. Save a continuous recording across refresh.
- While the card is visible, write `trigger-refresh.json` to the output directory:

   ```json
   {"nonce":"<nonce EXACTLY as runtime-receipt.json serializes it>","action":"refresh-fixed-fixture"}
   ```

  This is the only accepted action; no arbitrary commands or plugin source are
  loaded from the control file. The UUID is not a provider credential.
- The timer runs in common modes while NSMenu tracks. Observe receipt phases
  `refreshing-fixed-plugin`, `awaiting-guarded-rebuild`, then
  `replaced-in-open-root-native-capture-required`. Root begin/end counters must
  remain unchanged across refresh, card/view identities change, and fingerprint
  must bind the new store payload. A failure to rebuild within 15 seconds fails.
- WITHOUT reopening root OR More, capture 42% with error gone. Capture root/menu
  identity receipts and zero transport counts alongside the native UI recording.
- Repeat in the other system appearance with a new proof run if needed. Quit via
  the existing menu when complete. Do not click real provider/account/settings/
  external-link actions.

If child tracking notifications are not emitted by this macOS version, their
absence is not visibility evidence either way. Root tracking receipts and open
controller state prove only root lifecycle; the recording must prove the child
stayed open and actually repainted. If common-mode Task execution stalls while
tracking, preserve logs/phase timeout and report it; do not reopen the menu to
manufacture a passing result.

## Isolation and declared limitations

- All settings are in-memory, migration complete and Keychain disabled BEFORE
  init. Disposable config, plugin approval/cache and receipts only. Empty
  credential stores/stateful in-memory token accounts, no real auth files.
- Explicit UsageStore startup `.testing`, empty environment base, no startup
  hydration/refresh timers; agents, storage discovery, status, web and cost off.
  No ordinary AppDelegate/startup path is entered.
- Menu refresh MUST stay enabled for the actual guarded rebuild/open-root owner.
  Only automatic menu-open provider fetch is deferred 3600s through the existing
  DEBUG delay setter; explicit plugin completion/rebuild still executes normally.
  Seeded current Claude/Codex snapshots avoid missing-data retries. Any unexpected
  first-party/cost refresh fails immediately; global URLProtocol rejects HTTP(S),
  and the plugin's separate injected transport rejects all requests/counts them.
- Registry scans only the single fixed fixture directory; no real discovery or
  arbitrary plugin execution. Synthetic JS runtime execution is intentional.
- The control file initiates production refresh owners rather than simulating a
  mouse click on the card's Refresh button. UI input to that button is not proven.
- This is an instrumented packaged DEBUG app with synthetic/test-safety startup,
  not normal shipping startup/auth/plugin discovery or live provider proof.

## Gates still required

Adapter format/syntax parse/strict lint and Python compile are static checks.
Actual App-target compilation must validate all access/initializer/notification
signatures, then actual native UI capture must validate the user journey. There
is no local compile/runtime/UI claim. Keep compiler/setup failures distinct from
behavior failures. Existing permanent regression/core CI evidence is separate.

## Dedicated hosted controller

This branch owns only `.github/workflows/footer-app-proof.yml` and `footerproofkit/`.
One branch push launches one macos-26 job; do not also dispatch it. The immutable
native helper is copied from controller f79b05bb5da0f9be4389a48dd66710e58415a9fc.
It validates actual display coordinates and compares actual screen regions with
captured native window pixels. The footer driver requires the same root and More
CGWindow IDs throughout the one controlled transition, and never reopens either.
A stopped/closed/replaced native More window fails the automated attempt.

Original full-screen PNGs, root/More crops, AX snapshots, timestamps/receipts,
a continuous40second MOV, actual built app zip and all bundle/source hashes are
retained. Automated guards never mark original media accepted; human/agent
inspection of the actual original screenshots and movie is a separate gate.

## UI-only retry after first native viewport failure

Run42218270832 packaged the actual e8a/cfa app successfully. Its driver rejected the offscreen
More item before any refresh. The root was taller than the display; original screen/AX/receipts
are retained in that immutable artifact. No behavior acceptance was claimed.

The UI-only controller reuses that exact ZIP, source-overlay maps, all bundle-file hashes and
binary9f434d0d9f35adaa9421456f8e03f2ee90e6931aadcee414cedd10a497c4a9ff; no app rebuild or adapter change.
Navigation observes native down-chevron pixels in each current root screenshot, bounds-checks
the target against the actual window/display, and dwells at most12steps/12seconds while fetching
fresh AX. More must become visible inside the actual root (excluding arrow strips). Same open
root/More identities and rootBegin1/end0 remain required after the nonce refresh trigger.

A predeclared40second original clip starts before root click. The fixed finalization deadline is
85seconds from recorder launch. Before this first UI retry, prior actual chart run42222113762
observed49.503seconds launch-to-exit for a valid25second clip;85seconds reserves the observed near2x
wall time for40seconds plus5seconds margin. This is a predeclared bound, not a timeout increase after
failure, and does not establish a recording implementation cause. Both menus stay open until actual poll-observed exit0 and valid
media duration; Escape/app cleanup comes afterward. Real exit0/exit3/live-timeout controls run
on host. Pixel controls accept down-chevrons and reject blank/up-chevrons at1x/2x. These are guard
controls, not UI proof. Final acceptance still requires original continuous-media inspection.
The prior cold-build workflow is manual-only, so one proof-branch push launches only the UI retry.

## Evidence-specific native group capture correction

Second run42224431572 scrolled/opened actual More correctly and visibly captured5%+error. It
stopped before refreshing because native `screencapture -l rootID` returned the root+More union
615x668 while the comparison expected root-only310x668. Original unchanged PNGs independently
match the observed union with mean RGB error0.00002139; wrong root-only bounds give0.357645.
This was a capture-controller geometry failure, not a product refresh verdict.

The followup selects capture geometry only by exact PNG dimensions and freshly observed owned,
visible menu IDs: individual target menu or the root+More union. It validates actual CG ownerPID,
menu layer101 and display bounds. It never searches geometry by similarity score. The same936
samples and0.13tolerance then compare original native pixels with the actual full-screen capture.
Pointer targets continue to use individual menu/display bounds, never empty union space.

`capture-controls/` contains unchanged original synthetic hosted PNGs and source SHA/provenance:
chart42222113762 supplies a real root-only capture; footer42224431572 supplies the real group.
Offline controls exercise the exact same pixel comparison using recorded display geometry,
accept both positive cases and reject wrong dimensions, unowned menu geometry and wrong pixel
rectangles. The live driver always uses actual current CG display bounds. Two failed runs and
all raw original artifacts remain separate. No app, source adapter, navigation, recording budget
or refresh oracle changed for this evidence-specific correction.

## New declared adapter build after third-run oracle abort

Third run42225984906 reached the nonce refresh after passing actual root+More5%/error captures.
The app then aborted at proof-adapter327, the immediate fresh-cache assertion. Root-tracking and
store42%/nilerror checks had passed; this was not evidence of a product menu-closure defect.
The old baseline was captured before actual menu opening, and any later identity difference
could prematurely enter the assertion. Its raw app log, screenshots and classifications remain retained.

The corrected adapter is a NEW declared build against the same exact e8a product. It cannot reuse
the old binary. At nonce arrival it binds the current nested card/view/More to actual NSView.window
numbers and PID-owned visible native windows observed by the driver, records identities, fingerprints
and root/More epochs, then invokes the unchanged real refresh owner. It installs the existing DEBUG
production root-rebuild observer seam in the same order as OverviewOverflowPluginRefreshTests and
requires a post-owned-completion rebuild before considering replacement. That observer is declared
instrumentation: it also makes usesTaskSchedulerForTesting true; the explicit plugin-completion path
already requests the task scheduler (duringTracking defaultsfalse). This is an instrumented owner-path
proof, not an ordinary uninstrumented startup claim.

All eventual store42%/nilerror, scoped current card+view replacement, fresh fingerprint, view attached
to the same original More native window, root/More epochs/visible windows and15second deadline
requirements remain. Interim/loading views wait with diagnostics. Failure states write receipts and
preserve the native app for capture instead of aborting. The independent driver still requires visible
AX42%/clearederror, same root/More windows and original continuous media;85seconds from recorder
launch remains fixed. No source/product behavior, palette, real login or provider access is introduced.

`run_oracle_controls.py` compiles the verbatim pure decision block from the actual adapter. Thirteen
cheap deterministic cases reject stale preopen baselines, wait on interim or detached renders,
accept only complete post-rebuild state, and fail wrong scope, closed/reopened menus and timeouts.
The new build workflow runs those controls, process controls, arrow controls and original PNG capture
controls before the cold App build. Both older build/UI workflows are manual-only; one new push
handler performs the declared build plus native journey. No retry dispatch exists.

## Candidate UI-only navigation repair draft (not executed)

Branch `proof/footer-candidate-ui-only-20261106` uses the registered manual-only
`footer-app-ui-retry.yml`; a branch push must trigger zero jobs. Dispatch requires
root approval. It reuses run42242259960 artifact13516399711 byte-for-byte, including
actual x64 binary `cdcb62d6e2e6601b8322c2714cac5730c16bc9eb7d07d0b1d6ea7556c38b4c12`.
There is no App compilation or `.build` reuse. Four archive digests, full tracked
inputs/source maps, every bundle file and strict codesign are checked again.

The prior run failed PRE-refresh: native scrolling moved More from y930 to y906,
so the stale y942 pointer highlighted Refresh. No plugin refresh was triggered.
The original screen/MOV/receipt remain failure evidence, not candidate acceptance.
Only the pre-refresh hover is repaired: fresh live root-scoped AX More row and
parent hierarchy identity, same owned CG root/epoch/display, maximum3 moves only
when the center changes, within the original20sec opening deadline. The AX
identity is the observed hierarchy path/role/title, not an asserted AppKit pointer.
Each hover records fresh AX and actual-screen context; it never clicks, closes,
reopens, unhighlights, or commands refresh. After actual child5/error acceptance,
all existing owned refresh/42-clear/newcard-view/window/epoch oracles and40sec
movie/85sec recorder budget remain unchanged.

Offline hover controls cover recorded930→906, same-center/no extra post, move
limit, wrong PID/root/layer/parent, closed/reopened root, Refresh, ambiguous More,
changed identity, offscreen and nonfinite targets. Host GUI preflight and existing
arrow/process/capture controls precede the sole UI attempt. Original screenshots
and continuous media still require independent manual acceptance.
