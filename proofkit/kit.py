#!/usr/bin/env python3
"""Shared harness: the unmodified packaged app talks to real production hostnames, answered by a local TLS fixture.

Nothing is compiled into the app. /etc/hosts sends provider hostnames to 127.0.0.1 on this disposable hosted Mac, a
throwaway root CA is trusted for its lifetime, and every byte of input is a synthetic file or a synthetic HTTP reply.
Input is real: CGEvents through the HID tap. No real account, credential, or personal path exists on the runner.
"""
import base64, http.server, json, os, plistlib, ssl, subprocess, threading, time, zlib
from datetime import datetime, timedelta, timezone
from pathlib import Path

HOSTS = ['chatgpt.com', 'api.anthropic.com', 'platform.claude.com', 'claude.ai', 'api.commandcode.ai', 'api.kimi.com',
         'www.kimi.com', 'api.kimi.ai', 'www.kimi.ai', 'api.moonshot.ai', 'api.z.ai', 'openrouter.ai', 'api.deepseek.com', 'platform.deepseek.com',
         'api.minimax.io', 'api.groq.com', 'console.groq.com', 'admin.mistral.ai', 'console.mistral.ai', 'api.github.com',
         'api.openai.com', 'auth.openai.com', 'console.anthropic.com']
HOME = Path.home()
OUT = Path(os.environ['PROOF_OUT'])
T0 = time.monotonic()
_log = open(OUT / 'driver.log', 'a', buffering=1)
_req = open(OUT / 'fixture-requests.jsonl', 'a', buffering=1)
state = {'phase': 'normal', 'requests': 0, 'unknown': []}
ROUTES = {}  # (host, path-prefix) -> callable(handler) -> (status, json-object)
BUNDLE = os.environ.get('PROOF_BUNDLE', 'com.steipete.codexbar')
MARKER = 'codexbar-proof-fixture-only'


def say(msg):
    line = f'{time.monotonic() - T0:8.2f}s {msg}'
    print(line, flush=True)
    _log.write(line + '\n')


def iso(delta):
    return (datetime.now(timezone.utc) + delta).strftime('%Y-%m-%dT%H:%M:%S.000Z')


def epoch(delta):
    return int((datetime.now(timezone.utc) + delta).timestamp())


class Fixture(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *a):
        pass

    def _go(self):
        n = int(self.headers.get('Content-Length') or 0)
        if n:
            self.rfile.read(n)
        host = (self.headers.get('Host') or '').split(':')[0]
        state['requests'] += 1
        status, body = 404, {'error': 'no fixture route'}
        best = -1
        for (h, prefix), fn in ROUTES.items():
            if h == host and self.path.startswith(prefix) and len(prefix) > best:
                status, body = fn(self)
                best = len(prefix)
        if best < 0:
            state['unknown'].append(f'{self.command} {host}{self.path}')
        # Paths and status only. Synthetic bearer tokens are recorded as present/absent, never verbatim.
        _req.write(json.dumps({'t': round(time.monotonic() - T0, 2), 'm': self.command, 'host': host,
                               'path': self.path.split('?')[0], 'status': status, 'phase': state['phase'],
                               'auth': bool(self.headers.get('Authorization'))}) + '\n')
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(data)
        self.close_connection = True

    do_GET = do_POST = _go


