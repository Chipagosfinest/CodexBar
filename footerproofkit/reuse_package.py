#!/usr/bin/env python3
"""Verify and reuse only the exact previously built proof bundle; never rebuild it."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

archive, product, output = [Path(x).resolve() for x in sys.argv[1:]]
expected = {
    'proof-built-CodexBar.app.zip': 'f970ba777419e9d1f364a15f4c18d3a25e6ba3840c35b34511611003ad3132e1',
    'overlay.patch': '1a536ed3bb26ac096b69a9b624c18de283171816069906a1aae79fbfd1db4ae0',
    'built-input-verdict.json': '3187ebed80959a5e54338595cdf82f59513907c48ab44c946efc59a33baa8402',
    'overlay-manifest.json': '470c8226e3487a4dad3cce2e7ef704db54662811c0aad1c430f926c2cf766181',
}
for name, sha in expected.items():
    assert hashlib.sha256((archive / name).read_bytes()).hexdigest() == sha, name
assert (archive / 'controller-sha.txt').read_text().strip() == '2ee977920c6dd013b93afbdf349a33660fcff781'
assert not (product / '.build').exists() and not (product / 'CodexBar.app').exists(), 'Require fresh source-only checkout, no build reuse'
output.mkdir(parents=True, exist_ok=True)
subprocess.run([sys.executable, str(Path(__file__).with_name('prepare_overlay.py')),
                '--apply-to-disposable-copy', str(product), '--manifest-output', str(output / 'overlay-manifest.json')], check=True)
assert json.loads((output / 'overlay-manifest.json').read_text()) == json.loads((archive / 'overlay-manifest.json').read_text())
shutil.copyfile(archive / 'overlay.patch', output / 'overlay.patch')
subprocess.run(['ditto', '-x', '-k', str(archive / 'proof-built-CodexBar.app.zip'), str(product)], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name('verify_inputs.py')), str(product), str(output)], check=True)
actual = json.loads((output / 'built-input-verdict.json').read_text())
original = json.loads((archive / 'built-input-verdict.json').read_text())
assert original['binarySHA256'] == 'cdcb62d6e2e6601b8322c2714cac5730c16bc9eb7d07d0b1d6ea7556c38b4c12'
assert actual == original, 'Reused bundle/source/input identity differs from original built artifact'
subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(product / 'CodexBar.app')], check=True)
receipt = {'reusedRunID': 42242259960, 'reusedArtifactID': 13516399711,
           'originalBuildControllerSHA': '2ee977920c6dd013b93afbdf349a33660fcff781',
           'originalArchiveSHA256': expected, 'allTrackedAndSourceInputsMatchOriginal': True,
           'allBundleFilesMatchOriginal': True, 'binarySHA256': actual['binarySHA256'],
           'newAppCompilation': False, 'productSHA': actual['productSHA']}
(output / 'reuse-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
