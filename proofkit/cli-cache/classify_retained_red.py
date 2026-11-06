#!/usr/bin/env python3
"""Reclassify the retained hosted RED log; never execute or mutate product sources."""
import hashlib
import json
from pathlib import Path
import re
import sys

artifact = Path(sys.argv[1])
verdict = json.loads((artifact / "verdict.json").read_text())
log_bytes = (artifact / "tests.log").read_bytes()
log = log_bytes.decode(errors="replace")
assert verdict["expectation"] == "red" and verdict["exit_code"] == 1
assert verdict["product_sha"] == "ec61c49dd71c3aa6efe33162762ef2164ecfaea1"
assert verdict["production_source_matches_declared_candidate"] and verdict["selected_tests_unchanged"]
core = bool(re.search(r'Test "private CLI cache preserves explicit unified evidence through disk round trip" failed', log))
cli = bool(re.search(r'Test "private Cursor cache renders authoritative allowance labels" with 2 test cases failed', log))
assert core and cli
assert "Test run with 25 tests in 2 suites failed" in log
assert "with 6 issues" in log and 'contains("Weekly: 20% left")' in log
assert not re.search(r"error: (?:fatalError|Build failed)|Testing failed:|Command timed out", log)
assertions = re.findall(r"^[^\n]*Expectation failed:.*?(?=^[◇✘✔]|\Z)", log, re.MULTILINE | re.DOTALL)
assert len(assertions) == 6
verdict.update(cli_renderer_regression_failed=True, behavioral_red=True,
               classification="Local reclassification of original hosted runtime; no product rerun",
               explanation='Parameterized Swift Testing summary inserts "with 2 test cases" before "failed".',
               exact_runtime_assertions=[value.rstrip() for value in assertions],
               exact_runtime_summary=[line for line in log.splitlines() if "Test run with 25 tests in 2 suites failed" in line],
               original_hosted_red_job_conclusion="failure",
               original_verdict_sha256=hashlib.sha256((artifact / "verdict.json").read_bytes()).hexdigest(),
               original_runtime_log_sha256=hashlib.sha256(log_bytes).hexdigest())
print(json.dumps(verdict, indent=2))
