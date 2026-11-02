#!/usr/bin/env python3
"""Shared harness: the unmodified packaged app talks to real production hostnames, answered by a local TLS fixture.

Nothing is compiled into the app. A per-host resolver and /etc/hosts send provider hostnames to loopback on this
disposable hosted Mac, a throwaway root CA is trusted for its lifetime, and every input is a synthetic file or reply.
Containment is verified by a preflight and sampled every 5s, not enforced by a firewall; all tokens are synthetic.
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
DNS_PORT = 5354


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
                status, body = (401, {'error': {'message': 'Unauthorized'}}) if state.get('all_fail') and '__proof' not in prefix else fn(self)
                best = len(prefix)
        if best < 0:
            state['unknown'].append(f'{self.command} {host}{self.path}')
        if '__proof' not in self.path:
            state.setdefault('log', []).append({'phase': state['phase'], 'host': host, 'path': self.path.split('?')[0], 'status': status})
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


def check(name, ok, detail=''):
    """An acceptance assertion that keeps later stages running. Any failure fails the run in finish()."""
    state.setdefault('checks', []).append({'check': name, 'pass': bool(ok), 'detail': str(detail)[:600]})
    say(f"CHECK {'PASS' if ok else 'FAIL'} {name} {str(detail)[:300]}")
    (OUT / 'checks.json').write_text(json.dumps(state['checks'], indent=1))
    return bool(ok)


def phase_begin(name):
    """Starts a named fixture phase; only requests answered inside it count for that phase's oracle."""
    state['phase'] = name
    say(f'phase -> {name}')


def reached(phase, host, status=200):
    return [e for e in state.get('log', []) if e['phase'] == phase and e['host'] == host and e['status'] == status]


def verify_installed(path, name='head'):
    """Installed bytes must be the packaged bytes: main binary against the package manifest, extension against the zip."""
    path = Path(path)
    sha = lambda p: subprocess.run(['shasum', '-a', '256', str(p)], capture_output=True, text=True).stdout.split()[0]
    want = (OUT / 'binary-sha256.txt').read_text().split()[0]
    got = sha(path / 'Contents/MacOS/CodexBar')
    check(f'{name}: installed app binary equals package manifest', got == want, f'{got} vs {want}')
    return got


def start_banner():
    """Provenance on the real display, in every capture and recording. Run by the proof controller, not the product."""
    helper = os.environ['PROOF_HELPER']
    kit_sha = (OUT / 'kit-sha.txt').read_text().strip()[:9]
    text = (f"SYNTHETIC DATA ONLY - no real account. PR #{os.environ['PROOF_PR']} - product {os.environ['PROOF_SHA']}\n"
            f"Unmodified app packaged from that commit; provider hosts answered by a local fixture; kit {kit_sha}")
    state['banner'] = subprocess.Popen([helper, 'banner', text])
    for _ in range(40):
        time.sleep(0.25)
        shown = json.loads(subprocess.run([helper, 'windows', 'uihelper'], capture_output=True, text=True).stdout or '[]')
        if shown:
            say(f'banner on display: {shown}')
            return
    raise AssertionError('provenance banner never reached the display')


def start_fixture():
    start_banner()
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
    # /etc/hosts alone proved racy here: lookups intermittently escaped to the real hosts. A per-host resolver backed by
    # this local stub answers every query with loopback, so provider hostnames resolve locally (verified by preflight and sampling).
    threading.Thread(target=dns_stub, daemon=True).start()
    run('sudo', 'mkdir', '-p', '/etc/resolver')
    for h in HOSTS:
        f = wd / f'resolver-{h}'
        f.write_text(f'nameserver 127.0.0.1\nport {DNS_PORT}\n')
        run('sudo', 'cp', f, f'/etc/resolver/{h}')
    hosts = wd / 'hosts'
    hosts.write_text(open('/etc/hosts').read() + ''.join(f'127.0.0.1 {h}\n::1 {h}\n' for h in HOSTS))
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
def serve(family, addr):
    l = socket.socket(family); l.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); l.bind((addr, 443)); l.listen(128)
    while True:
        c, _ = l.accept(); u = socket.create_connection(("127.0.0.1", 8443))
        threading.Thread(target=pump, args=(c, u), daemon=True).start(); threading.Thread(target=pump, args=(u, c), daemon=True).start()
