#!/usr/bin/env python3
"""Packaged-app proof that Cursor's non-semantic Total quota drives the combined warning."""
import json, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, check, phase_begin, reached, state

HEAD_APP, _V083, HELPER = sys.argv[1:]
SELECT = ['cursor', 'codex']
kit.start_fixture()
providers.install()
kit.write_credentials(claude=False)
kit.write_config([p for p in providers.CONFIG if p['id'] in SELECT])
providers.PERCENTS['codex'] = (30, 20)
kit.verify_installed(HEAD_APP)


def label(app):
    items = app.items()
    return ' '.join(str(items[0].get(k) or '') for k in ('title', 'desc', 'value')).strip() if items else ''


for appearance, dark in [('light', False), ('dark', True)]:
    subprocess.run([HELPER, 'dark', '1' if dark else '0'], capture_output=True, text=True, check=True)
    time.sleep(2)
    phase_begin(appearance)
    kit.defaults_reset()
    providers.overview_defaults(refreshFrequency='manual', mergedOverviewSelectedProviders=SELECT,
                                mergedOverviewSelectionEditedActiveProviders=SELECT, unifiedIconSource='allProviders',
                                tokenCostUsageEnabled=False)
    app = App(HEAD_APP, HELPER, f'cursor-{appearance}')
    ok = app.wait(lambda: 'Cursor near limit, 5% left' in label(app) and 'average' in label(app), 'Cursor warning', 100)
    check(f'{appearance}: Cursor Total raises the combined warning at 5% left', ok, label(app))
    check(f'{appearance}: Cursor and Codex reached the fixture',
          bool(reached(appearance, 'cursor.com')) and bool(reached(appearance, 'chatgpt.com')),
          [e for e in state.get('log', []) if e['phase'] == appearance])
    app.ui('move', 300, 400, 8)
    app.shot(f'{appearance}-cursor-warning')
    app.open_menu()
    app.shot(f'{appearance}-cursor-menu', 'open combined dropdown')
    rows = [r['label'] for r in app.rows() if r['label']]
    (OUT / f'{appearance}-menu-labels.json').write_text(json.dumps(rows, indent=2))
    check(f'{appearance}: open menu contains Cursor and its Total quota',
          any('Cursor' in x for x in rows) and any('5%' in x for x in rows), rows)
    app.quit()

summary = {'scenario': 'Cursor Total outside semantic lanes', 'fixture_used_percent': {'total': 95, 'auto': 30, 'api': 70},
           'other_provider': 'Codex', 'combined_icon_source': 'allProviders', 'checks': state.get('checks', [])}
(OUT / 'summary.json').write_text(json.dumps(summary, indent=2))
kit.finish()
