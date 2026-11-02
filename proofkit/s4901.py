#!/usr/bin/env python3
"""#4901: real pointer hover over the Overview spend chart in the installed app, from real local transcripts."""
import json, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, check, phase_begin, reached, say, state, record
HEAD_APP, _, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.verify_installed(INSTALLED)
kit.start_fixture(); providers.install(); kit.write_credentials(); kit.write_config(providers.CONFIG[:2])
providers.write_history(14)
providers.overview_defaults(tokenCostUsageEnabled=True, mergedOverviewLayout='compact')
phase_begin('chart')
app = App(INSTALLED, HELPER, 'chart')
app.wait(lambda: reached('chart', 'api.anthropic.com'), 'launch refresh', 40)
time.sleep(30)
rec = record('chart-hover', 60)
time.sleep(2)
app.open_menu()
app.shot('c1-rest', 'chart at rest: label reads Today')


def points():
    return [r for r in app.rows() if r['role'] == 'AXUnknown' and r['w'] and ':' in r['label'] and r['label'][:3].isalpha()]


pts = points()
(OUT / 'c1-points.json').write_text(json.dumps(pts, indent=1))
check('the chart exposes one element per day of the range', len(pts) >= 7, f'{len(pts)} first={pts[:1]} last={pts[-1:]}')
if not pts:
    (OUT / 'c1-all-rows.json').write_text(json.dumps(app.rows(), indent=1))


def texts():
    return [r['label'] for r in app.rows() if r['w'] and (r['role'] == 'AXStaticText' or (r['role'] == 'AXUnknown' and r['label'].endswith('%')))]


rest = texts()
say('rest texts: ' + json.dumps(rest))
check('at rest the label reads Today', any(t.startswith('Today') for t in rest), rest[:8])
steps = {}
# Reading left to right, then leaving the chart: each hover is a stream of real mouse-moved events.
for name, frac in (('c2-hover-early', 0.62), ('c3-hover-mid', 0.8), ('c4-hover-latest', 0.97)):
    if not pts:
        break
    p = pts[int(frac * (len(pts) - 1))]
    app.ui('move', p['x'] + p['w'] / 2, p['y'] + p['h'] / 2, 30)
    time.sleep(1.0)
    app.shot(name, f'over: {p["label"]}')
    steps[name] = {'hovered_element': p['label'], 'texts': texts()}
    say(f'{name}: {json.dumps(steps[name])}')
    day = p['label'].split(':')[0]
    check(f'{name}: hover selects that day in the readout', any(t.startswith(day + ':') for t in steps[name]['texts']), f'{day} {steps[name]["texts"][:6]}')
quit_row = app.row('Quit')
app.hover(quit_row)
time.sleep(1.2)
app.shot('c5-pointer-left-chart', 'selection clears on exit')
steps['c5-pointer-left-chart'] = {'texts': texts()}
check('leaving the chart clears the selection', texts() == rest or any(t.startswith('Today') for t in texts()), texts()[:8])
if len(steps) >= 3:
    legends = [tuple(t for t in steps[k]['texts'] if t.endswith('%')) for k in steps if k != 'c5-pointer-left-chart']
    resting = tuple(t for t in rest if t.endswith('%'))
    check('legend shares update to the hovered day', all(legends) and (len(set(legends)) > 1 or resting not in legends), {'rest': resting, 'hovered': legends})
    check('the legend returns to range shares on exit', tuple(t for t in texts() if t.endswith('%')) == resting, resting)
(OUT / 'hover-readouts.json').write_text(json.dumps(steps, indent=1))
say(f'recording exit={rec.wait(timeout=80)}')
app.quit()
kit.finish()
