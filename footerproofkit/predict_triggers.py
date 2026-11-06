"""Predict own branch push filters before publication; never dispatches workflows."""
import fnmatch
import json
from pathlib import Path
import subprocess

branch = 'proof/footer-runtime-20261106'
changed = subprocess.check_output(['git', 'diff', '--cached', '--name-only'], text=True).splitlines()
assert changed
triggered = []
for path in sorted(Path('.github/workflows').glob('*.yml')):
    value = json.loads(subprocess.check_output(['ruby', '-ryaml', '-rjson', '-e',
                       'print JSON.generate(YAML.load_file(ARGV[0]))', str(path)], stderr=subprocess.DEVNULL))
    events = value.get('on', value.get('true', {}))
    if not isinstance(events, dict) or 'push' not in events:
        continue
    push = events['push'] or {}
    if 'tags' in push and 'branches' not in push:
        continue
    if 'branches' in push and not any(fnmatch.fnmatchcase(branch, p) for p in push['branches']):
        continue
    if any(fnmatch.fnmatchcase(branch, p) for p in push.get('branches-ignore', [])):
        continue
    if 'paths' in push and not any(fnmatch.fnmatchcase(n, p) for n in changed for p in push['paths']):
        continue
    if 'paths-ignore' in push and all(any(fnmatch.fnmatchcase(n, p) for p in push['paths-ignore']) for n in changed):
        continue
    triggered.append(str(path))
assert triggered == ['.github/workflows/footer-app-ui-retry.yml'], triggered
print(json.dumps({'branch': branch, 'changedFiles': changed, 'predictedPushWorkflows': triggered,
                  'coldAppWorkflowManualOnly': True, 'exactlyOneWorkflow': True}, indent=2))
