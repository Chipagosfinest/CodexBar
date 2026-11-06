"""Hosted-only static UI acceptance. No timed transition/movie claim; original screenshots required."""
import argparse,hashlib,json,os,re,subprocess,time,uuid
from pathlib import Path
from guards import named_meter_pairs
p=argparse.ArgumentParser();p.add_argument('--app',type=Path,required=True);p.add_argument('--helper',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--runtime-root',type=Path,required=True);p.add_argument('--overlay-sha',required=True);a=p.parse_args()
assert os.environ.get('GITHUB_ACTIONS')=='true' and os.environ.get('GITHUB_REPOSITORY')=='Chipagosfinest/CodexBar','No local UI execution'
out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);runtime=a.runtime_root.resolve();assert not runtime.exists()
helper=str(a.helper.resolve());binary=a.app.resolve()/'Contents/MacOS/CodexBar';PIN='fba37ba92f696416b36f49d4de89affcda3888ee'
def ui(*parts):return subprocess.check_output([helper,*map(str,parts)],text=True,timeout=15).strip()
displays=json.loads(ui('displays'));assert len(displays)==1
def inside(x,y,r):return r['x']<=x<r['x']+r['w'] and r['y']<=y<r['y']+r['h']
def center(r):
 x,y=r['x']+r['w']/2,r['y']+r['h']/2;assert any(inside(x,y,d) for d in displays);return x,y
