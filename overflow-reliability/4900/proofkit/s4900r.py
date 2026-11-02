#!/usr/bin/env python3
"""#4900 overflow reliability: repeat the click and record, at mouse-down, whether a row was there to receive it.

A selection failure is a highlighted row whose click does not select. A missed click has no highlighted row to click.
"""
import json, shutil, subprocess, sys, time, uuid
from pathlib import Path
import kit, providers
from kit import App, OUT, check, phase_begin, say, state, record
HEAD_APP, BEFORE_APP, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
TARGETS = [('Kimi Code · Synthetic Account 10', 'kimi'), ('z.ai / GLM', 'zai'), ('OpenRouter', 'openrouter')]
trials = []


def finish_recording(rec, timeout):
    """A stuck recorder loses a video, never the trials."""
    try:
        rec.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        rec.terminate()
        say(f'recorder still running after {timeout}s; stopped it')
        try:
            rec.wait(timeout=15)
        except subprocess.TimeoutExpired:
            rec.kill()


def flatten(n, out):
    out.append(n)
    for k in n.get('kids', []):
        flatten(k, out)
    return out


def child_row(app, label):
    return next((n for n in flatten(app.bar(), []) if n.get('role') == 'AXMenuItem' and n.get('title') == label and n.get('w')), None)


def prefs():
    r = subprocess.run(['defaults', 'read', kit.BUNDLE, 'mergedMenuLastSelectedWasOverview'], capture_output=True, text=True).stdout.strip()
    s = subprocess.run(['defaults', 'read', kit.BUNDLE, 'selectedMenuProvider'], capture_output=True, text=True).stdout.strip()
    return r == '1', s


def relaunch(name, app_path, **extra):
    kit.defaults_reset()
    providers.overview_defaults(mergedOverviewLayout='compact', mergedOverviewAllAccounts=True, **extra)
    phase_begin(name)
    app = App(app_path, HELPER, name)
    time.sleep(30)
    return app


def open_submenu(app):
    app.open_menu()
    assert prefs()[0], 'trial must begin on Overview'
    more = app.scroll_to(lambda r: any(l.startswith('More (') for l in r['labels']), 'More (n)')
    assert more, 'More (n) not reachable'
    app.hover(more)
    assert app.wait(lambda: len(app.menus()) == 2, 'overflow submenu', 5), 'overflow submenu did not open'
    time.sleep(0.5)
    return more


def highlighted(app, row, name):
    path = OUT / f'{name}.png'
    subprocess.run(['screencapture', '-x', '-C', str(path)], check=True)
    c = json.loads(app.ui('pixel', path, row['x'] + 8, row['y'] + row['h'] / 2) or '{}')
    return c, bool(c) and c['b'] > 150 and c['r'] < 90


def return_to_overview(app):
    if not app.menus():
        app.open_menu()
    button = next((n for n in flatten(app.bar(), []) if n.get('role') == 'AXButton' and n.get('desc', n.get('title')) == 'Overview' and n.get('w')), None)
    if button is None:
        button = next((r for r in app.rows() if r['role'] == 'AXButton' and r['label'] == 'Overview' and r['w']), None)
    assert button, 'no Overview tab'
    app.ui('move', button['x'] + button['w'] / 2, button['y'] + button['h'] / 2, 10)
    time.sleep(0.3)
    app.ui('click', button['x'] + button['w'] / 2, button['y'] + button['h'] / 2)
    assert app.wait(lambda: prefs()[0], 'Overview selected', 5), 'could not return to Overview'
    time.sleep(0.8)
    app.close_menu()
    time.sleep(1.5)


