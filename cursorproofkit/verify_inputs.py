#!/usr/bin/env python3
"""Verify immutable build inputs and preserve packaged-binary identity."""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys

product, output = map(lambda value: Path(value).resolve(), sys.argv[1:3])
assert not subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard"], cwd=product, text=True).strip(), "Unexpected untracked inputs"
manifest = json.loads((output / "overlay-manifest.json").read_text())
assert manifest["productSHA"] == "fba37ba92f696416b36f49d4de89affcda3888ee"
assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=product, text=True).strip() == manifest["productSHA"]
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert manifest["declaredChangedSourceFiles"] == ["Sources/CodexBar/CodexbarApp.swift"]
assert manifest["declaredAddedSourceFiles"] == sorted(["Sources/CodexBar/CursorProofFixtureSupport.swift", "Sources/CodexBar/PackagedCursorProof.swift"])
tracked_names = subprocess.check_output(["git", "ls-files"], cwd=product, text=True).splitlines()
actual_tracked = {name: digest(product / name) for name in tracked_names if (product / name).is_file()}
assert actual_tracked == manifest["afterTrackedInputSHA256"], "Exact tracked input map changed"
changed = set(subprocess.check_output(["git", "diff", "HEAD", "--name-only"], cwd=product, text=True).splitlines())
assert changed == set(manifest["declaredChangedSourceFiles"] + manifest["declaredAddedSourceFiles"])
assert all(digest(product / name) == value for name, value in manifest["afterSourceSHA256"].items())
current = {str(path.relative_to(product)) for path in (product / "Sources").rglob("*") if path.is_file()}
assert current == set(manifest["afterSourceSHA256"])
if "--inputs-only" in sys.argv:
    print(json.dumps({"allTrackedAndUntrackedInputsVerified": True, "productSHA": manifest["productSHA"]}))
    raise SystemExit(0)
app = product / "CodexBar.app"
with (app / "Contents/Info.plist").open("rb") as handle:
    info = plistlib.load(handle)
assert info["CFBundleIdentifier"] == "com.steipete.codexbar.debug"
assert info["SUFeedURL"] == "" and info["SUEnableAutomaticChecks"] is False
binary = app / "Contents/MacOS/CodexBar"
record = {"productSHA": manifest["productSHA"], "debugBundleIdentifier": info["CFBundleIdentifier"],
          "trackedInputCount": len(manifest["afterTrackedInputSHA256"]),
          "sourceFileCount": len(manifest["afterSourceSHA256"]),
          "allTrackedInputsMatchDeclaredOverlay": True, "allSourcesMatchDeclaredOverlay": True,
          "binarySHA256": digest(binary), "bundleInfo": info,
          "bundleFileSHA256": {str(path.relative_to(app)): digest(path) for path in sorted(app.rglob("*")) if path.is_file()}}
(output / "built-input-verdict.json").write_text(json.dumps(record, indent=2, default=str) + "\n")
dependency_deltas = []
for checkout in sorted((product / ".build/checkouts").glob("*")):
    result = subprocess.run(["git", "diff", "--binary", "HEAD"], cwd=checkout, capture_output=True)
    if result.returncode == 0 and result.stdout:
        dependency_deltas.append(b"# Normal package_app.sh build dependency: " + checkout.name.encode() + b"\n" + result.stdout)
(output / "normal-packaging-dependency-deltas.patch").write_bytes(b"\n".join(dependency_deltas))
print(json.dumps({key: value for key, value in record.items() if key not in ["bundleFileSHA256", "bundleInfo"]}, indent=2))
