#!/usr/bin/env python3
"""Diagnosis only: real clicks on Show details in an instrumented build, keeping the app's lifecycle log."""
import json, shutil, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, check, phase_begin, reached, say
HEAD_APP, _, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.start_fixture(); providers.install(); kit.write_credentials(); kit.write_config(providers.CONFIG)
providers.overview_defaults(mergedOverviewLayout='compact', mergedOverviewSelectedProviders=['claude', 'kimi', 'zai'],
                            mergedOverviewSelectionEditedActiveProviders=providers.OVERVIEW_IDS)
LOG = Path('/tmp/cbdiag.log')
def mark(t):
    with LOG.open('a') as f: f.write(f'{time.time()} ===== {t}\n')
phase_begin('diag')
app = App(INSTALLED, HELPER, 'diag')
app.wait(lambda: reached('diag', 'api.anthropic.com'), 'launch refresh', 40)
time.sleep(12)
def row():
    rows = [r for r in app.menu_items() if r['y'] >= 112]
    return next((r for r in rows if any(p in l for l in r['labels'][:12] for p in ('Claude', '65%'))), None)
def points():
    fly = min(app.menus(), key=lambda w: w['x'])
    return fly['x'] + fly['w'] / 2, fly['y'] + fly['h'] - 17
def overview():
    if not app.menus(): app.open_menu()
    tab = next(r for r in app.rows() if r['role'] == 'AXButton' and r['label'] == 'Overview' and r['w'])
    app.ui('click', tab['x'] + tab['w'] / 2, tab['y'] + tab['h'] / 2); time.sleep(1.5)
for n in range(3):
    mark(f'attempt {n}: open'); app.open_menu(); time.sleep(.5)
    if n: overview()
    mark(f'attempt {n}: hover'); app.hover(row()); app.wait(lambda: len(app.menus()) > 1, 'flyout', 6); time.sleep(1.2)
    x, y = points()
    mark(f'attempt {n}: move to show details'); app.ui('move', x, y, 20); time.sleep(1.0)
    app.shot(f'd{n}-highlighted')
    mark(f'attempt {n}: click'); app.ui('click', x, y); time.sleep(3)
    mark(f'attempt {n}: after click menus={app.menus()}')
    app.shot(f'd{n}-after'); kit.defaults_snapshot(f'd{n}')
    if app.menus(): app.close_menu(); time.sleep(.8)
app.quit()
if LOG.exists(): shutil.copy(LOG, OUT / 'cbdiag.log')
kit.finish()
