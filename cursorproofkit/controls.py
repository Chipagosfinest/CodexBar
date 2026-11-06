import hashlib,json,subprocess,sys
from pathlib import Path
from guards import guard_controls
kit=Path(__file__).resolve().parent; out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
lines=(kit/'PackagedCursorProof.swift').read_text().splitlines(keepends=True)
a=next(i for i,l in enumerate(lines) if 'BEGIN PURE CURSOR HTTP FIXTURE' in l)+1
b=next(i for i,l in enumerate(lines) if 'END PURE CURSOR HTTP FIXTURE' in l)
core='import Foundation\n'+''.join(lines[a:b]);(out/'Fixture.swift').write_text(core)
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
subprocess.run(['xcrun','--sdk','macosx','swiftc','-sdk',sdk,'-parse-as-library',str(out/'Fixture.swift'),str(kit/'FixtureControls.swift'),'-o',str(out/'controls')],check=True)
v=json.loads(subprocess.check_output([str(out/'controls')],text=True));assert v['controlsPassed'] and len(v['cases'])==12
v = {'controlsPassed': True, 'httpFixtureControls': v, 'namedMeterControls': guard_controls()}
v['adapterSHA256']=hashlib.sha256((kit/'PackagedCursorProof.swift').read_bytes()).hexdigest();v['SDK']=sdk
(out/'verdict.json').write_text(json.dumps(v,indent=2)+'\n');print(json.dumps(v,indent=2))
