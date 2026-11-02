#!/usr/bin/env python3
"""#4889: Usage & Spend in the shipped Settings window: Models selector, Show all/less, token and partial fallbacks."""
import json, subprocess, sys, time
from datetime import datetime, timedelta, timezone
from pathlib import Path
import kit, providers
from kit import App, OUT, say, state, record
HEAD_APP, _, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
INSTALLED = Path('/Applications/CodexBar.app')
subprocess.run(['ditto', HEAD_APP, str(INSTALLED)], check=True)
kit.start_fixture()
providers.install()
kit.write_credentials()
NOW = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0) - timedelta(hours=1)


def wipe():
    for p in ('.claude/projects', '.codex/sessions', 'Library/Caches/CodexBar', 'Library/Application Support/CodexBar'):
        subprocess.run(['rm', '-rf', str(kit.HOME / p)])


def case_priced():
    for i, (m, w) in enumerate((('claude-opus-4-5', 9), ('claude-sonnet-4-5', 7), ('claude-haiku-4-5', 3))):
        for b in range(5):
            kit.write_claude(NOW - timedelta(days=b), m, 100000 * w, 20000 * w, session=f'{m}{b}')
    for i, (m, w) in enumerate((('gpt-5.2-codex', 8), ('gpt-5.1-codex-mini', 2), ('gpt-5.2', 5), ('gpt-5.1-codex-max', 6))):
        for b in range(5):
            kit.write_codex(NOW - timedelta(days=b, minutes=i * 5), m, 100000 * w, 20000 * w)


def case_tokens():
    """One provider, one unpriced fictitious model: spend shares would overstate, so shares must use tokens."""
    for b in range(4):
        kit.write_claude(NOW - timedelta(days=b), 'claude-sonnet-4-5', 600000, 90000, session=f's{b}')
        kit.write_claude(NOW - timedelta(days=b), 'fictional-unpriced-model', 200000, 30000, session=f'u{b}')


def case_partial():
    """A request that never completed is excluded from totals, so named rows are only part of the whole."""
    for b in range(4):
        kit.write_claude(NOW - timedelta(days=b), 'claude-sonnet-4-5', 600000, 90000, session=f's{b}')
        kit.write_claude(NOW - timedelta(days=b), 'claude-opus-4-5', 300000, 40000, session=f'o{b}')
    kit.write_claude(NOW, 'claude-sonnet-4-5', 50000, 0, session='cut', stop=None)


def open_pane(app):
    app.open_menu()
    app.click_row(app.row('Settings'))
    assert app.wait(lambda: any(w['layer'] == 0 and w['w'] > 300 for w in app.windows()), 'Settings window', 12), 'no Settings window'
    time.sleep(2)
    (OUT / f'{app.name}-settings-window.json').write_text(json.dumps(app.win_rows(), indent=1))
    app.press('Usage & Spend')
    time.sleep(3)


def models_lens(app, tag):
    (OUT / f'{tag}-pane.json').write_text(json.dumps(app.win_rows(), indent=1))
    app.shot(f'{tag}-1-pane')
    hit = app.press('Models')
    time.sleep(2)
    app.shot(f'{tag}-2-models', f'clicked Models at {hit["x"]},{hit["y"]}')
    (OUT / f'{tag}-2-models.json').write_text(json.dumps(app.win_rows(), indent=1))
    say(f'{tag} texts: ' + json.dumps(app.texts())[:1500])


results = {}
for tag, build, cfg in (('priced', case_priced, providers.CONFIG[:2]),
                        ('tokens', case_tokens, providers.CONFIG[1:2]),
                        ('partial', case_partial, providers.CONFIG[1:2])):
    say(f'=== {tag}')
    wipe()
    build()
    kit.write_config(cfg)
    kit.defaults_reset()
    providers.overview_defaults(tokenCostUsageEnabled=True)
    app = App(INSTALLED, HELPER, tag)
    app.wait(lambda: state['requests'] > 2, 'launch refresh', 40)
    time.sleep(25)
    rec = record(f'{tag}-settings', 40)
    time.sleep(2)
    open_pane(app)
    models_lens(app, tag)
    results[tag] = {'models_texts': app.texts()}
    if tag == 'priced':
        labels = [r['label'] for r in app.win_rows() if r['w']]
        show = next((l for l in labels if l.lower().startswith('show all')), None)
        say(f'expand control: {show}')
        assert show, 'seven models but no Show all control'
        app.press(show)
        time.sleep(1.5)
        app.shot('priced-3-show-all')
        results[tag]['show_all_texts'] = app.texts()
        less = next((r['label'] for r in app.win_rows() if r['w'] and r['label'].lower().startswith('show less')), None)
        assert less, 'no Show less control after expanding'
        app.press(less)
        time.sleep(1.5)
        app.shot('priced-4-show-less')
        results[tag]['show_less_texts'] = app.texts()
    say(f'recording exit={rec.wait(timeout=60)}')
    app.quit()
(OUT / 'models-results.json').write_text(json.dumps(results, indent=1))
kit.finish()
