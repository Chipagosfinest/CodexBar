import SwiftUI
import Testing
import WidgetKit
@testable import CodexBarWidget

struct WidgetLowQuotaInkTests {
    @Test
    func `full colour widgets show a low limit in red`() {
        #expect(WidgetInk.lowBar(renderingMode: .fullColor) == .red)
    }

    @Test
    func `masked widgets keep a low limit at full ink strength`() {
        // Red reads dimmer than ink through a luminance mask, which would invert the warning.
        for mode in [WidgetRenderingMode.accented, .vibrant] {
            #expect(WidgetInk.lowBar(renderingMode: mode) == .primary)
            #expect(WidgetInk.lowBar(renderingMode: mode) != WidgetInk.data)
        }
    }
}
