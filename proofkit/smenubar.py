#!/usr/bin/env python3
"""All providers menu bar meter, driven through the unmodified packaged app with live fixture quota changes."""
import json, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, check, finding, phase_begin, reached, say, state

HEAD_APP, _V083_APP, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
SELECT = ['codex', 'claude', 'kimi', 'zai', 'deepseek']
kit.start_fixture()
providers.install()
real_claude = kit.ROUTES[('api.anthropic.com', '/api/oauth/usage')]
kit.ROUTES[('api.anthropic.com', '/api/oauth/usage')] = (
    lambda h: (500, {'error': {'message': 'Temporary failure'}}) if state.get('claude_down') else real_claude(h))
kit.write_credentials()
kit.write_config([p for p in providers.CONFIG if p['id'] in SELECT])
say('trusted(ax,screen,post)=' + subprocess.run([HELPER, 'trusted'], capture_output=True, text=True).stdout.strip())
subprocess.run(['rm', '-rf', str(INSTALLED)], check=True)
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.verify_installed(INSTALLED)
real_zai = kit.ROUTES[('api.z.ai', '/api/monitor/usage/quota/limit')]


def zai_route(h):
    status, body = real_zai(h)
    if not state.get('zai_burning'):
        # 72% used 4.5h into a 5h window lasts until reset, so no forecast fires.
        body['data']['limits'][0]['nextResetTime'] = kit.epoch(__import__('datetime').timedelta(minutes=30)) * 1000
    return status, body


kit.ROUTES[('api.z.ai', '/api/monitor/usage/quota/limit')] = zai_route
CALM = {'codex': (30, 20), 'claude': (35, 22), 'kimi': (15, 12), 'zai': (72,), 'commandcode': (0, 0), 'openrouter': 0}


def label(app):
    items = app.items()
    if not items:
        return ''
    return ' '.join(str(items[0].get(k) or '') for k in ('title', 'desc', 'value')).strip()


def wait_label(app, pred, what, timeout=200):
    ok = app.wait(lambda: pred(label(app)), what, timeout)
    say(f'label after {what}: {label(app)!r}')
    return ok


def shot(app, name, note='', park=True):
    if park:
        app.ui('move', 300, 400, 8)  # Keep the pointer off the status item so no frame hides a logo.
        time.sleep(0.4)
    app.shot(name, note)
    (OUT / f'{name}-item.json').write_text(json.dumps(app.items()[0] if app.items() else {}))


def seed(refresh='oneMinute', **prefs):
    kit.defaults_reset()
    providers.overview_defaults(refreshFrequency=refresh, mergedOverviewSelectedProviders=SELECT,
                                mergedOverviewSelectionEditedActiveProviders=SELECT, **prefs)


def saved_source():
    return subprocess.run(['defaults', 'read', kit.BUNDLE, 'unifiedIconSource'], capture_output=True, text=True).stdout.strip()


providers.PERCENTS.update(CALM)
phase_begin('default-source')
seed()
app = App(INSTALLED, HELPER, 'default-source')
assert app.wait(app.items, 'status item', 40), 'no status item'
before = state['requests']
app.wait(lambda: state['requests'] > before, 'first refresh', 60)
time.sleep(10)
shot(app, 'default-source', 'no source chosen: the existing default')
check('an existing install is unchanged: no total without opting in', 'average' not in label(app), label(app))
app.quit()

def storm(label_, app_path, prefs):
    """Original failing order: near limit, menu opened and closed, a second provider near limit, then Claude 500s."""
    providers.PERCENTS.update(CALM)
    state['claude_down'] = False
    state['zai_burning'] = False
    phase_begin(f'storm-{label_}')
    seed(**prefs)
    probe = App(app_path, HELPER, f'storm-{label_}')
    time.sleep(25)
    providers.PERCENTS['claude'] = (35, 92)
    time.sleep(62)
    probe.open_menu()
    time.sleep(3)
    probe.close_menu()
    providers.PERCENTS['zai'] = (97,)
    time.sleep(62)
    state['claude_down'] = True
    start = len(state.get('log', []))
    time.sleep(170)
    window = state.get('log', [])[start:]
    state['claude_down'] = False
    count = sum(1 for e in window if e['path'] == '/api/oauth/usage')
    say(f'STORM {label_}: claude_usage_requests_in_170s={count} all_requests={len(window)}')
    (OUT / f'storm-{label_}.json').write_text(json.dumps({'claude_usage_requests_in_170s': count, 'all_requests': len(window)}))
    probe.quit()
    providers.PERCENTS.update(CALM)
    return count