def trial(app, lane, n, path):
    label, expected = TARGETS[n % len(TARGETS)]  # diagonal-top passes multiples of three: always the top row.
    tag = f'{lane}-{n:02d}'
    rec = {'lane': lane, 'n': n, 'target': label, 'expected': expected}
    try:
        more = open_submenu(app)
        row = child_row(app, label)
        assert row, f'{label} not in submenu'
        target = (row['x'] + row['w'] / 2, row['y'] + row['h'] / 2)
        path(app, more, target)
        rec['windows_at_mousedown'] = len(app.menus())
        rec['submenu_open'] = rec['windows_at_mousedown'] == 2
        now = child_row(app, label) if rec['submenu_open'] else None
        rec['ax_selected'] = bool(now) and now.get('selected') == '1'
        rec['pixel'], rec['highlighted'] = highlighted(app, row, f'mousedown-{tag}')
        before = state['requests']
        app.ui('click', *target)
        time.sleep(2.5)
        rec['menu_closed'] = not app.menus()
        was_overview, provider = prefs()
        rec['overview_after'], rec['provider_after'] = was_overview, provider
        rec['selected'] = not was_overview and provider == expected
        rec['requests_after_click'] = state['requests'] - before
        if not rec['selected']:
            app.close_menu()
        else:
            app.open_menu()
            rec['reopened_on_tab'] = not app.row('More (')
            return_to_overview(app)
        say(f'TRIAL {json.dumps(rec, default=str)}')
    except Exception as e:  # A harness fault is reported as one, never counted as a product result.
        rec['harness_error'] = repr(e)
        say(f'TRIAL-ERROR {tag} {e!r}')
        subprocess.run(['screencapture', '-x', '-C', str(OUT / f'error-{tag}.png')])
        app.close_menu()
        time.sleep(1)
        if not prefs()[0]:
            try:
                return_to_overview(app)
            except Exception as e2:
                say(f'recovery failed {e2!r}')
    trials.append(rec)
    (OUT / 'trials.json').write_text(json.dumps(trials, indent=1, default=str, ensure_ascii=False))


def aimed(app, more, target):
    """Along the More row into the submenu, then up inside it, so the pointer never crosses a sibling row."""
    y = more['y'] + more['h'] / 2
    app.ui('move', target[0], y, 25)
    time.sleep(0.25)
    app.ui('move', target[0], target[1], 15)
    time.sleep(0.6)


def diagonal(app, more, target):
    """The straight line the original scenario glided, which crosses the sibling row above More."""
    app.ui('move', target[0], target[1], 15)
    time.sleep(0.6)


def rest_on_sibling(app, more, target):
    """Stop over the sibling row: AppKit retargets to it and closes the submenu, then go where the row used to be."""
    app.ui('move', more['x'] + more['w'] / 2, more['y'] - 30, 6)
    app.wait(lambda: len(app.menus()) == 1, 'submenu collapse', 4)
    app.ui('move', target[0], target[1], 15)
    time.sleep(0.6)


subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.verify_installed(INSTALLED)
kit.start_fixture(); providers.install(); kit.write_credentials()
cfg = json.loads(json.dumps(providers.CONFIG))
for p in cfg:
    if p['id'] == 'kimi':
        p['tokenAccounts'] = {'version': 1, 'activeIndex': 0, 'accounts': [
            {'id': str(uuid.UUID(int=i + 1)), 'label': f'Synthetic Account {i + 1:02d}', 'token': f'synthetic-kimi-{i + 1}',
             'addedAt': 1760000000 + i, 'lastUsed': None} for i in range(14)]}
kit.write_config(cfg)

say('=== lanes on the PR head')
app = relaunch('reliability', INSTALLED)
rec = record('aimed-first-trials', 60)
for n in range(12):
    trial(app, 'aimed', n, aimed)
finish_recording(rec, 90)
rec = record('diagonal-trials', 150)
for n in range(12):
    trial(app, 'diagonal', n, diagonal)
finish_recording(rec, 200)
for n in range(6):  # The top row alone, the longest crossing of the sibling row.
    trial(app, 'diagonal-top', n * 3, diagonal)
