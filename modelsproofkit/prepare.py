import argparse
import hashlib
import json
import pathlib
import subprocess

p = argparse.ArgumentParser()
p.add_argument("product", type=pathlib.Path)
p.add_argument("output", type=pathlib.Path)
args = p.parse_args()
kit = pathlib.Path(__file__).parent
product = args.product.resolve()
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)
sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=product, text=True).strip()
entry = product / "Sources/CodexBar/CodexbarApp.swift"
text = entry.read_text()
needle = "        self.removeAllocatorEnvironmentOverride()\n"
assert text.count(needle) == 1
entry.write_text(text.replace(needle, needle + "        #if DEBUG\n        if ModelsAppProof.runIfRequested() { return }\n        #endif\n"))
fixture = product / "Sources/CodexBar/ModelsAppProof.swift"
fixture.write_bytes((kit / "ModelsAppProof.swift").read_bytes())
subprocess.run(["git", "add", "-N", str(fixture.relative_to(product))], cwd=product, check=True)
(out / "overlay.patch").write_bytes(subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=product))
production = [
    "Sources/CodexBar/SpendDashboard/SpendDashboardModel.swift",
    "Sources/CodexBar/SpendDashboard/SpendDashboardModel+ModelBreakdown.swift",
    "Sources/CodexBar/SpendDashboard/SpendDashboardModelRanking.swift",
    "Sources/CodexBar/Settings/PreferencesSpendDashboardPane.swift",
]
hashes = {}
for path in production:
    original = subprocess.check_output(["git", "show", f"{sha}:{path}"], cwd=product)
    actual = (product / path).read_bytes()
    assert actual == original, path
    hashes[path] = hashlib.sha256(actual).hexdigest()
manifest = {
    "productSHA": sha,
    "synthetic": True,
    "normalStartupBypassed": "ModelsAppProof before resource smoke/settings/accounts/provider startup",
    "productionSourceSHA256": hashes,
    "overlaySHA256": hashlib.sha256((out / "overlay.patch").read_bytes()).hexdigest(),
    "fixtureSHA256": hashlib.sha256(fixture.read_bytes()).hexdigest(),
}
(out / "source-provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")
