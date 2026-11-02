#!/usr/bin/env python3
"""#4888: the rebuilt app's share preview and Copy Image, in light and dark, from real local transcripts."""
import json, subprocess, sys, time
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
kit.write_config(providers.CONFIG[:2])
providers.write_history(14)
providers.overview_defaults(tokenCostUsageEnabled=True)


def appearance(dark):
    r = subprocess.run(['osascript', '-e', f'tell application "System Events" to tell appearance preferences to set dark mode to {"true" if dark else "false"}'],
                       capture_output=True, text=True, timeout=40)
    now = subprocess.run(['defaults', 'read', '-g', 'AppleInterfaceStyle'], capture_output=True, text=True).stdout.strip()
    say(f'appearance dark={dark}: osascript rc={r.returncode} {r.stderr.strip()[:120]} AppleInterfaceStyle={now!r}')
    assert (now == 'Dark') == dark, 'appearance did not change'
    time.sleep(2)


results = {}
for name, dark in (('light', False), ('dark', True)):
    say(f'=== {name}')
    appearance(dark)
    phase_begin(name)
    app = App(INSTALLED, HELPER, f'share-{name}')
    app.wait(lambda: reached(name, 'api.anthropic.com'), 'launch refresh', 40)
    check(f'{name}: head app reached the fixture', reached(name, 'api.anthropic.com'))
    time.sleep(30)
    rec = record(f'share-{name}', 35)
    time.sleep(2)
    app.open_menu()
    app.shot(f's1-{name}-menu')
    (OUT / f's1-{name}-rows.json').write_text(json.dumps(app.menu_items(), indent=1))
    share = app.row('Share Usage Snapshot')
    assert share, 'no Share Usage Snapshot item'
    app.click_row(share)
    assert app.wait(lambda: any(w['layer'] == 0 and w['w'] > 300 for w in app.windows()), 'share window', 10), 'no share preview window'
    time.sleep(2)
    app.shot(f's2-{name}-preview', 'share preview window from the menu item')
    say('windows: ' + json.dumps(app.windows()))
    (OUT / f's2-{name}-window.json').write_text(json.dumps(app.win_rows(), indent=1))
    say('preview texts: ' + json.dumps(app.texts()))
    say('clipboard cleared, changeCount=' + app.ui('clearclipboard'))
    hit = app.press('Copy Image')
    time.sleep(1.5)
    app.shot(f's3-{name}-after-copy', 'feedback on the button after a real click')
    pasted = json.loads(app.ui('clipboard', OUT / f's4-{name}-clipboard.png'))
    say(f'pasteboard after Copy Image: {json.dumps(pasted)}')
    check(f'{name}: Copy Image put a 1200x630 image on the pasteboard', pasted.get('png') and (pasted.get('w'), pasted.get('h')) in ((1200, 630), (2400, 1260)), pasted)
    labels = [r['label'] for r in app.win_rows() if r['w'] and r['label']]
    check(f'{name}: the button reports the copy', any('Copied' in l for l in labels), [l for l in labels if 'Cop' in l])
    results[name] = {'clicked': hit, 'pasteboard': pasted, 'texts': app.texts()}
    say(f'recording exit={rec.wait(timeout=50)}')
    app.quit()
(OUT / 'copy-image-results.json').write_text(json.dumps(results, indent=1))
appearance(False)
kit.finish()
