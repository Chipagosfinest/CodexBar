#!/usr/bin/env python3
"""Single-purpose actual App/Core native-highlight RED->GREEN regression; no UI launch."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

BASE = "e8a0cca51036fa8f30362a0710754d812ace34a3"
TEST_SHA = "65125fe154fe846983ae550a6beff83d58860d0c7e90558f00c6b79631243281"
OLD = "successful refresh replaces a captured overflow plugin card without reopening Overview"
NEW = "native highlighted More refreshes its captured plugin card without replacing navigation"
SOURCE = "Sources/CodexBar/StatusItem/StatusItemController+UserPlugins.swift"
CASES = {"footer": {"sha": BASE,
    "sources": ["OverviewOverflowPluginRefreshTests.swift", "UserProviderPluginProofSuite.swift",
                "UserProviderPluginTestSupport.swift", "TestStores.swift", "ZaiTokenStoreTestSupport.swift",
                "CodexCredentialFixtures.swift"],
    "filter": "UserProviderPluginTests", "test": NEW}}
PRODUCTION_PATHS = {"footer": {SOURCE}}

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

def tracked(product):
    return {name: sha256(product / name) for name in git(product, 'ls-files').splitlines()
            if (product / name).is_file()}


def untracked_inputs(product):
    return git(product, 'ls-files', '--others', '--exclude-standard').splitlines()


def assert_no_untracked(product):
    unexpected = untracked_inputs(product)
    assert not unexpected, 'Unexpected untracked compile/input files: ' + repr(unexpected)


def save(value, path):
    path.write_text(json.dumps(value, indent=2) + '\n')


def prepare_red(product, output):
    assert git(product, 'rev-parse', 'HEAD') == BASE
    before = tracked(product)
    assert sha256(Path(__file__).parent / 'tests/footer/OverviewOverflowPluginRefreshTests.swift') == TEST_SHA
    prepare('footer', product, output, 'red')
    assert_no_untracked(product)
    save(before, output / 'before-tracked-input-sha256.json')
    save(tracked(product), output / 'expected-tracked-input-sha256.json')
    shutil.copyfile(Path(__file__).parent / 'patches/footer.patch', output / 'frozen-candidate.patch')


def transition(product, output, prior):
    verdict = json.loads((prior / 'verdict.json').read_text())
    assert verdict['behavioral_red'] and verdict['log_sha256'] == sha256(prior / 'tests.log')
    assert_no_untracked(product)
    previous = json.loads((prior / 'expected-tracked-input-sha256.json').read_text())
    assert tracked(product) == previous, 'Baseline input changed after RED'
    patch = Path(__file__).parent / 'patches/footer.patch'
    assert sha256(patch) == sha256(prior / 'frozen-candidate.patch')
    headers = re.findall(r'^diff --git a/(\S+) b/(\S+)$', patch.read_text(), re.MULTILINE)
    assert headers == [(SOURCE, SOURCE)], 'Production delta exceeds one owned file'
    subprocess.run(['git', 'apply', '--check', str(patch.resolve())], cwd=product, check=True)
    subprocess.run(['git', 'apply', str(patch.resolve())], cwd=product, check=True)
    assert set(git(product, 'diff', '--name-only', '--', 'Sources').splitlines()) == {SOURCE}
    output.mkdir(parents=True, exist_ok=True)
    metadata = json.loads((prior / 'provenance.json').read_text())
    assert all(sha256(product / name) == value for name, value in metadata['selected_source_sha256'].items())
    current = tracked(product)
    assert {name for name in current if current[name] != previous[name]} == {SOURCE}
    metadata.update(expectation='green', candidate_production_patch_sha256=sha256(patch),
                    prior_runtime_verdict_sha256=sha256(prior / 'verdict.json'))
    save(metadata, output / 'provenance.json')
    save(current, output / 'expected-tracked-input-sha256.json')
    expected_source = json.loads((prior / 'expected-production-source-sha256.json').read_text())
    save({name: sha256(product / name) for name in expected_source}, output / 'expected-production-source-sha256.json')
    for name in ['before-tracked-input-sha256.json', 'production-source-sha256.json']:
        shutil.copyfile(prior / name, output / name)
    shutil.copyfile(patch, output / 'candidate-production.patch')
    (output / 'test-harness.patch').write_bytes(subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=product))
    metadata['harness_patch_sha256'] = sha256(output / 'test-harness.patch')
    save(metadata, output / 'provenance.json')
    shutil.copytree(prior / 'selected-tests', output / 'selected-tests')
    print('UserProviderPluginTests')


def classify(log, exit_code, expectation):
    def outcome(name, result):
        # These two methods are deliberately nonparameterized. No optional test-case grammar.
        return bool(re.search(r'Test "' + re.escape(name) + r'" ' + result + r' after ', log))
    starts = all(f'Test "{name}" started' in log for name in [OLD, NEW])
    summaries = re.findall(r'Test run with (\d+) tests? in (\d+) suites? (passed|failed) after [^\n]+', log)
    exact_summary = len(summaries) == 1 and summaries[0] == ('2', '1', 'failed' if expectation == 'red' else 'passed')
    failures = [line for line in log.splitlines() if 'Expectation failed:' in line]
    witnesses = {
        'nested_callback': any('rebuilt' in line and 'overflow' in line for line in failures),
        'captured_card': any('freshCard' in line and 'oldCard' in line for line in failures),
        'captured_view': any('freshView' in line and 'oldView' in line for line in failures),
        'fresh_fingerprint': any('freshFingerprint' in line for line in failures),
    }
    expected_failures_only = all(any(token in line for token in ['rebuilt', 'freshCard', 'freshView', 'freshFingerprint'])
                                 for line in failures)
    infra = bool(re.search(r'(?:^|\n)[^\n]*(?:error:|Testing failed:|Command timed out|Fatal error:|Precondition failed)', log))
    result = {'both_named_tests_started': starts, 'original_control_passed': outcome(OLD, 'passed'),
              'new_regression_failed': outcome(NEW, 'failed'), 'new_regression_passed': outcome(NEW, 'passed'),
              'exact_two_test_one_suite_summary': exact_summary, 'summaries': summaries,
              'expected_runtime_witnesses': witnesses, 'expected_failures_only': expected_failures_only,
              'expectation_failure_lines': failures, 'infrastructure_error': infra, 'exit_code': exit_code}
    result['behavioral_red'] = (expectation == 'red' and exit_code == 1 and starts and exact_summary
                                and result['original_control_passed'] and result['new_regression_failed']
                                and all(witnesses.values()) and expected_failures_only and not infra)
    result['candidate_green'] = (expectation == 'green' and exit_code == 0 and starts and exact_summary
                                and result['original_control_passed'] and result['new_regression_passed']
                                and not failures and not infra)
    return result


def verify(product, output, expectation, exit_code):
    verdict = classify((output / 'tests.log').read_text(errors='replace'), exit_code, expectation)
    expected = json.loads((output / 'expected-tracked-input-sha256.json').read_text())
    verdict['unexpected_untracked_inputs'] = untracked_inputs(product)
    verdict['no_untracked_inputs'] = not verdict['unexpected_untracked_inputs']
    verdict['all_tracked_inputs_match'] = tracked(product) == expected
    verdict['frozen_test_sha256_matches'] = sha256(product / 'Tests/CodexBarTests/OverviewOverflowPluginRefreshTests.swift') == TEST_SHA
    verdict['log_sha256'] = sha256(output / 'tests.log')
    for key in ['behavioral_red', 'candidate_green']:
        verdict[key] = verdict[key] and verdict['no_untracked_inputs'] and verdict['all_tracked_inputs_match'] and verdict['frozen_test_sha256_matches']
    save(verdict, output / 'verdict.json')
    print(json.dumps(verdict, indent=2))
    return 0 if verdict['behavioral_red' if expectation == 'red' else 'candidate_green'] else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['prepare', 'transition', 'verify'])
    parser.add_argument('--product', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--prior', type=Path)
    parser.add_argument('--expect', choices=['red', 'green'])
    parser.add_argument('--exit-code', type=int)
    args = parser.parse_args()
    product, output = args.product.resolve(), args.output.resolve()
    if args.mode == 'prepare':
        prepare_red(product, output)
    elif args.mode == 'transition':
        transition(product, output, args.prior.resolve())
    else:
        assert args.expect and args.exit_code is not None
        sys.exit(verify(product, output, args.expect, args.exit_code))
