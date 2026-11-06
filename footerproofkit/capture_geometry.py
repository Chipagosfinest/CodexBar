"""Match native PNG extents only to owned, observed menu geometry; never chooses by pixel score."""
import math


def select_capture_rectangle(image, screen, display, windows, target_id, group_ids, owner_pid):
    by_id = {w['id']: w for w in windows}
    assert len(by_id) == len(windows), 'Duplicate observed window IDs'
    assert target_id in group_ids and len(set(group_ids)) == len(group_ids)
    assert all(i in by_id for i in group_ids), 'Owned visible menu missing'
    selected = [by_id[i] for i in group_ids]
    for w in selected:
        assert w['ownerPID'] == owner_pid and w['layer'] == 101, 'Unowned/non-menu capture geometry'
        assert all(math.isfinite(w[k]) for k in ['x', 'y', 'w', 'h']) and w['w'] > 0 and w['h'] > 0
        assert (display['x'] <= w['x'] and display['y'] <= w['y'] and
                w['x'] + w['w'] <= display['x'] + display['w'] and
                w['y'] + w['h'] <= display['y'] + display['h']), 'Menu outside display'
    scale = screen['width'] / display['w']
    assert scale >= 1 and abs(screen['height'] - display['h'] * scale) < 2
    target = {k: by_id[target_id][k] for k in ['x', 'y', 'w', 'h']}
    left, top = min(w['x'] for w in selected), min(w['y'] for w in selected)
    right, bottom = max(w['x'] + w['w'] for w in selected), max(w['y'] + w['h'] for w in selected)
    union = {'x': left, 'y': top, 'w': right - left, 'h': bottom - top}
    candidates = [('individual-menu', target)]
    if union != target:
        candidates.append(('observed-menu-group', union))
    matches = [(kind, rect) for kind, rect in candidates
               if abs(image['width'] - rect['w'] * scale) < 1
               and abs(image['height'] - rect['h'] * scale) < 1]
    assert len(matches) == 1, 'Native PNG dimensions match no unique owned menu/group extent'
    kind, rect = matches[0]
    return {'kind': kind, 'rectangle': rect, 'scale': scale, 'observedMenuIDs': group_ids,
            'targetMenuID': target_id, 'ownerPID': owner_pid}
