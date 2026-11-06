#!/usr/bin/env python3
"""Verify immutable build inputs and preserve packaged-binary identity."""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys

product, output = map(lambda value: Path(value).resolve(), sys.argv[1:3])
manifest = json.loads((output / "overlay-manifest.json").read_text())
assert manifest["productSHA"] == "e8a0cca51036fa8f30362a0710754d812ace34a3"
assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=product, text=True).strip() == manifest["productSHA"]
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert manifest["declaredChangedSourceFiles"] == ["Sources/CodexBar/CodexbarApp.swift"]
assert manifest["declaredAddedSourceFiles"] == ["Sources/CodexBar/PackagedFooterProof.swift"]
assert all(digest(product / name) == value for name, value in manifest["afterTrackedInputSHA256"].items())
assert all(digest(product / name) == value for name, value in manifest["afterSourceSHA256"].items())
current = {str(path.relative_to(product)) for path in (product / "Sources").rglob("*") if path.is_file()}
assert current == set(manifest["afterSourceSHA256"])
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
