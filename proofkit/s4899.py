#!/usr/bin/env python3
"""#4899: in-place upgrade from the genuine v0.83.0 release, then Compact rows through the installed app."""
import json, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, say, state, find, record

HEAD_APP, V083_APP, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
kit.start_fixture()
providers.install()
kit.write_credentials()
kit.write_config(providers.CONFIG)
say('trusted(ax,screen,post)=' + subprocess.run([HELPER, 'trusted'], capture_output=True, text=True).stdout.strip())


def plist(key):
    return subprocess.run(['/usr/libexec/PlistBuddy', '-c', f'Print :{key}', str(INSTALLED / 'Contents/Info.plist')],
                          capture_output=True, text=True).stdout.strip()


def install(src):
    subprocess.run(['rm', '-rf', str(INSTALLED)], check=True)
    subprocess.run(['ditto', src, str(INSTALLED)], check=True)
    sha = subprocess.run(['shasum', '-a', '256', str(INSTALLED / 'Contents/MacOS/CodexBar')], capture_output=True, text=True).stdout.split()[0]
    say(f'installed version={plist("CFBundleShortVersionString")} bundle={plist("CFBundleIdentifier")} sha256={sha}')
    return plist('CFBundleIdentifier')


def observe(name, wait=8):
    app = App(INSTALLED, HELPER, name)
    before = state['requests']
    ok = app.wait(lambda: state['requests'] > before, 'first refresh', 40)
    time.sleep(wait)
    app.open_menu()
    app.shot(name, f'refresh_seen={ok}')
    (OUT / f'{name}-labels.json').write_text(json.dumps([r['label'] for r in app.rows() if r['label']], indent=1))
    return app


selection = ['claude', 'kimi', 'zai']
six = ['codex', 'claude', 'commandcode', 'kimi', 'zai', 'openrouter']
active = providers.OVERVIEW_IDS
CASES = {
    'a-saved-detailed-subset': {'mergedOverviewLayout': 'detailed', 'mergedOverviewSelectedProviders': selection,
                                'mergedOverviewSelectionEditedActiveProviders': active},
    'b-saved-compact-six-of-eight': {'mergedOverviewLayout': 'compact', 'mergedOverviewSelectedProviders': six,
                                     'mergedOverviewSelectionEditedActiveProviders': active},
    'c-never-changed-defaults': {},
}
results = {}
for case, prefs in CASES.items():
    say(f'=== case {case}')
    bid = install(V083_APP)
    kit.BUNDLE = bid
    kit.defaults_reset()
    providers.overview_defaults(**prefs)
    before = kit.defaults_snapshot(f'{case}-seeded')
    app = observe(f'{case}-1-v083')
    app.quit()
    stored_v083 = kit.defaults_snapshot(f'{case}-2-after-v083-quit')
    assert install(HEAD_APP) == bid, 'head must use the release defaults domain for this to be an upgrade'
    app = observe(f'{case}-3-head')
    app.quit()
    stored_head = kit.defaults_snapshot(f'{case}-4-after-head-quit')
    keys = ('mergedOverviewLayout', 'mergedOverviewSelectedProviders', 'mergedOverviewSelectionEditedActiveProviders')
    results[case] = {'seeded': {k: before.get(k) for k in keys}, 'after_v083': {k: stored_v083.get(k) for k in keys},
                     'after_head': {k: stored_head.get(k) for k in keys},
                     'unchanged': all(stored_v083.get(k) == stored_head.get(k) for k in keys)}
(OUT / 'upgrade-results.json').write_text(json.dumps(results, indent=2, default=str))
say(json.dumps(results, default=str))

say('=== interaction stage: head app, never-changed defaults, real pointer and keyboard')
app = App(INSTALLED, HELPER, 'interact')
app.wait(lambda: state['requests'] > 3, 'launch refresh', 40)
time.sleep(10)


def labels_now():
    return [r['labels'][:4] for r in app.menu_items() if r['labels']]


