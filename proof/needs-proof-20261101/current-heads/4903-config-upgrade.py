import hashlib,json,os,pathlib,subprocess
import sys
root=pathlib.Path(sys.argv[3]); root.mkdir(parents=True,exist_ok=True)
stable=pathlib.Path(sys.argv[1])
head=pathlib.Path(sys.argv[2])
expected_head='14ae7e0e8c4ead511bd7bff6106eb22ac9e10208'
actual_head=subprocess.check_output(['git','-C',str(head.parent.parent.parent),'rev-parse','HEAD'],text=True).strip()
assert actual_head==expected_head,(actual_head,expected_head)
stable_version=subprocess.check_output([str(stable),'--version'],text=True).strip()
assert stable_version=='CodexBar 0.83.0',stable_version
binary_hashes={'stable':hashlib.sha256(stable.read_bytes()).hexdigest(),'head':hashlib.sha256(head.read_bytes()).hexdigest()}
rows=[]
for mode in ['auto','manual','off']:
 cfg=root/f'{mode}.json'; cfg.write_text(json.dumps({'version':1,'providers':[{'id':'ollama','enabled':True,'cookieSource':mode,**({'cookieHeader':'session=synthetic-upgrade-fixture'} if mode=='manual' else {})}]}))
 env=dict(os.environ,CODEXBAR_CONFIG=str(cfg))
 env.pop('OLLAMA_API_KEY',None)
 r=subprocess.run([str(stable),'config','set-source','--provider','ollama','--source','auto','--json'],env=env,capture_output=True,text=True,check=True)
 before=cfg.read_bytes(); digest=hashlib.sha256(before).hexdigest()
 def get(binary,cmd):
  r=subprocess.run([str(binary),'config',cmd,'--json'],env=env,capture_output=True,text=True,check=True)
  return json.loads(r.stdout)
 before_dump=get(stable,'dump'); after_dump=get(head,'dump'); validation=get(head,'validate')
 assert before_dump==after_dump,(mode,before_dump,after_dump)
 assert cfg.read_bytes()==before
 rows.append({'savedCookieSource':mode,'writtenBy':'released v0.83.0 CLI','head':actual_head,'stableReportedVersion':stable_version,'executableSHA256':binary_hashes,'decodedNormalizedConfigEqual':True,'fileUnchanged':True,'configSHA256':digest,'validation':validation})
(root/'results.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps(rows,indent=2))
