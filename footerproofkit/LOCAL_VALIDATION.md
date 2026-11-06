# Local static preparation only

Applied the exact overlay to a new clean disposable detached checkout at product
`e8a0cca51036fa8f30362a0710754d812ace34a3`.

- Only CodexbarApp.swift's declared early hook changed; PackagedFooterProof.swift
  was the only added source. All other source/tracked input hashes were preserved.
- Actual resulting entrypoint plus adapter syntax parse passed.
- Adapter SwiftFormat / strict SwiftLint passed with zero violations.
- Native UI helper was copied byte-for-byte from immutable controller
  f79b05bb5da0f9be4389a48dd66710e58415a9fc:proofkit/chart-app/ui.swift;
  actual local AppKit typecheck passed (deprecation warnings only).
- All Python files compile, workflow YAML parses.
- No actual App build, UI helper execution, app installation/launch, provider,
  Keychain, browser or local preferences action was performed.

These checks are not actual UI acceptance and not behavioral RED. Hosted GUI
preflight, actual App compilation and original-media inspection remain required.

Shared chart setup failure was classified before footer launch: the footer copy
now explicitly marks nested Delegate @MainActor, and BOTH UsageSnapshot
initializers pass required secondary:nil. A fresh clean overlay prepare was
repeated for these corrected bytes. A separate actual AppKit Swift6 typecheck
validated the delegate's selector-based NSMenu tracking observers and deinit.
Full App module semantic compilation still belongs to the hosted build.
