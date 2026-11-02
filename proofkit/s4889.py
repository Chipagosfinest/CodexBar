#!/usr/bin/env python3
"""#4889: Usage & Spend in the shipped Settings window: Models selector, Show all/less, token and partial fallbacks."""
import json, subprocess, sys, time
from datetime import datetime, timedelta, timezone
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
NOW = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0) - timedelta(hours=1)


def wipe():
    for p in ('.claude/projects', '.codex/sessions', 'Library/Caches/CodexBar', 'Library/Application Support/CodexBar'):
        subprocess.run(['rm', '-rf', str(kit.HOME / p)])


def case_priced():
    # Seven models, because a list of six or fewer has no Show all control.
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


def case_mixed():
    """Two providers and one unpriced model: tokens do not compare across providers, so shares must be withheld."""
    for b in range(4):
        kit.write_claude(NOW - timedelta(days=b), 'fictional-unpriced-model', 200000, 30000, session=f'u{b}')
        kit.write_codex(NOW - timedelta(days=b), 'gpt-5.2-codex', 500000, 70000)


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


MODELS = ('claude-opus-4-5', 'claude-sonnet-4-5', 'claude-haiku-4-5', 'gpt-5.2-codex', 'gpt-5.1-codex-mini', 'gpt-5.2',
          'gpt-5.1-codex-max', 'fictional-unpriced-model')


def model_rows(app):
    """Visible model rows, each a combined accessibility element naming exactly one model."""
    rows = {}
    for r in app.win_rows():
        if r['w'] and r['role'] != 'AXStaticText' and r['label']:
            hit = [m for m in MODELS if r['label'].startswith(m) or f', {m}' in r['label'] or r['label'] == m]
            if hit:
                rows[max(hit, key=len)] = r['label']
    if rows:
        return rows
    for t in app.texts():
        if t in MODELS:
            rows[t] = t
    return rows


def models_lens(app, tag):
    (OUT / f'{tag}-pane.json').write_text(json.dumps(app.win_rows(), indent=1))
    app.shot(f'{tag}-1-pane')
    hit = app.press('Models')
    time.sleep(2)
    now = next((r for r in app.win_rows() if r['label'] == 'Models' and r['w']), {})
    check(f'{tag}: the Models segment is really selected', str(now.get('value')) == '1', now)
    app.shot(f'{tag}-2-models', f'clicked Models at {hit["x"]},{hit["y"]}')
    (OUT / f'{tag}-2-models.json').write_text(json.dumps(app.win_rows(), indent=1))
    say(f'{tag} texts: ' + json.dumps(app.texts())[:1500])


def visible_text(app):
    return ' | '.join(r['label'] for r in app.win_rows() if r['w'] and r['label'])


results = {}
for tag, build, cfg in (('priced', case_priced, providers.CONFIG[:2]),
                        ('tokens', case_tokens, providers.CONFIG[1:2]),
                        ('mixed', case_mixed, providers.CONFIG[:2]),
                        ('partial', case_partial, providers.CONFIG[1:2])):
    say(f'=== {tag}')
    wipe()
    build()
    kit.write_config(cfg)
    kit.defaults_reset()
    # Keep the menu short enough on this 1024x768 display that its Settings row is onscreen; spend scope is unaffected.
    providers.overview_defaults(tokenCostUsageEnabled=True, mergedOverviewLayout='compact', mergedOverviewSelectedProviders=['claude'],
                                mergedOverviewSelectionEditedActiveProviders=[p['id'] for p in cfg])
    phase_begin(tag)
    app = App(INSTALLED, HELPER, tag)
    app.wait(lambda: reached(tag, 'api.anthropic.com'), 'launch refresh', 40)
    check(f'{tag}: head app reached the provider fixture', reached(tag, 'api.anthropic.com'))
    time.sleep(25)
    rec = record(f'{tag}-settings', 40)
    time.sleep(2)
    open_pane(app)
    models_lens(app, tag)
    rows = model_rows(app)
    text = visible_text(app)
    results[tag] = {'rows': rows, 'text': text[:2000]}
    say(f'{tag} rows: {json.dumps(rows)}')
    if tag == 'priced':
        check('priced: collapsed list shows five of seven models', len(rows) == 5, list(rows))
        check('priced: basis is estimated spend with shares', 'Estimated spend' in text and '%' in text, text[:200])
        show = next((r['label'] for r in app.win_rows() if r['w'] and r['label'].lower().startswith('show all')), None)
        check('priced: Show all control is offered', show, show)
        if show:
            app.press(show)
            time.sleep(1.5)
            app.shot('priced-3-show-all')
            expanded = model_rows(app)
            check('priced: Show all really reveals all seven rows', len(expanded) == 7, list(expanded))
            results[tag]['expanded'] = expanded
            less = next((r['label'] for r in app.win_rows() if r['w'] and r['label'].lower().startswith('show less')), None)
            check('priced: Show less control is offered', less, less)
            if less:
                app.press(less)
                time.sleep(1.5)
                app.shot('priced-4-show-less')
                check('priced: Show less returns to five rows', len(model_rows(app)) == 5, list(model_rows(app)))
    elif tag == 'tokens':
        check('tokens: one provider with an unpriced model ranks by Tracked tokens with shares', 'Tracked tokens' in text and '%' in text and 'Estimated spend' not in text, text[:300])
        check('tokens: both models listed', 'fictional-unpriced-model' in rows and 'claude-sonnet-4-5' in rows, list(rows))
    elif tag == 'mixed':
        check('mixed: two providers plus an unpriced model withhold the basis header', 'Tracked tokens' not in text and 'Estimated spend' not in text, text[:300])
        check('mixed: both models still listed', 'fictional-unpriced-model' in rows and 'gpt-5.2-codex' in rows, list(rows))
    else:
        check('partial: an incomplete request shows the partial warning', 'Partial model breakdown' in text, text[:300])
    say(f'recording exit={rec.wait(timeout=60)}')
    app.quit()
(OUT / 'models-results.json').write_text(json.dumps(results, indent=1))
kit.finish()
