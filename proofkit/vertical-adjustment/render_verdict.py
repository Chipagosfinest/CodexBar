#!/usr/bin/env python3
"""Record optional native-render evidence separately from deterministic tests."""
import hashlib
import json
from pathlib import Path
import sys

product = Path(sys.argv[1])
output = Path(sys.argv[2])
exit_code = int(sys.argv[3])
rendered = output / "rendered"
expected = json.loads((output / "expected-production-source-sha256.json").read_text())
metadata = json.loads((output / "provenance.json").read_text())
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
images = {path.name: digest(path) for path in rendered.glob("*.png") if path.stat().st_size > 100}
before = (rendered / "test-before-sha256.txt").read_text().split()[0]
states = json.loads((rendered / "states.json").read_text()) if (rendered / "states.json").exists() else []
verdict = {
    "boundary": "Synthetic production renderer on native NSButton; component fixture, not installed app",
    "exit_code": exit_code, "image_sha256": images, "state_count": len(states),
    "fixture_before_sha256": before, "fixture_after_sha256": digest(rendered / "fixture.swift"),
    "original_oracle_matches": before == metadata["selected_source_sha256"]["Tests/CodexBarTests/MenuBarUsageTotalTests.swift"],
    "production_source_matches_candidate": all(digest(product / name) == value for name, value in expected.items()),
    "render_log_sha256": digest(rendered / "tests.log"),
}
verdict["passed"] = (exit_code == 0 and len(images) == 4 and len(states) == 48
                     and verdict["original_oracle_matches"] and verdict["production_source_matches_candidate"])
(rendered / "verdict.json").write_text(json.dumps(verdict, indent=2) + "\n")
print(json.dumps(verdict, indent=2))
raise SystemExit(0 if verdict["passed"] else 1)
