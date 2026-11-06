#!/usr/bin/env python3
"""Run bounded account-boundary tests against intact hosted production modules."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

PRODUCT_SHA = "fc2866c6bd25b1e1f27e01d39e8cd31c76ac83f7"
SUITES = ["CursorAccountBoundaryTests", "CursorCostAccountBoundaryTests",
          "CursorLoginAccountBoundaryTests", "CursorLoginRunnerTests", "CursorLoginBrowserRoutingTests"]


def git(product, *args):
    return subprocess.check_output(["git", *args], cwd=product, text=True).strip()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(product, output):
    assert git(product, "rev-parse", "HEAD") == PRODUCT_SHA, "Product SHA mismatch"
    assert not git(product, "status", "--porcelain"), "Product checkout must start pristine"
    output.mkdir(parents=True, exist_ok=True)
    kit = Path(__file__).resolve().parent
    production = {name: digest(product / name) for name in git(product, "ls-files", "Sources").splitlines()
                  if name.endswith(".swift")}
    (output / "production-source-sha256.json").write_text(json.dumps(production, indent=2) + "\n")
    injected = []
    for fixture in sorted((kit / "tests").glob("*.swift")):
        name = "Tests/CodexBarTests/" + fixture.name
        shutil.copyfile(fixture, product / name)
        injected.append(name)
    selected = ["Tests/CodexBarTests/" + name + ".swift" for name in SUITES]
    assert all((product / name).is_file() for name in selected)
    manifest = product / "Package.swift"
    text = manifest.read_text()
    start = text.index('            name: "CodexBarTests",')
    end = text.index("            resources:", start)
    assert "            sources:" not in text[start:end]
    selection = "            sources: [" + ", ".join(json.dumps(name.removeprefix("Tests/")) for name in selected) + "],\n"
    manifest.write_text(text[:end] + selection + text[end:])
    runner = product / "Scripts/run_swift_test.py"
    text = runner.read_text()
    needle = 'tempfile.TemporaryDirectory(prefix="codexbar-native-test-home-")'
    assert text.count(needle) == 1 and text.count("import os\n") == 1
    # Xcode Metal mounts can outlive compilation; retain only this disposable hosted HOME.
    text = text.replace("import os\n", "import contextlib\nimport os\n", 1)
    text = text.replace(needle, 'contextlib.nullcontext(tempfile.mkdtemp(prefix="codexbar-proof-test-home-"))', 1)
    runner.write_text(text)
    changed = set(git(product, "diff", "--name-only").splitlines())
    untracked = set(git(product, "ls-files", "--others", "--exclude-standard").splitlines())
    assert changed | untracked <= {"Package.swift", "Scripts/run_swift_test.py", *injected}
    assert not git(product, "diff", "--name-only", "--", "Sources"), "No production source edits permitted"
    subprocess.run(["git", "add", "--intent-to-add", "--", *injected], cwd=product, check=True)
    (output / "test-harness.patch").write_bytes(subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=product))
    for name in selected:
        destination = output / "selected-tests" / Path(name).name
        destination.parent.mkdir(exist_ok=True)
        shutil.copyfile(product / name, destination)
    metadata = {"product_sha": PRODUCT_SHA, "controller_sha": git(kit.parent.parent, "rev-parse", "HEAD"),
                "selected_sources": selected, "selected_source_sha256": {name: digest(product / name) for name in selected},
                "harness_patch_sha256": digest(output / "test-harness.patch"), "filter": "|".join(SUITES),
                "boundary": "Synthetic tests compile intact CodexBar App/Core modules. Injected browser/network/cache seams; no live login or installed-app claim."}
    (output / "provenance.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(metadata["filter"])


def verify(product, output, exit_code):
    log = (output / "tests.log").read_text(errors="replace")
    metadata = json.loads((output / "provenance.json").read_text())
    source_hashes = json.loads((output / "production-source-sha256.json").read_text())
    suite_passes = {name: bool(re.search(r'Suite "?' + re.escape(name) + r'"? passed', log)) for name in SUITES}
    summary = re.findall(r"Test run with (\d+) tests?[^\n]*", log)
    verdict = {"product_sha": PRODUCT_SHA, "exit_code": exit_code, "suites_passed": suite_passes,
               "test_counts": summary, "production_source_unchanged": all(digest(product / name) == value for name, value in source_hashes.items()),
               "selected_tests_unchanged": all(digest(product / name) == value for name, value in metadata["selected_source_sha256"].items()),
               "unexpected_failure": bool(re.search(r"Expectation failed|Issue recorded|error: (?:fatalError|Build failed)|Testing failed:|Command timed out", log))}
    verdict["verified_green"] = (exit_code == 0 and all(suite_passes.values()) and bool(summary)
                                 and verdict["production_source_unchanged"] and verdict["selected_tests_unchanged"]
                                 and not verdict["unexpected_failure"])
    (output / "verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
    print(json.dumps(verdict, indent=2))
    return 0 if verdict["verified_green"] else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "verify"])
    parser.add_argument("--product", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--exit-code", type=int)
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare(args.product.resolve(), args.output.resolve())
    else:
        assert args.exit_code is not None
        raise SystemExit(verify(args.product.resolve(), args.output.resolve(), args.exit_code))