# Upgrade and downgrade against the genuine release: saved choices survive and the new value degrades safely.
phase_begin('upgrade')
seed(unifiedIconSource='highestUsage')
app = App(_V083_APP, HELPER, 'upgrade-v083')
assert app.wait(app.items, 'release status item', 40), 'release app showed no status item'
time.sleep(12)
app.quit()
app = App(INSTALLED, HELPER, 'upgrade-head')
assert app.wait(app.items, 'head status item', 40), 'head showed no status item'
time.sleep(12)
check('upgrade from v0.83.0 keeps a saved Highest usage choice and shows no total',
      saved_source() == 'highestUsage' and 'average' not in label(app), f'{saved_source()} {label(app)}')
app.quit()
phase_begin('downgrade')
seed(unifiedIconSource='allProviders')
app = App(_V083_APP, HELPER, 'downgrade-v083')
ok = app.wait(app.items, 'release status item with the new saved value', 40)
time.sleep(12)
check('the v0.83.0 release still runs with the new saved value and shows no total', ok and 'average' not in label(app), label(app))
shot(app, 'downgrade-v083')
app.quit()
app = App(INSTALLED, HELPER, 'downgrade-back-head')
check('returning to head restores the total from the same saved value',
      wait_label(app, lambda l: 'average' in l, 'total after downgrade round trip', 90) and saved_source() == 'allProviders', label(app))
app.quit()

# A Codex weekly limit reaches its reset on manual refresh: the warning must clear from the clock alone.
phase_begin('reset-clock')
real_codex = kit.ROUTES[('chatgpt.com', '/backend-api/wham/usage')]
reset_at = {}


def codex_route(h):
    status, body = real_codex(h)
    body['rate_limit']['secondary_window'].update(used_percent=100, reset_at=reset_at['t'])
    return status, body


kit.ROUTES[('chatgpt.com', '/backend-api/wham/usage')] = codex_route
reset_at['t'] = kit.epoch(__import__('datetime').timedelta(seconds=100))
seed(refresh='manual', unifiedIconSource='allProviders')
app = App(INSTALLED, HELPER, 'reset-clock')
check('manual refresh: Codex at 100% weekly warns before its reset',
      app.wait(lambda: 'Codex near limit, 0% left' in label(app), 'Codex warning', 60), label(app))
shot(app, 'reset-1-codex-exhausted')
before = sum(1 for e in state.get('log', []) if e['path'] == '/backend-api/wham/usage')
end = time.monotonic() + 170
while time.monotonic() < end and 'near limit' in label(app):
    time.sleep(5)  # Plain sleeps: this oracle counts requests, so the driver must not provoke any.
after = sum(1 for e in state.get('log', []) if e['path'] == '/backend-api/wham/usage')
check('manual refresh: the warning clears at reset from the clock alone, with no new request',
      'near limit' not in label(app) and after == before, f'requests {before}->{after} {label(app)}')
shot(app, 'reset-2-cleared-no-fetch')
app.quit()
kit.ROUTES[('chatgpt.com', '/backend-api/wham/usage')] = real_codex

