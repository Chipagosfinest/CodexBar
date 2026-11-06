"""Compile/run the verbatim pure oracle block from the actual proof adapter, without app startup."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

kit = Path(__file__).resolve().parent
out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
lines = (kit / 'PackagedFooterProof.swift').read_text().splitlines(keepends=True)
start = next(i for i, s in enumerate(lines) if 'BEGIN PURE FOOTER ORACLE' in s) + 1
end = next(i for i, s in enumerate(lines) if 'END PURE FOOTER ORACLE' in s)
core = ''.join(lines[start:end]).encode()
(out / 'FooterOracle.swift').write_bytes(core)
compiler = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--find', 'swiftc'], text=True).strip()
sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
context = {'developerDir': os.environ.get('DEVELOPER_DIR'), 'resolvedCompiler': compiler, 'explicitSDK': sdk,
           'version': subprocess.check_output(['xcrun', '--sdk', 'macosx', 'swiftc', '--version'], text=True, stderr=subprocess.STDOUT)}
(out / 'compiler-context.json').write_text(json.dumps(context, indent=2) + '\n')
subprocess.run(['xcrun', '--sdk', 'macosx', 'swiftc', '-sdk', sdk, '-parse-as-library', str(out / 'FooterOracle.swift'), str(kit / 'OracleControls.swift'),
                '-o', str(out / 'oracle-controls')], check=True)
value = json.loads(subprocess.check_output([str(out / 'oracle-controls')], text=True))
assert value['controlsPassed'] and len(value['cases']) == 13
value['actualAdapterSHA256'] = hashlib.sha256((kit / 'PackagedFooterProof.swift').read_bytes()).hexdigest()
value['verbatimOracleBlockSHA256'] = hashlib.sha256(core).hexdigest()
(out / 'controls.json').write_text(json.dumps(value, indent=2) + '\n')
print(json.dumps(value, indent=2))
