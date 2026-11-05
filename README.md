# Share-card render QA — 2026-11-05

Product: PR #4888, `faed79c392ff940698587950a1809589e04ed394`.

Fresh PNGs from the production `ShareStatsRenderer`, with synthetic payloads. These are exported cards, not screenshots of the preview window or evidence of button/menu interaction. No real provider, account, clipboard, or personal data appears in these assets. No product source changes were needed for this pass.

- Existing `ShareStatsTests` + `ShareStatsModelSharesTests`: 28 tests across two suites passed, including 1200×630 PNG/TIFF export to an isolated named pasteboard and explicit appearance checks.
- Existing `ShareStatsCompletenessTests` + `ShareStatsPeriodTests`: 7 tests across two suites passed.
- Research-only harness: one exploratory rendering test passed; seven payload states rendered in light and dark. Harness preserved here, removed from the product worktree after the pass.
- Inspected all fourteen representative exports and seven localized exports. OCR of saved English/German/Spanish/French labels confirmed complete text. Provider overflow, partial-data labeling, unavailable amounts, and neutral light/dark appearances looked sound in these fixtures.

Files and hashes: [manifest](share-card-qa/manifest.json). Fixture source: [harness](share-card-qa/ShareStatsVisualProofTests.swift).

Remaining: normal preview-to-export fidelity; Copy Image/Stats and Save/cancel through actual controls; focus, keyboard, dismissal and appearance changes in the running app. No interactive or whole-PR sign-off is claimed.

## Widget pair

[Combined #4887 + #4890 evidence](widget-pair-qa/README.md): tested integration recipe, controlled red/green comparison and current localized/account-overflow renders. Explicit installed-host and interaction gaps remain.