def start_fixture():
    wd = Path(os.environ['RUNNER_TEMP']) / 'tls'
    wd.mkdir(exist_ok=True)
    san = ','.join(f'DNS:{h}' for h in HOSTS)

    def run(*c):
        subprocess.run([str(x) for x in c], check=True, capture_output=True)

    run('openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2', '-keyout', wd / 'ca.key', '-out', wd / 'ca.crt',
        '-subj', '/CN=CodexBar proof throwaway CA', '-addext', 'basicConstraints=critical,CA:TRUE')
    run('openssl', 'req', '-newkey', 'rsa:2048', '-nodes', '-keyout', wd / 'leaf.key', '-out', wd / 'leaf.csr', '-subj', '/CN=proof.fixture')
    (wd / 'ext').write_text(f'subjectAltName={san}\nextendedKeyUsage=serverAuth\n')
    run('openssl', 'x509', '-req', '-in', wd / 'leaf.csr', '-CA', wd / 'ca.crt', '-CAkey', wd / 'ca.key', '-CAcreateserial',
        '-days', '2', '-out', wd / 'leaf.crt', '-extfile', wd / 'ext')
    (wd / 'chain.crt').write_text((wd / 'leaf.crt').read_text() + (wd / 'ca.crt').read_text())
    run('sudo', 'security', 'add-trusted-cert', '-d', '-r', 'trustRoot', '-k', '/Library/Keychains/System.keychain', wd / 'ca.crt')
    hosts = wd / 'hosts'
    hosts.write_text(open('/etc/hosts').read() + ''.join(f'127.0.0.1 {h}\n' for h in HOSTS))
    run('sudo', 'cp', hosts, '/etc/hosts')
    run('sudo', 'dscacheutil', '-flushcache')
    # Port 443 needs root; forward it to the unprivileged fixture rather than running this whole harness as root.
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 8443), Fixture)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(wd / 'chain.crt', wd / 'leaf.key')
    server.socket = ctx.wrap_socket(server.socket, server_side=True, do_handshake_on_connect=False)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    forward = wd / 'forward.py'
    forward.write_text('''
import socket, threading
def pump(a, b):
    try:
        while True:
            d = a.recv(65536)
            if not d: break
            b.sendall(d)
    except OSError: pass
    for s in (a, b):
        try: s.shutdown(socket.SHUT_RDWR)
        except OSError: pass
l = socket.socket(); l.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); l.bind(("127.0.0.1", 443)); l.listen(128)
while True:
    c, _ = l.accept(); u = socket.create_connection(("127.0.0.1", 8443))
    threading.Thread(target=pump, args=(c, u), daemon=True).start(); threading.Thread(target=pump, args=(u, c), daemon=True).start()
''')
    subprocess.Popen(['sudo', '/usr/bin/python3', str(forward)])
    time.sleep(2)
    # A status code proves nothing: a real host answers 404 too. Only this fixture returns this body, and no app may
    # launch until every hostname resolves to it, so synthetic tokens can never leave the machine.
    ROUTES.clear()
    for h in HOSTS:
        ROUTES[(h, '/__proof_fixture')] = lambda _: (200, {'fixture': MARKER})
    subprocess.run(['sudo', 'launchctl', 'kickstart', '-k', 'system/com.apple.mDNSResponder'], capture_output=True)
    time.sleep(3)
    say('etc-hosts tail: ' + ' | '.join(open('/etc/hosts').read().strip().splitlines()[-3:]))
    say('resolver: ' + subprocess.run(['dscacheutil', '-q', 'host', '-a', 'name', 'api.anthropic.com'], capture_output=True, text=True).stdout.replace(chr(10), ' '))
    for h in HOSTS:
        check = subprocess.run(['curl', '-sS', '-m', '10', f'https://{h}/__proof_fixture'], capture_output=True, text=True)
        assert MARKER in check.stdout, f'{h} is not answered by the fixture: {check.stdout[:80]} {check.stderr.strip()}'
    say(f'fixture answers all {len(HOSTS)} hostnames over trusted TLS')


def jwt(payload):
    def enc(o):
        return base64.urlsafe_b64encode(json.dumps(o).encode()).rstrip(b'=').decode()
    return f"{enc({'alg': 'none'})}.{enc(payload)}.synthetic"


