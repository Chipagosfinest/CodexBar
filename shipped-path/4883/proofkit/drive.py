#!/usr/bin/env python3
"""Drives the unmodified packaged app through a real click plus Command-R against a loopback fixture.

The only inputs are a synthetic config file and the upstream debug-only COMMANDCODE_API_URL loopback override.
Refreshes run StatusItemController -> UsageStore -> ProviderFetchPipeline -> CommandCodeUsageFetcher -> HTTP.
"""
import http.server, json, os, shutil, socket, struct, subprocess, sys, threading, time
from datetime import datetime, timedelta, timezone
from pathlib import Path

app, helper = Path(sys.argv[1]).resolve(), sys.argv[2]
out = Path(os.environ['PROOF_OUT']); label = os.environ['PROOF_LABEL']
KEY = 'synthetic-commandcode-key'
state = {'phase': 'success', 'failed': 0, 'ok': 0}
VALUES = {'success': (89, 40, 80), 'recovered': (90, 41, 79)}  # 5-hour used, weekly used, monthly remaining
events = open(out / 'fixture-requests.jsonl', 'w', buffering=1)
driver = open(out / 'driver.log', 'w', buffering=1)
t0 = time.monotonic()

def say(message):
    line = f'{time.monotonic() - t0:7.2f}s {message}'
    print(line, flush=True); driver.write(line + '\n')

def iso(delta):
    return (datetime.now(timezone.utc) + delta).strftime('%Y-%m-%dT%H:%M:%S.000Z')

class Fixture(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *args): pass
    def do_GET(self):
        phase = state['phase']
        auth_ok = self.headers.get('Authorization') == f'Bearer {KEY}'
        record = {'t': round(time.monotonic() - t0, 2), 'path': self.path, 'phase': phase, 'auth_is_synthetic_key': auth_ok}
        if phase == 'fail':
            state['failed'] += 1
            record['response'] = 'connection closed with no reply'
            events.write(json.dumps(record) + '\n')
            # RST with no bytes: URLSession reports NSURLErrorNetworkConnectionLost, a retained-snapshot failure.
            self.connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
            self.close_connection = True
            self.connection.close()
            return
        state['ok'] += 1
        if self.path.endswith('/billing/credits'):
            five, week, monthly = VALUES[phase]
            body = {'credits': {'monthlyCredits': monthly, 'monthlyCreditsGranted': 100, 'purchasedCredits': 0,
                                'windowLimits': {'fiveHour': {'cap': 100, 'used': five, 'resetAt': iso(timedelta(hours=2))},
                                                 'weekly': {'cap': 100, 'used': week, 'resetAt': iso(timedelta(days=3))}}}}
        elif self.path.endswith('/billing/subscriptions'):
            body = {'success': True, 'data': {'planId': 'individual-pro', 'status': 'active', 'currentPeriodEnd': iso(timedelta(days=20))}}
        else:
            body = {}
        data = json.dumps(body).encode()
        record.update(response=200, body=body if body else None)
        events.write(json.dumps(record) + '\n')
        self.send_response(200); self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data))); self.send_header('Connection', 'close')
        self.end_headers(); self.wfile.write(data); self.close_connection = True

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Fixture)
threading.Thread(target=server.serve_forever, daemon=True).start()
port = server.server_address[1]

iso_root = Path(os.environ['RUNNER_TEMP']) / f'isolated-{label}'
home = iso_root / 'home'; (home / '.config').mkdir(parents=True); (iso_root / 'tmp').mkdir()
config = home / 'config.json'
config.write_text(json.dumps({'version': 1, 'providers': [
    {'id': 'codex', 'enabled': False}, {'id': 'claude', 'enabled': False},
    {'id': 'commandcode', 'enabled': True, 'source': 'api', 'apiKey': KEY}]}, indent=2))
(out / 'config-used.json').write_text(config.read_text())
env = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': str(home), 'CFFIXED_USER_HOME': str(home),
       'XDG_CONFIG_HOME': str(home / '.config'), 'CODEXBAR_CONFIG': str(config), 'TMPDIR': str(iso_root / 'tmp') + '/',
       'COMMANDCODE_API_URL': f'http://127.0.0.1:{port}', 'CODEXBAR_DISABLE_KEYCHAIN_ACCESS': '1'}

def ui(*args):
    return subprocess.run([helper, *map(str, args)], capture_output=True, text=True, timeout=30).stdout.strip()

def wait(predicate, what, timeout=45):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if predicate(): return True
        time.sleep(0.25)
    say(f'TIMEOUT waiting for {what}'); return False

def menu_window():
    candidates = [w for w in json.loads(ui('windows') or '[]') if w['layer'] >= 100 and w['h'] > 120]
    return max(candidates, key=lambda w: w['h']) if candidates else None

