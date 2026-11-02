#!/usr/bin/env python3
"""#4899 attention rows, same driver for both builds: all selected providers failed, and one failed row by keyboard, AX and pointer."""
import json, os, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, check, finding, phase_begin, reached, say, state, find

HEAD_APP, HELPER = sys.argv[1], sys.argv[3]
FIXED = os.environ['PROOF_ROLE'] == 'after'
INSTALLED = Path('/Applications/CodexBar.app')
kit.start_fixture()
providers.install()
kit.write_credentials()
subprocess.run(['rm', '-rf', str(INSTALLED)], check=True)
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.verify_installed(INSTALLED, os.environ['PROOF_ROLE'])
say('role=' + os.environ['PROOF_ROLE'] + ' trusted(ax,screen,post)=' + subprocess.run([HELPER, 'trusted'], capture_output=True, text=True).stdout.strip())
FAILING_CONFIG = [p for p in providers.CONFIG if p['id'] != 'deepseek']


def expect(name, ok, detail=''):
    """The fixed build must pass; on the unfixed build the same oracle is a measured defect."""
    return (check if FIXED else finding)(name, ok, detail)


def cold(name, config, wait=25, **defaults):
    subprocess.run(['rm', '-rf', str(kit.HOME / 'Library/Caches/CodexBar'), str(kit.HOME / 'Library/Application Support/CodexBar'),
                    str(kit.HOME / 'Library/Application Support/com.steipete.codexbar')])
    kit.write_config(config)
    kit.defaults_reset()
    providers.overview_defaults(**defaults)
    a = App(INSTALLED, HELPER, name)
    time.sleep(wait)
    return a


def text(app, top=112):
    return ' | '.join(l for r in app.menu_items() if r['y'] >= top for l in r['labels'])


def attention(app, name='Kimi Code'):
    return next((r for r in app.menu_items() if r['y'] > 112 and any(name in l for l in r['labels'])), None)


def back_to_overview(app):
    if not app.menus():
        app.open_menu()
    tabs = find(app.rows(), 'Overview', 'AXButton')
    app.ui('click', tabs[0]['x'] + tabs[0]['w'] / 2, tabs[0]['y'] + tabs[0]['h'] / 2)
    time.sleep(2)


def selected_after(app, shot, note):
    """Reopen when activation closed the menu, then read both the rendered tab and the saved selection."""
    closed = not app.menus()
    if closed:
        app.open_menu()
    app.shot(shot, f'{note} closed={closed}')
    saved = kit.defaults_snapshot(shot)
    body = text(app, 123)
    return saved, body


def on_kimi(saved, body):
    return saved.get('selectedMenuProvider') == 'kimi' and saved.get('mergedMenuLastSelectedWasOverview') is False and 'Copy error' in body


say('=== Detailed, every selected provider failed: the empty state must not change')
state['all_fail'] = True
phase_begin('detailed-all-fail')
app = cold('detailed', FAILING_CONFIG, mergedOverviewLayout='detailed')
check('all-failed launch asked the fixture and was refused', reached('detailed-all-fail', 'api.anthropic.com', 401))
app.open_menu()
app.shot('d1-detailed-all-failed', 'Detailed layout, nothing cached')
check('Detailed keeps "No overview data available."', 'No overview data available' in text(app), text(app)[:240])
app.quit()

say('=== Compact, every selected provider failed')
phase_begin('compact-all-fail')
app = cold('allfail', FAILING_CONFIG)
check('compact all-failed launch asked the fixture and was refused', reached('compact-all-fail', 'api.anthropic.com', 401))
app.open_menu()
app.shot('e1-compact-all-failed', 'Compact layout, nothing cached')
e1 = app.menu_items()
(OUT / 'e1-rows.json').write_text(json.dumps(e1, indent=1))
e1text = text(app)
expect('all failed: Compact names the failed providers instead of the empty state',
       'No overview data available' not in e1text and 'Kimi Code' in e1text and 'Claude' in e1text, e1text[:300])
