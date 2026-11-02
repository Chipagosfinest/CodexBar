mutant-owner-red: StatusItemController+OverviewSubmenus.swift, `sender.menu?.supermenu ?? sender.menu` -> `sender.menu`
mutant-close-red: StatusItemController+Menu.swift, menuDidClose gains `if menu.supermenu != nil { settings.mergedMenuLastSelectedWasOverview = false }`
base-red: upstream main 897bff317 plus only Tests/CodexBarTests/OverviewBoundedMenuTests.swift
head-green: this PR's head test file against unmodified Sources
Run locally with Swift Testing in a mirrored checkout carrying a local-only test target; nothing here is pushed to the PR.
