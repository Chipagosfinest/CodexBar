"""Compile/run the verbatim pure oracle block from the actual proof adapter, without app startup."""
import hashlib
import json
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
compiler = subprocess.check_output(['xcrun', '--find', 'swiftc'], text=True).strip()
subprocess.run([compiler, '-parse-as-library', str(out / 'FooterOracle.swift'), str(kit / 'OracleControls.swift'),
                '-o', str(out / 'oracle-controls')], check=True)
value = json.loads(subprocess.check_output([str(out / 'oracle-controls')], text=True))
assert value['controlsPassed'] and len(value['cases']) == 13
value['actualAdapterSHA256'] = hashlib.sha256((kit / 'PackagedFooterProof.swift').read_bytes()).hexdigest()
value['verbatimOracleBlockSHA256'] = hashlib.sha256(core).hexdigest()
(out / 'controls.json').write_text(json.dumps(value, indent=2) + '\n')
print(json.dumps(value, indent=2))
