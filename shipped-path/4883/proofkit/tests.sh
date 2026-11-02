#!/bin/bash
# Runs the PR's own test file at base, against head with its production change neutralised, and at head.
set -u
product=$1; out=$2
cd "$product" || exit 2
T=Tests/CodexBarTests/MenuCardStaleTintTests.swift
cp "$T" "$out/MenuCardStaleTintTests.swift"
run() { # name
  swift test --filter MenuCardStaleTintTests > "$out/$1.log" 2>&1
  echo "$1 exit=$?" | tee -a "$out/summary.txt"
}
# 1. Head first so the later runs build incrementally and the pass result is never a leftover.
git checkout -q "$HEAD_SHA"; git rev-parse HEAD >> "$out/summary.txt"; run head-pass
# 2. Head with only the production derivation neutralised: the API exists, so failures are assertions.
python3 - <<'E'
p='Sources/CodexBar/Menu/MenuCardMetricRow.swift'; s=open(p).read()
a='self.isRetainedMeasurement ? UsageMenuCardView.Model.staleProgressColor : self.progressColor'
assert a in s; open(p,'w').write(s.replace(a,'self.progressColor'))
p='Sources/CodexBar/Menu/MenuCardView.swift'; s=open(p).read()
a='let showsRetainedMeasurement = input.snapshot != nil && Self.lastError(input: input) != nil'
assert a in s; open(p,'w').write(s.replace(a,'let showsRetainedMeasurement = false'))
E
git diff > "$out/head-neutralised.patch"; run head-neutralised-fail; git checkout -q -- Sources
# 3. Base production code with the PR's test file: the tests name API the base does not have.
git checkout -q "$BASE_SHA"; git rev-parse HEAD >> "$out/summary.txt"; cp "$out/MenuCardStaleTintTests.swift" "$T"; run base-fail
rm -f "$T"; git checkout -q "$HEAD_SHA"
for f in head-pass head-neutralised-fail base-fail; do
  { echo "=== $f"; grep -E "error:.*(MenuCardStaleTint|Retained|staleProgress|barTint)|✘|✔|Test run with|recorded an issue|Expectation failed|Build complete|error: fatalError" "$out/$f.log" | cut -c1-200 | sort -u | head -40; } >> "$out/excerpt.txt"
done
cat "$out/summary.txt" "$out/excerpt.txt"
