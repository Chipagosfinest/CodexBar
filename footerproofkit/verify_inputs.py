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
candidate_source = "Sources/CodexBar/StatusItem/StatusItemController+UserPlugins.swift"
assert manifest["productionCandidate"] == {
    "baseProductSHA": manifest["productSHA"],
    "patchSHA256": "574c1c7468735d813b979c1ff2c83963807df36ebee2a5caa229adf28ab3f961",
    "sourceFile": candidate_source,
    "sourceSHA256": "9792aa446f3edd603aa0445ee1c5085b765707a6c62281d5e224086073759524",
}
assert manifest["declaredProductionChangedSourceFiles"] == [candidate_source]
assert manifest["declaredProofChangedSourceFiles"] == ["Sources/CodexBar/CodexbarApp.swift"]
assert manifest["declaredChangedSourceFiles"] == sorted(["Sources/CodexBar/CodexbarApp.swift", candidate_source])
assert manifest["declaredAddedSourceFiles"] == ["Sources/CodexBar/PackagedFooterProof.swift"]
assert not subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard"], cwd=product, text=True).strip(), "Unexpected untracked inputs"
tracked_names = subprocess.check_output(["git", "ls-files"], cwd=product, text=True).splitlines()
assert {name: digest(product / name) for name in tracked_names if (product / name).is_file()} == manifest["afterTrackedInputSHA256"], "Tracked input map changed"
changed_paths = set(subprocess.check_output(["git", "diff", "HEAD", "--name-only"], cwd=product, text=True).splitlines())
assert changed_paths == set(manifest["declaredChangedSourceFiles"] + manifest["declaredAddedSourceFiles"])
assert digest(product / candidate_source) == manifest["productionCandidate"]["sourceSHA256"]
assert all(digest(product / name) == value for name, value in manifest["afterSourceSHA256"].items())
current = {str(path.relative_to(product)) for path in (product / "Sources").rglob("*") if path.is_file()}
assert current == set(manifest["afterSourceSHA256"])
if "--inputs-only" in sys.argv:
    print(json.dumps({"allInputsVerified": True, "productionCandidate": manifest["productionCandidate"]}))
    raise SystemExit(0)
app = product / "CodexBar.app"
with (app / "Contents/Info.plist").open("rb") as handle:
    info = plistlib.load(handle)
assert info["CFBundleIdentifier"] == "com.steipete.codexbar.debug"
assert info["SUFeedURL"] == "" and info["SUEnableAutomaticChecks"] is False
binary = app / "Contents/MacOS/CodexBar"
record = {"productSHA": manifest["productSHA"], "productionCandidate": manifest["productionCandidate"], "debugBundleIdentifier": info["CFBundleIdentifier"],
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
