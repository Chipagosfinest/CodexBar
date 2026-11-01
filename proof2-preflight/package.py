from pathlib import Path
import hashlib, json, os, plistlib, shutil, subprocess, sys
product=Path(sys.argv[1]).resolve()
output=Path(os.environ['PROOF_OUTPUT'])
b=Path(subprocess.check_output(['swift','build','--show-bin-path'],cwd=product,text=True).strip())
app=output/'CodexBar Proof.app';c=app/'Contents'
for d in ['MacOS','Resources','Frameworks']:(c/d).mkdir(parents=True,exist_ok=True)
shutil.copy2(b/'CodexBar',c/'MacOS/CodexBar')
for p in b.glob('*.bundle'):shutil.copytree(p,c/'Resources'/p.name,dirs_exist_ok=True)
sparkle=b/'Sparkle.framework'
if not sparkle.exists():
    candidates=list((product/'.build').glob('artifacts/**/macos-arm64_x86_64/Sparkle.framework'))
    assert candidates, 'Sparkle framework absent'
    sparkle=candidates[0]
shutil.copytree(sparkle,c/'Frameworks/Sparkle.framework',dirs_exist_ok=True,symlinks=True)
subprocess.run(['install_name_tool','-add_rpath','@executable_path/../Frameworks',str(c/'MacOS/CodexBar')],check=True,capture_output=True)
info={'CFBundleIdentifier':'com.codexbar.hostedproof.'+os.environ['PROOF_PR'],'CFBundleExecutable':'CodexBar','CFBundleName':'CodexBar Proof','CFBundleDisplayName':'CodexBar Proof','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.83.1','CFBundleVersion':'1','LSUIElement':True,'NSHighResolutionCapable':True,'CodexGitCommit':os.environ['PROOF_SHA']}
(c/'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True,capture_output=True)
(output/'binary-sha256.txt').write_text(hashlib.sha256((c/'MacOS/CodexBar').read_bytes()).hexdigest()+'  CodexBar Proof.app/Contents/MacOS/CodexBar\n')
print(app)