rec = record('forced-miss', 50)
for n in range(3):
    trial(app, 'forced-miss', n, rest_on_sibling)
finish_recording(rec, 90)
app.quit()


def lane(name):
    return [t for t in trials if t['lane'] == name and 'harness_error' not in t]


errors = [t for t in trials if 'harness_error' in t]
a, d, f = lane('aimed'), lane('diagonal'), lane('forced-miss')
check('aimed: twelve clean trials', len(a) == 12, len(a))
check('aimed: every click had a highlighted row and selected its provider', all(t['highlighted'] and t['selected'] for t in a), [(t['n'], t['highlighted'], t['selected']) for t in a])
check('diagonal: twelve clean trials', len(d) == 12, len(d))
t = lane('diagonal-top')
all_clicks = a + d + f + t
check('no selection failure: every highlighted row selected', all(t['selected'] for t in all_clicks if t['highlighted']), [t['n'] for t in all_clicks if t['highlighted'] and not t['selected']])
check('no phantom selection: nothing selected without a highlighted row', not any(t['selected'] for t in all_clicks if not t['highlighted']), [t['n'] for t in all_clicks if t['selected'] and not t['highlighted']])
check('forced miss: submenu was closed at mouse-down and the click stayed on Overview', len(f) == 3 and all(not t['submenu_open'] and not t['selected'] and t['overview_after'] and t['menu_closed'] for t in f), f)
say(f'SUMMARY aimed selected={sum(x["selected"] for x in a)}/{len(a)} diagonal selected={sum(x["selected"] for x in d)}/{len(d)} '
    f'diagonal missed={sum(not x["highlighted"] for x in d)} top-row selected={sum(x["selected"] for x in t)}/{len(t)} forced-miss selected={sum(x["selected"] for x in f)}/{len(f)} harness_errors={len(errors)}')

say('=== rival cause: refresh completing while the overflow submenu is open')
try:
    app = relaunch('dwell', INSTALLED, refreshFrequency='oneMinute')
    more = open_submenu(app)
    samples, start, before = [], time.monotonic(), state['requests']
    while time.monotonic() - start < 130:
        samples.append({'t': round(time.monotonic() - start, 1), 'windows': len(app.menus()), 'requests': state['requests'] - before})
        time.sleep(5)
    (OUT / 'dwell-samples.json').write_text(json.dumps(samples, indent=1))
    app.shot('dwell-after-130s', 'submenu held open across timer refreshes')
    say(f'dwell samples: {samples}')
    grew = samples[-1]['requests'] > 0
    stayed = all(s['windows'] == 2 for s in samples)
    say(f'FINDING refresh requests during dwell={samples[-1]["requests"]} submenu stayed open={stayed}')
    check('a timer refresh ran while the submenu was open', grew, samples[-1])
    check('the submenu survives a refresh completing behind it', stayed, [s for s in samples if s['windows'] != 2][:3])
    if stayed:
        row = child_row(app, TARGETS[0][0])
        aimed(app, more, (row['x'] + row['w'] / 2, row['y'] + row['h'] / 2))
        app.ui('click', row['x'] + row['w'] / 2, row['y'] + row['h'] / 2)
        time.sleep(2.5)
        check('a click after the refresh still selects', prefs() == (False, 'kimi'), prefs())
    app.quit()
except Exception as e:
    check('dwell lane completed', False, repr(e))

say('=== control: plain NSMenu, same geometry, no CodexBar code')
control = []


