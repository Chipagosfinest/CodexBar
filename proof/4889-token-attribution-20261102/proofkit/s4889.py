#!/usr/bin/env python3
"""#4889: Usage & Spend in the shipped Settings window: Models selector, Show all/less, token and partial fallbacks."""
import json, subprocess, sys, time
from datetime import datetime, timedelta, timezone
from pathlib import Path
import kit, providers
from kit import App, OUT, check, finding, phase_begin, reached, say, state, record
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
    """One provider, only unpriced fictitious models: no spend basis exists, so shares must use tokens."""
    for b in range(4):
        kit.write_claude(NOW - timedelta(days=b), 'fictional-unpriced-model', 600000, 90000, session=f's{b}')
        kit.write_claude(NOW - timedelta(days=b), 'fictional-unpriced-model-two', 200000, 30000, session=f'u{b}')


def case_mixed():
    """Two providers and one unpriced model: tokens do not compare across providers, so shares must be withheld."""
    for b in range(4):
        kit.write_claude(NOW - timedelta(days=b), 'fictional-unpriced-model', 200000, 30000, session=f'u{b}')
        kit.write_codex(NOW - timedelta(days=b), 'gpt-5.2-codex', 500000, 70000)


def case_partial():
    """Claude mixes priced and unpriced models, so its history is not attributable; Codex's named rows are only part."""
    for b in range(4):
        kit.write_claude(NOW - timedelta(days=b), 'claude-sonnet-4-5', 600000, 90000, session=f's{b}')
        kit.write_claude(NOW - timedelta(days=b), 'fictional-unpriced-model', 200000, 30000, session=f'u{b}')
        kit.write_codex(NOW - timedelta(days=b), 'gpt-5.2-codex', 500000, 70000)


def open_pane(app):
    app.open_menu()
    opened = False
    for attempt in range(2):
        # A one-provider menu can run past the display, so its footer is scrolled into the menu's visible part.
        target = app.scroll_to(lambda r: any(l.startswith('Settings') for l in r['labels']) and r['y'] > 30, 'Settings row')
        app.click_row(target)
        opened = app.wait(lambda: any(w['layer'] == 0 and w['w'] > 300 for w in app.windows()), 'Settings window', 12)
        if opened:
            break
        app.shot(f'{app.name}-settings-attempt-{attempt}', f'no window after clicking {target["labels"][:2]} at y={target["y"]}')
        if not app.menus():
            app.open_menu()
    assert opened, 'no Settings window'
    time.sleep(2)
    (OUT / f'{app.name}-settings-window.json').write_text(json.dumps(app.win_rows(), indent=1))
    app.press('Usage & Spend')
    time.sleep(3)


MODELS = ('fictional-unpriced-model-two', 'claude-opus-4-5', 'claude-sonnet-4-5', 'claude-haiku-4-5', 'gpt-5.2-codex', 'gpt-5.1-codex-mini', 'gpt-5.2',
          'gpt-5.1-codex-max', 'fictional-unpriced-model')


def model_rows(app):
    """Visible rows: each is one accessibility element reading 'model, provider, share, value'."""
    rows = {}
    for r in app.win_rows():
        if r['w'] and r['role'] == 'AXStaticText' and r['label'].split(',')[0] in MODELS:
            rows[r['label'].split(',')[0]] = r['label']
    return rows


def bring_lens_onscreen(app):
    """The lens sits below the fold on this display, so scroll the Settings pane with real wheel events."""
    r = next(r for r in app.win_rows() if r['label'] == 'Models' and r['w'])
    app.ui('move', r['x'] + r['w'] / 2, 300, 10)
    for _ in range(50):
        r = next(r for r in app.win_rows() if r['label'] == 'Models' and r['w'])
        if r['y'] < 130:
            break
        app.ui('scroll', -3)
        time.sleep(0.15)
    time.sleep(0.6)


