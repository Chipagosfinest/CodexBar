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
    'proof-built-CodexBar.app.zip': 'bae027c75d3d3c878aabe415e33ceda7d86a30b38e20fc5a40b4addf48bdac5d',
    'overlay.patch': '8203cd21642e387a4406011a4c2ce65f990cb82203f25c2279261036bfade72d',
    'built-input-verdict.json': '0118a4c19ef6b3c2063e3b5253fbf0d2a5922fc86fdaa6a0a3dcf41814238d50',
    'overlay-manifest.json': '69dff9b07825997e9f91db8b32dba83da07cd3c0b0a96eb8e1687b066cf76839',
}
for name, sha in expected.items():
    assert hashlib.sha256((archive / name).read_bytes()).hexdigest() == sha, name
assert (archive / 'controller-sha.txt').read_text().strip() == 'd0b7ee6a66fb374068b59bb32533c4fda93ebf67'
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
receipt = {'reusedRunID': 42218059156, 'reusedArtifactID': 13501669086,
           'originalBuildControllerSHA': 'd0b7ee6a66fb374068b59bb32533c4fda93ebf67',
           'originalArchiveSHA256': expected, 'allTrackedAndSourceInputsMatchOriginal': True,
           'allBundleFilesMatchOriginal': True, 'binarySHA256': actual['binarySHA256'],
           'newAppCompilation': False, 'productSHA': actual['productSHA']}
(output / 'reuse-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
