#!/usr/bin/env python3
"""Run real subprocess exit controls before the actual screen journey."""
import json
import subprocess
import sys
from wait_process import observed_exit

results = []
for expected in [0, 3]:
    child = subprocess.Popen([sys.executable, '-c', f'import time,sys; time.sleep(0.15); sys.exit({expected})'])
    actual = observed_exit(child, 3)
    assert actual == expected
    results.append({'case': 'real-child-exit', 'expected': expected, 'observed': actual})
child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(5)'])
try:
    try:
        observed_exit(child, 0.1)
    except subprocess.TimeoutExpired:
        assert child.poll() is None
        results.append({'case': 'live-child-times-out', 'verified': True})
    else:
        raise AssertionError('Live process falsely reported complete')
finally:
    child.terminate()
    assert observed_exit(child, 3) != 0
print(json.dumps({'controlsPassed': True, 'cases': results}, indent=2))
