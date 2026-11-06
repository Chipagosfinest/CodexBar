"""Predict own branch push filters before publication; never dispatches workflows."""
import fnmatch
import json
from pathlib import Path
import subprocess

branch = 'proof/footer-runtime-20261106'
changed = subprocess.check_output(['git', 'diff', '--cached', '--name-only'], text=True).splitlines()
assert changed
triggered = []
prior_manual_only = {}
for path in sorted(Path('.github/workflows').glob('*.yml')):
    value = json.loads(subprocess.check_output(['ruby', '-ryaml', '-rjson', '-e',
                       'print JSON.generate(YAML.load_file(ARGV[0]))', str(path)], stderr=subprocess.DEVNULL))
    events = value.get('on', value.get('true', {}))
    if path.name in ['footer-app-proof.yml', 'footer-app-ui-retry.yml']:
        prior_manual_only[path.name] = isinstance(events, dict) and 'workflow_dispatch' in events and 'push' not in events
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
assert triggered == ['.github/workflows/footer-app-oracle-proof.yml'], triggered
assert len(prior_manual_only) == 2 and all(prior_manual_only.values())
print(json.dumps({'branch': branch, 'changedFiles': changed, 'predictedPushWorkflows': triggered,
                  'priorWorkflowsManualOnly': prior_manual_only, 'exactlyOneWorkflow': True}, indent=2))
