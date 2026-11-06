#!/usr/bin/env python3
"""Install the declared proof-only overlay into an explicitly supplied disposable checkout."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

PIN = "e8a0cca51036fa8f30362a0710754d812ace34a3"
ENTRY = "Sources/CodexBar/CodexbarApp.swift"
ADAPTER = "Sources/CodexBar/PackagedFooterProof.swift"
CANDIDATE_SOURCE = "Sources/CodexBar/StatusItem/StatusItemController+UserPlugins.swift"
CANDIDATE_PATCH_SHA = "574c1c7468735d813b979c1ff2c83963807df36ebee2a5caa229adf28ab3f961"
CANDIDATE_SOURCE_SHA = "9792aa446f3edd603aa0445ee1c5085b765707a6c62281d5e224086073759524"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_hashes(root):
    return {str(p.relative_to(root)): digest(p) for p in sorted((root / "Sources").rglob("*")) if p.is_file()}


def tracked_hashes(root):
    names = subprocess.check_output(["git", "-C", str(root), "ls-files", "-z"]).decode().split("\0")
    return {name: digest(root / name) for name in names if name and (root / name).is_file()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply-to-disposable-copy", required=True, type=Path)
    parser.add_argument("--manifest-output", required=True, type=Path)
    args = parser.parse_args()
    root = args.apply_to_disposable_copy.resolve()
    if root == Path("/Users/alecgstudio/projects/CodexBar-clean-pr4900"):
        raise SystemExit("Refusing to edit the product worktree")
    head = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    if head != PIN:
        raise SystemExit(f"Expected exact product {PIN}, got {head}")
    if subprocess.check_output(
            ["git", "-C", str(root), "status", "--porcelain", "--untracked-files=all"], text=True).strip():
        raise SystemExit("Refusing a dirty checkout, including manifests, build scripts, and untracked files")
    tracked_before = tracked_hashes(root)
    before = source_hashes(root)
    candidate = Path(__file__).with_name("candidate-production.patch").resolve()
    assert digest(candidate) == CANDIDATE_PATCH_SHA, "Frozen production patch drifted"
    subprocess.run(["git", "-C", str(root), "apply", "--check", str(candidate)], check=True)
    subprocess.run(["git", "-C", str(root), "apply", str(candidate)], check=True)
    candidate_inputs = tracked_hashes(root)
    assert candidate_inputs.keys() == tracked_before.keys()
    assert {name for name in tracked_before if tracked_before[name] != candidate_inputs[name]} == {CANDIDATE_SOURCE}
    assert digest(root / CANDIDATE_SOURCE) == CANDIDATE_SOURCE_SHA
    entry = root / ENTRY
    original = entry.read_text()
    marker = "        #if DEBUG\n        if MenuBarLayoutNativeProof.runIfRequested() {"
    replacement = ("        #if DEBUG\n"
                   "        if PackagedFooterProof.runIfRequested() { return }\n"
                   "        if MenuBarLayoutNativeProof.runIfRequested() {")
    if original.count(marker) != 1:
        raise SystemExit("Early-startup anchor drifted; inspect instead of guessing")
    if (root / ADAPTER).exists():
        raise SystemExit("Proof adapter path already exists")
    entry.write_text(original.replace(marker, replacement, 1))
    shutil.copyfile(Path(__file__).with_name("PackagedFooterProof.swift"), root / ADAPTER)
    subprocess.run(["git", "-C", str(root), "add", "--intent-to-add", "--", ADAPTER], check=True)
    after = source_hashes(root)
    changed = [p for p in before if before[p] != after.get(p)]
    added = [p for p in after if p not in before]
    assert changed == sorted([ENTRY, CANDIDATE_SOURCE]), changed
    assert added == [ADAPTER], added
    manifest = {"productSHA": PIN, "proofOnly": True,
                "productionCandidate": {"baseProductSHA": PIN, "patchSHA256": CANDIDATE_PATCH_SHA,
                                        "sourceFile": CANDIDATE_SOURCE, "sourceSHA256": CANDIDATE_SOURCE_SHA},
                "declaredProductionChangedSourceFiles": [CANDIDATE_SOURCE],
                "declaredProofChangedSourceFiles": [ENTRY],
                "ordinaryShippingStartup": False,
                "declaredChangedSourceFiles": changed, "declaredAddedSourceFiles": added,
                "beforeSourceSHA256": before, "afterSourceSHA256": after,
                "beforeTrackedInputSHA256": tracked_before,
                "afterTrackedInputSHA256": tracked_hashes(root),
                "unchangedSourceCount": sum(before[p] == after[p] for p in before)}
    args.manifest_output.parent.mkdir(parents=True, exist_ok=True)
    args.manifest_output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
