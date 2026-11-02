#!/usr/bin/env python3
"""#4899: in-place upgrade from the genuine v0.83.0 release, then Compact rows through the installed app."""
import json, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, check, phase_begin, reached, say, state, find, record

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
    phase_begin(f'{case}-head')
    kit.verify_installed(INSTALLED, f'{case}')
    app = observe(f'{case}-3-head')
    check(f'{case}: head app itself reached the fixture', reached(f'{case}-head', 'chatgpt.com') or reached(f'{case}-head', 'api.anthropic.com'))
    rows = [r for r in app.menu_items() if r['y'] >= 123]
    text = ' | '.join(l for r in rows for l in r['labels'])
    height = app.menus()[0]['h']
    if case.startswith('a-'):
        check('explicit Detailed + subset: head renders Detailed cards of only the saved three',
              'LEVEL_INTERMEDIATE' in text and '5-hour 30% left' in text and 'Moonshot' not in text and 'DeepSeek' not in text and '8% Usage remaining' not in text, text[:300])
    elif case.startswith('b-'):
        check('explicit Compact + six of eight: head renders one-line rows of only the saved six',
              'Usage remaining, 30%' in text and 'Moonshot' not in text and 'DeepSeek' not in text and 'Left' in text, text[:300])
    else:
        check('unset layout: effective default CHANGES to Compact, showing all eight rows (intentional; owner decision open)',
              'Moonshot' in text and 'DeepSeek' in text and 'Left' in text and height < 500, f'height={height} {text[:240]}')
    app.quit()
    stored_head = kit.defaults_snapshot(f'{case}-4-after-head-quit')
    keys = ('mergedOverviewLayout', 'mergedOverviewSelectedProviders', 'mergedOverviewSelectionEditedActiveProviders')
    check(f'{case}: raw saved preferences unchanged across the upgrade',
          all(stored_v083.get(k) == stored_head.get(k) and before.get(k) == stored_head.get(k) for k in keys),
          {k: stored_head.get(k) for k in keys})
    results[case] = {'seeded': {k: before.get(k) for k in keys}, 'after_v083': {k: stored_v083.get(k) for k in keys},
                     'after_head': {k: stored_head.get(k) for k in keys},
                     'unchanged': all(stored_v083.get(k) == stored_head.get(k) for k in keys)}
(OUT / 'upgrade-results.json').write_text(json.dumps(results, indent=2, default=str))
say(json.dumps(results, default=str))

say('=== interaction stage: head app, never-changed defaults, real pointer and keyboard')
phase_begin('interact')
app = App(INSTALLED, HELPER, 'interact')
app.wait(lambda: state['requests'] > 3, 'launch refresh', 40)
time.sleep(10)


def labels_now():
    return [r['labels'][:4] for r in app.menu_items() if r['labels']]