def write_credentials(codex=True, claude=True):
    if codex:
        (HOME / '.codex').mkdir(exist_ok=True)
        (HOME / '.codex/auth.json').write_text(json.dumps({'OPENAI_API_KEY': None, 'last_refresh': iso(timedelta(0)), 'tokens': {
            'access_token': jwt({'exp': epoch(timedelta(days=7))}), 'refresh_token': 'synthetic-refresh',
            'id_token': jwt({'email': 'codex@example.test', 'exp': epoch(timedelta(days=7)),
                             'https://api.openai.com/auth': {'chatgpt_plan_type': 'pro', 'chatgpt_account_id': 'synthetic-account'}}),
            'account_id': 'synthetic-account'}}))
    if claude:
        (HOME / '.claude').mkdir(exist_ok=True)
        (HOME / '.claude/.credentials.json').write_text(json.dumps({'claudeAiOauth': {
            'accessToken': 'synthetic-claude-oauth', 'refreshToken': 'synthetic-refresh',
            'expiresAt': epoch(timedelta(days=7)) * 1000, 'scopes': ['user:profile', 'user:inference'],
            'subscriptionType': 'max', 'rateLimitTier': 'default_claude_max_5x'}}))


def write_config(providers):
    path = HOME / '.codexbar/config.json'
    path.parent.mkdir(exist_ok=True)
    text = json.dumps({'version': 1, 'providers': providers}, indent=2)
    path.write_text(text)
    (OUT / 'config-used.json').write_text(text)


def write_claude(when, model, inp, out, cread=0, ccreate=0, session='s', idx=0, project='synthetic-project', stop='end_turn'):
    d = HOME / '.claude/projects' / project
    d.mkdir(parents=True, exist_ok=True)
    rec = {'type': 'assistant', 'timestamp': when.strftime('%Y-%m-%dT%H:%M:%S.000Z'), 'sessionId': f'{session}{idx}',
           'requestId': f'req-{model}-{when.date()}-{idx}',
           'message': {'id': f'msg-{model}-{when.date()}-{idx}', 'model': model, 'stop_reason': stop, 'usage': {
               'input_tokens': inp, 'output_tokens': out, 'cache_read_input_tokens': cread, 'cache_creation_input_tokens': ccreate}}}
    with open(d / f'{session}.jsonl', 'a') as f:
        f.write(json.dumps(rec) + '\n')


def write_codex(when, model, inp, out, cached=0):
    d = HOME / '.codex/sessions' / when.strftime('%Y/%m/%d')
    d.mkdir(parents=True, exist_ok=True)
    ts = when.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    p = d / f"rollout-{when.strftime('%Y-%m-%dT%H-%M-%S')}-{zlib.crc32(model.encode()):08x}.jsonl"
    usage = {'input_tokens': inp, 'cached_input_tokens': cached, 'output_tokens': out, 'total_tokens': inp + out}
    with open(p, 'a') as f:
        f.write(json.dumps({'type': 'session_meta', 'timestamp': ts, 'payload': {'id': p.stem}}) + '\n')
        f.write(json.dumps({'type': 'turn_context', 'timestamp': ts, 'payload': {'model': model}}) + '\n')
        f.write(json.dumps({'type': 'event_msg', 'timestamp': ts, 'payload': {'type': 'token_count', 'info': {
            'model': model, 'total_token_usage': usage, 'last_token_usage': usage}}}) + '\n')


def defaults_write(key, value):
    if isinstance(value, bool):
        arg = ['-bool', 'YES' if value else 'NO']
    elif isinstance(value, list):
        arg = ['-array'] + value
    else:
        arg = ['-string', str(value)]
    subprocess.run(['defaults', 'write', BUNDLE, key] + arg, check=True)


def defaults_reset():
    subprocess.run(['defaults', 'delete', BUNDLE], capture_output=True)


def defaults_snapshot(name):
    """The Overview preferences exactly as saved, read back from the real defaults domain after the app quit."""
    r = subprocess.run(['defaults', 'export', BUNDLE, '-'], capture_output=True)
    data = plistlib.loads(r.stdout) if r.returncode == 0 and r.stdout else {}
    keep = {k: v for k, v in data.items() if k.startswith('merged') or k in ('tokenCostUsageEnabled', 'selectedMenuProvider')}
    (OUT / f'defaults-{name}.json').write_text(json.dumps(keep, indent=2, default=str, sort_keys=True))
    say(f'defaults {name}: {json.dumps(keep, default=str, sort_keys=True)}')
    return keep