def status_window():
    candidates = [w for w in json.loads(ui('items', process.pid) or '[]') if w['w'] > 0]
    return candidates[0] if candidates else None

summary = []
def capture(name, note):
    time.sleep(1.2)
    window = menu_window()
    full = out / f'{name}-screen.png'
    subprocess.run(['screencapture', '-x', str(full)], check=True)
    pixels = {}
    if window:
        path = out / f'{name}-menu.png'
        subprocess.run(['screencapture', '-x', '-o', f"-l{window['id']}", str(path)], check=True)
        pixels = json.loads(ui('pixels', path) or '{}')
    row = {'state': name, 'note': note, 'menu_open': bool(window), 'requests_ok': state['ok'],
           'requests_dropped': state['failed'], 'purple_pixels': pixels.get('purple')}
    summary.append(row); say(json.dumps(row))

say('trusted(ax,screen,post)=' + ui('trusted'))
recording = None
log = open(out / 'app-stdout.log', 'w')
process = subprocess.Popen([str(app / 'Contents/MacOS/CodexBar'), '-iCloudSyncEnabled', 'NO', '-debugDisableKeychainAccess', 'YES',
                            '-SUEnableAutomaticChecks', 'NO', '-SUAutomaticallyUpdate', 'NO', '-refreshFrequency', 'manual',
                            # A manual refresh only covers the selected tab, so the fixture's provider must be selected.
                            '-selectedMenuProvider', 'commandcode'],
                           env=env, stdout=log, stderr=subprocess.STDOUT)
try:
    ok = wait(lambda: state['ok'] >= 2, 'launch refresh to reach the fixture')
    say(f'launch refresh reached fixture={ok} windows={ui("windows")}')
    wait(status_window, 'status item', 30)
    (out / 'window-inventory.txt').write_text(ui('all') + '\n')
    time.sleep(3)
    item = status_window()
    assert item, 'no status item'
    # A timed recording finishes and saves by itself; terminating screencapture -v loses the file.
    recording = subprocess.Popen(['screencapture', '-v', '-V', '35', '-x', str(out / f'screen-{label}.mov')],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(2)
    say(f'clicking status item at {item}')
    ui('click', item['x'] + item['w'] / 2, item['y'] + item['h'] / 2)
    assert wait(menu_window, 'menu window', 10), 'menu did not open from a real click'
    capture('1-success', 'launch refresh succeeded')
    assert summary[-1]['menu_open'], 'menu closed before the first capture'

    def refresh(phase, name, note):
        state['phase'] = phase
        before = state['ok'] + state['failed']
        say(f'{name}: fixture={phase}, Command-R in the open menu')
        ui('cmd-r')
        arrived = wait(lambda: state['ok'] + state['failed'] > before, 'Command-R refresh to reach the fixture', 8)
        if not arrived:
            target = json.loads(ui('menu-item', process.pid, 'Refresh') or 'null')
            say(f'{name}: Command-R produced no request, clicking the Refresh item at {target}')
            assert target, 'Refresh item not found'
            ui('click', target['x'] + target['w'] / 2, target['y'] + target['h'] / 2)
            arrived = wait(lambda: state['ok'] + state['failed'] > before, 'Refresh click to reach the fixture', 12)
            time.sleep(1)
            if not menu_window():
                ui('click', item['x'] + item['w'] / 2, item['y'] + item['h'] / 2)
                wait(menu_window, 'menu window after the Refresh click', 10)
        say(f'{name}: refresh reached fixture={arrived}')
        assert arrived, f'{name}: refresh never reached the fixture'
        if phase == 'fail':
            assert state['failed'] > 0, f'{name}: no request was dropped'
        time.sleep(1.5)  # enrichment and the menu's live update settle
        capture(name, note)

    refresh('fail', '2-first-failure', 'first failure: the consecutive-failure gate keeps it silent')
    refresh('fail', '3-failed-retained', 'second failure: error surfaces with the retained snapshot')
    refresh('recovered', '4-recovered', 'fixture recovered with new values')
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    assert process.poll() is None, 'app exited during the run'
finally:
    if recording:
        try: say(f'recording exit={recording.wait(timeout=70)}')
        except subprocess.TimeoutExpired: recording.kill(); say('recording killed')
    ui('esc')
    process.terminate()
    try: process.wait(timeout=5)
    except subprocess.TimeoutExpired: process.kill()
    log.close()
    with open(out / 'app-unified.log', 'w') as handle:
        subprocess.run(['log', 'show', '--last', '6m', '--info', '--debug', '--style', 'compact',
                        '--predicate', 'process == "CodexBar" AND (category CONTAINS[c] "commandcode" OR category CONTAINS[c] "refresh" OR category CONTAINS[c] "usage" OR eventMessage CONTAINS[c] "refresh")'],
                       stdout=handle, stderr=subprocess.STDOUT)
    shutil.rmtree(iso_root, ignore_errors=True)
say('done')
