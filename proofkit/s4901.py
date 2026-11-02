#!/usr/bin/env python3
"""#4901: real pointer hover over the Overview spend chart in the installed app, from real local transcripts."""
import json, subprocess, sys, time
from pathlib import Path
import kit, providers
from kit import App, OUT, say, state, record
HEAD_APP, _, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.start_fixture(); providers.install(); kit.write_credentials(); kit.write_config(providers.CONFIG[:2])
providers.write_history(14)
providers.overview_defaults(tokenCostUsageEnabled=True, mergedOverviewLayout='compact')
app = App(INSTALLED, HELPER, 'chart')
app.wait(lambda: state['requests'] > 2, 'launch refresh', 40)
time.sleep(30)
rec = record('chart-hover', 60)
time.sleep(2)
app.open_menu()
app.shot('c1-rest', 'chart at rest: label reads Today')


def points():
    return [r for r in app.rows() if r['role'] == 'AXUnknown' and r['w'] and ':' in r['label'] and r['label'][:3].isalpha()]


pts = points()
(OUT / 'c1-points.json').write_text(json.dumps(pts, indent=1))
say(f'{len(pts)} chart day elements; first={pts[:1]} last={pts[-1:]}')
if not pts:
    (OUT / 'c1-all-rows.json').write_text(json.dumps(app.rows(), indent=1))


def texts():
    return [r['label'] for r in app.rows() if r['role'] == 'AXStaticText' and r['w']]


say('rest texts: ' + json.dumps(texts()))
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
quit_row = app.row('Quit')
app.hover(quit_row)
time.sleep(1.2)
app.shot('c5-pointer-left-chart', 'selection clears on exit')
steps['c5-pointer-left-chart'] = {'texts': texts()}
(OUT / 'hover-readouts.json').write_text(json.dumps(steps, indent=1))
say(f'recording exit={rec.wait(timeout=80)}')
app.quit()
kit.finish()
