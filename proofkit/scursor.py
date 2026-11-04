#!/usr/bin/env python3
"""Packaged-app proof that Cursor's Total quota, outside the semantic lanes, drives the all-providers warning.

Control and proof differ in one fixture value, Total. Auto and API stay put and can never reach the 10% warning line.
"""
import json, subprocess, sys, time
import kit, providers
from kit import App, OUT, check, phase_begin, reached, say, state

HEAD_APP, _V083, HELPER = sys.argv[1:]
SELECT = ['cursor', 'codex']
AUTO, API = 30, 70
kit.start_fixture()
providers.install()
kit.write_credentials(claude=False)
kit.write_config([providers.CURSOR_CONFIG] + [p for p in providers.CONFIG if p['id'] == 'codex'])
providers.PERCENTS['codex'] = (30, 20)  # Tightest remaining 70%, so Codex never warns and the average is exact.
kit.verify_installed(HEAD_APP)


def label(app):
    items = app.items()
    return ' '.join(str(items[0].get(k) or '') for k in ('title', 'desc', 'value')).strip() if items else ''


def launch(name, total):
    providers.PERCENTS['cursor'] = (total, AUTO, API)
    phase_begin(name)
    kit.defaults_reset()
    providers.overview_defaults(refreshFrequency='manual', mergedOverviewSelectedProviders=SELECT,
                                mergedOverviewSelectionEditedActiveProviders=SELECT, mergedOverviewLayout='detailed',
                                unifiedIconSource='allProviders', tokenCostUsageEnabled=False)
    return App(HEAD_APP, HELPER, f'cursor-{name}')


def reached_both(name):
    paths = [e['path'] for e in reached(name, 'cursor.com')]
    return '/api/usage-summary' in paths and bool(reached(name, 'chatgpt.com')), [e for e in state.get('log', []) if e['phase'] == name]


def shot_bar(app, name):
    """The whole display, plus a focused crop of the menu bar around the status item."""
    app.ui('move', 300, 400, 8)  # Keep the pointer off the status item so no frame hides the logo.
    app.shot(name)
    it = app.items()[0]
    (OUT / f'{name}-item.json').write_text(json.dumps(it))
    x, w = max(0, int(it['x']) - 60), int(it['w']) + 120
    subprocess.run(['screencapture', '-x', f'-R{x},0,{w},{int(it["y"] + it["h"])}', str(OUT / f'{name}-focus.png')], check=True)


def menu_labels(app, name):
    rows = [r['label'] for r in app.rows() if r['label']]
    (OUT / f'{name}-menu-labels.json').write_text(json.dumps(rows, indent=2))
    return rows


# Control: Total at 40% used, lanes unchanged. API at 30% left is Cursor's tightest, averaged with Codex's 70%.
subprocess.run([HELPER, 'dark', '0'], capture_output=True, text=True, check=True)
time.sleep(2)
app = launch('control', 40)
ok = app.wait(lambda: 'average 50% left' in label(app) and 'near limit' not in label(app), 'calm total', 100)
check('control: Total 40% used with the same lanes raises no warning', ok, label(app))
check('control: Cursor and Codex reached the fixture', *reached_both('control'))
shot_bar(app, 'control-no-warning')
app.open_menu()
app.shot('control-menu', 'open combined dropdown')
rows = menu_labels(app, 'control')
check('control: dropdown shows Total 60% left and the unchanged lanes',
      {'Total 60% left', 'Cursor 70% left', 'Third Party 30% left'} <= set(rows), rows)
app.quit()

# Proof: only Total moves. Cursor 5% left and Codex 70% left average to 37.5%, displayed as 38%.
for appearance, dark in [('light', False), ('dark', True)]:
    subprocess.run([HELPER, 'dark', '1' if dark else '0'], capture_output=True, text=True, check=True)
    time.sleep(2)
    app = launch(appearance, 95)
    ok = app.wait(lambda: 'Cursor near limit, 5% left' in label(app) and 'average 38% left' in label(app), 'Cursor warning', 100)
    check(f'{appearance}: Cursor Total raises the combined warning at 5% left, average 38%', ok, label(app))
    check(f'{appearance}: Cursor and Codex reached the fixture', *reached_both(appearance))
    shot_bar(app, f'{appearance}-cursor-warning')
    app.open_menu()
    app.shot(f'{appearance}-cursor-menu', 'open combined dropdown')
    rows = menu_labels(app, appearance)
    check(f'{appearance}: dropdown shows Cursor Total 5% left', 'Total 5% left' in rows, rows)
    check(f'{appearance}: dropdown shows the lanes above the warning line',
          {'Cursor 70% left', 'Third Party 30% left'} <= set(rows), rows)
    app.quit()
subprocess.run([HELPER, 'dark', '0'], capture_output=True)

try:
    kit.finish()
finally:
    summary = {'scenario': 'Cursor Total outside semantic lanes', 'product_sha': kit.os.environ['PROOF_SHA'],
               'fixture_used_percent': {'control': {'total': 40, 'auto': AUTO, 'api': API},
                                        'proof': {'total': 95, 'auto': AUTO, 'api': API}},
               'other_provider': {'id': 'codex', 'used_percent': providers.PERCENTS['codex']},
               'combined_icon_source': 'allProviders', 'overview_layout': 'detailed', 'checks': state.get('checks', [])}
    (OUT / 'summary.json').write_text(json.dumps(summary, indent=2))
    say('summary written')