row = attention(app)
if row:
    app.hover(row)
    time.sleep(2.5)
    app.shot('e2-all-failed-flyout', 'pointer resting on the attention row')
    flyouts = app.menus()
    check('all failed: the attention row opens a flyout naming each provider', len(flyouts) >= 2, flyouts)
    (OUT / 'e2-ax.json').write_text(app.ui('tree', app.proc.pid, 'AXExtrasMenuBar'))
    if len(flyouts) >= 2:
        fly = flyouts[0]  # Sorted by x: the flyout opens left of the root menu.
        app.ui('move', fly['x'] + fly['w'] / 2, fly['y'] + 16, 15)
        time.sleep(0.5)
        app.ui('click', fly['x'] + fly['w'] / 2, fly['y'] + 16)
        time.sleep(2.5)
        closed = not app.menus()
        if closed:
            app.open_menu()
        app.shot('e3-after-flyout-child-click', f'clicked the first flyout row closed={closed}')
        saved = kit.defaults_snapshot('e3-after-flyout-child')
        check('all failed: a flyout row selects its provider', saved.get('mergedMenuLastSelectedWasOverview') is False and saved.get('selectedMenuProvider') == 'codex', saved)
app.quit()

say('=== Compact, the one selected provider failed, another healthy provider is not selected')
state['all_fail'] = False
state['kimi_expired'] = True
phase_begin('only-selected-failed')
app = cold('onlyselected', providers.CONFIG, mergedOverviewSelectedProviders=['kimi'], mergedOverviewSelectionEditedActiveProviders=providers.OVERVIEW_IDS)
app.open_menu()
app.shot('s1-only-selected-failed', 'selection is Kimi only')
s1 = text(app)
expect('the only selected provider failing shows its row, not the empty state', 'No overview data available' not in s1 and 'Kimi Code' in s1, s1[:240])
app.quit()

say('=== Compact, exactly one provider failing among healthy rows')
phase_begin('kimi-expired')
app = cold('attention', providers.CONFIG)
app.open_menu()
app.shot('a1-single-attention-row', 'expired Kimi key')
(OUT / 'a1-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
att = attention(app)
check('one failing provider renders one attention row', att, att)
app.hover(att)
time.sleep(0.8)
app.ui('down')
time.sleep(0.2)
app.ui('up')
time.sleep(0.6)
app.shot('a2-attention-keyboard-selected', 'highlight moved by arrow keys; no click')
app.ui('return')
time.sleep(2.5)
saved, body = selected_after(app, 'a3-after-return-on-attention', 'Return')
expect('Return on the single attention row selects Kimi Code', on_kimi(saved, body), f'{saved} {body[:200]}')
back_to_overview(app)
att = attention(app)
pressed = app.ui('axpress', app.proc.pid, att['y'])
time.sleep(2.5)
saved, body = selected_after(app, 'a4-after-axpress-on-attention', f'AXPress result={pressed}')
expect('accessibility press on the single attention row selects Kimi Code', on_kimi(saved, body), f'{pressed} {saved} {body[:200]}')
back_to_overview(app)
att = attention(app)
app.click_row(att)
time.sleep(2.5)
saved, body = selected_after(app, 'a5-pointer-click-attention-row', 'pointer')
check('pointer click on the single attention row still selects Kimi Code', on_kimi(saved, body), f'{saved} {body[:200]}')
back_to_overview(app)
deepseek = next((r for r in app.menu_items() if r['y'] > 123 and any(l.startswith('DeepSeek') for l in r['labels'])), None)
check('a plain row with no flyout is on screen for the keyboard check', deepseek, deepseek)
app.hover(deepseek)
time.sleep(0.8)
app.ui('return')
time.sleep(2.5)
saved = kit.defaults_snapshot('a5b-after-return-on-plain-row')
app.shot('a5b-after-return-on-plain-row', 'Return on the DeepSeek row')
expect('Return on a plain row with no flyout selects its provider', saved.get('selectedMenuProvider') == 'deepseek' and saved.get('mergedMenuLastSelectedWasOverview') is False, saved)
back_to_overview(app)
# Harness control: Return must work on a standard item in this same session, or a keyboard miss above says nothing.
settings = app.row('Settings')
app.hover(settings)
time.sleep(0.6)
app.ui('return')
control = app.wait(lambda: any(w['layer'] == 0 and w['w'] > 300 for w in app.windows()), 'Settings window from Return', 6)
app.shot('a6-control-return-on-settings', f'control opened Settings={control}')
check('harness control: Return activates a standard highlighted menu item', control, app.windows())
app.quit()
kit.finish()
