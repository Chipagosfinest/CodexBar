import Foundation

@main
struct FooterOracleControls {
    static func main() throws {
        func final() -> FooterOracleObservation {
            FooterOracleObservation(
                ownedCompletionFinished: true,
                postCompletionRebuildObserved: true,
                storeHas42AndNoError: true,
                currentCardReplaced: true,
                currentViewReplaced: true,
                freshFingerprintPresent: true,
                currentViewInOriginalMoreWindow: true)
        }
        var results: [[String: Any]] = []
        func check(_ name: String, _ state: FooterOracleObservation, _ expected: FooterOracleDecision) {
            let actual = footerOracleDecision(state)
            precondition(actual == expected, "Oracle control failed: \(name)")
            results.append(["case": name, "actual": String(describing: actual), "matchesExpected": true])
        }
        check("post-owned-completion-rebuild-final", final(), .accepted)
        var stalePreopen = final()
        stalePreopen.baselineBoundInOpenMenus = false
        check("preopen-identity-difference-cannot-pass", stalePreopen, .failed("wrong-scope-or-baseline"))
        var beforeCompletion = final()
        beforeCompletion.ownedCompletionFinished = false
        check(
            "fresh-looking-before-owned-completion-cannot-pass",
            beforeCompletion,
            .waiting("owned-completion-and-rebuild-pending"))
        var beforeRebuild = final()
        beforeRebuild.postCompletionRebuildObserved = false
        check(
            "interim-identity-change-before-rebuild-cannot-pass",
            beforeRebuild,
            .waiting("owned-completion-and-rebuild-pending"))
        var interim = final()
        interim.freshFingerprintPresent = false
        check("interim-render-awaits-fresh-cache", interim, .waiting("interim-render-awaiting-complete-fresh-payload"))
        interim = final()
        interim.storeHas42AndNoError = false
        check(
            "retained-payload-awaits42-and-cleared-error",
            interim,
            .waiting("interim-render-awaiting-complete-fresh-payload"))
        interim = final()
        interim.currentViewInOriginalMoreWindow = false
        check(
            "fresh-cache-detached-view-cannot-pass",
            interim,
            .waiting("interim-render-awaiting-complete-fresh-payload"))
        interim = final()
        interim.currentCardReplaced = false
        interim.currentViewReplaced = false
        interim.currentViewInOriginalMoreWindow = false
        check(
            "temporarily-absent-nested-card-waits",
            interim,
            .waiting("interim-render-awaiting-complete-fresh-payload"))
        var wrongScope = final()
        wrongScope.correctNestedScope = false
        check("wrong-provider-or-parent-scope-fails", wrongScope, .failed("wrong-scope-or-baseline"))
        var closed = final()
        closed.rootTracked = false
        check("closed-root-fails", closed, .failed("menu-closed-or-reopened"))
        closed = final()
        closed.bothOriginalMenuWindowsVisible = false
        check("closed-more-window-fails", closed, .failed("menu-closed-or-reopened"))
        closed = final()
        closed.sameMoreEpoch = false
        check("reopened-more-epoch-fails", closed, .failed("menu-closed-or-reopened"))
        var expired = final()
        expired.deadlineExpired = true
        check("deadline-fails-even-if-final-now-looks-fresh", expired, .failed("replacement-deadline-expired"))
        try print(String(data: JSONSerialization.data(
            withJSONObject: ["controlsPassed": true, "cases": results],
            options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
