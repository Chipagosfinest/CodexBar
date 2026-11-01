import Foundation
import CodexBarCore

@main struct RoutingProof {
    static func main() async {
        let detector = BrowserDetection(cacheTTL: 0)
        for source in [ProviderCookieSource.auto, .manual, .off] {
            let context = ProviderFetchContext(runtime: .cli, sourceMode: .auto, includeCredits: false,
                webTimeout: 1, webDebugDumpHTML: false, verbose: false,
                env: ["OLLAMA_API_KEY": "synthetic-api-account"],
                settings: .make(ollama: .init(cookieSource: source,
                    manualCookieHeader: source == .manual ? "session=synthetic-cookie-account" : nil)),
                fetcher: UsageFetcher(), claudeFetcher: ClaudeUsageFetcher(browserDetection: detector),
                browserDetection: detector)
            let strategies = await OllamaProviderDescriptor.descriptor.fetchPlan.pipeline.resolveStrategies(context)
            print("Auto source with saved cookieSource=\(source): \(strategies.map(\.id).joined(separator: " -> "))")
        }
    }
}
