#!/usr/bin/env python3
"""Refresh rate while Claude answers 500 from a near-limit state: the v0.83.0 release against this head."""
import json, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, finding, phase_begin, say, state

HEAD_APP, V083_APP, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
SELECT = ['codex', 'claude', 'kimi', 'zai', 'deepseek']
kit.start_fixture()
providers.install()
real = kit.ROUTES[('api.anthropic.com', '/api/oauth/usage')]
kit.ROUTES[('api.anthropic.com', '/api/oauth/usage')] = (
    lambda h: (500, {'error': {'message': 'Temporary failure'}}) if state.get('claude_down') else real(h))
kit.write_credentials()
kit.write_config([p for p in providers.CONFIG if p['id'] in SELECT])
providers.PERCENTS.update({'codex': (30, 20), 'kimi': (15, 12), 'zai': (72,), 'commandcode': (0, 0), 'openrouter': 0})


def run(label, path, prefs, claude):
    providers.PERCENTS['claude'] = claude
    state['claude_down'] = False
    phase_begin(f'storm-{label}')
    kit.defaults_reset()
    providers.overview_defaults(refreshFrequency='oneMinute', mergedOverviewSelectedProviders=SELECT,
                                mergedOverviewSelectionEditedActiveProviders=SELECT, **prefs)
    app = App(path, HELPER, f'storm-{label}')
    time.sleep(25)
    state['claude_down'] = True
    start = len(state.get('log', []))
    time.sleep(170)
    window = state.get('log', [])[start:]
    state['claude_down'] = False
    count = sum(1 for e in window if e['path'] == '/api/oauth/usage')
    say(f'STORM {label}: claude_usage_requests_in_170s={count} all_requests={len(window)}')
    app.quit()
    return count


near, calm = (35, 92), (35, 22)
results = {
    'release-near': run('release-near', V083_APP, {}, near),
    'head-default-near': run('head-default-near', HEAD_APP, {}, near),
    'head-total-near': run('head-total-near', HEAD_APP, {'unifiedIconSource': 'allProviders'}, near),
    'head-total-calm': run('head-total-calm', HEAD_APP, {'unifiedIconSource': 'allProviders'}, calm),
    'release-calm': run('release-calm', V083_APP, {}, calm),
}
(OUT / 'storm.json').write_text(json.dumps(results, indent=1))
say(json.dumps(results))
