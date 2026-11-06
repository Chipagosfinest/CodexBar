#!/usr/bin/env python3
"""Prepare and classify bounded, synthetic RED proofs; never alter production sources."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

CASES = {
    "core": {
        "sha": "b3e44381197a743c88a5f82d9008848e8a578b44",
        "sources": ["OverviewProviderLineFreshnessTests.swift", "OverviewProviderLineTests.swift",
                    "MenuCardStaleTintTests.swift", "TestStores.swift", "ZaiTokenStoreTestSupport.swift",
                    "CodexCredentialFixtures.swift"],
        "filter": "OverviewProviderLineFreshnessTests|OverviewProviderLineTests|MenuCardStaleTintTests",
        "test": "retained code review stays stale when the quota refresh succeeded",
        "assertion": r"Expectation failed:[^\n]*line\.(?:status|caption)",
    },
    "chart": {
        "sha": "cf6efdea76161eb3061e0b954d8150231181149f",
        "sources": ["OverviewSpendChartTests.swift"],
        "filter": "OverviewSpendChartTests",
        "test": "a provider with unavailable range spend retains its priced daily contribution",
        "assertion": r"Expectation failed:[^\n]*(?:segments|daily\.legend|daily\.share)",
    },
    "footer": {
        "sha": "13185f0888b8e60ad22f72d66767f23601d7b960",
        "sources": ["OverviewOverflowPluginRefreshTests.swift", "UserProviderPluginProofSuite.swift",
                    "UserProviderPluginTestSupport.swift", "TestStores.swift",
                    "ZaiTokenStoreTestSupport.swift", "CodexCredentialFixtures.swift"],
        "filter": "UserProviderPluginTests.*successful refresh replaces a captured overflow plugin card without reopening Overview",
        "test": "successful refresh replaces a captured overflow plugin card without reopening Overview",
        "assertion": r"Expectation failed:[^\n]*(?:rebuilt|freshCard|freshView|freshFingerprint)",
    },
}

PRODUCTION_PATHS = {
    "core": {"Sources/CodexBar/Menu/OverviewProviderLine.swift"},
    "chart": {"Sources/CodexBar/Menu/OverviewSpendChart.swift",
              "Sources/CodexBar/StatusItem/StatusItemController+OverviewChart.swift"},
    "footer": {"Sources/CodexBar/StatusItem/StatusItemController+UserPlugins.swift"},
}


def git(product, *args):
    return subprocess.check_output(["git", *args], cwd=product, text=True).strip()


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(case, product, output, expectation):
    config = CASES[case]
    assert git(product, "rev-parse", "HEAD") == config["sha"], "Product SHA mismatch"
    assert not git(product, "status", "--porcelain"), "Product checkout must start pristine"
    output.mkdir(parents=True, exist_ok=True)
    kit = Path(__file__).resolve().parent
    source_files = git(product, "ls-files", "Sources").splitlines()
    source_hashes = {name: sha256(product / name) for name in source_files if name.endswith(".swift")}
    (output / "production-source-sha256.json").write_text(json.dumps(source_hashes, indent=2) + "\n")
    candidate_paths = set()
    candidate_patch_hash = None
    if expectation == "green":
        candidate = kit / "patches" / (case + ".patch")
        patch_text = candidate.read_text()
        headers = re.findall(r"^diff --git a/(\S+) b/(\S+)$", patch_text, re.MULTILINE)
        assert headers and all(before == after for before, after in headers), "Unexpected candidate patch paths"
        candidate_paths = {after for _, after in headers}
        assert candidate_paths == PRODUCTION_PATHS[case], "Candidate patch exceeds case ownership"
        subprocess.run(["git", "apply", "--check", str(candidate)], cwd=product, check=True)
        subprocess.run(["git", "apply", str(candidate)], cwd=product, check=True)
        shutil.copyfile(candidate, output / "candidate-production.patch")
        candidate_patch_hash = sha256(candidate)
    expected_hashes = {name: sha256(product / name) for name in source_hashes}
    (output / "expected-production-source-sha256.json").write_text(json.dumps(expected_hashes, indent=2) + "\n")
    injected = []
    for fixture in sorted((kit / "tests" / case).glob("*.swift")):
        destination = product / "Tests/CodexBarTests" / fixture.name
        shutil.copyfile(fixture, destination)
        injected.append("Tests/CodexBarTests/" + fixture.name)
    selected = ["Tests/CodexBarTests/" + name for name in config["sources"]]
    assert all((product / name).is_file() for name in selected), "Missing bounded test source"
    manifest = product / "Package.swift"
    text = manifest.read_text()
    start = text.index('            name: "CodexBarTests",')
    end = text.index("            resources:", start)
    assert "            sources:" not in text[start:end], "Unexpected prior source selection"
    selection = "            sources: [" + ", ".join(json.dumps(name.removeprefix("Tests/")) for name in selected) + "],\n"
    manifest.write_text(text[:end] + selection + text[end:])
    runner = product / "Scripts/run_swift_test.py"
    text = runner.read_text()
    needle = 'tempfile.TemporaryDirectory(prefix="codexbar-native-test-home-")'
    assert text.count(needle) == 1 and text.count("import os\n") == 1
    # A temporary Xcode Metal mount can outlive its build. Keep this disposable HOME
    # until the hosted runner is destroyed, without changing process containment.
    text = text.replace("import os\n", "import contextlib\nimport os\n", 1)
    text = text.replace(needle, 'contextlib.nullcontext(tempfile.mkdtemp(prefix="codexbar-proof-test-home-"))', 1)
    runner.write_text(text)
    allowed = {"Package.swift", "Scripts/run_swift_test.py", *injected, *candidate_paths}
    changed = set(git(product, "diff", "--name-only").splitlines())
    untracked = set(git(product, "ls-files", "--others", "--exclude-standard").splitlines())
    assert changed | untracked <= allowed, (changed | untracked) - allowed
    assert set(git(product, "diff", "--name-only", "--", "Sources").splitlines()) == candidate_paths
    # Include newly injected files in the patch as intent-to-add, without creating a commit.
    subprocess.run(["git", "add", "--intent-to-add", "--", *injected], cwd=product, check=True)
    patch = subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=product)
    (output / "test-harness.patch").write_bytes(patch)
    for name in selected:
        destination = output / "selected-tests" / Path(name).name
        destination.parent.mkdir(exist_ok=True)
        shutil.copyfile(product / name, destination)
    metadata = {"case": case, "expectation": expectation, "product_sha": config["sha"],
                "controller_sha": git(kit.parent, "rev-parse", "HEAD"),
                "filter": config["filter"], "expected_test": config["test"], "selected_sources": selected,
                "selected_source_sha256": {name: sha256(product / name) for name in selected},
                "harness_patch_sha256": sha256(output / "test-harness.patch"),
                "candidate_production_patch_sha256": candidate_patch_hash,
                "boundary": "Synthetic bounded tests; immutable base plus explicit candidate delta; no UI journey claim"}
    (output / "provenance.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(config["filter"])


def verify(case, product, output, exit_code, expectation):
    config = CASES[case]
    log = (output / "tests.log").read_text(errors="replace")
    started = f'Test "{config["test"]}" started' in log
    expected = re.findall(config["assertion"], log)
    controls_passed = case != "core" or bool(re.search(r'Suite "?MenuCardStaleTintTests"? passed', log))
    has_test_summary = bool(re.search(r"Test run with \d+ tests?", log))
    expected_hashes = json.loads((output / "expected-production-source-sha256.json").read_text())
    source_matches = all(sha256(product / name) == value for name, value in expected_hashes.items())
    infrastructure_error = bool(re.search(r"error: (?:fatalError|Build failed)|Testing failed:|Command timed out", log))
    verdict = {"case": case, "expectation": expectation, "product_sha": config["sha"], "exit_code": exit_code,
               "expected_test_started": started, "expected_assertions": expected,
               "baseline_metric_controls_passed": controls_passed, "has_test_summary": has_test_summary,
               "production_source_matches_declared_input": source_matches,
               "production_source_unchanged": expectation == "red" and source_matches,
               "infrastructure_error": infrastructure_error}
    verdict["behavioral_red"] = (expectation == "red" and exit_code != 0 and started and bool(expected) and controls_passed
                                 and has_test_summary and source_matches and not infrastructure_error)
    verdict["candidate_green"] = (expectation == "green" and exit_code == 0 and started and controls_passed
                                  and has_test_summary and source_matches and not infrastructure_error
                                  and "Expectation failed" not in log)
    (output / "verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
    print(json.dumps(verdict, indent=2))
    passed = verdict["behavioral_red"] if expectation == "red" else verdict["candidate_green"]
    return 0 if passed else 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "verify"])
    parser.add_argument("--case", choices=CASES, required=True)
    parser.add_argument("--product", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--exit-code", type=int)
    parser.add_argument("--expect", choices=["red", "green"], default="red")
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare(args.case, args.product.resolve(), args.output.resolve(), args.expect)
        return 0
    assert args.exit_code is not None
    return verify(args.case, args.product.resolve(), args.output.resolve(), args.exit_code, args.expect)


if __name__ == "__main__":
    sys.exit(main())
