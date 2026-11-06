#!/usr/bin/env python3
"""Add a declared early CLI adapter and append-only production-writer bridge in a disposable checkout."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

PIN = "725fb4fdda831b5cca8bf265d2c066aa8ebc04ca"
ENTRY = "Sources/CodexBarCLI/CLIEntry.swift"
CORE = "Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthDelegatedRefreshCoordinator.swift"
ADAPTER = "Sources/CodexBarCLI/PackagedCooldownProof.swift"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tracked_hashes(root):
    names = subprocess.check_output(["git", "-C", str(root), "ls-files", "-z"]).decode().split("\0")
    return {name: digest(root / name) for name in names if name and (root / name).is_file()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply-to-disposable-copy", required=True, type=Path)
    parser.add_argument("--manifest-output", required=True, type=Path)
    args = parser.parse_args()
    root = args.apply_to_disposable_copy.resolve()
    if root == Path("/Users/alecgstudio/projects/CodexBar-ci-cooldown-isolation"):
        raise SystemExit("Refusing the product worktree")
    head = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    if head != PIN:
        raise SystemExit(f"Expected exact product {PIN}, got {head}")
    if subprocess.check_output(
            ["git", "-C", str(root), "status", "--porcelain", "--untracked-files=all"], text=True).strip():
        raise SystemExit("Refusing any dirty source/build inputs or untracked files")
    before = tracked_hashes(root)
    entry = root / ENTRY
    core = root / CORE
    original_entry = entry.read_text()
    original_core = core.read_bytes()
    marker = "    static func main() async {\n"
    hook = '''    static func main() async {
        #if DEBUG && os(macOS)
        do {
            if try PackagedCooldownProof.runIfRequested() { return }
        } catch {
            FileHandle.standardError.write(Data("Packaged cooldown proof failed: \\(error)\\n".utf8))
            Darwin.exit(1)
        }
        #endif
'''
    if original_entry.count(marker) != 1 or (root / ADAPTER).exists():
        raise SystemExit("Entry anchor drift or adapter exists; inspect rather than guess")
    fragment = Path(__file__).with_name("CoordinatorBridge.swift.fragment").read_bytes()
    entry.write_text(original_entry.replace(marker, hook, 1))
    core.write_bytes(original_core + fragment)
    assert core.read_bytes()[:len(original_core)] == original_core
    shutil.copyfile(Path(__file__).with_name("PackagedCooldownProof.swift"), root / ADAPTER)
    after = tracked_hashes(root)
    changes = sorted(name for name in before if before[name] != after[name])
    assert changes == sorted([ENTRY, CORE]), changes
    manifest = {"productSHA": PIN, "proofOnly": True,
                "ordinaryProviderRefresh": False,
                "declaredChangedSourceFiles": changes,
                "declaredAddedSourceFiles": [ADAPTER],
                "coreBridgeAppendOnly": True,
                "originalCoreByteCount": len(original_core),
                "coreBridgeAppendSHA256": hashlib.sha256(fragment).hexdigest(),
                "adapterSHA256": digest(root / ADAPTER),
                "beforeTrackedInputSHA256": before,
                "afterTrackedInputSHA256": after,
                "unchangedTrackedCount": sum(before[p] == after[p] for p in before)}
    args.manifest_output.parent.mkdir(parents=True, exist_ok=True)
    args.manifest_output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
