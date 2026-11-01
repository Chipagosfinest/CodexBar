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
kit.finish()
