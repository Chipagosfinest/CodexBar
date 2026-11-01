import hashlib,json,os,pathlib,subprocess
import sys
root=pathlib.Path(sys.argv[3]); root.mkdir(parents=True,exist_ok=True)
stable=pathlib.Path(sys.argv[1])
head=pathlib.Path(sys.argv[2])
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
 rows.append({'savedCookieSource':mode,'writtenBy':'released v0.83.0 CLI','head':'11935aee6ec16fe23595dbddaada349562218547','decodedNormalizedConfigEqual':True,'fileUnchanged':True,'configSHA256':digest,'validation':validation})
(root/'results.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps(rows,indent=2))