def control_trial(lane_name, n, path):
    proc = subprocess.Popen([HELPER, 'controlmenu', '708', '91'], stdout=subprocess.PIPE, text=True)
    rec = {'lane': lane_name, 'n': n}
    try:
        def windows():
            raw = json.loads(subprocess.run([HELPER, 'windows', Path(HELPER).name], capture_output=True, text=True).stdout or '[]')
            return sorted([w for w in raw if 50 < w['h'] < 720 and w['layer'] < 500], key=lambda w: w['x'])
        def h(*a):
            subprocess.run([HELPER, *map(str, a)], capture_output=True, text=True)
        end = time.monotonic() + 8
        while not windows() and time.monotonic() < end:
            time.sleep(0.1)
        parent = windows()[-1]
        more = {'x': parent['x'], 'w': parent['w'], 'y': parent['y'] + 5 + 540, 'h': 22}
        y = more['y'] + 11
        h('move', parent['x'] + parent['w'] / 2, y, 25)
        end = time.monotonic() + 5
        while len(windows()) < 2 and time.monotonic() < end:
            time.sleep(0.1)
        sub = windows()[0]
        rec['parent'], rec['submenu'] = parent, sub
        target = (sub['x'] + sub['w'] / 2, sub['y'] + 17)
        time.sleep(1.2)
        if path == 'aimed':
            h('move', target[0], y, 25)
            time.sleep(0.25)
        h('move', target[0], target[1], 15)
        time.sleep(0.6)
        rec['submenu_open'] = len(windows()) == 2
        subprocess.run(['screencapture', '-x', '-C', str(OUT / f'control-{lane_name}-{n:02d}.png')])
        h('click', *target)
        out, _ = proc.communicate(timeout=10)
        rec['picked'] = out.strip()
    except Exception as e:
        rec['harness_error'] = repr(e)
        proc.kill()
    say(f'CONTROL {json.dumps(rec, default=str)}')
    control.append(rec)
    time.sleep(0.5)


try:
    rec = record('control-menu', 80)
    for n in range(6):
        control_trial('diagonal', n, 'diagonal')
    for n in range(6):
        control_trial('aimed', n, 'aimed')
    finish_recording(rec, 120)
    (OUT / 'control-trials.json').write_text(json.dumps(control, indent=1, default=str))
    clean = [c for c in control if 'harness_error' not in c]
    say(f"SUMMARY control diagonal picked={sum(bool(c['picked']) for c in clean if c['lane'] == 'diagonal')}/{sum(c['lane'] == 'diagonal' for c in clean)} "
        f"aimed picked={sum(bool(c['picked']) for c in clean if c['lane'] == 'aimed')}/{sum(c['lane'] == 'aimed' for c in clean)} errors={len(control) - len(clean)}")
    check('control lane ran without harness errors', len(clean) == 12, len(clean))
    check('control: every aimed click picked Child 0', all(c['picked'] == 'picked Child 0' for c in clean if c['lane'] == 'aimed'), [c['picked'] for c in clean if c['lane'] == 'aimed'])
    check('control: a click with the submenu open picks, and one without it does not', all(bool(c['picked']) == c['submenu_open'] for c in clean), [(c['submenu_open'], c['picked']) for c in clean])
except Exception as e:
    check('control lane completed', False, repr(e))

say('=== before: v0.83.0, where the same roster has no overflow row')
try:
    shutil.rmtree(INSTALLED)
    subprocess.run(['ditto', BEFORE_APP, str(INSTALLED)], check=True)
    app = relaunch('before', INSTALLED)
    app.open_menu()
    (OUT / 'before-rows.json').write_text(json.dumps(app.menu_items(), indent=1, ensure_ascii=False))
    app.shot('before-open')
    check('before: no More (n) row exists', not app.row('More ('), [r['labels'][:2] for r in app.menu_items()][-4:])
    row = app.scroll_to(lambda r: any('Synthetic Account 14' in l for l in r['labels']), 'last account')
    app.shot('before-scrolled-to-account-14')
    check('before: the fourteenth account is an inline row', row, row and row['labels'][:3])
    app.click_row(row)
    time.sleep(2.5)
    check('before: clicking that inline row selects its provider', prefs() == (False, 'kimi'), prefs())
    app.quit()
except Exception as e:
    check('before lane completed', False, repr(e))
kit.finish()
