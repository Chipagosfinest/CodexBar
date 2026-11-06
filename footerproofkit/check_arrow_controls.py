"""Offline pixel detector controls; no GUI execution."""
import json
from pathlib import Path
import subprocess
import sys

helper, root = sys.argv[1], Path(sys.argv[2])
results = []
for scale in [1, 2]:
    for direction in ['down', 'up', 'blank']:
        result = subprocess.run([helper, str(root / f'{direction}-{scale}x.png'),
                                 '50', '20', '200', '170', '0', '0', '300', '200'], capture_output=True, text=True)
        if direction == 'down':
            assert result.returncode == 0, result.stderr
            value = json.loads(result.stdout)
            assert value['downChevronObserved'] and value['scale'] == scale
            assert abs(value['x'] - 150) <= 1 and abs(value['y'] - 174) <= 1
        else:
            assert result.returncode != 0, 'Non-down arrow accepted as native scrolling target'
        results.append({'scale': scale, 'direction': direction, 'expectedAccepted': direction == 'down',
                        'actualAccepted': result.returncode == 0})
print(json.dumps({'controlsPassed': True, 'cases': results}, indent=2))
