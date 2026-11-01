import CodexBarCore
import Foundation
import Testing
@testable import CodexBarWidget

@MainActor
struct WidgetProviderMarkAssetTests {
    private static let curatedProviders: [UsageProvider] = [
        .codex, .claude, .cursor, .copilot, .gemini, .antigravity, .devin, .kilo, .kimi,
        .minimax, .mistral, .opencode, .opencodego, .qwencloud, .zai, .alibaba, .alibabatokenplan,
    ]

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test
    func `every curated widget provider draws its real mark`() {
        for provider in Self.curatedProviders {
            #expect(WidgetProviderMarkAsset.image(for: provider, fullColor: false) != nil, "\(provider.rawValue)")
            #expect(WidgetProviderMarkAsset.image(for: provider, fullColor: true) != nil, "\(provider.rawValue)")
        }
    }

    @Test
    func `template marks stay templates so tinted widgets can mask them`() throws {
        let template = try #require(WidgetProviderMarkAsset.image(for: .gemini, fullColor: false))
        let curated = try #require(WidgetProviderMarkAsset.image(for: .claude, fullColor: true))

        #expect(template.isTemplate)
        #expect(!curated.isTemplate)
    }

    @Test
    func `bundled widget marks are byte identical to the app resources`() throws {
        let widgetMarks = Self.repositoryRoot.appendingPathComponent("Sources/CodexBarWidget/Resources/ProviderMarks")
        let appResources = Self.repositoryRoot.appendingPathComponent("Sources/CodexBar/Resources")
        let files = try FileManager.default.contentsOfDirectory(atPath: widgetMarks.path).filter { !$0.hasPrefix(".") }

        #expect(!files.isEmpty)
        for file in files {
            let copy = try Data(contentsOf: widgetMarks.appendingPathComponent(file))
            let original = try Data(contentsOf: appResources.appendingPathComponent(file))
            #expect(copy == original, "\(file) drifted from Sources/CodexBar/Resources")
        }
    }
}
