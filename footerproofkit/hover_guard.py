"""Pure pre-refresh AX target guard; never posts events or changes menus."""
import math
import re


def fresh_more(rows, window, display, owner_pid, root_id, epochs, expected_identity=None):
    assert window['id'] == root_id and window['ownerPID'] == owner_pid and window['layer'] == 101
    assert epochs == (1, 0), 'Root tracking ended/reopened'
    assert all(math.isfinite(window[k]) for k in ('x', 'y', 'w', 'h'))
    assert window['w'] > 0 and window['h'] > 0
    assert display['x'] <= window['x'] and display['y'] <= window['y']
    assert window['x'] + window['w'] <= display['x'] + display['w']
    assert window['y'] + window['h'] <= display['y'] + display['h']
    parents = []
    targets = []
    for index, row in enumerate(rows):
        depth = row['depth']
        while parents and parents[-1][1]['depth'] >= depth:
            parents.pop()
        if row.get('role') == 'AXMenuItem' and re.fullmatch(r'More \(\d+\)', row.get('title', '')):
            assert parents, 'More lacks observed parent'
            parent_index, parent = parents[-1]
            if parent.get('role') == 'AXMenu' and parent['frame'] == {k: window[k] for k in ('x', 'y', 'w', 'h')}:
                identity = (root_id, parent_index, parent['depth'], index, depth, row['role'], row['title'])
                targets.append((row, identity))
        parents.append((index, row))
    assert len(targets) == 1, 'No unique actual root More parent/row'
    row, identity = targets[0]
    assert expected_identity is None or identity == expected_identity, 'Actual AX parent/More identity changed'
    frame = row['frame']
    assert all(math.isfinite(frame[k]) for k in ('x', 'y', 'w', 'h')) and frame['w'] > 0 and frame['h'] > 0
    point = (frame['x'] + frame['w'] / 2, frame['y'] + frame['h'] / 2)
    x, y = point
    assert window['x'] <= x < window['x'] + window['w'] and window['y'] + 22 < y < window['y'] + window['h'] - 22
    assert display['x'] <= x < display['x'] + display['w'] and display['y'] <= y < display['y'] + display['h']
    return {'point': point, 'identity': identity, 'frame': frame}


def should_hover(point, previous, moves):
    if point == previous:
        return False
    assert moves < 3, 'Three pre-refresh hover moves exhausted; no retry/reopen'
    return True
