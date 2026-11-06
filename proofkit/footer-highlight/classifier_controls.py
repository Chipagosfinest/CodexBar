"""Synthetic classifier unit strings only: these are not product/runtime evidence."""
import json
from prove import OLD, NEW, classify

starts = f'Test "{OLD}" started.\nTest "{NEW}" started.\n'
control = f'Test "{OLD}" passed after 0.1 seconds.\n'
witness = '\n'.join('Expectation failed: ' + expression for expression in [
    'rebuilt.contains { $0 === overflow }', 'freshCard !== oldCard',
    'freshView !== oldView', 'controller.menuCardHeightCache.keys.contains { $0.fingerprint == freshFingerprint }'])
red = starts + control + witness + f'\nTest "{NEW}" failed after 1 seconds with 4 issues.\nTest run with 2 tests in 1 suite failed after 1 seconds with 4 issues.\n'
green = starts + control + f'Test "{NEW}" passed after 0.1 seconds.\nTest run with 2 tests in 1 suite passed after 0.2 seconds.\n'
cases = [
    ('synthetic-valid-red', red, 1, 'red', True),
    ('synthetic-valid-green', green, 0, 'green', True),
    ('compiler-failure-no-tests', 'error: cannot compile\n', 1, 'red', False),
    ('missing-test-start', red.replace(f'Test "{NEW}" started.\n', ''), 1, 'red', False),
    ('wrong-test-count', red.replace('with 2 tests', 'with 3 tests'), 1, 'red', False),
    ('wrong-failure', red.replace('freshCard !== oldCard', 'transport.requestCount != 0'), 1, 'red', False),
    ('old-control-failed', red.replace(f'Test "{OLD}" passed', f'Test "{OLD}" failed'), 1, 'red', False),
    ('compiler-error-plus-fake-summary', 'error: compile failed\n' + red, 1, 'red', False),
    ('unexpected-green-issue', green + 'Expectation failed: arbitrary\n', 0, 'green', False),
]
results = []
for label, log, code, expectation, expected in cases:
    verdict = classify(log, code, expectation)
    actual = verdict['behavioral_red' if expectation == 'red' else 'candidate_green']
    assert actual == expected, label
    results.append({'case': label, 'expectedAccepted': expected, 'actualAccepted': actual})
print(json.dumps({'syntheticClassifierControlsOnly': True, 'controlsPassed': True, 'cases': results}, indent=2))
