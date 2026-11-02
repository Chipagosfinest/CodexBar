# PR 4902: Show details real-click proof

- `after/`: unmodified release package of `0ff1e04c1`, real CGEvent input, synthetic fixture data. Run 41391784267.
- `diagnosis/`: lifecycle log from a temporary instrumented build (`instrumentation.patch`, never part of the PR). Run 41387208938.
- `kit/`: scenario and workflow. Shared harness: fork branch `proof/ui-lane`, `proofkit/`.