class App:
    def __init__(self, path, helper, name='app'):
        self.path, self.helper, self.name = Path(path), helper, name
        env = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'HOME': str(HOME), 'TMPDIR': os.environ.get('TMPDIR', '/tmp/'),
               'USER': os.environ.get('USER', 'runner'), 'CODEXBAR_DISABLE_KEYCHAIN_ACCESS': '1'}
        self.log = open(OUT / f'{name}-stdout.log', 'a')
        self.proc = subprocess.Popen([str(self.path / 'Contents/MacOS/CodexBar'), '-SUEnableAutomaticChecks', 'NO',
                                      '-SUAutomaticallyUpdate', 'NO', '-debugDisableKeychainAccess', 'YES'],
                                     env=env, stdout=self.log, stderr=subprocess.STDOUT)
        say(f'launched {name} pid={self.proc.pid}')

    def ui(self, *args, timeout=30):
        return subprocess.run([self.helper, *map(str, args)], capture_output=True, text=True, timeout=timeout).stdout.strip()

    def bar(self):
        return json.loads(self.ui('tree', self.proc.pid, 'AXExtrasMenuBar') or '{}')

    def items(self):
        return [k for k in self.bar().get('kids', []) if k.get('w', 0) > 0]

    def windows(self):
        return json.loads(self.ui('windows') or '[]')

    def menus(self):
        return sorted([w for w in self.windows() if w['layer'] >= 100 and w['h'] > 30], key=lambda w: w['x'])

    def wait(self, pred, what, timeout=45):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if pred():
                return True
            time.sleep(0.25)
        say(f'TIMEOUT waiting for {what}')
        return False

    def open_menu(self):
        assert self.wait(self.items, 'status item', 40), 'no status item'
        it = self.items()[0]
        say(f'click status item at {it["x"]},{it["y"]} size {it["w"]}x{it["h"]}')
        self.ui('click', it['x'] + it['w'] / 2, it['y'] + it['h'] / 2)
        assert self.wait(self.menus, 'menu window', 10), 'menu did not open from a real click'
        time.sleep(1.2)

    def close_menu(self):
        for _ in range(4):
            if not self.menus():
                return
            self.ui('esc')
            time.sleep(0.5)

    def rows(self):
        """Every node in the open menu's accessibility tree, flattened in tree order, with its frame."""
        out = []

        def walk(n):
            label = n.get('title') or n.get('desc') or n.get('value') or ''
            out.append({'role': n.get('role'), 'label': label, 'x': n.get('x'), 'y': n.get('y'), 'w': n.get('w'),
                        'h': n.get('h'), 'help': n.get('help'), 'id': n.get('identifier')})
            for k in n.get('kids', []):
                walk(k)
        walk(self.bar())
        return out

    def shot(self, name, note=''):
        time.sleep(0.5)
        subprocess.run(['screencapture', '-x', '-C', str(OUT / f'{name}-screen.png')], check=True)
        (OUT / f'{name}-ax.json').write_text(self.ui('tree', self.proc.pid, 'AXExtrasMenuBar'))
        say(f'SHOT {name} menus={[(w["x"], w["y"], w["w"], w["h"]) for w in self.menus()]} requests={state["requests"]} {note}')

    def quit(self):
        self.close_menu()
        self.proc.terminate()
        try:
            self.proc.wait(timeout=8)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        self.log.close()
        say(f'{self.name} stopped')
        time.sleep(1.5)


def record(name, seconds):
    return subprocess.Popen(['screencapture', '-v', '-V', str(seconds), '-x', '-C', str(OUT / f'{name}.mov')],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def find(rows, text, role=None):
    return [r for r in rows if text.lower() in (r['label'] or '').lower() and (role is None or r['role'] == role) and r['w']]


def finish():
    if state['unknown']:
        (OUT / 'unrouted-requests.txt').write_text('\n'.join(sorted(set(state['unknown']))) + '\n')
    say('done')
