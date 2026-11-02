#!/usr/bin/env python3
"""#4902: Compact hover flyout, nested chart access, provider-tab selection, and a reopen after a changed model."""
import json, subprocess, sys, time
from datetime import timedelta
from pathlib import Path
import kit, providers
from kit import App, OUT, check, phase_begin, reached, say, state, record
HEAD_APP, _, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.verify_installed(INSTALLED)
kit.start_fixture()
providers.install()
kit.write_credentials()
kit.write_config(providers.CONFIG)
providers.overview_defaults(mergedOverviewLayout='compact')
phase_begin('flyout')
app = App(INSTALLED, HELPER, 'flyout')
app.wait(lambda: reached('flyout', 'api.anthropic.com'), 'launch refresh', 40)
time.sleep(12)
rec = record('flyout', 70)
time.sleep(2)


def provider_row(name):
    """The Compact row for this provider, selected by its identity and content rather than by a height."""
    rows = [r for r in app.menu_items() if r['y'] >= 112]
    # Compact rows name the provider, or for hosted rows expose its account or known fixture value.
    probes = {'Claude': ('Claude', 'claude@example.test', '65%', '65% left', '30% left', 'Session 30%')}[name]
    return next((r for r in rows if any(p in l for l in r['labels'][:12] for p in probes)), None)


def all_labels():
    return [r['label'] for r in app.rows() if r['label']]


app.open_menu()
app.shot('v1-compact-open')
(OUT / 'v1-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
claude = provider_row('Claude')
check('Compact Overview has a Claude row', claude, claude and claude['labels'][:6])
app.hover(claude)
opened = app.wait(lambda: len(app.menus()) > 1, 'flyout window', 6)
check('hovering the Compact row opens a flyout window', opened, app.menus())
time.sleep(1.5)
app.shot('v2-hover-claude-flyout', 'pointer rests on the Compact Claude row')
fly = [r for r in app.rows() if r['w'] and r['role'] == 'AXMenuItem' and r['label'] in ('Plan Usage', 'Cost', 'Storage', 'Show details')]
(OUT / 'v2-flyout.json').write_text(json.dumps(app.rows(), indent=1))
check('the flyout hosts the full provider card', 'Session 65% left' in all_labels() and 'Weekly 78% left' in all_labels(), [l for l in all_labels() if 'left' in l][:8])
chart = next((r for r in fly if r['label'] in ('Plan Usage', 'Cost', 'Storage')), None)
show = next((r for r in fly if r['label'] == 'Show details'), None)
check('the flyout offers a nested chart and Show details', chart and show, fly)
if chart:
    before = len(app.menus())
    app.ui('move', chart['x'] + chart['w'] / 2, chart['y'] + chart['h'] / 2, 25)
    nested = app.wait(lambda: len(app.menus()) > before, 'nested chart window', 6)
    check('the nested chart opens from the flyout', nested, app.menus())
    time.sleep(1.5)
    app.shot('v3-nested-chart', f'nested {chart["label"]} chart from the flyout')
if show:
    app.ui('move', show['x'] + show['w'] / 2, show['y'] + show['h'] / 2, 20)
    time.sleep(1.2)
    app.ui('click', show['x'] + show['w'] / 2, show['y'] + show['h'] / 2)
    time.sleep(3)
    app.shot('v4-show-details-selects-provider', 'after clicking Show details')
    if not app.menus():
        app.open_menu()
        app.shot('v5-reopened-provider-tab')
    v5 = app.menu_items()
    (OUT / 'v5-rows.json').write_text(json.dumps(v5, indent=1))
    text = ' | '.join(l for r in v5 if r['y'] >= 112 for l in r['labels'])
    check('Show details lands on the Claude provider tab', 'claude@example.test' in text and 'Usage Dashboard' in text and 'Kimi' not in text, text[:240])
say(f'recording exit={rec.wait(timeout=100)}')
app.quit()

# Reopen after a changed model: hydrate the flyout, move away with Overview open, change the provider, refresh, hover again.
kit.defaults_write('mergedMenuLastSelectedWasOverview', True)
phase_begin('before-refresh')
app = App(INSTALLED, HELPER, 'reopen')
app.wait(lambda: reached('before-refresh', 'api.anthropic.com'), 'launch refresh', 40)
time.sleep(12)
rec = record('flyout-reopen', 45)
time.sleep(2)
app.open_menu()
claude = provider_row('Claude')
app.hover(claude)
check('first flyout opened before the refresh', app.wait(lambda: len(app.menus()) > 1, 'flyout', 6), app.menus())
time.sleep(1.5)
app.shot('r1-first-flyout', 'before the refresh: Session and Weekly only')
first = all_labels()
check('first flyout shows no Sonnet window yet', not any('Sonnet' in l for l in first), [l for l in first if 'left' in l][:8])
providers.EXTRA_CLAUDE['seven_day_sonnet'] = {'utilization': 80, 'resets_at': kit.iso(timedelta(days=5))}
providers.PERCENTS['claude'] = (70, 44)
phase_begin('claude-gains-a-window')
refresh = next(r for r in app.menu_items() if any('Refresh' in l for l in r['labels']))
app.hover(refresh)
time.sleep(0.6)
app.ui('click', refresh['x'] + refresh['w'] / 2, refresh['y'] + refresh['h'] / 2)
ok = app.wait(lambda: reached('claude-gains-a-window', 'api.anthropic.com'), 'refresh', 25)
check('the refresh reached the provider with Overview open', ok, len(reached('claude-gains-a-window', 'api.anthropic.com')))
time.sleep(5)
app.shot('r2-after-refresh-menu-open')
claude = provider_row('Claude')
check('Claude row is still present after the refresh', claude)
if claude:
    app.hover(claude)
    check('flyout reopens after the refresh', app.wait(lambda: len(app.menus()) > 1, 'flyout', 6), app.menus())
    time.sleep(2)
    app.shot('r3-reopened-flyout', 'review asks: does the reopened card show the new values and Sonnet window?')
    (OUT / 'r3-flyout.json').write_text(json.dumps(app.rows(), indent=1))
    later = all_labels()
    check('the reopened flyout renders the current card', any('Session 30% left' in l for l in later) and any('Sonnet' in l for l in later),
          [l for l in later if 'left' in l][:8])
say(f'recording exit={rec.wait(timeout=60)}')
app.quit()
kit.finish()
