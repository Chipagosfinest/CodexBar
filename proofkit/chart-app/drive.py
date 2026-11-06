#!/usr/bin/env python3
"""Actual CGEvent/AX/screen proof of a packaged app with declared synthetic startup."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import time
from wait_process import observed_exit

PIN = "c16893bbe515695c74a5c7d594b083ce641c3d20"
SANDBOX = "(version 1)(allow default)(deny network*)"
parser = argparse.ArgumentParser()
parser.add_argument("--app", type=Path, required=True)
parser.add_argument("--helper", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--runtime-root", type=Path, required=True)
parser.add_argument("--overlay-sha", required=True)
args = parser.parse_args()
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)
root = args.runtime_root.resolve()
assert not root.exists(), "Fresh disposable runtime root required"
(root / "tmp").mkdir(parents=True)
helper = str(args.helper.resolve())
app = args.app.resolve()
binary = app / "Contents/MacOS/CodexBar"
t0 = time.monotonic()
events = []
recordings = []


def log(kind, **data):
    row = {"event": kind, "elapsed": round(time.monotonic() - t0, 3), **data}
    events.append(row)
    (out / "events.json").write_text(json.dumps(events, indent=2) + "\n")
    print(json.dumps(row), flush=True)


def ui(*parameters):
    return subprocess.check_output([helper, *map(str, parameters)], text=True, timeout=15).strip()


displays = json.loads(ui("displays"))
assert len(displays) == 1, "Bounded proof requires a single observed display"


def onscreen_point(x, y):
    return math.isfinite(x) and math.isfinite(y) and any(
        d["x"] <= x < d["x"] + d["w"] and d["y"] <= y < d["y"] + d["h"] for d in displays)


def valid_point(x, y, menu=None):
    assert onscreen_point(x, y), "Offscreen pointer target rejected"
    if menu:
        assert menu["x"] <= x < menu["x"] + menu["w"] and menu["y"] <= y < menu["y"] + menu["h"], "Chart target outside observed menu"


def wait(function, label, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = function()
        if result:
            return result
        time.sleep(0.25)
    raise RuntimeError("Timed out: " + label)


def appearance(dark):
    value = "true" if dark else "false"
    subprocess.run(["osascript", "-e", 'tell application "System Events" to tell appearance preferences to set dark mode to ' + value],
                   check=True, capture_output=True, text=True, timeout=15)
    time.sleep(1)


def nodes():
    return json.loads(ui("ax", process.pid))


def text(node):
    return " ".join(str(node.get(key, "")) for key in ["title", "description", "value", "help"])


def legend_matches(rows, claude, codex):
    texts = ["".join(str(row.get(key, "")).casefold().split())
             for row in rows for key in ["title", "description", "value"]]
    return "claude" + claude in texts and "codex" + codex in texts


def menu_window():
    candidates = [window for window in json.loads(ui("windows", process.pid)) if window["w"] > 220 and window["h"] > 120]
    return max(candidates, key=lambda value: value["h"]) if candidates else None


def receipt():
    path = out / "runtime/runtime-receipt.json"
    if not path.exists():
        assert process.poll() is None, "App exited before runtime receipt"
        return None
    data = json.loads(path.read_text())
    assert data["productSHA"] == PIN and data["synthetic"] and data["proofOnlyEarlyStartup"]
    assert data["knownDayUSD"] == 5 and data["claudeDayUSD"] == 2 and data["codexDayUSD"] == 3
    assert data["claudeHoveredShare"] == 0.4 and data["codexHoveredShare"] == 0.6
    assert data["rangeSharesUnknown"] and data["actualStatusItemController"] and data["actualMergedMenu"]
    assert data["forbiddenProviderRefreshes"] == 0 and data["blockedHTTPRequests"] == 0
    return data


def capture(name, expectation):
    time.sleep(0.5)
    current = wait(menu_window, "actual open NSMenu")
    current_nodes = nodes()
    assert legend_matches(current_nodes, *expectation)
    assert receipt()
    (out / (name + "-ax.json")).write_text(json.dumps(current_nodes, indent=2) + "\n")
    subprocess.run(["screencapture", "-x", str(out / (name + "-screen.png"))], check=True, timeout=15)
    subprocess.run(["screencapture", "-x", "-o", "-l" + str(current["id"]), str(out / (name + "-menu.png"))],
                   check=True, timeout=15)
    image = json.loads(ui("image-info", out / (name + "-screen.png")))
    assert image["width"] >= 640 and image["height"] >= 480 and image["contrast"] > 0.1
    similarity = json.loads(ui("screen-similarity", out / (name + "-screen.png"), out / (name + "-menu.png"),
                               current["x"], current["y"], current["w"], current["h"]))
    assert similarity["meanRGBError"] < 0.13, "Window-only capture does not match actual displayed menu region"
    log("capture", name=name, expected_legend=list(expectation), menu=current,
        actual_screen_image=image, screen_menu_similarity=similarity)


minimal = {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": str(root), "CFFIXED_USER_HOME": str(root),
           "XDG_CONFIG_HOME": str(root / ".config"), "CODEXBAR_CONFIG": str(root / "config.json"),
           "CODEX_HOME": str(root / "codex"), "TMPDIR": str(root / "tmp") + "/", "LANG": "en_US.UTF-8",
           "SWIFT_TESTING": "1", "CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS": "1", "CODEXBAR_DISABLE_KEYCHAIN_ACCESS": "1",
           "CODEXBAR_TEST_CODEX_FILE_ISOLATION": "1", "CODEXBAR_TEST_SESSION_FILE_ISOLATION": "1",
           "PACKAGED_CHART_PROOF_PRODUCT_SHA": PIN, "PACKAGED_CHART_PROOF_ROOT": str(root),
           "PACKAGED_CHART_PROOF_OUTPUT": str(out / "runtime")}
original_dark = subprocess.check_output(["osascript", "-e", 'tell application "System Events" to tell appearance preferences to get dark mode'],
                                        text=True, timeout=15).strip() == "true"
app_log = (out / "app.log").open("w")
banner_log = (out / "banner.log").open("w")
banner = subprocess.Popen(["sandbox-exec", "-p", SANDBOX, helper, "banner", str(out), PIN, args.overlay_sha],
                          stdout=banner_log, stderr=subprocess.STDOUT)
process = subprocess.Popen(["sandbox-exec", "-p", SANDBOX, str(binary), "--packaged-chart-proof"],
                           env=minimal, stdout=app_log, stderr=subprocess.STDOUT)
passed = False
try:
    setup = wait(receipt, "synthetic production-store setup", 45)
    identity = json.loads(ui("application", process.pid))
    assert Path(identity["executable"]).resolve() == binary.resolve(), "Unexpected/stale app executable"
    log("setup", app_pid=process.pid, banner_pid=banner.pid, runtime=setup,
        binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(), sandbox_profile=SANDBOX,
        application_identity=identity, observed_displays=displays)
    for dark in [False, True]:
        theme = "dark" if dark else "light"
        ui("esc")
        appearance(dark)
        ui("move", 20, 300)
        current_nodes = nodes()
        (out / (theme + "-initial-ax.json")).write_text(json.dumps(current_nodes, indent=2) + "\n")
        items = [row for row in current_nodes if row.get("identifier") == "codexbar-packaged-chart-proof"]
        if not items:
            items = [row for row in current_nodes if row.get("role") == "AXMenuBarItem" and row["frame"]["y"] < 35
                     and 0 < row["frame"]["w"] < 300 and 0 < row["frame"]["h"] < 40]
        item = next(row for row in items if row["frame"]["w"] > 0)["frame"]
        valid_point(item["x"] + item["w"] / 2, item["y"] + item["h"] / 2)
        subprocess.run(["screencapture", "-x", str(out / (theme + "-0-status-screen.png"))], check=True, timeout=15)
        rectangle = ",".join(str(round(item[key])) for key in ["x", "y", "w", "h"])
        status_crop = out / (theme + "-0-status.png")
        subprocess.run(["screencapture", "-x", "-R" + rectangle, str(status_crop)], check=True, timeout=15)
        status_pixels = json.loads(ui("image-info", status_crop))
        assert status_pixels["width"] > 2 and status_pixels["height"] > 2 and status_pixels["contrast"] > 0.08, "Status icon not visibly distinguishable on actual target screen"
        log("status_visible", theme=theme, frame=item, pixels=status_pixels,
            manual_original_screen_inspection_required=True)
        recording_log = (out / (theme + "-video.log")).open("w")
        recording = subprocess.Popen(["screencapture", "-v", "-V", "25", "-x", str(out / (theme + "-screen.mov"))],
                                     stdout=recording_log, stderr=subprocess.STDOUT)
        video_start = time.monotonic()
        recordings.append((recording, recording_log))
        log("recorder_start", pid=recording.pid, requested_duration_seconds=25, theme=theme)
        time.sleep(1)
        ui("click", item["x"] + item["w"] / 2, item["y"] + item["h"] / 2)
        wait(menu_window, "menu opened by actual pointer click")
        wait(lambda: legend_matches(nodes(), "unknown", "unknown"), "Unknown range legends")
        capture(theme + "-1-range", ("unknown", "unknown"))
        rows = nodes()
        points = [row for row in rows if "$5" in text(row) and "claude" in text(row).casefold()
                  and "codex" in text(row).casefold() and row["frame"]["w"] > 0 and 2 < row["frame"]["h"] <= 60]
        if points:
            target = min(points, key=lambda row: row["frame"]["h"])["frame"]
            targets = [(target["x"] + target["w"] / 2, target["y"] + target["h"] / 2)]
        else:
            headers = [row for row in rows if "today" in text(row).casefold() and "$5" in text(row)
                       and row["frame"]["w"] > 0 and 2 < row["frame"]["h"] < 30]
            assert headers, "No observed chart header/point accessibility frame"
            header = min(headers, key=lambda row: row["frame"]["y"])["frame"]
            menu = menu_window()
            targets = [(menu["x"] + menu["w"] * 0.75, header["y"] + header["h"] + distance) for distance in [12, 24, 36]]
        hover = None
        for x, y in targets:
            observed_menu = menu_window()
            assert observed_menu, "Menu closed before hover"
            valid_point(x, y, observed_menu)
            log("pointer_move", theme=theme, target=[x, y], source="observed chart accessibility geometry")
            ui("move", x, y)
            try:
                wait(lambda: legend_matches(nodes(), "40%", "60%"), "real hover 40/60", 4)
                hover = [x, y]
                break
            except RuntimeError:
                continue
        assert hover, "Actual chart hover did not show Claude40/Codex60"
        capture(theme + "-2-hover", ("40%", "60%"))
        menu = menu_window()
        ui("move", max(5, menu["x"] - 25), menu["y"] + 30)
        wait(lambda: legend_matches(nodes(), "unknown", "unknown"), "actual pointer exit restored range")
        capture(theme + "-3-exit", ("unknown", "unknown"))
        last_state = time.monotonic() - video_start
        assert last_state < 24, "Video could miss final state; retain screenshots but reject recording coverage"
        ui("esc")
        recording_exit = observed_exit(recording, 45)
        log("recorder_exit", pid=recording.pid, exit_code=recording_exit, seconds_since_launch=time.monotonic() - video_start)
        assert recording_exit == 0
        recording_log.close()
        media = json.loads(ui("media", out / (theme + "-screen.mov")))
        assert media["duration"] >= last_state and media["width"] > 0
        log("recording", theme=theme, last_state_elapsed=last_state, media=media)
    receipt()
    assert process.poll() is None
    passed = True
except BaseException as error:
    log("primary_failure", error_type=type(error).__name__, error=str(error))
    raise
finally:
    try:
        current_nodes = nodes() if process.poll() is None else []
        quits = [row for row in current_nodes if row.get("role") == "AXMenuItem" and text(row).strip().startswith("Quit")
                 and row["frame"]["w"] > 0
                 and onscreen_point(row["frame"]["x"] + row["frame"]["w"] / 2, row["frame"]["y"] + row["frame"]["h"] / 2)]
        if not quits and process.poll() is None:
            current_nodes = nodes()
            items = [row for row in current_nodes if row.get("identifier") == "codexbar-packaged-chart-proof" and row["frame"]["w"] > 0]
            if items:
                item = items[0]["frame"]
                ui("click", item["x"] + item["w"] / 2, item["y"] + item["h"] / 2)
                time.sleep(0.5)
                quits = [row for row in nodes() if row.get("role") == "AXMenuItem" and text(row).strip().startswith("Quit")
                         and row["frame"]["w"] > 0
                         and onscreen_point(row["frame"]["x"] + row["frame"]["w"] / 2, row["frame"]["y"] + row["frame"]["h"] / 2)]
        if quits:
            quit_frame = quits[-1]["frame"]
            ui("click", quit_frame["x"] + quit_frame["w"] / 2, quit_frame["y"] + quit_frame["h"] / 2)
            try:
                process.wait(timeout=5)
                log("quit", via="actual menu item")
            except subprocess.TimeoutExpired:
                pass
    except Exception as cleanup_error:
        log("menu_cleanup_failure", error_type=type(cleanup_error).__name__, error=str(cleanup_error))
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
            log("quit", via="owned-process termination fallback")
        banner.terminate()
        banner.wait(timeout=5)
        for recording, handle in recordings:
            if recording.poll() is None:
                try:
                    observed_exit(recording, 45)
                except subprocess.TimeoutExpired:
                    recording.terminate()
                    recording.wait(timeout=5)
                    passed = False
                    log("recording_cleanup_failure", error="Recording did not finalize within bounded 45-second budget")
            if not handle.closed:
                handle.close()
        appearance(original_dark)
        app_log.close()
        banner_log.close()
        verdict = {"ui_states_passed": passed, "product_sha": PIN, "overlay_patch_sha256": args.overlay_sha,
                   "boundary": "Synthetic packaged-App menu journey with declared early-startup overlay; no shipping startup/live-account claim",
                   "sandbox_profile": SANDBOX, "events": len(events),
                   "manual_original_screen_and_recording_inspection_required": True}
        (out / "ui-verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
assert passed
