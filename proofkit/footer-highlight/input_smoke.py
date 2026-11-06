"""Disposable source/input-only smoke. Never runs App/tests or creates a runtime verdict."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--clone-from', type=Path, required=True)
args = parser.parse_args()
kit = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('footer_highlight_prove', kit / 'prove.py')
proof = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proof)
root = Path(tempfile.mkdtemp(prefix='footer-highlight-input-smoke-'))
try:
    product, out = root / 'product', root / 'prepared'
    subprocess.run(['git', 'clone', '--quiet', '--shared', '--no-checkout', str(args.clone_from), str(product)], check=True)
    subprocess.run(['git', '-C', str(product), 'checkout', '--quiet', '--detach', proof.BASE], check=True)
    proof.prepare_red(product, out)
    before = json.loads((out / 'expected-tracked-input-sha256.json').read_text())
    metadata = json.loads((out / 'provenance.json').read_text())
    injected = product / 'Sources/CodexBar/UntrackedInputNegativeControl.swift'
    injected.write_text('// Input guard control only; never compiled.\n')
    try:
        proof.assert_no_untracked(product)
    except AssertionError:
        assert str(injected.relative_to(product)) in proof.untracked_inputs(product)
    else:
        raise AssertionError('Untracked source injection was not rejected')
    injected.unlink()
    proof.assert_no_untracked(product)
    assert proof.tracked(product) == before
    # Same patch commands and frozen-test/input guards as transition, without inventing an actual RED witness.
    patch = kit / 'patches/footer.patch'
    subprocess.run(['git', 'apply', '--check', str(patch)], cwd=product, check=True)
    subprocess.run(['git', 'apply', str(patch)], cwd=product, check=True)
    proof.assert_no_untracked(product)
    after = proof.tracked(product)
    changed = [name for name in before if before[name] != after[name]]
    assert changed == [proof.SOURCE]
    assert all(proof.sha256(product / name) == sha for name, sha in metadata['selected_source_sha256'].items())
    result = {'inputOnlySmoke': True, 'productTestsOrAppExecuted': False, 'fabricatedRuntimeVerdict': False,
              'preparePassed': True, 'transitionPatchAndSameOracleGuardsPassed': True,
              'untrackedSourceInjectionRejected': True, 'trackedInputsAfterHarness': len(before),
              'onlyTransitionChangedPath': changed, 'frozenTestSHA256': proof.TEST_SHA,
              'candidatePatchSHA256': proof.sha256(patch), 'candidateSourceSHA256': proof.sha256(product / proof.SOURCE)}
    (kit / 'local-smoke.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
finally:
    shutil.rmtree(root)
