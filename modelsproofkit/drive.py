import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import time

p = argparse.ArgumentParser()
p.add_argument("app", type=pathlib.Path)
p.add_argument("helper", type=pathlib.Path)
p.add_argument("output", type=pathlib.Path)
p.add_argument("--label", required=True)
p.add_argument("--sha", required=True)
args = p.parse_args()
out = args.output.resolve()
home = out / "synthetic-home"
home.mkdir(exist_ok=True)
binary = args.app.resolve() / "Contents/MacOS/CodexBar"
env = {
    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
    "HOME": str(home),
    "CFFIXED_USER_HOME": str(home),
    "CODEXBAR_DISABLE_KEYCHAIN_ACCESS": "1",
    "CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS": "1",
    "CODEXBAR_MODELS_APP_PROOF_OUT": str(out),
    "CODEXBAR_MODELS_PRODUCT_SHA": args.sha,
    "CODEXBAR_MODELS_PROOF_LABEL": args.label,
}
helper = str(args.helper.resolve())
process = subprocess.Popen(
    ["sandbox-exec", "-p", "(version 1)(allow default)(deny network*)", str(binary)],
    env=env, stdout=(out / "app.log").open("w"), stderr=subprocess.STDOUT)
checks = []

def require(condition, description):
    checks.append({"check": description, "passed": bool(condition)})
    if not condition:
        raise RuntimeError(description)

def wait_for(day):
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"app exited {process.returncode}")
        try:
            current = json.loads((out / "current.json").read_text())
            if current["selectedDay"] == day:
                return current
        except FileNotFoundError:
            pass
        time.sleep(.25)
    raise RuntimeError(f"day {day} did not appear")

def capture(name):
    time.sleep(1)
    data = json.loads(subprocess.check_output([helper, "ax", str(process.pid)]))
    (out / f"{name}-accessibility.json").write_text(json.dumps(data, indent=2))
    subprocess.run(["screencapture", "-x", str(out / f"{name}-screen.png")], check=True, timeout=10)
    return data

try:
    partial = wait_for(15)
    require(partial["productSHA"] == args.sha, "runtime product SHA matches")
    require([r["value"] for r in partial["rows"]] == [1, 1], "partial day retains dollar amounts")
    expected_partial = args.label == "after"
    require(partial["rankingPartial"] == expected_partial, "partial warning matches baseline/fixed contract")
    require([r["share"] for r in partial["rows"]] == ([None, None] if expected_partial else [.5, .5]),
            "partial day share visibility matches baseline/fixed contract")
    ax = capture("partial")
    buttons = [r for r in ax if r.get("identifier") == "models-proof-select-complete"]
    require(len(buttons) == 1, "complete-day button visible in real accessibility tree")
    frame = buttons[0]["frame"]
    subprocess.run([helper, "click", str(frame["x"] + frame["w"] / 2), str(frame["y"] + frame["h"] / 2)], check=True)
    complete = wait_for(16)
    require([r["value"] for r in complete["rows"]] == [3, 3], "complete selected day has own costs")
    require(not complete["rankingPartial"], "complete selected day restores complete ranking")
    require([r["share"] for r in complete["rows"]] == [.5, .5], "complete selected day restores shares")
    require(complete["windowHasPartialCost"], "whole window remains partial independently")
    capture("complete")
    (out / "verdict.json").write_text(json.dumps({"verdict": "passed", "checks": checks}, indent=2) + "\n")
except Exception as error:
    (out / "verdict.json").write_text(json.dumps({"verdict": "failed", "checks": checks,
                                                "error": str(error)}, indent=2) + "\n")
    raise
finally:
    process.terminate()
    try:
        process.wait(timeout=8)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)
    manifest = json.loads((out / "source-provenance.json").read_text())
    manifest["executableSHA256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
    manifest["screens"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob("*-screen.png")}
    (out / "runtime-provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")