rec = record('interaction', 70)
time.sleep(2)
app.open_menu()
app.shot('i1-compact-rows', 'urgency sorted, default never changed')
(OUT / 'i1-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
check('interaction launch reached fixture', reached('interact', 'api.anthropic.com'))
claude = app.row('65% Usage remaining')
assert claude, 'no row for Claude at 65% left'
app.hover(claude)
time.sleep(2.5)
app.shot('i2-hover-opens-usage-submenu', 'pointer resting on the Claude row')
check('hovering a Compact row opens its usage submenu', len(app.menus()) >= 2, app.menus())
app.click_row(claude)
time.sleep(2.5)
app.shot('i3-pointer-click-opens-provider', 'clicked the Claude row')
i3 = app.menu_items()
(OUT / 'i3-rows.json').write_text(json.dumps(i3, indent=1))
i3text = ' | '.join(l for r in i3 if r['y'] >= 123 for l in r['labels'])
check('clicking the Claude row selects the Claude provider tab', 'claude@example.test' in i3text and 'Usage Dashboard' in i3text, i3text[:240])
ov = find(app.rows(), 'Overview', 'AXButton')
assert ov, 'no Overview tab after activation'
app.ui('click', ov[0]['x'] + ov[0]['w'] / 2, ov[0]['y'] + ov[0]['h'] / 2)
time.sleep(2.5)
app.shot('i4-back-on-overview')
# Usage only rises within one reset window, as in reality; plan history keeps the window's high mark.
providers.PERCENTS['claude'] = (97, 60)
providers.PERCENTS['zai'] = (75, 5)
phase_begin('refreshed')
say('fixture changed: claude 3% left, z.ai 25% left; clicking Refresh')
r = app.row('Refresh')
assert r, 'no Refresh row'
app.click_row(r)
ok = app.wait(lambda: reached('refreshed', 'api.anthropic.com') and reached('refreshed', 'chatgpt.com'), 'refresh to reach both providers', 25)
check('normal refresh requested new data from the head app', ok, f"anthropic={len(reached('refreshed', 'api.anthropic.com'))} chatgpt={len(reached('refreshed', 'chatgpt.com'))}")
time.sleep(6)
app.shot('i5-menu-after-refresh-still-open')
app.close_menu()
time.sleep(1)
app.open_menu()
app.shot('i6-reopened-after-normal-refresh', 'resorted from fresh values')
i6 = app.menu_items()
(OUT / 'i6-rows.json').write_text(json.dumps(i6, indent=1))
c3, c8 = app.row('3% Usage remaining'), app.row('8% Usage remaining')
check('refresh re-sorted: Claude, now 3% left, moved above Codex at 8% left', c3 and c8 and c3['y'] < c8['y'], f'{c3 and c3["y"]} {c8 and c8["y"]}')
z25 = next((r for r in i6 if any(l.startswith('z.ai / GLM,') and '25%' in l for l in r['labels'])), None)
check('refresh rendered the new z.ai value, 25% left', z25, z25 and z25['labels'][:1])


def provider_text():
    return ' | '.join(l for r in app.menu_items() if r['y'] >= 123 for l in r['labels'])


def to_overview():
    if not app.menus():
        app.open_menu()
    ov = find(app.rows(), 'Overview', 'AXButton')
    app.ui('click', ov[0]['x'] + ov[0]['w'] / 2, ov[0]['y'] + ov[0]['h'] / 2)
    time.sleep(1.5)


z = app.row('z.ai / GLM,')
assert z, 'no z.ai row'
app.hover(z)
time.sleep(0.8)
# The keyboard moves the highlight off and back, so Return acts on a keyboard-selected row, then on the same row.
app.ui('down')
time.sleep(0.2)
app.ui('up')
time.sleep(0.6)
app.shot('i7-zai-row-keyboard-selected', 'highlight moved by arrow keys; no click')
app.ui('return')
time.sleep(2.5)
closed = not app.menus()
if closed:
    app.open_menu()
app.shot('i8-after-return-on-compact-row', f'menu closed by Return={closed}')
kit.defaults_snapshot('nav-after-return-plain')
check('Return on a plain Compact row selects its provider tab', 'Token quota' in provider_text() and 'Usage Dashboard' in provider_text(), provider_text()[:240])
to_overview()
z = app.row('z.ai / GLM,')
pressed = app.ui('axpress', app.proc.pid, z['y'])
time.sleep(2.5)
closed = not app.menus()
if closed:
    app.open_menu()
app.shot('i9-after-axpress-on-compact-row', f'AXPress result={pressed} closed={closed}')
kit.defaults_snapshot('nav-after-axpress-plain')
check('accessibility press on a plain Compact row selects its provider tab', 'Token quota' in provider_text(), f'{pressed} {provider_text()[:200]}')
to_overview()
# Harness control: if Return also fails on a standard item, a keyboard failure above says nothing about the product.
quit_row = app.row('Settings')
app.hover(quit_row)
time.sleep(0.6)
app.ui('return')
control = app.wait(lambda: any(w['layer'] == 0 and w['w'] > 300 for w in app.windows()), 'Settings window from Return', 6)
app.shot('i10-control-return-on-settings', f'control opened Settings={control}')
check('harness control: Return activates a standard highlighted menu item', control, app.windows())
say(f'recording exit={rec.wait(timeout=130)}')
app.quit()
kit.defaults_snapshot('interact-after-quit')


def cold(name, config, wait=25):
    """A fresh launch with no retained usage, so an error is not gated behind a cached snapshot."""
    subprocess.run(['rm', '-rf', str(kit.HOME / 'Library/Caches/CodexBar'), str(kit.HOME / 'Library/Application Support/CodexBar'),
                    str(kit.HOME / 'Library/Application Support/com.steipete.codexbar')])
    kit.write_config(config)
    kit.defaults_reset()
    providers.overview_defaults()
    a = App(INSTALLED, HELPER, name)
    time.sleep(wait)
    return a


say('=== exactly one provider failing, cold launch')
providers.PERCENTS['claude'] = (35, 22)
providers.PERCENTS['zai'] = (70, 5)
state['kimi_expired'] = True
phase_begin('kimi-expired')
app = cold('attention', providers.CONFIG)
rec = record('single-attention-row', 45)
time.sleep(2)
app.open_menu()
app.shot('a1-single-attention-row', 'expired Kimi key')
rows = app.menu_items()
(OUT / 'a1-rows.json').write_text(json.dumps(rows, indent=1))
att = next((r for r in rows if r['y'] > 123 and any('Kimi Code' in l for l in r['labels'])), None)
check('one failing provider renders one attention row', att, att)
check('the single attention row is wired for keyboard and accessibility activation', att and att['action'], att)
if att:
    app.hover(att)
    time.sleep(0.8)
    app.ui('down')
    time.sleep(0.2)
    app.ui('up')
    time.sleep(0.6)
    app.shot('a2-attention-keyboard-selected', 'highlight moved by arrow keys; no click')
    app.ui('return')
    time.sleep(2.5)
    closed = not app.menus()
    if closed:
        app.open_menu()
    app.shot('a3-after-return-on-attention', f'menu closed by Return={closed}')
    a3 = ' | '.join(l for r in app.menu_items() if r['y'] >= 123 for l in r['labels'])
    check('Return on the single attention row selects Kimi Code', 'Copy error' in a3 or 'Usage Dashboard' in a3, a3[:240])
    tabs = find(app.rows(), 'Overview', 'AXButton')
    app.ui('click', tabs[0]['x'] + tabs[0]['w'] / 2, tabs[0]['y'] + tabs[0]['h'] / 2)
    time.sleep(2)
    att = next((r for r in app.menu_items() if r['y'] > 123 and any('Kimi Code' in l for l in r['labels'])), None)
    if att:
        pressed = app.ui('axpress', app.proc.pid, att['y'])
        time.sleep(2.5)
        closed = not app.menus()
        if closed:
            app.open_menu()
        app.shot('a4-after-axpress-on-attention', f'AXPress result={pressed} closed={closed}')
        a4 = ' | '.join(l for r in app.menu_items() if r['y'] >= 123 for l in r['labels'])
        check('accessibility press on the single attention row selects Kimi Code', 'Copy error' in a4 or 'Usage Dashboard' in a4, f'{pressed} {a4[:200]}')
        tabs = find(app.rows(), 'Overview', 'AXButton')
        app.ui('click', tabs[0]['x'] + tabs[0]['w'] / 2, tabs[0]['y'] + tabs[0]['h'] / 2)
        time.sleep(2)
    att = next((r for r in app.menu_items() if r['y'] > 123 and any('Kimi Code' in l for l in r['labels'])), None)
    if att:
        app.click_row(att)
        time.sleep(2.5)
        app.shot('a5-pointer-click-attention-row', 'pointer activation')
        a5 = app.menu_items()
        (OUT / 'a5-rows.json').write_text(json.dumps(a5, indent=1))
        a5text = ' | '.join(l for r in a5 if r['y'] >= 123 for l in r['labels'])
        check('pointer click on the single attention row selects Kimi Code', 'Copy error' in a5text, a5text[:240])
say(f'recording exit={rec.wait(timeout=60)}')
app.quit()

say('=== every selected provider failing, cold launch')
state['all_fail'] = True
phase_begin('all-fail')
app = cold('allfail', [p for p in providers.CONFIG if p['id'] != 'deepseek'])
check('all-failed launch asked the fixture and was refused', reached('all-fail', 'api.anthropic.com', 401))
app.open_menu()
app.shot('e1-all-providers-failed', 'advertised attention rows when nothing has cached usage')
e1 = app.menu_items()
(OUT / 'e1-rows.json').write_text(json.dumps(e1, indent=1))
e1text = ' | '.join(l for r in e1 if r['y'] >= 112 for l in r['labels'])
check('when every provider failed, the attention row still names them', 'No overview data available' not in e1text and 'Kimi Code' in e1text, e1text[:240])
app.quit()
kit.finish()
