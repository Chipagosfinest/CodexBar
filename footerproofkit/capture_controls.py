"""Original, unmodified hosted PNGs exercise exact live pixel code with their recorded display bounds."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from capture_geometry import select_capture_rectangle

helper, source = sys.argv[1], Path(sys.argv[2])
provenance = json.loads((source / 'provenance.json').read_text())
for name, entry in provenance.items():
    if name.endswith('.png'):
        assert hashlib.sha256((source / name).read_bytes()).hexdigest() == entry['sha256']
display = {'x': 0, 'y': 0, 'w': 1024, 'h': 768}
results = []


def info(path):
    return json.loads(subprocess.check_output([helper, 'image-info', str(path)]))


def similarity(screen, native, rect):
    result = json.loads(subprocess.check_output([helper, 'screen-similarity-recorded', str(screen), str(native),
                        *[str(rect[k]) for k in ['x', 'y', 'w', 'h']],
                        *[str(display[k]) for k in ['x', 'y', 'w', 'h']]]))
    assert result['samples'] == 936
    return result


for kind in ['root', 'group']:
    screen, native = source / (kind + '-screen.png'), source / (kind + '-native.png')
    pid = provenance[kind + 'OwnerPID']
    root = {'id': 40 if kind == 'root' else 39, 'ownerPID': pid, 'layer': 101,
            'x': 708, 'y': 31, 'w': 310, 'h': 668}
    menus = [root]
    if kind == 'group':
        menus.append({'id': 40, 'ownerPID': pid, 'layer': 101, 'x': 403, 'y': 488, 'w': 310, 'h': 211})
    group_ids = [w['id'] for w in menus]
    extent = select_capture_rectangle(info(native), info(screen), display, menus, root['id'], group_ids, pid)
    assert extent['kind'] == ('individual-menu' if kind == 'root' else 'observed-menu-group')
    comparison = similarity(screen, native, extent['rectangle'])
    assert comparison['meanRGBError'] < 0.13
    results.append({'case': kind + '-original-positive', 'extent': extent, 'similarity': comparison})
    bad_dimensions = dict(info(native), width=9999)
    unowned = copy.deepcopy(menus)
    unowned[-1]['ownerPID'] = pid + 1
    for name, dimensions, observed in [('wrong-dimensions', bad_dimensions, menus),
                                       ('unowned-window', info(native), unowned)]:
        try:
            select_capture_rectangle(dimensions, info(screen), display, observed, root['id'], group_ids, pid)
        except AssertionError:
            results.append({'case': kind + '-' + name, 'rejected': True})
        else:
            raise AssertionError('Invalid native capture geometry accepted: ' + name)
    wrong = dict(extent['rectangle'], x=0)
    comparison = similarity(screen, native, wrong)
    assert comparison['meanRGBError'] >= 0.13
    results.append({'case': kind + '-wrong-rectangle', 'rejected': True, 'similarity': comparison})
print(json.dumps({'controlsPassed': True, 'cases': results}, indent=2))