all_results=[]
for scenario in ['allowances','manual401']:
 folder=out/scenario;folder.mkdir();root=runtime/scenario;(root/'tmp').mkdir(parents=True);nonce=str(uuid.uuid4()).upper()
 env={'PATH':'/usr/bin:/bin:/usr/sbin:/sbin','HOME':str(root),'CFFIXED_USER_HOME':str(root),'TMPDIR':str(root/'tmp')+'/',
      'XDG_CONFIG_HOME':str(root/'.config'),'CODEXBAR_CONFIG':str(root/'config.json'),'CODEX_HOME':str(root/'codex'),
      'TOKSCALE_CONFIG_DIR':str(root/'tokscale'),'LANG':'en_US.UTF-8','SWIFT_TESTING':'1',
      'CODEXBAR_DISABLE_KEYCHAIN_ACCESS':'1','CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS':'1',
      'CODEXBAR_TEST_CODEX_FILE_ISOLATION':'1','CODEXBAR_TEST_SESSION_FILE_ISOLATION':'1',
      'CURSOR_PROOF_ROOT':str(root),'CURSOR_PROOF_OUTPUT':str(folder),'CURSOR_PROOF_NONCE':nonce,
      'CURSOR_PROOF_SCENARIO':scenario,'CURSOR_PROOF_PRODUCT_SHA':PIN}
 process=None;passed=False;failure=None;native_menu=None
 def nodes():return json.loads(ui('ax',process.pid))
 def wait(fn,label,seconds=50):
  deadline=time.monotonic()+seconds
  while time.monotonic()<deadline:
   assert process.poll() is None,'App exited'
   value=fn()
   if value:return value
   time.sleep(.2)
  raise RuntimeError('Bounded wait: '+label)
 def receipt(final=False):
  path=folder/'runtime.json'
  if not path.exists():return None
  value=json.loads(path.read_text());assert value['nonce']==nonce and value['scenario']==scenario and value['productSHA']==PIN
  assert value['proofOnlyEarlyStartup'] and not value['ordinaryAppStartup'];assert value['phase']!='failed',value
  return value if value['phase']==('finalized' if final else 'ready') else None
 def text(rows):return '\n'.join(' '.join(str(r.get(k,'')) for k in ['title','description','value','help']) for r in rows)
 try:
  with (folder/'app.log').open('w') as log:
   process=subprocess.Popen(['sandbox-exec','-p','(version 1)(allow default)(deny network*)',str(binary),'--packaged-cursor-proof'],env=env,stdout=log,stderr=subprocess.STDOUT)
   value=wait(receipt,'real quota/cost owners')
   (folder/'ready-owner-receipt.json').write_text(json.dumps(value,indent=2)+'\n')
   identity=json.loads(ui('application',process.pid));assert Path(identity['executable']).resolve()==binary
   (folder/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
   rows=nodes();item=next(r['frame'] for r in rows if r.get('identifier')=='codexbar-cursor-proof' and r['frame']['w']>0)
   subprocess.run(['screencapture','-x',str(folder/'0-before-menu-screen.png')],check=True,timeout=15)
   rect=','.join(str(round(item[k])) for k in ['x','y','w','h']);subprocess.run(['screencapture','-x','-R'+rect,str(folder/'status-item.png')],check=True,timeout=15)
   assert json.loads(ui('image-info',folder/'status-item.png'))['contrast']>.08
   ui('click',*center(item))
   native_menu=wait(lambda:next((w for w in json.loads(ui('windows',process.pid)) if w['layer']==101 and w['w']>180 and w['h']>60),None),'actual native provider menu')
   def rows_in(window):
    selected=[]
    for r in nodes():
     f=r['frame'];x,y=f['x']+f['w']/2,f['y']+f['h']/2
     if f['w']>0 and f['h']>0 and inside(x,y,window) and any(inside(x,y,d) for d in displays):selected.append(r)
    return selected
   def expected_ui():
    t=text(rows_in(native_menu))
    if scenario=='allowances':return 'Grok Bot' in t and 'Total' in t and re.search(r'(?<!\d)20\s*%',t) and re.search(r'(?<!\d)80\s*%',t) and 'Weekly' not in t
    cost=next((w for w in json.loads(ui('windows',process.pid)) if w['id']==value['costWindowID']),None)
    if not cost:return False
    cost_text=text(rows_in(cost))
    return 'Not logged in to Cursor' in t and 'Cursor:' in cost_text and 'Not logged in to Cursor' in cost_text and '$42' not in cost_text and '42.00' not in cost_text
   wait(expected_ui,'production visible labels',15)
   rows=nodes();(folder/'actual-ax.json').write_text(json.dumps(rows,indent=2)+'\n')
   subprocess.run(['screencapture','-x',str(folder/'1-actual-screen.png')],check=True,timeout=15)
   subprocess.run(['screencapture','-x','-o','-l'+str(native_menu['id']),str(folder/'provider-menu.png')],check=True,timeout=15)
   comparison=json.loads(ui('screen-similarity',folder/'1-actual-screen.png',folder/'provider-menu.png',*[native_menu[k] for k in ['x','y','w','h']]))
   assert comparison['samples']==936 and comparison['meanRGBError']<.13
   if scenario=='allowances':
    assert value['primaryUsed']==20 and value['botUsed']==80 and value['unified'] is False
    assert named_meter_pairs(value['actualStatusTitle'],value['actualStatusAccessibility']), 'Actual renderer must name T20% and GB80%, not swapped pairs'
   else:
    assert value['quotaSnapshotNil'] and value['tokenSnapshotNil'] and value['csvTotal']==42
    cost=next(w for w in json.loads(ui('windows',process.pid)) if w['id']==value['costWindowID'])
    subprocess.run(['screencapture','-x','-o','-l'+str(cost['id']),str(folder/'production-cost-settings.png')],check=True,timeout=15)
    (folder/'cost-window.json').write_text(json.dumps(cost,indent=2)+'\n')
   assert value['savedLayoutRoundTrip'] and all(e['allowed'] for e in value['httpEvents'])
   temporary=folder/'finalize.tmp';temporary.write_text(json.dumps({'nonce':nonce,'action':'finalize'}));temporary.replace(folder/'finalize.json')
   final=wait(lambda:receipt(final=True),'fresh final owner/HTTP receipt after captures',10)
   assert final['httpEvents'] and all(e['allowed'] for e in final['httpEvents'])
   (folder/'final-owner-receipt.json').write_text(json.dumps(final,indent=2)+'\n')
   if scenario=='allowances':
    assert final['primaryUsed']==20 and final['botUsed']==80 and not final['unified']
    assert named_meter_pairs(final['actualStatusTitle'],final['actualStatusAccessibility'])
   else:assert final['quotaSnapshotNil'] and final['tokenSnapshotNil'] and final['csvTotal']==42
   assert process.poll() is None, 'App exited before owned termination after final receipt'
   passed=True
 except Exception as error:
  failure=str(error)
  try:
   subprocess.run(['screencapture','-x',str(folder/'failure-screen.png')],check=True,timeout=15)
   (folder/'failure-ax.json').write_text(json.dumps(nodes(),indent=2)+'\n')
  except Exception:pass
 finally:
  teardown={'terminationRequested':False,'alreadyExitedBeforeTermination':False,'forcedKill':False}
  if process is not None:
   teardown['alreadyExitedBeforeTermination']=process.poll() is not None
   if passed and teardown['alreadyExitedBeforeTermination']:
    passed=False;failure='App exited unexpectedly before owned termination'
   if process.poll() is None:
    teardown['terminationRequested']=True
    try:
     process.terminate()
     deadline=time.monotonic()+5
     while process.poll() is None and time.monotonic()<deadline:time.sleep(.1)
     if process.poll() is None:
      teardown['forcedKill']=True;passed=False;failure=failure or 'Owned termination timed out';process.kill()
      deadline=time.monotonic()+1
      while process.poll() is None and time.monotonic()<deadline:time.sleep(.05)
    except Exception as error:passed=False;failure=failure or str(error)
   teardown['observedExitCode']=process.poll()
  (folder/'teardown.json').write_text(json.dumps(teardown,indent=2)+'\n')
  try:
   final_http=json.loads((folder/'http-events.json').read_text())
   assert all(e['allowed'] for e in final_http)
   if passed:assert len(final_http)==len(final['httpEvents']), 'Late HTTP after finalization'
  except Exception as error:passed=False;failure=failure or str(error)
  result={'scenario':scenario,'automatedStaticUIChecksPassed':passed,'manualOriginalScreensRequired':True,'failure':failure,'nativeMenu':native_menu,'binarySHA256':hashlib.sha256(binary.read_bytes()).hexdigest()}
  (folder/'ui-verdict.json').write_text(json.dumps(result,indent=2)+'\n');all_results.append(result)
 if not passed:break
(out/'ui-verdict.json').write_text(json.dumps({'productSHA':PIN,'overlaySHA256':a.overlay_sha,'scenarios':all_results,'automatedChecksPassed':len(all_results)==2 and all(r['automatedStaticUIChecksPassed'] for r in all_results),'manualOriginalScreenAcceptance':False,'claim':'Synthetic production-owner static App UI only; no live auth or durability'},indent=2)+'\n')
if len(all_results)!=2 or not all(r['automatedStaticUIChecksPassed'] for r in all_results):raise SystemExit(1)
