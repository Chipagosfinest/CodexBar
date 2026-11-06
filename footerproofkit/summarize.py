#!/usr/bin/env python3
"""Preserve a readable classification; never turns source/AX receipts into manual UI acceptance."""
import hashlib
import json
import os
from pathlib import Path
import sys

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
verdict_file = out / "ui-verdict.json"
verdict = json.loads(verdict_file.read_text()) if verdict_file.exists() else None
built = out / "built-input-verdict.json"
preflight_file = out / "preflight/preflight.json"
preflight = json.loads(preflight_file.read_text()) if preflight_file.exists() else {}
preflight_ok = all(preflight.get(k) for k in ["preflightPassed", "actualCGEventOpenedNativeMenu", "axTrusted", "screenCaptureAllowed", "postEventAllowed"])
if verdict and verdict.get("automated_ui_state_checks_passed"):
    classification = "automated_native_guards_passed_manual_media_pending"
elif verdict:
    classification = "native_driver_halted_before_acceptance"
elif built.exists():
    classification = "built_app_driver_or_setup_incomplete"
elif preflight_ok:
    classification = "packaging_or_source_setup_failure"
else:
    classification = "native_GUI_preflight_failed_or_incomplete"
record = {"productSHA": "e8a0cca51036fa8f30362a0710754d812ace34a3",
          "controllerSHA": os.environ.get("GITHUB_SHA"), "runID": os.environ.get("GITHUB_RUN_ID"),
          "classification": classification, "manualOriginalMediaAccepted": False,
          "preflightPassed": preflight_ok, "uiVerdict": verdict,
          "boundary": "Proof-only packaged DEBUG startup with synthetic plugin; no ordinary startup or auth claim"}
(out / "terminal-classification.json").write_text(json.dumps(record, indent=2) + "\n")
report = f"""# Packaged Overview overflow refresh proof

Product: `{record['productSHA']}`. Controller: `{record['controllerSHA']}`.
Run: https://github.com/Chipagosfinest/CodexBar/actions/runs/{record['runID']}

Classification: **{classification}**. Original-media acceptance is still **pending**.

The intended actual native journey is one root menu and one More submenu kept open:
Synthetic Overflow Meter **5% + synthetic error → 42% + error cleared**. A nonce control invokes
the real plugin refresh owner and production guarded menu-rebuild completion. Captured-card/view identity,
production fingerprint, store state and root tracking receipts independently constrain the result.
Native window identity, AX states, actual-screen/window-region comparisons and one continuous original
screen recording constrain visibility. Those guards do not replace inspection of the original media.

The fixed JavaScript fixture returns42 without host calls; all other provider/cost refreshes are trapped.
A minimal test-safety child environment and OS network denial prevent real provider/auth startup.
The ordinary CodexBarApp init is bypassed by a declared proof-only early entry.

`package.log`, `app.log`, `driver.log`, `runtime/runtime-receipt.json`, AX dumps,
original PNGs/MOV, source overlay manifest, binary/bundle hashes and the built app archive are retained
when produced. Compiler/setup errors are not behavioral RED; no timeout triggers a retry or menu reopen.
"""
if verdict and verdict.get("failure"):
    report += "\nDriver stop reason: " + verdict["failure"] + "\n"
(out / "REPORT.md").write_text(report)
files = {str(p.relative_to(out)): hashlib.sha256(p.read_bytes()).hexdigest()
         for p in sorted(out.rglob("*")) if p.is_file() and p.name != "artifact-sha256.json"}
(out / "artifact-sha256.json").write_text(json.dumps(files, indent=2, sort_keys=True) + "\n")
print(report)
