#!/usr/bin/env python3
"""Classify real Cursor CLI cache RED/GREEN using intact production App/Core/CLI modules."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

PRODUCT_SHA = "ec61c49dd71c3aa6efe33162762ef2164ecfaea1"
SUITES = ["CursorAccountBoundaryTests", "CursorCostAccountBoundaryTests", "CursorLoginAccountBoundaryTests",
          "CursorLoginRunnerTests", "CursorLoginBrowserRoutingTests", "CLIUsageCacheTests"]
SUPPORT = []
PATCH_PATHS = {"Sources/CodexBarCore/CLIUsageCache.swift",
               "Sources/CodexBarCore/Providers/Cursor/CursorProviderDescriptor.swift",
               "Tests/CodexBarTests/CLIUsageCacheTests.swift", "Tests/CodexBarTests/CursorAccountBoundaryTests.swift"}
CORE_TEST = "private CLI cache preserves explicit unified evidence through disk round trip"
CLI_TEST = "private Cursor cache renders authoritative allowance labels"



def git(product, *args):
    return subprocess.check_output(["git", *args], cwd=product, text=True).strip()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(product, output, expectation):
    assert git(product, "rev-parse", "HEAD") == PRODUCT_SHA, "Product SHA mismatch"
    assert not git(product, "status", "--porcelain"), "Product checkout must start pristine"
    output.mkdir(parents=True, exist_ok=True)
    kit = Path(__file__).resolve().parent
    production = {name: digest(product / name) for name in git(product, "ls-files", "Sources").splitlines()
                  if name.endswith(".swift")}
    (output / "production-source-sha256.json").write_text(json.dumps(production, indent=2) + "\n")
    candidate = kit / "candidate.patch"
    headers = re.findall(r"^diff --git a/(\S+) b/(\S+)$", candidate.read_text(), re.MULTILINE)
    assert headers and all(before == after for before, after in headers)
    assert {after for _, after in headers} == PATCH_PATHS
    selection = ["--include=Tests/CodexBarTests/*"] if expectation == "red" else []
    subprocess.run(["git", "apply", "--check", *selection, str(candidate)], cwd=product, check=True)
    subprocess.run(["git", "apply", *selection, str(candidate)], cwd=product, check=True)
    shutil.copyfile(candidate, output / "candidate.patch")
    expected = {name: digest(product / name) for name in production}
    (output / "expected-production-source-sha256.json").write_text(json.dumps(expected, indent=2) + "\n")
    selected = ["Tests/CodexBarTests/" + name + ".swift" for name in SUITES]
    selected += ["Tests/CodexBarTests/" + name for name in SUPPORT]
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
    assert changed | untracked <= {"Package.swift", "Scripts/run_swift_test.py", *PATCH_PATHS}
    assert set(git(product, "diff", "--name-only", "--", "Sources").splitlines()) == ({name for name in PATCH_PATHS if name.startswith("Sources/")} if expectation == "green" else set())
    (output / "test-harness.patch").write_bytes(subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=product))
    for name in selected:
        destination = output / "selected-tests" / Path(name).name
        destination.parent.mkdir(exist_ok=True)
        shutil.copyfile(product / name, destination)
    metadata = {"product_sha": PRODUCT_SHA, "controller_sha": git(kit.parent.parent, "rev-parse", "HEAD"),
                "selected_sources": selected, "selected_source_sha256": {name: digest(product / name) for name in selected},
                "harness_patch_sha256": digest(output / "test-harness.patch"), "filter": "|".join(SUITES if expectation == "green" else ["CursorAccountBoundaryTests", "CLIUsageCacheTests"]), "expectation": expectation, "candidate_patch_sha256": digest(candidate),
                "boundary": "Synthetic tests compile intact App/Core modules at immutable baseline plus declared four-file cache/test delta (tests only for RED). No account/keychain or installed-app claim."}
    (output / "provenance.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(metadata["filter"])


def verify(product, output, exit_code, expectation):
    log = (output / "tests.log").read_text(errors="replace")
    metadata = json.loads((output / "provenance.json").read_text())
    source_hashes = json.loads((output / "expected-production-source-sha256.json").read_text())
    suite_passes = {name: bool(re.search(r'Suite "?' + re.escape(name) + r'"? passed', log)) for name in SUITES}
    summary = re.findall(r"Test run with (\d+) tests?[^\n]*", log)
    verdict = {"product_sha": PRODUCT_SHA, "exit_code": exit_code, "suites_passed": suite_passes,
               "test_counts": summary, "production_source_matches_declared_candidate": all(digest(product / name) == value for name, value in source_hashes.items()),
               "selected_tests_unchanged": all(digest(product / name) == value for name, value in metadata["selected_source_sha256"].items()),
               "unexpected_failure": bool(re.search(r"Expectation failed|Issue recorded|error: (?:fatalError|Build failed)|Testing failed:|Command timed out", log))}
    runtime_core_failure = bool(re.search(r'Test "' + re.escape(CORE_TEST) + r'" failed', log))
    runtime_cli_failure = bool(re.search(r'Test "' + re.escape(CLI_TEST) + r'"(?: with \d+ test cases)? failed', log))
    verdict.update(expectation=expectation, core_regression_failed=runtime_core_failure,
                   cli_renderer_regression_failed=runtime_cli_failure)
    infrastructure_error = bool(re.search(r"error: (?:fatalError|Build failed)|Testing failed:|Command timed out", log))
    verdict["behavioral_red"] = (expectation == "red" and exit_code != 0 and runtime_core_failure
                                  and runtime_cli_failure and bool(summary)
                                  and "Expectation failed" in log and not infrastructure_error
                                  and verdict["production_source_matches_declared_candidate"]
                                  and verdict["selected_tests_unchanged"])
    verdict["verified_green"] = (expectation == "green" and exit_code == 0 and all(suite_passes.values()) and bool(summary)
                                 and verdict["production_source_matches_declared_candidate"] and verdict["selected_tests_unchanged"]
                                 and not verdict["unexpected_failure"])
    (output / "verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
    print(json.dumps(verdict, indent=2))
    return 0 if (verdict["verified_green"] if expectation == "green" else verdict["behavioral_red"]) else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "verify"])
    parser.add_argument("--product", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--exit-code", type=int)
    parser.add_argument("--expect", choices=["red", "green"], required=True)
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare(args.product.resolve(), args.output.resolve(), args.expect)
    else:
        assert args.exit_code is not None
        raise SystemExit(verify(args.product.resolve(), args.output.resolve(), args.exit_code, args.expect))
