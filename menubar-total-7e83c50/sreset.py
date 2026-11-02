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


phase_begin('reset')
reset['t'] = kit.epoch(timedelta(seconds=75))
kit.defaults_reset()
providers.overview_defaults(refreshFrequency='manual', mergedOverviewSelectedProviders=SELECT,
                            mergedOverviewSelectionEditedActiveProviders=SELECT, unifiedIconSource='allProviders')
app = App(HEAD_APP, HELPER, 'reset')
app.wait(app.items, 'status item', 40)
time.sleep(20)
before_label = label(app)
check('manual refresh: Codex at 100% weekly warns before its reset', 'Codex near limit, 0% left' in before_label, before_label)
app.ui('move', 300, 400, 8)
app.shot('reset-1-warning')
count = lambda: sum(1 for e in state.get('log', []) if e['path'] == '/backend-api/wham/usage')
n = count()
# Reset passes at about 75s; the redraw tick is at most a minute later. Plain sleeps so the driver provokes nothing.
time.sleep(max(0, reset['t'] - kit.epoch(timedelta(0))) + 70)
after_label = label(app)
m = count()
check('manual refresh: the warning clears after the reset from the clock alone, with no new request',
      'near limit' not in after_label and m == n, f'requests {n}->{m} {before_label!r} -> {after_label!r}')
app.shot('reset-2-cleared')
app.quit()
kit.finish()
