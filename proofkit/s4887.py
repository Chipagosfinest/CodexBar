#!/usr/bin/env python3
"""#4887: the installed extension's layouts and logos, fed by the unmodified app through the real app-group snapshot."""
import json, os, subprocess, sys, time
from datetime import timedelta
from pathlib import Path
import kit, providers
from kit import App, OUT, check, phase_begin, reached, say, state
HEAD_APP, _, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.verify_installed(INSTALLED)
for b in ('Contents/PlugIns/CodexBarWidget.appex/Contents/MacOS/CodexBarWidget',):
    h = [subprocess.run(['shasum', '-a', '256', str(Path(p) / b)], capture_output=True, text=True).stdout.split()[0] for p in (HEAD_APP, INSTALLED)]
    (OUT / 'extension-sha256.txt').write_text(h[0] + '\n')
    check('installed extension equals the packaged extension', h[0] == h[1], h)
for label, path in (('app', INSTALLED), ('widget', INSTALLED / 'Contents/PlugIns/CodexBarWidget.appex')):
    ent = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(path)], capture_output=True, text=True).stdout
    (OUT / f'{label}-entitlements.plist').write_text(ent)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(INSTALLED)], check=True)
ls = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
subprocess.run([ls, '-f', str(INSTALLED)], check=True)
subprocess.run(['pluginkit', '-a', str(INSTALLED / 'Contents/PlugIns/CodexBarWidget.appex')], check=True)
(OUT / 'registration.txt').write_text(subprocess.run(['pluginkit', '-m', '-A', '-D', '-i', 'com.steipete.codexbar.widget'], capture_output=True, text=True).stdout)
kit.start_fixture()
providers.install()
kit.write_credentials()
providers.PERCENTS['claude'] = (61, 30)
providers.EXTRA_CLAUDE['seven_day_sonnet'] = {'utilization': 92, 'resets_at': kit.iso(timedelta(days=5))}
order = ['claude', 'codex', 'kimi', 'zai']
kit.write_config([next(p for p in providers.CONFIG if p['id'] == i) for i in order])
providers.write_history(14)
providers.overview_defaults(tokenCostUsageEnabled=True)
phase_begin('widgetfeed')
app = App(INSTALLED, HELPER, 'widgetfeed')
app.wait(lambda: reached('widgetfeed', 'api.anthropic.com'), 'launch refresh', 40)
time.sleep(35)
app.open_menu()
app.shot('w0-app-feeding-widget', 'the same unmodified app supplies the snapshot')
app.close_menu()
snaps = [p for p in (kit.HOME / 'Library/Group Containers').glob('*/widget-snapshot.json')]
say(f'snapshots: {snaps}')
assert snaps, 'the app wrote no widget snapshot into an app-group container'
snap = json.loads(snaps[0].read_text())
report = {'container': snaps[0].parent.name, 'providers': [
    {'provider': e.get('provider'), 'primary': e.get('primary'), 'secondary': e.get('secondary'), 'tertiary': e.get('tertiary'),
     'daily_points': len(e.get('dailyUsage') or [])} for e in snap.get('entries', [])], 'generatedAt': snap.get('generatedAt')}
(OUT / 'transport-report.json').write_text(json.dumps(report, indent=1, default=str))
say('transport: ' + json.dumps(report, default=str)[:900])
by = {e['provider']: e for e in report['providers']}
check('snapshot carries the four enabled providers', set(order) <= set(by), list(by))
claude_entry = by.get('claude', {})
check('snapshot Claude session is 39% left (61 used), from the fixture reply', (claude_entry.get('primary') or {}).get('usedPercent') == 61, claude_entry.get('primary'))
check('snapshot Claude has 14-day local history from transcripts', claude_entry.get('daily_points', 0) >= 7, claude_entry.get('daily_points'))
fresh = time.time() - snaps[0].stat().st_mtime
check('snapshot was written by this launch', fresh < 120, f'{fresh:.0f}s old')
subprocess.run(['launchctl', 'load', '-w', '/System/Library/LaunchAgents/com.apple.notificationcenterui.plist'], capture_output=True)
time.sleep(3)
env = dict(os.environ)
r = subprocess.run(['xcodebuild', 'test', '-project', 'proofkit/WidgetDesktopSmoke/WidgetDesktopSmoke.xcodeproj', '-scheme', 'WidgetDesktopSmoke',
                    '-configuration', 'Debug', '-destination', 'platform=macOS', '-derivedDataPath', os.environ['RUNNER_TEMP'] + '/ui-build',
                    '-resultBundlePath', str(OUT / 'Widgets.xcresult'), '-only-testing:WidgetDesktopSmokeUITests/WidgetHostProofTests/testInstallAndResize',
                    'CODE_SIGN_IDENTITY=-', 'CODE_SIGN_STYLE=Manual'], capture_output=True, text=True, env=env, timeout=1100)
(OUT / 'ui-test.log').write_text(r.stdout[-200000:] + r.stderr[-20000:])
check('installed-widget host test passed (gallery install, small/medium/large resize, data present)', r.returncode == 0, r.returncode)
(OUT / 'attachments').mkdir(exist_ok=True)
subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(OUT / 'Widgets.xcresult'), '--output-path', str(OUT / 'attachments')], check=False)
subprocess.run(['screencapture', '-x', str(OUT / 'w9-final-screen.png')], check=False)
app.quit()
kit.finish()