rec = record('interaction', 110)
time.sleep(2)
app.open_menu()
app.shot('i1-compact-rows', 'urgency sorted, default never changed')
(OUT / 'i1-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
claude = app.row('65% Usage remaining')
assert claude, 'no row for Claude at 65% left'
app.hover(claude)
time.sleep(2.5)
app.shot('i2-hover-opens-usage-submenu', 'pointer resting on the Claude row')
say(f'menus while hovering: {app.menus()}')
app.click_row(claude)
time.sleep(2.5)
app.shot('i3-pointer-click-opens-provider', 'clicked the Claude row')
(OUT / 'i3-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
ov = find(app.rows(), 'Overview', 'AXButton')
assert ov, 'no Overview tab after activation'
app.ui('click', ov[0]['x'] + ov[0]['w'] / 2, ov[0]['y'] + ov[0]['h'] / 2)
time.sleep(2.5)
app.shot('i4-back-on-overview')
before = state['requests']
providers.PERCENTS['claude'] = (97, 60)
providers.PERCENTS['codex'] = (20, 10)
state['kimi_expired'] = True
state['phase'] = 'refreshed'
say('fixture changed: claude 3% left, codex 80% left, kimi 401; clicking Refresh')
r = app.row('Refresh')
assert r, 'no Refresh row'
app.click_row(r)
ok = app.wait(lambda: state['requests'] > before + 3, 'refresh to reach fixture', 25)
say(f'refresh reached fixture={ok} requests +{state["requests"] - before}')
time.sleep(6)
app.shot('i5-menu-after-refresh-still-open')
app.close_menu()
time.sleep(1)
app.open_menu()
app.shot('i6-reopened-after-normal-refresh', 'resorted; kimi moved to attention row')
(OUT / 'i6-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
att = app.row('Kimi Code')
kimi_rows = [x for x in app.menu_items() if any('Kimi Code' in l and 'Moonshot' not in l for l in x['labels'])]
say(f'Kimi row: {kimi_rows[:1]}')
if kimi_rows:
    # Reach the row with the keyboard, as the review asks, then press Return with no pointer on it.
    app.hover(kimi_rows[0])
    time.sleep(1.2)
    app.shot('i7-hover-single-attention-row')
    app.ui('return')
    time.sleep(2.5)
    app.shot('i8-return-on-single-attention-row', 'keyboard activation of the single attention row')
    say('menus after Return: ' + str(app.menus()))
    (OUT / 'i8-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
    app.close_menu()
    time.sleep(1)
    app.open_menu()
    app.shot('i9-reopen-after-return', 'which tab does the app show after Return')
    (OUT / 'i9-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
    ov = find(app.rows(), 'Overview', 'AXButton')
    app.ui('click', ov[0]['x'] + ov[0]['w'] / 2, ov[0]['y'] + ov[0]['h'] / 2)
    time.sleep(2)
    rows = [x for x in app.menu_items() if any('Kimi Code' in l and 'Moonshot' not in l for l in x['labels'])]
    if rows:
        app.click_row(rows[0])
        time.sleep(2.5)
        app.shot('i10-pointer-click-attention-row')
        (OUT / 'i10-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
say(f'recording exit={rec.wait(timeout=130)}')
app.quit()
kit.defaults_snapshot('interact-after-quit')

say('=== all selected providers failing on a fresh launch')
state['all_fail'] = True
subprocess.run(['rm', '-rf', str(kit.HOME / 'Library/Caches/CodexBar'), str(kit.HOME / 'Library/Application Support/CodexBar')])
app = App(INSTALLED, HELPER, 'allfail')
time.sleep(25)
app.open_menu()
app.shot('e1-all-providers-failed', 'advertised attention rows when nothing has cached usage')
(OUT / 'e1-labels.json').write_text(json.dumps([r['label'] for r in app.rows() if r['label']], indent=1))
app.quit()
kit.finish()
