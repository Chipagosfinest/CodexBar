#!/usr/bin/env python3
import json, subprocess, sys, time
import kit, providers
from kit import App, OUT, say, state
HEAD_APP, V083_APP, HELPER = sys.argv[1], sys.argv[2], sys.argv[3]
kit.start_fixture(); providers.install(); kit.write_credentials(); kit.write_config(providers.CONFIG)
providers.overview_defaults()
for i in range(2):
    app = App(HEAD_APP, HELPER, f'dbg{i}')
    time.sleep(22)
    app.open_menu(); app.shot(f'dbg{i}')
    (OUT / f'dbg{i}-labels.json').write_text(json.dumps([r['label'] for r in app.rows() if r['label']], indent=1))
    app.quit()
    (OUT / f'config-after-{i}.json').write_text((kit.HOME / '.codexbar/config.json').read_text())
subprocess.run(f"/usr/bin/log show --last 5m --info --debug --style compact --predicate 'process == \"CodexBar\"' > {OUT}/unified.log 2>&1", shell=True)
subprocess.run(f"ls -la {kit.HOME}/.codexbar {kit.HOME}/.config/codexbar >> {OUT}/ls.txt 2>&1", shell=True)
kit.finish()
