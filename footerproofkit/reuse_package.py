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
    'proof-built-CodexBar.app.zip': 'eb6e6de23e425cb610b7a440b0ba9937868e4ebc814f9d6622f33c4badb5d172',
    'overlay.patch': '3e35779751bef87413f8dd3f2bfbf591223fea7250dca869abf35ac08b53889f',
    'built-input-verdict.json': '6b473f2021f954255f402c5691bb1fbe91eed089379a6527a0d4d564147b0618',
    'overlay-manifest.json': '41c52f5226855d86196e9f486c839df8ef0612846a223c33b2e7b8c6ea0bea05',
}
for name, sha in expected.items():
    assert hashlib.sha256((archive / name).read_bytes()).hexdigest() == sha, name
assert (archive / 'controller-sha.txt').read_text().strip() == 'cfa990386e590bebf1e9febaf3a6dd99e40aad6b'
output.mkdir(parents=True, exist_ok=True)
subprocess.run([sys.executable, str(Path(__file__).with_name('prepare_overlay.py')),
                '--apply-to-disposable-copy', str(product), '--manifest-output', str(output / 'overlay-manifest.json')], check=True)
assert json.loads((output / 'overlay-manifest.json').read_text()) == json.loads((archive / 'overlay-manifest.json').read_text())
shutil.copyfile(archive / 'overlay.patch', output / 'overlay.patch')
subprocess.run(['ditto', '-x', '-k', str(archive / 'proof-built-CodexBar.app.zip'), str(product)], check=True)
subprocess.run([sys.executable, str(Path(__file__).with_name('verify_inputs.py')), str(product), str(output)], check=True)
actual = json.loads((output / 'built-input-verdict.json').read_text())
original = json.loads((archive / 'built-input-verdict.json').read_text())
assert actual == original, 'Reused bundle/source/input identity differs from original built artifact'
subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(product / 'CodexBar.app')], check=True)
receipt = {'reusedRunID': 42218270832, 'reusedArtifactID': 13502523884,
           'originalBuildControllerSHA': 'cfa990386e590bebf1e9febaf3a6dd99e40aad6b',
           'originalArchiveSHA256': expected, 'allTrackedAndSourceInputsMatchOriginal': True,
           'allBundleFilesMatchOriginal': True, 'binarySHA256': actual['binarySHA256'],
           'newAppCompilation': False, 'productSHA': actual['productSHA']}
(output / 'reuse-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
