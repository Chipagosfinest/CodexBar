#!/usr/bin/env python3
"""Hosted-only actual pointer + open root/More + fixed-plugin refresh screen journey."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import time

PIN = "e8a0cca51036fa8f30362a0710754d812ace34a3"
SANDBOX = "(version 1)(allow default)(deny network*)"
parser = argparse.ArgumentParser()
parser.add_argument("--app", required=True, type=Path)
parser.add_argument("--helper", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--runtime-root", required=True, type=Path)
parser.add_argument("--overlay-sha", required=True)
args = parser.parse_args()
assert os.environ.get("GITHUB_ACTIONS") == "true" and os.environ.get("GITHUB_REPOSITORY") == "Chipagosfinest/CodexBar", "No local UI execution"
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)
root = args.runtime_root.resolve()
assert not root.exists(), "Require fresh disposable runtime root"
(root / "tmp").mkdir(parents=True)
helper = str(args.helper.resolve())
binary = args.app.resolve() / "Contents/MacOS/CodexBar"
nonce = str(__import__("uuid").uuid4()).upper()
events = []
t0 = time.monotonic()
process = None
banner = None
recording = None
handles = []
passed = False
failure = None
root_window = None
child_window = None
video_start = None


def log(event, **data):
    events.append({"event": event, "elapsed": round(time.monotonic() - t0, 3), **data})
    (out / "events.json").write_text(json.dumps(events, indent=2) + "\n")
    print(json.dumps(events[-1]), flush=True)


def ui(*parts):
    return subprocess.check_output([helper, *map(str, parts)], text=True, timeout=15).strip()


displays = json.loads(ui("displays"))
assert len(displays) == 1


def inside(x, y, frame):
    return frame["x"] <= x < frame["x"] + frame["w"] and frame["y"] <= y < frame["y"] + frame["h"]


def center(frame):
    x, y = frame["x"] + frame["w"] / 2, frame["y"] + frame["h"] / 2
    assert math.isfinite(x) and math.isfinite(y) and any(inside(x, y, d) for d in displays), "Offscreen point rejected"
    return x, y


def wait(check, label, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(0.2)
    raise RuntimeError("Bounded wait failed: " + label + "; no retry/reopen")


def nodes():
    assert process is not None and process.poll() is None, "Proof app exited"
    return json.loads(ui("ax", process.pid))


def text(row):
    return " ".join(str(row.get(key, "")) for key in ["title", "description", "value", "help"])


def visible_rows():
    return [row for row in nodes() if row["frame"]["w"] > 0 and row["frame"]["h"] > 0]


def menu_windows():
    return [w for w in json.loads(ui("windows", process.pid)) if w["w"] > 180 and w["h"] > 65]


def receipt():
    path = out / "runtime/runtime-receipt.json"
    if not path.exists():
        assert process.poll() is None
        return None
    value = json.loads(path.read_text())
    assert value["productSHA"] == PIN and value["nonce"] == nonce and value["synthetic"]
    assert value["forbiddenFirstPartyRefreshes"] == value["pluginTransportRequests"] == value["blockedHTTPRequests"] == 0
    assert value["ordinaryAppStartup"] is False and value["proofOnlyEarlyStartup"]
    return value


def card_state(percent, error_present):
    rows = visible_rows()
    joined = "\n".join(text(row) for row in rows).casefold()
    has_value = re.search(r"(?<!\d)" + str(percent) + r"\s*%", joined) is not None
    has_error = "synthetic prior refresh failure" in joined
    return "synthetic overflow meter" in joined and has_value and has_error == error_present


def stable_open_windows():
    observed = {w["id"] for w in menu_windows()}
    assert root_window["id"] in observed, "Root menu closed/replaced; do not reopen"
    assert child_window["id"] in observed, "More submenu closed/replaced; do not reopen"
    value = receipt()
    assert value["rootBegins"] == 1 and value["rootEnds"] == 0, "Root tracking ended/reopened"
    return value


def capture(label, percent, error_present):
    assert card_state(percent, error_present)
    state = stable_open_windows()
    (out / (label + "-ax.json")).write_text(json.dumps(nodes(), indent=2) + "\n")
    (out / (label + "-receipt.json")).write_text(json.dumps(state, indent=2) + "\n")
    screen = out / (label + "-screen.png")
    subprocess.run(["screencapture", "-x", str(screen)], check=True, timeout=15)
    info = json.loads(ui("image-info", screen))
    assert info["width"] >= 640 and info["height"] >= 480 and info["contrast"] > 0.1
    for kind, window in [("root", root_window), ("more", child_window)]:
        png = out / (label + "-" + kind + ".png")
        subprocess.run(["screencapture", "-x", "-o", "-l" + str(window["id"]), str(png)], check=True, timeout=15)
        similarity = json.loads(ui("screen-similarity", screen, png, window["x"], window["y"], window["w"], window["h"]))
        assert similarity["meanRGBError"] < 0.13, "Actual display does not match native menu window"
        log("window-capture", label=label, kind=kind, window=window, similarity=similarity)
    log("capture", label=label, percent=percent, error_present=error_present, actual_screen=info)


minimal = {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": str(root), "CFFIXED_USER_HOME": str(root),
           "XDG_CONFIG_HOME": str(root / ".config"), "CODEXBAR_CONFIG": str(root / "config.json"),
           "CODEX_HOME": str(root / "codex"), "TMPDIR": str(root / "tmp") + "/", "LANG": "en_US.UTF-8",
           "SWIFT_TESTING": "1", "CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS": "1", "CODEXBAR_DISABLE_KEYCHAIN_ACCESS": "1",
           "CODEXBAR_TEST_CODEX_FILE_ISOLATION": "1", "CODEXBAR_TEST_SESSION_FILE_ISOLATION": "1",
           "PACKAGED_FOOTER_PROOF_PRODUCT_SHA": PIN, "PACKAGED_FOOTER_PROOF_ROOT": str(root),
           "PACKAGED_FOOTER_PROOF_OUTPUT": str(out / "runtime"), "PACKAGED_FOOTER_PROOF_NONCE": nonce}
original_dark = subprocess.check_output(["osascript", "-e", 'tell application "System Events" to tell appearance preferences to get dark mode'], text=True, timeout=15).strip() == "true"
try:
    subprocess.run(["osascript", "-e", 'tell application "System Events" to tell appearance preferences to set dark mode to false'], check=True, timeout=15)
    for name in ["app.log", "banner.log", "video.log"]:
        handles.append((out / name).open("w"))
    banner = subprocess.Popen(["sandbox-exec", "-p", SANDBOX, helper, "banner", str(out), PIN, args.overlay_sha],
                              env=minimal, stdout=handles[1], stderr=subprocess.STDOUT)
    process = subprocess.Popen(["sandbox-exec", "-p", SANDBOX, str(binary), "--packaged-footer-proof"],
                               env=minimal, stdout=handles[0], stderr=subprocess.STDOUT)
    setup = wait(receipt, "synthetic footer setup", 45)
    assert setup["phase"] == "ready-initial-5-error"
    identity = json.loads(ui("application", process.pid))
    assert Path(identity["executable"]).resolve() == binary.resolve()
    log("setup", app_pid=process.pid, binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(), identity=identity, sandbox=SANDBOX)
    item = wait(lambda: next((row["frame"] for row in nodes() if row.get("identifier") == "codexbar-packaged-footer-proof" and row["frame"]["w"] > 0), None), "actual status item")
    x, y = center(item)
    subprocess.run(["screencapture", "-x", str(out / "0-status-screen.png")], check=True, timeout=15)
    crop = out / "0-status-crop.png"
    rectangle = ",".join(str(round(item[k])) for k in ["x", "y", "w", "h"])
    subprocess.run(["screencapture", "-x", "-R" + rectangle, str(crop)], check=True, timeout=15)
    status = json.loads(ui("image-info", crop))
    assert status["width"] > 2 and status["height"] > 2 and status["contrast"] > 0.08
    recording = subprocess.Popen(["screencapture", "-v", "-V", "40", "-x", str(out / "continuous-screen.mov")], stdout=handles[2], stderr=subprocess.STDOUT)
    video_start = time.monotonic()
    time.sleep(1)
    ui("click", x, y)
    root_window = wait(lambda: max(menu_windows(), key=lambda w: w["h"], default=None), "actual root opened by pointer")
    more = wait(lambda: next((row["frame"] for row in visible_rows() if row.get("role") == "AXMenuItem" and text(row).strip().startswith("More (") and inside(*center(row["frame"]), root_window)), None), "actual More item")
    x, y = center(more)
    ui("move", x, y)
    wait(lambda: card_state(5, True), "visible overflow 5% with error")
    header = next(row["frame"] for row in visible_rows() if "synthetic overflow meter" in text(row).casefold())
    hx, hy = center(header)
    child_window = wait(lambda: next((w for w in menu_windows() if w["id"] != root_window["id"] and inside(hx, hy, w)), None), "actual More window")
    capture("1-before", 5, True)
    assert receipt()["rootBegins"] == 1
    trigger = out / "runtime/trigger-refresh.json"
    temporary = trigger.with_suffix(".tmp")
    temporary.write_text(json.dumps({"nonce": nonce, "action": "refresh-fixed-fixture"}))
    temporary.replace(trigger)
    log("controlled-production-refresh-triggered", nonce=nonce)

    def fresh():
        value = stable_open_windows()
        return value if value["phase"] == "replaced-in-open-root-native-capture-required" and card_state(42, False) else None

    final = wait(fresh, "same open root/More painted 42% with error cleared", 18)
    assert final["cardAndViewReplacedInOpenRoot"]
    capture("2-after", 42, False)
    time.sleep(1)
    stable_open_windows()
    capture("3-still-open", 42, False)
    last_state = time.monotonic() - video_start
    assert last_state < 37, "Continuous recording may not cover final state"
    ui("esc")
    ui("esc")
    assert recording.wait(timeout=45) == 0
    media = json.loads(ui("media", out / "continuous-screen.mov"))
    assert media["duration"] >= last_state and media["width"] > 0
    log("continuous-recording", media=media, last_state_elapsed=last_state)
    passed = True
except Exception as error:
    failure = str(error)
    log("failure", reason=failure)
    try:
        subprocess.run(["screencapture", "-x", str(out / "failure-screen.png")], check=True, timeout=15)
        (out / "failure-ax.json").write_text(json.dumps(nodes(), indent=2) + "\n")
    except Exception:
        pass
finally:
    if recording is not None and recording.poll() is None:
        try:
            recording.wait(timeout=45)
        except subprocess.TimeoutExpired:
            recording.terminate()
            recording.wait(timeout=5)
    if process is not None and process.poll() is None:
        process.terminate()
        process.wait(timeout=5)
    if banner is not None and banner.poll() is None:
        banner.terminate()
        banner.wait(timeout=5)
    subprocess.run(["osascript", "-e", 'tell application "System Events" to tell appearance preferences to set dark mode to ' + ("true" if original_dark else "false")], check=True, timeout=15)
    for handle in handles:
        handle.close()
    verdict = {"automated_ui_state_checks_passed": passed, "manual_original_media_inspection_required": True,
               "productSHA": PIN, "overlaySHA256": args.overlay_sha, "failure": failure,
               "boundary": "Instrumented packaged DEBUG app; synthetic test-safety startup, no ordinary startup/auth claim",
               "rootWindow": root_window, "moreWindow": child_window, "eventCount": len(events)}
    (out / "ui-verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
if not passed:
    raise SystemExit(1)
