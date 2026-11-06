#!/usr/bin/env python3
"""Hosted-only real CLI build and three-process, nonce-scoped standard-preferences proof."""
import argparse
import hashlib
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import time
import traceback
import uuid

PIN = "725fb4fdda831b5cca8bf265d2c066aa8ebc04ca"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def call(command, log, *, cwd, env=None, timeout=2400):
    started = time.time()
    with log.open("w") as output:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise RuntimeError(f"Bounded command timeout; retained {log.name}; no retry")
    return {"command": command, "pid": process.pid, "exitCode": code,
            "elapsedSeconds": round(time.time() - started, 3), "log": log.name}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkout", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("GITHUB_REPOSITORY") != "Chipagosfinest/CodexBar":
        raise SystemExit("Hosted fork-only: refusing local build/preferences execution")
    root = args.checkout.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    result = {"productSHA": PIN, "controllerSHA": os.environ.get("GITHUB_SHA"),
              "runID": os.environ.get("GITHUB_RUN_ID"), "runAttempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
              "classification": "setup_incomplete", "verified": False,
              "phaseCommands": [], "limitations": [
                  "Instrumented built CLI early entry calls unchanged private production persistence owner.",
                  "No ordinary provider refresh, login, real credential, GUI, or upgrade claim."]}
    binary = None
    child_env = None
    runtime = output / "runtime"
    runtime.mkdir(exist_ok=True)
    nonce = str(uuid.uuid4()).upper()
    profile_base = output / "disposable-profile-base"
    profile_base.mkdir(exist_ok=True)
    try:
        overlay = json.loads((output / "overlay-manifest.json").read_text())
        if overlay["productSHA"] != PIN or not overlay["coreBridgeAppendOnly"]:
            raise RuntimeError("Overlay provenance mismatch")
        result["build"] = call(["swift", "build", "-c", "debug", "--product", "CodexBarCLI", "--force-resolved-versions"],
                               output / "build.log", cwd=root)
        if result["build"]["exitCode"] != 0:
            result["classification"] = "compiler_or_build_failure"
            raise RuntimeError("Actual CLI build failed; not behavioral evidence")
        bin_result = subprocess.run(["swift", "build", "-c", "debug", "--show-bin-path"], cwd=root,
                                    text=True, capture_output=True, timeout=90)
        (output / "show-bin-path.log").write_text(bin_result.stdout + bin_result.stderr)
        if bin_result.returncode:
            raise RuntimeError("Cannot resolve actual build output")
        binary = Path(bin_result.stdout.strip().splitlines()[-1]) / "CodexBarCLI"
        if not binary.is_file():
            raise RuntimeError("Actual CLI executable missing")
        changed = [name for name, digest in overlay["afterTrackedInputSHA256"].items()
                   if sha(root / name) != digest]
        if changed:
            raise RuntimeError("Build changed tracked inputs: " + ", ".join(changed))
        result["binarySHA256"] = sha(binary)
        result["binaryPath"] = str(binary)
        result["overlayManifestSHA256"] = sha(output / "overlay-manifest.json")
        result["nonce"] = nonce
        result["classification"] = "runtime_incomplete"
        child_home = output / "disposable-home"
        child_temp = output / "disposable-temp"
        child_home.mkdir(exist_ok=True)
        child_temp.mkdir(exist_ok=True)
        child_env = {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8",
                     "HOME": str(child_home), "CFFIXED_USER_HOME": str(child_home),
                     "TMPDIR": str(child_temp) + "/", "CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS": "1"}
        result["childEnvironmentKeys"] = sorted(child_env)
        result["runtimeNetworkDenied"] = True
        for phase in ["write", "read"]:
            command = ["/usr/bin/sandbox-exec", "-p", "(version 1)(allow default)(deny network*)", str(binary),
                       "--packaged-cooldown-proof", phase, nonce, str(runtime), str(profile_base)]
            record = call(command, output / f"{phase}.log", cwd=output, env=child_env, timeout=60)
            result["phaseCommands"].append(record)
            if record["exitCode"]:
                result["classification"] = "runtime_assertion_failure"
                raise RuntimeError(f"{phase} failed; original log retained")
        writer = json.loads((runtime / "write.json").read_text())
        reader = json.loads((runtime / "read.json").read_text())
        assert writer["pid"] != reader["pid"]
        assert writer["pid"] == result["phaseCommands"][0]["pid"]
        assert reader["pid"] == result["phaseCommands"][1]["pid"]
        assert writer["nonce"] == reader["nonce"] == nonce
        assert writer["profileIdentifier"] == reader["profileIdentifier"]
        assert writer["persistedTimestamp"] == reader["persistedTimestamp"] == 1800000000
        assert writer["persistedInterval"] == reader["persistedInterval"] == 300
        assert reader["freshProcess"] and reader["inCooldownAtPlusOne"]
        assert reader["remainingAtPlusOne"] == 299 and not reader["inCooldownAtExpiry"]
        result["readVerified"] = True
    except Exception as error:
        if "Bounded command timeout" in str(error):
            result["classification"] = "timeout_indeterminate"
        result["error"] = str(error)
        (output / "failure.txt").write_text(traceback.format_exc())
    finally:
        if binary is not None and child_env is not None:
            try:
                record = call(["/usr/bin/sandbox-exec", "-p", "(version 1)(allow default)(deny network*)", str(binary),
                               "--packaged-cooldown-proof", "cleanup", nonce, str(runtime), str(profile_base)],
                              output / "cleanup.log", cwd=output, env=child_env, timeout=60)
                result["phaseCommands"].append(record)
                if record["exitCode"] == 0:
                    cleanup = json.loads((runtime / "cleanup.json").read_text())
                    assert len(cleanup["removedOnlyNonceKeys"]) == 2
                    result["cleanupVerified"] = True
                else:
                    result["cleanupError"] = "Nonce-key cleanup failed; no broad cleanup attempted"
            except Exception:
                result["cleanupError"] = traceback.format_exc()
        if result.get("readVerified") and result.get("cleanupVerified") and not result.get("error"):
            result["verified"] = True
            result["classification"] = "verified_runtime_persistence"
        (output / "result.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
        status = "VERIFIED" if result["verified"] else "FAILED / INCOMPLETE"
        report = f"""# Cooldown standard-preferences restart proof: {status}

Product: `{PIN}`. Controller: `{result['controllerSHA']}`.
Run: https://github.com/Chipagosfinest/CodexBar/actions/runs/{result['runID']}
Classification: `{result['classification']}`.

The actual CodexBarCLI target was built with a declared early-entry adapter and an append-only DEBUG bridge.
That bridge invokes the unchanged production `recordAttempt(...sharedState)` owner, which falls back to
`UserDefaults.standard`. No TaskLocal/injected preferences or test-state reset was used.
Separate writer/reader processes must agree on nonce profile, timestamp1800000000 and interval300;
public readers must return active/299seconds at t+1 and expired at t+300. Cleanup removes only the two nonce keys.

Binary SHA256: `{result.get('binarySHA256', 'not built')}`.
Fresh-process read verified: `{result.get('readVerified', False)}`.
Nonce-only cleanup verified: `{result.get('cleanupVerified', False)}`.

Runtime child environment is allowlisted, has no SWIFT_TESTING/XCTest/provider credentials, and HTTP/network
is denied by the macOS sandbox. HOME is disposable but NOT claimed to isolate CFPreferences.

This proves the instrumented CLI persistence owner's synthetic restart behavior only. It does not prove
ordinary provider refresh, login, real credentials, packaged GUI startup, or upgrades.

Raw source/binary hashes, overlay manifest, build log and all three phase receipts/logs accompany this report.
No compiler/setup failure is counted as behavioral proof. No retry is triggered by a timeout.
"""
        if result.get("error"):
            report += "\nFailure: " + result["error"] + "\n"
        if result.get("cleanupError"):
            report += "\nCleanup limitation: " + result["cleanupError"] + "\n"
        (output / "REPORT.md").write_text(report)
    return 0 if result["verified"] else 1


if __name__ == "__main__":
    sys.exit(main())
