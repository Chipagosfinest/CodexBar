#!/usr/bin/env python3
"""All providers menu bar meter, driven through the unmodified packaged app with live fixture quota changes."""
import json, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, check, finding, phase_begin, reached, say, state

HEAD_APP, _V083_APP, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
SELECT = ['codex', 'claude', 'kimi', 'zai', 'deepseek']
kit.start_fixture()
providers.install()
kit.write_credentials()
kit.write_config([p for p in providers.CONFIG if p['id'] in SELECT])
say('trusted(ax,screen,post)=' + subprocess.run([HELPER, 'trusted'], capture_output=True, text=True).stdout.strip())
subprocess.run(['rm', '-rf', str(INSTALLED)], check=True)
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.verify_installed(INSTALLED)
CALM = {'codex': (30, 20), 'claude': (35, 22), 'kimi': (15, 12), 'zai': (72,), 'commandcode': (0, 0), 'openrouter': 0}


def label(app):
    items = app.items()
    if not items:
        return ''
    return ' '.join(str(items[0].get(k) or '') for k in ('title', 'desc', 'value')).strip()


def wait_label(app, pred, what, timeout=200):
    ok = app.wait(lambda: pred(label(app)), what, timeout)
    say(f'label after {what}: {label(app)!r}')
    return ok


def shot(app, name, note=''):
    app.shot(name, note)
    (OUT / f'{name}-item.json').write_text(json.dumps(app.items()[0] if app.items() else {}))


def seed(**prefs):
    kit.defaults_reset()
    providers.overview_defaults(refreshFrequency='oneMinute', mergedOverviewSelectedProviders=SELECT,
                                mergedOverviewSelectionEditedActiveProviders=SELECT, **prefs)


providers.PERCENTS.update(CALM)
phase_begin('default-source')
seed()
app = App(INSTALLED, HELPER, 'default-source')
assert app.wait(app.items, 'status item', 40), 'no status item'
before = state['requests']
app.wait(lambda: state['requests'] > before, 'first refresh', 60)
time.sleep(10)
shot(app, 'default-source', 'no source chosen: the existing default')
check('an existing install is unchanged: no total without opting in', 'average' not in label(app), label(app))
app.quit()

for name, dark in (('light', False), ('dark', True)):
    say(f'=== appearance {name}: {subprocess.run([HELPER, "dark", "1" if dark else "0"], capture_output=True, text=True).stdout.strip()}')
    time.sleep(3)
    providers.PERCENTS.update(CALM)
    state['all_fail'] = False
    phase_begin(f'{name}-calm')
    seed(unifiedIconSource='allProviders')
    app = App(INSTALLED, HELPER, f'total-{name}')
    # (70 + 65 + 85 + 28) / 4 = 62; DeepSeek is balance-only and must not be counted.
    check(f'{name}: calm total averages the four quota providers and skips balance-only DeepSeek',
          wait_label(app, lambda l: 'average 62% left' in l and 'near limit' not in l, 'calm total'), label(app))
    check(f'{name}: every quota provider reached the fixture',
          all(reached(f'{name}-calm', h) for h in ('chatgpt.com', 'api.anthropic.com', 'api.z.ai')), state.get('log', [])[-6:])
    shot(app, f'{name}-1-calm')

    phase_begin(f'{name}-near')
    providers.PERCENTS['claude'] = (35, 92)
    # Claude is not the primary quota driving the item here, so this also proves every provider is observed.
    check(f'{name}: a live quota change raises the warning naming Claude with the total kept',
          wait_label(app, lambda l: 'Claude near limit, 8% left' in l and 'average 48% left' in l, 'Claude near limit'), label(app))
    shot(app, f'{name}-2-near-limit-claude')
    app.open_menu()
    shot(app, f'{name}-3-near-limit-menu-open', 'real click on the status item')
    (OUT / f'{name}-menu-labels.json').write_text(json.dumps([r['label'] for r in app.rows() if r['label']], indent=1))
    app.close_menu()

    phase_begin(f'{name}-two')
    providers.PERCENTS['zai'] = (97,)
    check(f'{name}: the tighter of two near-limit providers leads, and both are announced',
          wait_label(app, lambda l: '3% left' in l and '8% left' in l,
                     'second provider near limit'), label(app))
    check(f'{name}: tightest provider is announced first', label(app).find('3% left') < label(app).find('8% left'), label(app))
    shot(app, f'{name}-4-two-near-limit')

    if not dark:
        phase_begin('light-stale')
        state['all_fail'] = True
        finding('failed refreshes on every provider never raise the warning from stale data',
                wait_label(app, lambda l: 'near limit' not in l, 'stale clears warning', 240), label(app))
        shot(app, 'light-5-stale-all-failing')
        state['all_fail'] = False

    phase_begin(f'{name}-recovered')
    providers.PERCENTS.update(CALM)
    check(f'{name}: recovery returns to the calm total',
          wait_label(app, lambda l: 'average 62% left' in l and 'near limit' not in l, 'recovered', 240), label(app))
    shot(app, f'{name}-6-recovered')

    if not dark:
        try:
            app.open_menu()
            app.click_row(app.row('Settings'))
            app.wait(lambda: any(w['layer'] == 0 and w['w'] > 300 for w in app.windows()), 'Settings window', 10)
            time.sleep(1)
            app.press('Menu Bar')
            time.sleep(1.5)
            shot(app, 'light-7-settings')
            finding('Settings shows All providers as the chosen combined icon source', 'All providers' in ' '.join(
                str(r['label']) + str(r['value']) for r in app.win_rows()), '')
        except Exception as error:  # A Settings navigation miss must not cost the appearance matrix.
            finding('Settings pane could be driven', False, repr(error))
    app.quit()

subprocess.run([HELPER, 'dark', '0'], capture_output=True)
kit.finish()
