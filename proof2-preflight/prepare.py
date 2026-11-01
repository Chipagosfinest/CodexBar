from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys
product = Path(sys.argv[1]).resolve()
output = Path(os.environ['PROOF_OUTPUT'])
output.mkdir(parents=True, exist_ok=True)
fixture = Path(__file__).with_name('RealBehaviorProof.swift')
source = fixture.read_text()
# Adapt proof chrome only to the hosted runner's 1024x768 display.
source = source.replace('NSRect(x: 280, y: 380, width: 440, height: 160)', 'NSRect(x: 100, y: 100, width: 820, height: 560)')
source = source.replace('NSPoint(x: 20, y: 100)', 'NSPoint(x: 20, y: 520)')
source = source.replace('NSRect(x: 20, y: 110, width: 400, height: 22)', 'NSRect(x: 20, y: 520, width: 780, height: 22)')
(product/'Sources/CodexBar/RealBehaviorProof.swift').write_text(source)
entry = product/'Sources/CodexBar/CodexBarApp.swift'
entry.write_text(entry.read_text().replace('if MenuBarLayoutNativeProof.runIfRequested() {', 'if RealBehaviorProof.runIfRequested() { return }\n        if MenuBarLayoutNativeProof.runIfRequested() {'))
(output/'fixture.swift').write_text(source)
(output/'plumbing.patch').write_text(subprocess.check_output(['git', 'diff', '--', 'Sources/CodexBar/CodexBarApp.swift'], cwd=product, text=True))
(output/'source-provenance.json').write_text(json.dumps({
    'pr': os.environ['PROOF_PR'],
    'head_sha': subprocess.check_output(['git','rev-parse','HEAD'],cwd=product,text=True).strip(),
    'fixture_sha256': hashlib.sha256(source.encode()).hexdigest(),
    'original_fixture_sha256': hashlib.sha256(fixture.read_bytes()).hexdigest(),
    'boundary': 'Full CodexBar target at PR head plus early opt-in fixture entry. Real production view and refresh monitor hosted in native NSMenu. Synthetic data, no real transports or StatusItemController routing.'
}, indent=2)+'\n')