def models_lens(app, tag):
    (OUT / f'{tag}-pane.json').write_text(json.dumps(app.win_rows(), indent=1))
    app.shot(f'{tag}-1-pane')
    hit = app.press('Models')
    time.sleep(2)
    now = next((r for r in app.win_rows() if r['label'] == 'Models' and r['w']), {})
    check(f'{tag}: the Models segment is really selected', str(now.get('value')) == '1', now)
    bring_lens_onscreen(app)
    app.shot(f'{tag}-2-models', f'clicked Models at {hit["x"]},{hit["y"]}; pane scrolled to the lens')
    (OUT / f'{tag}-2-models.json').write_text(json.dumps(app.win_rows(), indent=1))
    say(f'{tag} texts: ' + json.dumps(app.texts())[:1500])


def lens_headers(app):
    """Only the Models lens's own basis header: the pane's summary above also says Tracked tokens."""
    w = app.win_rows()
    top = next(r for r in w if r['label'] == 'Models' and r['w'])['y']
    first = min((r['y'] for r in w if r['w'] and r['role'] == 'AXStaticText' and r['label'].split(',')[0] in MODELS), default=top + 60)
    return [r['label'] for r in w if r['w'] and r['role'] == 'AXStaticText' and top < r['y'] < first]


def visible_text(app):
    return ' | '.join(r['label'] for r in app.win_rows() if r['w'] and r['label'])


ONLY_CLAUDE = [{'id': 'codex', 'enabled': False}, providers.CONFIG[1]]
results = {}
for tag, build, cfg in (('priced', case_priced, providers.CONFIG[:2]),
                        ('tokens', case_tokens, ONLY_CLAUDE),
                        ('mixed', case_mixed, providers.CONFIG[:2]),
                        ('partial', case_partial, providers.CONFIG[:2])):
    say(f'=== {tag}')
    wipe()
    build()
    kit.write_config(cfg)
    kit.defaults_reset()
    # Keep the menu short enough on this 1024x768 display that its Settings row is onscreen; spend scope is unaffected.
    providers.overview_defaults(tokenCostUsageEnabled=True, mergedOverviewLayout='compact', mergedOverviewSelectedProviders=['claude'],
                                mergedOverviewSelectionEditedActiveProviders=[p['id'] for p in cfg if p['enabled']])
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
        check('priced: basis is estimated spend with a share on every row', 'Estimated spend' in text and all('%' in v for v in rows.values()), rows)
        (OUT / 'priced-2b-lens.json').write_text(json.dumps(app.win_rows(), indent=1))
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
        h = lens_headers(app)
        check('tokens: one provider with no price basis falls back to Tracked tokens, showing token values', 'Tracked tokens' in h and 'Estimated spend' not in h and rows and not any('$' in v for v in rows.values()), {'header': h, 'rows': rows})
        check('tokens: complete token attribution has no partial model warning', 'Partial model breakdown' not in h, h)
        check('tokens: both models carry correct token percentages', len(rows) == 2 and any('75%' in v for v in rows.values()) and any('25%' in v for v in rows.values()), rows)
        check('tokens: both models listed', len(rows) == 2, list(rows))
    elif tag == 'mixed':
        h = lens_headers(app)
        check('mixed: two providers plus an unpriced model withhold shares and any single basis', rows and not any('%' in v for v in rows.values()) and 'Tracked tokens' not in h and 'Estimated spend' not in h, {'header': h, 'rows': rows})
        check('mixed: the unpriced history carries the partial warning', 'Partial model breakdown' in h, h)
        check('mixed: both models still listed', 'fictional-unpriced-model' in rows and 'gpt-5.2-codex' in rows, list(rows))
    else:
        check('partial: unattributable history shows the partial warning and withholds shares', 'Partial model breakdown' in lens_headers(app) and rows and not any('%' in v for v in rows.values()), {'header': lens_headers(app), 'rows': rows})
    say(f'recording exit={rec.wait(timeout=60)}')
    app.quit()
(OUT / 'models-results.json').write_text(json.dumps(results, indent=1))
kit.finish()
