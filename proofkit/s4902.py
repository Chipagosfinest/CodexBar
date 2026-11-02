#!/usr/bin/env python3
"""#4902: Compact hover flyout, nested chart access, provider-tab selection, and a reopen after a changed model."""
import json, subprocess, sys, time
from datetime import timedelta
from pathlib import Path
import kit, providers
from kit import App, OUT, check, finding, phase_begin, reached, say, state, record
HEAD_APP, _, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.verify_installed(INSTALLED)
kit.start_fixture()
providers.install()
kit.write_credentials()
kit.write_config(providers.CONFIG)
# Three saved providers keep the footer on this 1024x768 display.
providers.overview_defaults(mergedOverviewLayout='compact', mergedOverviewSelectedProviders=['claude', 'kimi', 'zai'],
                            mergedOverviewSelectionEditedActiveProviders=providers.OVERVIEW_IDS)
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


def visible_labels():
    """Only nodes with a real frame. Every row's unopened flyout also sits in the tree, at zero size."""
    return [r['label'] for r in app.rows() if r['label'] and r['w']]


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
(OUT / 'v2-flyout.json').write_text(json.dumps(app.rows(), indent=1))
labels = visible_labels()
fly = min(app.menus(), key=lambda w: w['x'])
check('the flyout hosts the full provider card', fly['h'] > 150 and 'Session 65% left' in labels and 'Weekly 78% left' in labels and 'Plan Usage' in labels and 'Show details' in labels,
      {'flyout': fly, 'labels': [l for l in labels if 'left' in l or l in ('Plan Usage', 'Show details')][:10]})


def flyout_points():
    """Accessibility reports flyout rows at unusable coordinates, so the last two native rows come from the real window."""
    fly = min(app.menus(), key=lambda w: w['x'])
    x = fly['x'] + fly['w'] / 2
    show_y = fly['y'] + fly['h'] - 17
    return x, show_y - 24, show_y


x, chart_y, show_y = flyout_points()
before = len(app.menus())
app.ui('move', x, chart_y, 25)
nested = app.wait(lambda: len(app.menus()) > before, 'nested chart window', 6)
check('the nested chart opens from the flyout', nested, app.menus())
time.sleep(1.5)
app.shot('v3-nested-chart', 'nested Plan Usage chart from the flyout')
app.ui('move', x, show_y, 20)
time.sleep(1.2)
app.shot('v3b-show-details-highlighted')
app.ui('click', x, show_y)
time.sleep(3)
app.shot('v4-show-details-selects-provider', 'after clicking Show details')
closed = not app.menus()
kit.defaults_snapshot('nav-after-show-details')


def on_claude_tab():
    text = ' | '.join(l for r in app.menu_items() if r['y'] >= 112 for l in r['labels'])
    (OUT / 'v5-text.txt').write_text(text)
    return 'Max 5x' in text and 'Usage Dashboard' in text and '5-hour usage' not in text, text[:240]


if not closed:
    app.close_menu()
    time.sleep(0.8)
app.open_menu()
app.shot('v5-reopened-provider-tab', f'closed by the click={closed}')
landed, detail = on_claude_tab()
if not landed:
    # Separate a slow rebuild from a lost selection before calling this a failure.
    app.close_menu()
    time.sleep(2)
    app.open_menu()
    app.shot('v6-second-reopen')
    landed2, detail = on_claude_tab()
    finding('the first reopen after Show details already shows the provider tab', False, 'second reopen landed=' + str(landed2))
    landed = landed2
finding('Show details after visiting the nested chart selects the provider tab', landed, detail)
results_after_chart = landed


def overview_tab():
    if not app.menus():
        app.open_menu()
    tab = next(r for r in app.rows() if r['role'] == 'AXButton' and r['label'] == 'Overview' and r['w'])
    app.ui('click', tab['x'] + tab['w'] / 2, tab['y'] + tab['h'] / 2)
    time.sleep(1.5)


# Direct path, no nested chart first: the same item, reached straight from the row.
overview_tab()
claude = provider_row('Claude')
app.hover(claude)
check('flyout reopens for the direct Show details path', app.wait(lambda: len(app.menus()) > 1, 'flyout', 6), app.menus())
time.sleep(1)
x, chart_y, show_y = flyout_points()
app.ui('move', x, show_y, 20)
time.sleep(1.0)
app.shot('v7-direct-show-details-highlighted')
app.ui('click', x, show_y)
time.sleep(3)
direct_closed = not app.menus()
app.shot('v8-after-direct-show-details', f'closed={direct_closed}')
kit.defaults_snapshot('nav-after-direct-show-details')
if direct_closed:
    app.open_menu()
app.shot('v9-reopened-after-direct-show-details')
direct, detail = on_claude_tab()
finding('Show details reached directly selects the provider tab', direct, detail)
# The row click itself is the other route to the provider tab.
if not direct:
    overview_tab()
claude = provider_row('Claude')
if claude and not direct:
    app.click_row(claude)
    time.sleep(2.5)
    if not app.menus():
        app.open_menu()
    app.shot('v10-row-click-selects-provider', 'pointer click on the Compact row')
    row_click, detail = on_claude_tab()
    check('pointer click on the Compact row selects the Claude provider tab', row_click, detail)
check('provider-tab selection reachable from the flyout (Show details)', results_after_chart or direct, f'after chart={results_after_chart} direct={direct}')
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
first = visible_labels()
fly = min(app.menus(), key=lambda w: w['x'])
check('first flyout shows no Sonnet window yet', not any('Sonnet' in l for l in first), [l for l in first if 'left' in l][:8])
(OUT / 'r1-flyout.json').write_text(json.dumps(app.rows(), indent=1))
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
    later = visible_labels()
    fly2 = min(app.menus(), key=lambda w: w['x'])
    check('the reopened flyout renders the current card: new values, new Sonnet window, taller frame',
          'Session 30% left' in later and 'Sonnet 20% left' in later and fly2['h'] > fly['h'],
          {'before': fly['h'], 'after': fly2['h'], 'labels': [l for l in later if 'left' in l][:10]})
say(f'recording exit={rec.wait(timeout=60)}')
app.quit()
kit.finish()
