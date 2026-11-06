import Foundation

@main
struct CursorFixtureControls {
    static func main() throws {
        let cookie = "WorkosCursorSessionToken=synthetic-control-nonce"
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func request(
            _ path: String,
            method: String = "GET",
            host: String = "cursor.com",
            header: String? = nil) -> URLRequest
        {
            var r = URLRequest(url: URL(string: "https://\(host)\(path)")!)
            r.httpMethod = method; r.setValue(header ?? cookie, forHTTPHeaderField: "Cookie"); return r
        }
        var names: [String] = []
        func check(_ name: String, _ r: URLRequest, _ mode: String, _ status: Int?) {
            precondition(cursorFixtureReply(r, cookie: cookie, scenario: mode, now: now)?.status == status, name)
            names.append(name)
        }
        check("summary200", request("/api/usage-summary"), "allowances", 200)
        check("userinfo200", request("/api/auth/me"), "allowances", 200)
        check("sand200", request("/api/dashboard/get-sand-usage-status", method: "POST"), "allowances", 200)
        check("quota401", request("/api/usage-summary"), "manual401", 401)
        check("cost401", request("/api/dashboard/get-filtered-usage-events", method: "POST"), "manual401", 401)
        check(
            "costNotAllowedInAllowanceScenario",
            request("/api/dashboard/get-filtered-usage-events", method: "POST"),
            "allowances",
            nil)
        check("wrongCookie", request("/api/usage-summary", header: "invalid"), "allowances", nil)
        check("wrongHost", request("/api/usage-summary", host: "example.invalid"), "manual401", nil)
        check("wrongMethod", request("/api/usage-summary", method: "POST"), "allowances", nil)
        check("wrongRoute", request("/login"), "manual401", nil)
        check("queryRejected", request("/api/usage-summary?extra=1"), "allowances", nil)
        check("wrongScenario", request("/api/usage-summary"), "invalid", nil)
        guard let summaryReply = cursorFixtureReply(
            request("/api/usage-summary"),
            cookie: cookie,
            scenario: "allowances",
            now: now),
            let summary = try JSONSerialization.jsonObject(with: summaryReply.body) as? [String: Any],
            let individual = summary["individualUsage"] as? [String: Any],
            let plan = individual["plan"] as? [String: Any],
            let sandReply = cursorFixtureReply(
                request("/api/dashboard/get-sand-usage-status", method: "POST"),
                cookie: cookie,
                scenario: "allowances",
                now: now),
            let sand = try JSONSerialization.jsonObject(with: sandReply.body) as? [String: Any]
        else { throw CocoaError(.coderInvalidValue) }
        precondition(plan["totalPercentUsed"] as? Int == 20)
        precondition(sand["usagePercent"] as? Int == 80 && sand["isUnified"] as? Bool == false)
        try print(String(
            data: JSONSerialization
                .data(withJSONObject: ["controlsPassed": true, "cases": names], options: .prettyPrinted),
            encoding: .utf8)!)
    }
}
