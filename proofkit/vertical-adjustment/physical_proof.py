#!/usr/bin/env python3
"""Classify attachment baseline regressions against intact hosted production App/Core modules."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

PRODUCT_SHA = "5614c2736caf037cd5205151194dd036f205f792"
SUITES = ["MenuBarUsageTotalTests"]
SUPPORT = ["TestStores.swift", "ZaiTokenStoreTestSupport.swift", "CodexCredentialFixtures.swift"]



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
    original_tests = (product / "Tests/CodexBarTests/MenuBarUsageTotalTests.swift").read_text()
    original_names = re.findall(r"func `([^`]+)`", original_tests)
    assert digest(kit / "tests/MenuBarUsageTotalTests.swift") == "0e442f51112e7ee2dc1456eb77a38b2fab01dc5296ec096b9e9c1a6defc24303"
    injected = []
    for fixture in sorted((kit / "tests").glob("*.swift")):
        name = "Tests/CodexBarTests/" + fixture.name
        shutil.copyfile(fixture, product / name)
        injected.append(name)
    candidate_paths = set()
    candidate_hash = None
    if expectation in {"red", "green"}:
        candidate = kit / ("prephysical-ee6b.patch" if expectation == "red" else "candidate.patch")
        headers = re.findall(r"^diff --git a/(\S+) b/(\S+)$", candidate.read_text(), re.MULTILINE)
        assert headers and all(before == after for before, after in headers)
        assert {after for _, after in headers} == {"Sources/CodexBar/Menu/MenuBarUsageTotal.swift",
                                                   "Tests/CodexBarTests/MenuBarUsageTotalTests.swift"}
        subprocess.run(["git", "apply", "--check", "--include=Sources/*", str(candidate)], cwd=product, check=True)
        subprocess.run(["git", "apply", "--include=Sources/*", str(candidate)], cwd=product, check=True)
        candidate_paths = {"Sources/CodexBar/Menu/MenuBarUsageTotal.swift"}
        candidate_hash = digest(candidate)
        shutil.copyfile(candidate, output / "candidate.patch")
    expected = {name: digest(product / name) for name in production}
    (output / "expected-production-source-sha256.json").write_text(json.dumps(expected, indent=2) + "\n")
    selected = ["Tests/CodexBarTests/" + name + ".swift" for name in SUITES]
    selected += ["Tests/CodexBarTests/" + name for name in SUPPORT]
    fixture_names = re.findall(r"func `([^`]+)`", (product / selected[0]).read_text())
    assert set(original_names) <= set(fixture_names), "Original methods removed"
    added = set(fixture_names) - set(original_names)
    assert {"saved vertical adjustment moves every total attachment equally",
            "saved vertical adjustment moves the actual normal contrast leading pixels"} <= added
    regressions = ["native warning capsule pixels follow the saved vertical adjustment"]
    assert regressions[0] in added
    original_names = sorted(set(fixture_names) - set(regressions))
    assert regressions and set(original_names) <= set(fixture_names), "Added regressions required; original tests retained"
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
    assert changed | untracked <= {"Package.swift", "Scripts/run_swift_test.py", *injected, *candidate_paths}
    assert set(git(product, "diff", "--name-only", "--", "Sources").splitlines()) == candidate_paths
    subprocess.run(["git", "add", "--intent-to-add", "--", *injected], cwd=product, check=True)
    (output / "test-harness.patch").write_bytes(subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=product))
    for name in selected:
        destination = output / "selected-tests" / Path(name).name
        destination.parent.mkdir(exist_ok=True)
        shutil.copyfile(product / name, destination)
    metadata = {"product_sha": PRODUCT_SHA, "controller_sha": git(kit.parent.parent, "rev-parse", "HEAD"), "expectation": expectation, "candidate_patch_sha256": candidate_hash, "reused_behavioral_red_run": 42200878422, "limited_green_and_failed_visual_run": 42202916289,
                "selected_sources": selected, "selected_source_sha256": {name: digest(product / name) for name in selected},
                "harness_patch_sha256": digest(output / "test-harness.patch"), "filter": "|".join(SUITES), "baseline_test_names": original_names, "regression_test_names": regressions,
                "boundary": "Synthetic actual AppKit attachment tests compile intact production App/Core modules; baseline or explicit production-only candidate delta; no installed-app claim."}
    (output / "provenance.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(metadata["filter"])


def transition(product, output, prior):
    kit = Path(__file__).resolve().parent
    assert git(product, "rev-parse", "HEAD") == PRODUCT_SHA
    previous_verdict = json.loads((prior / "verdict.json").read_text())
    metadata = json.loads((prior / "provenance.json").read_text())
    assert previous_verdict["behavioral_red"] is True, "Actual physical-oracle RED required"
    expected = json.loads((prior / "expected-production-source-sha256.json").read_text())
    assert all(digest(product / name) == value for name, value in expected.items())
    assert all(digest(product / name) == value for name, value in metadata["selected_source_sha256"].items())
    candidate = kit / "candidate.patch"
    headers = re.findall(r"^diff --git a/(\S+) b/(\S+)$", candidate.read_text(), re.MULTILINE)
    assert headers and all(before == after for before, after in headers)
    assert {after for _, after in headers} == {"Sources/CodexBar/Menu/MenuBarUsageTotal.swift",
                                               "Tests/CodexBarTests/MenuBarUsageTotalTests.swift"}
    prephysical = kit / "prephysical-ee6b.patch"
    assert digest(prephysical) == metadata["candidate_patch_sha256"]
    subprocess.run(["git", "apply", "-R", "--check", "--include=Sources/*", str(prephysical)], cwd=product, check=True)
    subprocess.run(["git", "apply", "-R", "--include=Sources/*", str(prephysical)], cwd=product, check=True)
    subprocess.run(["git", "apply", "--check", "--include=Sources/*", str(candidate)], cwd=product, check=True)
    subprocess.run(["git", "apply", "--include=Sources/*", str(candidate)], cwd=product, check=True)
    assert all(digest(product / name) == value for name, value in metadata["selected_source_sha256"].items()), "Oracle changed"
    assert set(git(product, "diff", "--name-only", "--", "Sources").splitlines()) == {"Sources/CodexBar/Menu/MenuBarUsageTotal.swift"}
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(prior / "production-source-sha256.json", output / "production-source-sha256.json")
    (output / "expected-production-source-sha256.json").write_text(json.dumps(
        {name: digest(product / name) for name in expected}, indent=2) + "\n")
    for name in metadata["selected_sources"]:
        destination = output / "selected-tests" / Path(name).name
        destination.parent.mkdir(exist_ok=True)
        shutil.copyfile(product / name, destination)
    (output / "test-harness.patch").write_bytes(subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=product))
    shutil.copyfile(candidate, output / "candidate.patch")
    metadata.update(expectation="green", candidate_patch_sha256=digest(candidate),
                    harness_patch_sha256=digest(output / "test-harness.patch"),
                    prephysical_patch_sha256=digest(prephysical),
                    prior_runtime_verdict_sha256=digest(prior / "verdict.json"))
    (output / "provenance.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(metadata["filter"])


def verify(product, output, exit_code, expectation):
    log = (output / "tests.log").read_text(errors="replace")
    metadata = json.loads((output / "provenance.json").read_text())
    source_hashes = json.loads((output / "expected-production-source-sha256.json").read_text())
    suite_passes = {name: bool(re.search(r'Suite "?' + re.escape(name) + r'"? passed', log)) for name in SUITES}
    summary = re.findall(r"Test run with (\d+) tests?[^\n]*", log)
    verdict = {"product_sha": PRODUCT_SHA, "exit_code": exit_code, "suites_passed": suite_passes,
               "test_counts": summary, "production_source_matches_declared_input": all(digest(product / name) == value for name, value in source_hashes.items()),
               "selected_tests_unchanged": all(digest(product / name) == value for name, value in metadata["selected_source_sha256"].items()),
               "unexpected_failure": bool(re.search(r"Expectation failed|Issue recorded|error: (?:fatalError|Build failed)|Testing failed:|Command timed out", log))}
    controls = {name: bool(re.search(r'Test "' + re.escape(name) + r'"(?: with \d+ test cases)? passed', log))
                for name in metadata["baseline_test_names"]}
    regressions = {name: bool(re.search(r'Test "' + re.escape(name) + r'"(?: with \d+ test cases)? failed', log))
                   for name in metadata["regression_test_names"]}
    infra = bool(re.search(r"error: (?:fatalError|Build failed)|Testing failed:|Command timed out", log))
    verdict.update(baseline_controls_passed=controls, regression_tests_failed=regressions)
    verdict["behavioral_red"] = (expectation == "red" and exit_code != 0 and all(controls.values()) and all(regressions.values())
                                 and bool(summary) and "Expectation failed" in log and not infra
                                 and verdict["production_source_matches_declared_input"] and verdict["selected_tests_unchanged"])
    regression_passes = {name: bool(re.search(r'Test "' + re.escape(name) + r'"(?: with \d+ test cases)? passed', log))
                         for name in metadata["regression_test_names"]}
    verdict.update(expectation=expectation, regression_tests_passed=regression_passes)
    verdict["verified_green"] = (expectation == "green" and exit_code == 0 and all(controls.values())
                                  and all(regression_passes.values()) and all(suite_passes.values()) and bool(summary)
                                  and not verdict["unexpected_failure"] and verdict["production_source_matches_declared_input"]
                                  and verdict["selected_tests_unchanged"])
    (output / "verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
    print(json.dumps(verdict, indent=2))
    return 0 if (verdict["behavioral_red"] if expectation == "red" else verdict["verified_green"]) else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["prepare", "transition", "verify"])
    parser.add_argument("--product", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--exit-code", type=int)
    parser.add_argument("--prior", type=Path)
    parser.add_argument("--expect", choices=["red", "green"], default="red")
    args = parser.parse_args()
    if args.mode == "prepare":
        prepare(args.product.resolve(), args.output.resolve(), args.expect)
    elif args.mode == "transition":
        assert args.prior is not None
        transition(args.product.resolve(), args.output.resolve(), args.prior.resolve())
    else:
        assert args.exit_code is not None
        raise SystemExit(verify(args.product.resolve(), args.output.resolve(), args.exit_code, args.expect))
