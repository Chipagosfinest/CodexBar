#!/usr/bin/env python3
"""Fresh GREEN only; separately classify immutable prior native-highlight runtime RED."""
import argparse, hashlib, importlib.util, json, os, re, subprocess, zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('frozen_footer', HERE.parent / 'footer-highlight/prove.py')
old = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(old)
RUN = 42237102523
ARTIFACT = 13514105099
CONTROLLER = '2b593a0865d851605f98d93bd447df98c56cec65'
ZIP_SHA = '53cb100d6fd0d596521bafb7a865a81cc91afcbe0f01aa05af448b0fc5ff1e74'
LOG_SHA = 'a31f5b49c65b31f8838d99b6a91138ac9e5e042b4185a6907ded943d86cff9e2'
PATCH_SHA = '574c1c7468735d813b979c1ff2c83963807df36ebee2a5caa229adf28ab3f961'
SOURCE_SHA = '9792aa446f3edd603aa0445ee1c5085b765707a6c62281d5e224086073759524'

def api(path):
    return subprocess.check_output(['gh', 'api', 'repos/Chipagosfinest/CodexBar/' + path])

def classify_prior(prior):
    log = (prior / 'tests.log').read_text()
    assert old.sha256(prior / 'tests.log') == LOG_SHA
    original = json.loads((prior / 'verdict.json').read_text())
    assert original['behavioral_red'] is False
    result = old.classify(log, 1, 'red')
    failures = result['expectation_failure_lines']
    assert len(failures) == 3
    tokens = [('rebuilt', 'overflow'), ('freshCard', 'oldCard'), ('freshView', 'oldView')]
    assert all(sum(all(t in line for t in pair) for line in failures) == 1 for pair in tokens)
    assert all(old.NEW in line for line in failures)
    assert result['both_named_tests_started'] and result['original_control_passed']
    assert result['new_regression_failed'] and not result['new_regression_passed']
    assert result['exact_two_test_one_suite_summary'] and not result['infrastructure_error']
    assert re.search(r'Test run with 2 tests in 1 suite failed after [^\n]* with 3 issues\.', log)
    assert (prior / 'test-exit.txt').read_text().strip() == '1'
    assert all(original[k] for k in ['no_untracked_inputs', 'all_tracked_inputs_match', 'frozen_test_sha256_matches'])
    assert original['unexpected_untracked_inputs'] == []
    metadata = json.loads((prior / 'provenance.json').read_text())
    assert metadata['product_sha'] == old.BASE and metadata['controller_sha'] == CONTROLLER
    assert metadata['selected_sources'] == old.CASES['footer']['sources'] or metadata['selected_sources'] == ['Tests/CodexBarTests/' + n for n in old.CASES['footer']['sources']]
    assert all(old.sha256(prior / 'selected-tests' / Path(n).name) == v for n,v in metadata['selected_source_sha256'].items())
    assert old.sha256(prior / 'selected-tests/OverviewOverflowPluginRefreshTests.swift') == old.TEST_SHA
    assert old.sha256(prior / 'frozen-candidate.patch') == PATCH_SHA
    assert json.loads((prior / 'production-source-sha256.json').read_text()) == json.loads((prior / 'expected-production-source-sha256.json').read_text())
    return {'correctedBehavioralRed': True, 'originalVerdictUnchanged': False == original['behavioral_red'],
            'originalVerdictSHA256': old.sha256(prior / 'verdict.json'), 'rawLogSHA256': LOG_SHA,
            'priorRun': RUN, 'priorController': CONTROLLER, 'archiveSHA256': ZIP_SHA,
            'exactThreeFailures': failures, 'summary': result['summaries'],
            'explanation': 'Original classifier over-required fresh-cache fingerprint failure. Cache may warm while captured card/view remain stale. Actual test assertions unchanged.'}

def download(out):
    out.mkdir(parents=True, exist_ok=True)
    run = json.loads(api(f'actions/runs/{RUN}'))
    artifact = json.loads(api(f'actions/artifacts/{ARTIFACT}'))
    assert run['id'] == RUN and run['head_sha'] == CONTROLLER
    assert run['status'] == 'completed' and run['conclusion'] == 'failure'
    assert artifact['id'] == ARTIFACT and artifact['workflow_run']['id'] == RUN
    assert artifact['workflow_run']['head_sha'] == CONTROLLER and not artifact['expired']
    assert artifact['name'] == 'footer-highlight-red-green-1'
    archive = out / 'original-artifact.zip'
    archive.write_bytes(api(f'actions/artifacts/{ARTIFACT}/zip'))
    assert old.sha256(archive) == ZIP_SHA, 'Original archive mismatch'
    old.save(run, out / 'original-run-metadata.json'); old.save(artifact, out / 'original-artifact-metadata.json')
    with zipfile.ZipFile(archive) as z:
        assert all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in z.namelist())
        z.extractall(out / 'original')
    prior = out / 'original/red'
    old.save(classify_prior(prior), out / 'corrected-baseline-classification.json')

def prepare(product, out):
    prior = out / 'original/red'
    corrected = classify_prior(prior)
    frozen = subprocess.check_output(['git', 'show', CONTROLLER + ':proofkit/footer-highlight/prove.py'], cwd=HERE)
    assert (HERE.parent / 'footer-highlight/prove.py').read_bytes() == frozen, 'Frozen harness changed'
    assert old.sha256(HERE.parent / 'footer-highlight/patches/footer.patch') == PATCH_SHA
    assert old.sha256(HERE.parent / 'footer-highlight/tests/footer/OverviewOverflowPluginRefreshTests.swift') == old.TEST_SHA
    before = old.tracked(product)
    assert before == json.loads((prior / 'before-tracked-input-sha256.json').read_text()), 'Fresh baseline differs from actual prior compiled baseline'
    old.prepare('footer', product, out / 'green', 'green')
    old.assert_no_untracked(product)
    current = old.tracked(product)
    previous = json.loads((prior / 'expected-tracked-input-sha256.json').read_text())
    assert current.keys() == previous.keys()
    assert {n for n in current if current[n] != previous[n]} == {old.SOURCE}
    assert old.sha256(product / old.SOURCE) == SOURCE_SHA
    metadata = json.loads((out / 'green/provenance.json').read_text())
    assert metadata['selected_source_sha256'] == json.loads((prior / 'provenance.json').read_text())['selected_source_sha256']
    old.save(current, out / 'green/expected-tracked-input-sha256.json')
    old.save(corrected, out / 'corrected-baseline-classification.json')
    old.save({'sameSixTestHashes': True, 'onlyCompiledInputDelta': old.SOURCE,
              'candidateSourceSHA256': SOURCE_SHA, 'candidatePatchSHA256': PATCH_SHA,
              'priorArchiveSHA256': ZIP_SHA}, out / 'green/input-comparison.json')

if __name__ == '__main__':
    p = argparse.ArgumentParser(); p.add_argument('mode', choices=['download','prepare','verify'])
    p.add_argument('--output', type=Path, required=True); p.add_argument('--product', type=Path); p.add_argument('--exit-code', type=int)
    a=p.parse_args(); out=a.output.resolve()
    if a.mode == 'download': download(out)
    elif a.mode == 'prepare': prepare(a.product.resolve(),out)
    else:
        classify_prior(out / 'original/red')
        assert old.sha256(a.product / old.SOURCE) == SOURCE_SHA
        raise SystemExit(old.verify(a.product.resolve(),out/'green','green',a.exit_code))
