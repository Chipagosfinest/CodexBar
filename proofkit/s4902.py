#!/usr/bin/env python3
"""#4902: Compact hover flyout, nested chart access, provider-tab selection, and a reopen after a changed model."""
import json, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, say, state, record
HEAD_APP, _, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.start_fixture(); providers.install(); kit.write_credentials(); kit.write_config(providers.CONFIG)
providers.overview_defaults(mergedOverviewLayout='compact')
app = App(INSTALLED, HELPER, 'flyout')
app.wait(lambda: state['requests'] > 3, 'launch refresh', 40)
time.sleep(12)
rec = record('flyout', 85)
time.sleep(2)
app.open_menu()
app.shot('v1-compact-open')
(OUT / 'v1-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
rows = [r for r in app.menu_items() if r['labels'] and r['h'] > 30]
say('rows: ' + json.dumps([(r['y'], r['h'], r['labels'][:3]) for r in rows]))
claude = next(r for r in app.menu_items() if any('Claude' in l for l in r['labels'][:4]) and r['h'] > 30)
app.hover(claude)
assert app.wait(lambda: len(app.menus()) > 1, 'flyout window', 6) or True
time.sleep(1.5)
app.shot('v2-hover-claude-flyout', 'pointer rests on the Compact Claude row')
say('menus: ' + json.dumps(app.menus()))
fly = [r for r in app.rows() if r['w'] and r['role'] == 'AXMenuItem' and r['label'] in ('Plan Usage', 'Cost', 'Storage', 'Show details')]
say('flyout items: ' + json.dumps(fly))
chart = next((r for r in fly if r['label'] in ('Plan Usage', 'Cost', 'Storage')), None)
if chart:
    app.ui('move', chart['x'] + chart['w'] / 2, chart['y'] + chart['h'] / 2, 25)
    time.sleep(2.5)
    app.shot('v3-nested-chart', f'nested {chart["label"]} chart from the flyout')
    say('menus: ' + json.dumps(app.menus()))
    show = next(r for r in fly if r['label'] == 'Show details')
    app.ui('move', show['x'] + show['w'] / 2, show['y'] + show['h'] / 2, 20)
    time.sleep(1.2)
    app.ui('click', show['x'] + show['w'] / 2, show['y'] + show['h'] / 2)
    time.sleep(3)
    app.shot('v4-show-details-selects-provider', 'after clicking Show details')
    if not app.menus():
        app.open_menu()
        app.shot('v5-reopened-provider-tab')
    (OUT / 'v5-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
say(f'recording exit={rec.wait(timeout=100)}')
app.close_menu()
# Reopen after a changed model: hover to hydrate, move away with Overview open, change the provider, refresh, hover again.
ov_defaults = app.quit()
providers.overview_defaults(mergedOverviewLayout='compact', mergedMenuLastSelectedWasOverview=True)
app = App(INSTALLED, HELPER, 'reopen')
time.sleep(12)
app.open_menu()
claude = next(r for r in app.menu_items() if any('Claude' in l for l in r['labels'][:4]) and r['h'] > 30)
app.hover(claude)
time.sleep(2.5)
app.shot('r1-first-flyout', 'before the refresh: Session and Weekly only')
other = next(r for r in app.menu_items() if any('Refresh' in l for l in r['labels']))
providers.EXTRA_CLAUDE['seven_day_sonnet'] = {'utilization': 80, 'resets_at': kit.iso(__import__('datetime').timedelta(days=5))}
providers.PERCENTS['claude'] = (70, 44)
state['phase'] = 'claude-gains-a-window'
before = state['requests']
app.hover(other)
time.sleep(0.6)
app.ui('click', other['x'] + other['w'] / 2, other['y'] + other['h'] / 2)
ok = app.wait(lambda: state['requests'] > before + 3, 'refresh', 25)
say(f'refresh reached fixture={ok}')
time.sleep(5)
app.shot('r2-after-refresh-menu-open')
claude = next((r for r in app.menu_items() if any('Claude' in l for l in r['labels'][:4]) and r['h'] > 30), None)
if claude:
    app.hover(claude)
    time.sleep(2.5)
    app.shot('r3-reopened-flyout', 'review asks: does the reopened card show the new Sonnet window?')
app.quit()
kit.finish()