threading.Thread(target=serve, args=(socket.AF_INET6, "::1"), daemon=True).start()
serve(socket.AF_INET, "127.0.0.1")
''')
    subprocess.Popen(['sudo', '/usr/bin/python3', str(forward)])
    time.sleep(2)
    # A status code proves nothing: a real host answers 404 too. Only this fixture returns this body, and no app
    # launches until every hostname is observed resolving to it.
    ROUTES.clear()
    for h in HOSTS:
        ROUTES[(h, '/__proof_fixture')] = lambda _: (200, {'fixture': MARKER})
    subprocess.run(['sudo', 'launchctl', 'kickstart', '-k', 'system/com.apple.mDNSResponder'], capture_output=True)
    deadline = time.monotonic() + 90
    while True:
        bad = resolver_escapes()
        if not bad:
            break
        assert time.monotonic() < deadline, f'hostnames still resolve off the machine: {bad}'
        subprocess.run(['sudo', 'dscacheutil', '-flushcache'], capture_output=True)
        time.sleep(3)
    say(f'all {len(HOSTS)} hostnames resolve only to loopback after {time.monotonic() - T0:.0f}s')
    for h in HOSTS:
        # The privileged forwarder can take a few seconds to bind on a cold runner.
        for attempt in range(15):
            probe = subprocess.run(['curl', '-sS', '-m', '10', f'https://{h}/__proof_fixture'], capture_output=True, text=True)
            if MARKER in probe.stdout:
                break
            time.sleep(2)
        assert MARKER in probe.stdout, f'{h} is not answered by the fixture: {probe.stdout[:80]} {probe.stderr.strip()}'
    say(f'fixture answers all {len(HOSTS)} hostnames over trusted TLS')
    threading.Thread(target=resolver_watch, daemon=True).start()


def dns_stub():
    import socket
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(('127.0.0.1', DNS_PORT))
    while True:
        q, addr = s.recvfrom(512)
        end = 12
        while q[end]:
            end += q[end] + 1
        question = q[12:end + 5]
        qtype = int.from_bytes(q[end + 1:end + 3], 'big')
        answer = b''
        if qtype == 1:
            answer = b'\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04\x7f\x00\x00\x01'
        elif qtype == 28:
            answer = b'\xc0\x0c\x00\x1c\x00\x01\x00\x00\x00\x3c\x00\x10' + bytes(15) + b'\x01'
        s.sendto(q[:2] + b'\x81\x80\x00\x01' + (b'\x00\x01' if answer else b'\x00\x00') + b'\x00\x00\x00\x00' + question + answer, addr)


def resolver_escapes():
    import socket
    bad = {}
    for h in HOSTS:
        try:
            addrs = {i[4][0] for i in socket.getaddrinfo(h, 443)}
        except OSError as e:
            bad[h] = str(e)
            continue
        off = addrs - {'127.0.0.1', '::1'}
        if off:
            bad[h] = sorted(off)
    return bad


def resolver_watch():
    """Sampled evidence, not containment: rechecks every hostname every 5s for the whole run."""
    checks = 0
    while True:
        bad = resolver_escapes()
        checks += 1
        state['resolver_checks'] = checks
        if bad:
            state.setdefault('resolver_escapes', []).append(bad)
            say(f'RESOLVER ESCAPE {bad}')
        time.sleep(5)


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
        # Compact, as Claude Code writes it: the scanner prefilters raw bytes before decoding.
        f.write(json.dumps(rec, separators=(',', ':')) + '\n')


def write_codex(when, model, inp, out, cached=0):
    d = HOME / '.codex/sessions' / when.strftime('%Y/%m/%d')
    d.mkdir(parents=True, exist_ok=True)
    ts = when.strftime('%Y-%m-%dT%H:%M:%S.000Z')
    p = d / f"rollout-{when.strftime('%Y-%m-%dT%H-%M-%S')}-{zlib.crc32(model.encode()):08x}.jsonl"
    usage = {'input_tokens': inp, 'cached_input_tokens': cached, 'output_tokens': out, 'total_tokens': inp + out}
    with open(p, 'a') as f:
        for rec in ({'type': 'session_meta', 'timestamp': ts, 'payload': {'id': p.stem}},
                    {'type': 'turn_context', 'timestamp': ts, 'payload': {'model': model}},
                    {'type': 'event_msg', 'timestamp': ts, 'payload': {'type': 'token_count', 'info': {
                        'model': model, 'total_token_usage': usage, 'last_token_usage': usage}}}):
            f.write(json.dumps(rec, separators=(',', ':')) + '\n')


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
    keep.pop('mergedOverviewSelectionEditedActiveProviders', None) if name.startswith('nav-') else None
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
        if args[0] in ('click', 'move'):
            assert self.in_screen(float(args[1]), float(args[2])), f'{args[0]} target {args[1]},{args[2]} is outside the display'
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

    def screen(self):
        return json.loads(self.ui('screen'))

    def in_screen(self, x, y):
        s = self.screen()
        return s['x'] <= x < s['x'] + s['w'] and s['y'] <= y < s['y'] + s['h']

    def open_menu(self):
        assert self.wait(self.items, 'status item', 40), 'no status item'
        it = self.items()[0]
        # Acceptance gate: the icon must be proven onscreen and visibly drawn before anything clicks it.
        cx, cy = it['x'] + it['w'] / 2, it['y'] + it['h'] / 2
        assert self.in_screen(cx, cy), f'status item centre {cx},{cy} is outside {self.screen()}'
        state['opens'] = state.get('opens', 0) + 1
        pre = OUT / f'preclick-{self.name}-{state["opens"]}.png'
        subprocess.run(['screencapture', '-x', str(pre)], check=True)
        drawn = json.loads(self.ui('iconcheck', pre, it['x'], it['y'], it['w'], it['h']) or '{}')
        assert drawn.get('colors', 0) > 2, f'status item region has no drawn icon: {drawn}'
        say(f'preclick display captured; icon drawn colors={drawn.get("colors")} inside screen={self.screen()}')
        say(f'click status item at {it["x"]},{it["y"]} size {it["w"]}x{it["h"]}')
        self.ui('click', it['x'] + it['w'] / 2, it['y'] + it['h'] / 2)
        assert self.wait(self.menus, 'menu window', 10), 'menu did not open from a real click'
        time.sleep(1.2)
        assert self.menu_items(), 'menu opened empty'

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

    def menu_items(self):
        """The open root menu's rows, each with every label beneath it. Hosted rows expose text only on descendants."""
        def labels(n):
            own = [n.get('title') or n.get('desc') or n.get('value') or '']
            for c in n.get('kids', []):
                own += labels(c)
            return [x for x in own if x]
        for it in self.bar().get('kids', []):
            for m in it.get('kids', []):
                if m.get('role') == 'AXMenu':
                    return [{'y': r['y'], 'h': r['h'], 'x': r['x'], 'w': r['w'], 'labels': labels(r),
                             'action': r.get('identifier') or r.get('help')} for r in m.get('kids', [])]
        return []

    def row(self, text):
        """The root-menu row whose subtree mentions text, wherever the app hosted it."""
        for r in self.menu_items():
            if r['w'] and any(text.lower() in l.lower() for l in r['labels']):
                return r
        return None

    def hover(self, row, steps=25):
        cx, cy = row['x'] + row['w'] / 2, row['y'] + row['h'] / 2
        assert self.in_screen(cx, cy), f'row centre {cx},{cy} is outside the display; a click here would prove nothing'
        self.ui('move', cx, cy, steps)
        return cx, cy

    def click_row(self, row):
        cx, cy = self.hover(row)
        time.sleep(0.4)
        self.ui('click', cx, cy)

    def scroll_to(self, pred, what):
        """Real wheel events over the menu until the wanted row's centre is onscreen. Fails rather than clicking off-display."""
        menu = self.menus()[-1]
        self.ui('move', menu['x'] + menu['w'] / 2, menu['y'] + menu['h'] / 2, 10)
        s = self.screen()
        for _ in range(60):
            row = next((r for r in self.menu_items() if r['w'] and pred(r)), None)
            if row and 30 < row['y'] + row['h'] / 2 < min(s['h'] - 90, menu['y'] + menu['h'] - 24):
                return row
            self.ui('scroll', -5)
            time.sleep(0.15)
        raise AssertionError(f'could not scroll {what} onscreen')

    def win_rows(self):
        """Every node in the app's ordinary windows, flattened, with frames, for Settings and the share preview."""
        out = []

        def walk(n):
            out.append({'role': n.get('role'), 'label': n.get('title') or n.get('desc') or n.get('value') or '', 'value': n.get('value'),
                        'x': n.get('x'), 'y': n.get('y'), 'w': n.get('w'), 'h': n.get('h'), 'help': n.get('help'), 'sub': n.get('sub')})
            for c in n.get('kids', []):
                walk(c)
        for w in json.loads(self.ui('tree', self.proc.pid, 'AXWindows', 22, timeout=60) or '[]'):
            walk(w)
        return out

    def click_at(self, r):
        cx, cy = r['x'] + r['w'] / 2, r['y'] + r['h'] / 2
        assert self.in_screen(cx, cy), f'target {r.get("label")} at {cx},{cy} is outside the display'
        self.ui('move', cx, cy, 15)
        time.sleep(0.3)
        self.ui('click', cx, cy)

    def press(self, label, roles=None):
        """A real click on the visible window control with this exact accessible label."""
        hits = [r for r in self.win_rows() if r['label'] == label and r['w'] and (roles is None or r['role'] in roles)]
        assert hits, f'no visible control labelled {label!r}'
        self.click_at(hits[0])
        return hits[0]

    def texts(self):
        return [r['label'] for r in self.win_rows() if r['role'] == 'AXStaticText' and r['label'] and r['w']]

    def shot(self, name, note=''):
        time.sleep(0.5)
        subprocess.run(['screencapture', '-x', '-C', str(OUT / f'{name}-screen.png')], check=True)
        (OUT / f'{name}-ax.json').write_text(self.ui('tree', self.proc.pid, 'AXExtrasMenuBar'))
        assert state['banner'].poll() is None, 'provenance banner died'
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
    # A cumulative request count proves nothing about a stage; scenarios assert per-phase oracles through check().
    log = state.get('log', [])
    ok = [e for e in log if e['status'] == 200]
    say(f'provider requests answered 200 by the fixture: {len(ok)} of {len(log)}')
    check('app reached the fixture', ok, len(ok))
    (OUT / 'resolver-watch.json').write_text(json.dumps({'checks': state.get('resolver_checks', 0), 'escapes': state.get('resolver_escapes', [])}))
    say(f"resolver watch (sampled): {state.get('resolver_checks', 0)} checks, {len(state.get('resolver_escapes', []))} escapes")
    check('no sampled resolver escape', not state.get('resolver_escapes'), state.get('resolver_escapes', []))
    if state['unknown']:
        (OUT / 'unrouted-requests.txt').write_text('\n'.join(sorted(set(state['unknown']))) + '\n')
    failed = [c for c in state.get('checks', []) if not c['pass']]
    say(f"checks: {len(state.get('checks', [])) - len(failed)} passed, {len(failed)} failed")
    say('done')
    assert not failed, f'{len(failed)} acceptance checks failed: {[c["check"] for c in failed]}'
