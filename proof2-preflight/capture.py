from pathlib import Path
import json, os, subprocess, threading, time
out=Path(os.environ['PROOF_OUTPUT']);state=out/'synthetic-home';state.mkdir()
(state/'phase').write_text('healthy')
pr=os.environ['PROOF_PR'];sha=os.environ['PROOF_SHA'];app=out/'CodexBar Proof.app'
log=open(out/'runtime.log','w')
env={'PATH':'/usr/bin:/bin:/usr/sbin:/sbin','HOME':str(state),'CFFIXED_USER_HOME':str(state),'CODEXBAR_REAL_PROOF_DIR':str(state),'CODEXBAR_REAL_PROOF_LABEL':f'PR #{pr} {sha}','CODEXBAR_DISABLE_KEYCHAIN_ACCESS':'1','CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS':'1','CODEXBAR_TEST_CODEX_FILE_ISOLATION':'1','CODEXBAR_TEST_SESSION_FILE_ISOLATION':'1','CODEXBAR_DISABLE_CLAUDE_WATCHDOG':'1','SWIFT_TESTING':'1'}
# Direct bundle executable starts the actual NSApplication in this verified Aqua session.
process=subprocess.Popen([str(app/'Contents/MacOS/CodexBar'),'--real-behavior-proof'],env=env,stdout=log,stderr=subprocess.STDOUT)
try:
    time.sleep(3)
    assert process.poll() is None, 'App exited before opening menu'
    (state/'open').touch()
    time.sleep(2)
    subprocess.run(['screencapture','-x',str(out/'healthy.png')],check=True)
    events=[]
    plan={'4881':[(3,'critical'),(9,'healthy')], '4883':[(3,'refreshing'),(6,'failed'),(11,'recovered')], '4884':[(2,'tick11'),(7,'tick88'),(13,'tick11')]}[pr]
    def phases():
        started=time.monotonic()
        for offset,phase in plan:
            time.sleep(max(0,started+offset-time.monotonic()))
            (state/'phase').write_text(phase)
            events.append({'offset_s':round(time.monotonic()-started,3),'phase':phase})
            time.sleep(1)
            subprocess.run(['screencapture','-x',str(out/f'{offset:02d}-{phase}.png')],check=True)
    writer=threading.Thread(target=phases);writer.start()
    result=subprocess.run(['screencapture','-v','-V','16',str(out/f'pr{pr}-{sha[:9]}.mov')],capture_output=True,text=True,timeout=30)
    writer.join()
    (out/'capture.json').write_text(json.dumps({'screencapture_exit':result.returncode,'stderr':result.stderr,'events':events,'app_pid':process.pid,'app_running_after_capture':process.poll() is None},indent=2)+'\n')
    assert result.returncode == 0, result.stderr
    assert process.poll() is None, 'App exited during capture'
finally:
    process.terminate()
    try:process.wait(timeout=5)
    except subprocess.TimeoutExpired:process.kill()
    log.close()
