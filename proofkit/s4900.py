#!/usr/bin/env python3
"""#4900: logo-only switcher names on hover, the More submenu's actions, and overflow navigation, in the installed app."""
import json, subprocess, sys, time, uuid
from pathlib import Path
import kit, providers
from kit import App, OUT, check, phase_begin, reached, say, state, find, record
HEAD_APP, _, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.verify_installed(INSTALLED)
kit.start_fixture(); providers.install(); kit.write_credentials(); kit.write_config(providers.CONFIG)
# Detailed cards overflow this 1024x768 display, which would hide the footer under test. A saved Compact layout and
# subset keep More reachable; the switcher still shows all nine segments.
providers.overview_defaults(mergedOverviewLayout='compact', mergedOverviewSelectedProviders=['claude', 'kimi', 'zai'],
                            mergedOverviewSelectionEditedActiveProviders=providers.OVERVIEW_IDS)
phase_begin('footer')
app = App(INSTALLED, HELPER, 'footer')
app.wait(lambda: reached('footer', 'api.anthropic.com'), 'launch refresh', 40)
time.sleep(10)
rec = record('hover-and-more', 60)
time.sleep(2)
app.open_menu()
app.shot('f1-logo-only-switcher', 'nine segments')
buttons = [r for r in app.rows() if r['role'] == 'AXButton' and r['w']]
(OUT / 'f1-switcher.json').write_text(json.dumps(buttons, indent=1))
check('nine switcher segments', len(buttons) == 9, [b['label'] for b in buttons])
check('logo row keeps every provider name for accessibility and hover', all(b['help'] for b in buttons), [(b['label'], b['help']) for b in buttons])
target = next(b for b in buttons if b['label'] == 'Claude')
app.ui('move', target['x'] + target['w'] / 2, target['y'] + target['h'] / 2, 25)
before = {w['id'] for w in app.windows()}
time.sleep(4)
extra = [w for w in app.windows() if w['id'] not in before]
check('hovering a logo shows its native tooltip window', extra, extra)
app.shot('f2-hover-claude-logo', 'native tooltip, if any, is a new small window')
more = app.row('More')
say(f'More row: {more and more["labels"][:8]}')
assert more, 'no More row'
app.hover(more)
time.sleep(2)
app.shot('f3-more-submenu-open')
about = next((r for r in app.rows() if r['label'].startswith('About') and r['w']), None)
check('About is inside More', about, about and about['label'])
assert about, 'About not reachable inside More'
app.ui('move', about['x'] + about['w'] / 2, about['y'] + about['h'] / 2, 15)
time.sleep(0.6)
app.shot('f4-about-highlighted')
app.ui('click', about['x'] + about['w'] / 2, about['y'] + about['h'] / 2)
time.sleep(3)
app.shot('f5-about-activated', 'Settings About window from the More submenu')
check('More > About activates the Settings window', any(w['layer'] == 0 and w['w'] > 300 for w in app.windows()), app.windows())
say(f'recording exit={rec.wait(timeout=80)}')
app.quit()

say('=== overflow: all-accounts roster beyond twelve rows')
cfg = json.loads(json.dumps(providers.CONFIG))
for p in cfg:
    if p['id'] == 'kimi':
        p['tokenAccounts'] = {'version': 1, 'activeIndex': 0, 'accounts': [
            {'id': str(uuid.UUID(int=i + 1)), 'label': f'Synthetic Account {i + 1:02d}', 'token': f'synthetic-kimi-{i + 1}',
             'addedAt': 1760000000 + i, 'lastUsed': None} for i in range(14)]}
kit.write_config(cfg)
kit.defaults_reset()
providers.overview_defaults(mergedOverviewLayout='compact', mergedOverviewAllAccounts=True)
phase_begin('overflow')
app = App(INSTALLED, HELPER, 'overflow')
app.wait(lambda: reached('overflow', 'api.kimi.com'), 'launch refresh', 40)
time.sleep(25)
rec = record('overflow-navigation', 45)
time.sleep(2)
app.open_menu()
app.shot('o1-overflow-row', 'twelve inline rows, More (n), Quit on screen')
(OUT / 'o1-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
over = next((r for r in app.menu_items() if any(l.startswith('More (') for l in r['labels'])), None)
check('a roster over twelve rows collapses into More (n) with Quit on screen', over and app.row('Quit') and app.in_screen(app.row('Quit')['x'] + 5, app.row('Quit')['y'] + 5), over and over['labels'][:4])
if over:
    app.hover(over)
    time.sleep(2)
    app.shot('o2-overflow-submenu')
    child = next((r for r in app.rows() if 'Synthetic Account' in r['label'] and r['w'] and r['role'] == 'AXMenuItem'), None)
    check('the overflow submenu lists account rows', child, child and child['label'])
    if child:
        app.ui('move', child['x'] + child['w'] / 2, child['y'] + child['h'] / 2, 15)
        time.sleep(0.6)
        app.ui('click', child['x'] + child['w'] / 2, child['y'] + child['h'] / 2)
        time.sleep(3)
        app.shot('o3-overflow-activated', 'clicked an overflow account')
        if not app.menus():
            app.open_menu()
            app.shot('o4-reopened-after-overflow-click', 'selected provider tab')
        o4 = app.menu_items()
        (OUT / 'o4-rows.json').write_text(json.dumps(o4, indent=1))
        text = ' | '.join(l for r in o4 if r['y'] >= 112 for l in r['labels'])
        check('clicking an overflow row selects that provider', 'Usage Dashboard' in text or '5-hour usage' in text, text[:240])
say(f'recording exit={rec.wait(timeout=60)}')
app.quit()
kit.finish()
