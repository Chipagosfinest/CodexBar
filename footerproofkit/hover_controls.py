#!/usr/bin/env python3
"""Offline real recorded AX frames plus adversarial pure guard controls; no UI."""
import copy
import json
from hover_guard import fresh_more, should_hover

window = dict(id=127, ownerPID=28273, layer=101, x=1604, y=31, w=310, h=953)
display = dict(x=0, y=0, w=1920, h=1080)
rows = [dict(depth=3, role='AXMenu', frame={k: window[k] for k in ('x', 'y', 'w', 'h')}),
        dict(depth=4, role='AXMenuItem', title='More (4)', frame=dict(x=1604, y=930, w=310, h=24))]
cases = []

def target(r=rows, w=window, epochs=(1, 0), identity=None):
    return fresh_more(r, w, display, 28273, 127, epochs, identity)


def reject(name, action):
    try:
        action()
    except AssertionError:
        cases.append(name)
    else:
        raise AssertionError('Negative accepted: ' + name)

old = target()
shifted = copy.deepcopy(rows)
shifted[1]['frame']['y'] = 906
fresh = target(shifted, identity=old['identity'])
assert old['point'] == (1759, 942) and fresh['point'] == (1759, 918)
assert should_hover(fresh['point'], old['point'], 1)
cases.append('actual930-to906-reacquires918-not-stale942')
assert not should_hover(fresh['point'], fresh['point'], 3)
cases.append('same-center-never-reposts')
reject('fourth-hover-rejected', lambda: should_hover((1759, 900), fresh['point'], 3))
for key, bad in [('ownerPID', 7), ('id', 8), ('layer', 0)]:
    reject('wrong-root-' + key, lambda key=key, bad=bad: target(w={**window, key: bad}))
reject('root-reopened', lambda: target(epochs=(2, 1)))
reject('root-closed', lambda: target(epochs=(1, 1)))
wrong = copy.deepcopy(rows); wrong[1]['title'] = 'Refresh'
reject('refresh-is-not-more', lambda: target(wrong))
wrong = copy.deepcopy(rows); wrong[0]['frame']['y'] += 1
reject('wrong-live-parent', lambda: target(wrong))
wrong = copy.deepcopy(rows); wrong[1]['frame']['y'] = 1100
reject('offscreen-row', lambda: target(wrong))
wrong = copy.deepcopy(rows); wrong[1]['title'] = 'More (3)'
reject('more-identity-changed', lambda: target(wrong, identity=old['identity']))
wrong = copy.deepcopy(rows); wrong.append(copy.deepcopy(rows[1]))
reject('ambiguous-more', lambda: target(wrong))
wrong = copy.deepcopy(rows); wrong[1]['frame']['y'] = float('nan')
reject('nonfinite-row', lambda: target(wrong))
print(json.dumps({'passed': True, 'cases': cases, 'actualRecordedFrames': {'beforeY':930,'afterY':906},
                  'noUIExecution': True}, indent=2))
