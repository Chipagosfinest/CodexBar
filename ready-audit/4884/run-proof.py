import subprocess,pathlib,json,hashlib,os
root=pathlib.Path(__file__).parent
repo=os.environ.get('CODEXBAR_PROOF_REPO', os.getcwd())
head='8c311de2545db92f4914629d3f0692a5dbf18acf'; base='897bff31731bb4b21b105f6e8bf4c32a8a8bf095'
source='Sources/CodexBar/Menu/UsageMenuCardHeaderAndUsageSectionView.swift'; style='Sources/CodexBar/Menu/MenuHighlightStyle.swift';tests='Tests/CodexBarTests/MenuCardNumericTypographyTests.swift'
def show(sha,path):return subprocess.check_output(['git','-C',repo,'show',f'{sha}:{path}']).decode()
originaltests=show(head,tests)
manifest={'head':head,'base':base,'cases':[],'scope':'Extracted production MetricRowHeader and MenuHighlightStyle compiled with SwiftUI/AppKit; original PR Swift Testing cases. No packaged app or full target claim.'}
for label,sha,adapt in [('head',head,False),('base-exact-tests',base,False),('base-compatible-tests',base,True)]:
 w=root/label;(w/'Sources/CodexBar').mkdir(parents=True,exist_ok=True);(w/'Tests/ProofTests').mkdir(parents=True,exist_ok=True)
 full=show(sha,source);header='import SwiftUI\n\n'+full[full.index('struct MetricRowHeader:'):]
 fullstyle=show(sha,style);colors='import SwiftUI\n\n'+fullstyle[fullstyle.index('enum MenuHighlightStyle'):]
 (w/'Sources/CodexBar/Header.swift').write_text(header);(w/'Sources/CodexBar/Colors.swift').write_text(colors)
 t=originaltests
 if adapt:
  t=t.replace('title: title,\n            layoutTitle: title,','title: title + " " + percent,\n            layoutTitle: title + " " + percent,').replace('isHighlighted: false,\n            percentText: percent,\n            layoutPercentText: percent)','isHighlighted: false)')
 (w/'Tests/ProofTests/MenuCardNumericTypographyTests.swift').write_text(t)
 (w/'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TypographyProof", platforms: [.macOS(.v15)], products: [.library(name: "CodexBar", targets: ["CodexBar"])], targets: [.target(name: "CodexBar"), .testTarget(name: "ProofTests", dependencies: ["CodexBar"])])
''')
 framework='/Library/Developer/CommandLineTools/Library/Developer/Frameworks'
 cmd=['swift','test','--disable-xctest','--build-system','native','--jobs','2','-Xswiftc','-F','-Xswiftc',framework,'-Xlinker','-F','-Xlinker',framework,'-Xlinker','-rpath','-Xlinker',framework,'--filter','MenuCardNumericTypographyTests']
 r=subprocess.run(cmd,cwd=w,capture_output=True,text=True,env={**os.environ,'CODEXBAR_DISABLE_KEYCHAIN_ACCESS':'1','CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS':'1'})
 (root/(label+'.log')).write_text(r.stdout+r.stderr)
 manifest['cases'].append({'label':label,'sha':sha,'exit':r.returncode,'headerFullFileSHA256':hashlib.sha256(full.encode()).hexdigest(),'extractedHeaderSHA256':hashlib.sha256(header.encode()).hexdigest(),'testsAdaptedForOldAPI':adapt})
 print(label,'exit',r.returncode,flush=True)
 print('\n'.join(line for line in (r.stdout+r.stderr).splitlines() if any(x in line for x in ['Test run with','Test \"','Suite ','Expectation failed','extra arguments','plugin for module'])),flush=True)
(root/'manifest.json').write_text(json.dumps(manifest,indent=2))
assert [x['exit']==0 for x in manifest['cases']]==[True,False,False],manifest
assert 'Expectation failed' in (root/'base-compatible-tests.log').read_text(), 'Red must be assertion failure, not infrastructure'
assert '3 tests' in (root/'head.log').read_text(), 'Head must execute tests'
