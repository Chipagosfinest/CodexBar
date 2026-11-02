#!/usr/bin/env python3
"""Why did an exhausted Codex weekly window not warn on manual refresh? Serve it, log it, read the app."""
import json, subprocess, sys, time
from datetime import timedelta
import kit, providers
from kit import App, OUT, check, phase_begin, say, state

HEAD_APP, _V083, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
SELECT = ['codex', 'claude', 'kimi', 'zai', 'deepseek']
kit.start_fixture()
providers.install()
kit.write_credentials()
kit.write_config([p for p in providers.CONFIG if p['id'] in SELECT])
providers.PERCENTS.update({'codex': (30, 20), 'claude': (35, 22), 'kimi': (15, 12), 'zai': (72,), 'commandcode': (0, 0), 'openrouter': 0})
real_codex = kit.ROUTES[('chatgpt.com', '/backend-api/wham/usage')]
real_zai = kit.ROUTES[('api.z.ai', '/api/monitor/usage/quota/limit')]


def zai_route(h):
    status, body = real_zai(h)
    body['data']['limits'][0]['nextResetTime'] = kit.epoch(timedelta(minutes=30)) * 1000
    return status, body


kit.ROUTES[('api.z.ai', '/api/monitor/usage/quota/limit')] = zai_route
reset = {}


def codex_route(h):
    status, body = real_codex(h)
    body['rate_limit']['secondary_window'].update(used_percent=100, reset_at=reset['t'])
    say('SERVED codex ' + json.dumps(body['rate_limit']))
    return status, body


kit.ROUTES[('chatgpt.com', '/backend-api/wham/usage')] = codex_route


def label(app):
    items = app.items()
    return ' '.join(str(items[0].get(k) or '') for k in ('title', 'desc', 'value')).strip() if items else ''


def texts(app):
    return [r['label'] for r in app.rows() if r['label']]


for name, refresh, seconds in (('far-manual', 'manual', 3600), ('near-manual', 'manual', 150), ('far-minute', 'oneMinute', 3600)):
    phase_begin(name)
    reset['t'] = kit.epoch(timedelta(seconds=seconds))
    kit.defaults_reset()
    providers.overview_defaults(refreshFrequency=refresh, mergedOverviewSelectedProviders=SELECT,
                                mergedOverviewSelectionEditedActiveProviders=SELECT, unifiedIconSource='allProviders')
    app = App(HEAD_APP, HELPER, name)
    app.wait(app.items, 'status item', 40)
    for t in (15, 30, 60):
        time.sleep(t - (0 if t == 15 else {30: 15, 60: 30}[t]))
        say(f'{name} t={t}: {label(app)!r}')
    app.open_menu()
    app.shot(f'{name}-menu', 'menu open')
    (OUT / f'{name}-labels.json').write_text(json.dumps(texts(app), indent=1))
    say(f'{name} menu rows: {[x for x in texts(app) if "left" in x.lower() or "weekly" in x.lower() or "session" in x.lower()][:10]}')
    app.close_menu()
    if name == 'near-manual':
        n = sum(1 for e in state.get('log', []) if e['path'] == '/backend-api/wham/usage' and e['phase'] == name)
        time.sleep(100)
        m = sum(1 for e in state.get('log', []) if e['path'] == '/backend-api/wham/usage' and e['phase'] == name)
        say(f'near-manual after reset: {label(app)!r} requests {n}->{m}')
    app.quit()
kit.finish()