for name, dark in (('light', False), ('dark', True)):
    say(f'=== appearance {name}: {subprocess.run([HELPER, "dark", "1" if dark else "0"], capture_output=True, text=True).stdout.strip()}')
    time.sleep(3)
    providers.PERCENTS.update(CALM)
    state['all_fail'] = False
    phase_begin(f'{name}-calm')
    seed(unifiedIconSource='allProviders')
    app = App(INSTALLED, HELPER, f'total-{name}')
    # (70 + 65 + 85 + 28) / 4 = 62; DeepSeek is balance-only and must not be counted.
    check(f'{name}: calm total averages the four quota providers and skips balance-only DeepSeek',
          wait_label(app, lambda l: 'average 62% left' in l and 'near limit' not in l, 'calm total'), label(app))
    check(f'{name}: every quota provider reached the fixture',
          all(reached(f'{name}-calm', h) for h in ('chatgpt.com', 'api.anthropic.com', 'api.z.ai')), state.get('log', [])[-6:])
    shot(app, f'{name}-1-calm')

    phase_begin(f'{name}-forecast')
    state['zai_burning'] = True
    # 72% used 2h into 5h runs out in about 47 minutes: the dropdown's red rule, at 28% left.
    check(f'{name}: a run-out forecast within the hour warns even with plenty left',
          wait_label(app, lambda l: 'z.ai / GLM near limit, 28% left' in l, 'forecast warning'), label(app))
    shot(app, f'{name}-1b-forecast-zai')
    app.open_menu()
    shot(app, f'{name}-1c-forecast-menu-open', 'dropdown beside the forecast warning', park=False)
    (OUT / f'{name}-forecast-menu-labels.json').write_text(json.dumps([r['label'] for r in app.rows() if r['label']], indent=1))
    app.close_menu()
    state['zai_burning'] = False
    wait_label(app, lambda l: 'near limit' not in l, 'forecast cleared')

    phase_begin(f'{name}-session-forecast')
    providers.PERCENTS['claude'] = (70, 22)
    # 70% used 2h into 5h runs out in about 51 minutes; the weekly window, which drives the layout metric, lasts.
    check(f'{name}: a session forecast warns although the weekly window would last',
          wait_label(app, lambda l: 'Claude near limit, 30% left' in l, 'session forecast warning'), label(app))
    shot(app, f'{name}-1d-session-forecast-claude')
    providers.PERCENTS.update(CALM)
    wait_label(app, lambda l: 'near limit' not in l, 'session forecast cleared')

    phase_begin(f'{name}-near')
    providers.PERCENTS['claude'] = (35, 92)
    # Claude is not the primary quota driving the item here, so this also proves every provider is observed.
    check(f'{name}: a live quota change raises the warning naming Claude with the total kept',
          wait_label(app, lambda l: 'Claude near limit, 8% left' in l and 'average 48% left' in l, 'Claude near limit'), label(app))
    shot(app, f'{name}-2-near-limit-claude')
    app.open_menu()
    shot(app, f'{name}-3-near-limit-menu-open', 'real click on the status item', park=False)
    (OUT / f'{name}-menu-labels.json').write_text(json.dumps([r['label'] for r in app.rows() if r['label']], indent=1))
    app.close_menu()

    phase_begin(f'{name}-two')
    providers.PERCENTS['zai'] = (97,)
    check(f'{name}: the tighter of two near-limit providers leads, and both are announced',
          wait_label(app, lambda l: '3% left' in l and '8% left' in l,
                     'second provider near limit'), label(app))
    check(f'{name}: tightest provider is announced first', label(app).find('3% left') < label(app).find('8% left'), label(app))
    shot(app, f'{name}-4-two-near-limit')

    if not dark:
        phase_begin('light-stale')
        state['claude_down'] = True
        finding('Claude server failures stop its warning',
                wait_label(app, lambda l: 'Claude near limit' not in l, 'Claude stops warning', 180), label(app))
        shot(app, 'light-5-claude-failing')
        state['claude_down'] = False

    phase_begin(f'{name}-recovered')
    providers.PERCENTS.update(CALM)
    check(f'{name}: recovery returns to the calm total',
          wait_label(app, lambda l: 'average 62% left' in l and 'near limit' not in l, 'recovered', 240), label(app))
    shot(app, f'{name}-6-recovered')

    if not dark:
        try:
            app.open_menu()
            app.click_row(app.scroll_to(lambda r: any(l.startswith('Settings') for l in r['labels']), 'Settings row'))
            app.wait(lambda: any(w['layer'] == 0 and w['w'] > 300 for w in app.windows()), 'Settings window', 10)
            time.sleep(1)
            app.press('Menu Bar')
            time.sleep(1.5)
            pane = [w for w in app.windows() if w['layer'] == 0 and w['w'] > 300][0]
            app.ui('move', pane['x'] + pane['w'] * 0.7, pane['y'] + pane['h'] * 0.6, 10)
            row = []
            for _ in range(40):
                row = [r for r in app.win_rows() if r['label'] == 'Combined icon source' and r['w']]
                if row and pane['y'] + 60 < row[0]['y'] < pane['y'] + pane['h'] - 80:
                    break
                app.ui('scroll', -3)
                time.sleep(0.25)
            time.sleep(0.8)
            shot(app, 'light-7-settings', park=False)
            rows = app.win_rows()
            near = [r for r in rows if row and r['w'] and abs(r['y'] - row[0]['y']) < 26]
            (OUT / 'settings-rows.json').write_text(json.dumps(near, indent=1, default=str))
            check('Settings shows All providers (average) in the Combined icon source row itself',
                  any('All providers (average)' in str(r['label']) + str(r['value']) for r in near),
                  [str(r['label']) + '/' + str(r['value']) for r in near])
        except Exception as error:  # A Settings navigation miss must not cost the appearance matrix.
            finding('Settings pane could be driven', False, repr(error))
    app.quit()

subprocess.run([HELPER, 'dark', '0'], capture_output=True)
kit.finish()
