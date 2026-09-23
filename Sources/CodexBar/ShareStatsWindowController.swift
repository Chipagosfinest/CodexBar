import AppKit
import SwiftUI

@MainActor
final class ShareStatsPresenter {
    static let shared = ShareStatsPresenter()

    private var windowController: ShareStatsWindowController?

    func present(payload: ShareStatsPayload) {
        let controller = self.windowController ?? ShareStatsWindowController(payload: payload)
        controller.update(payload: payload)
        self.windowController = controller
        controller.present()
    }
}

@MainActor
final class ShareStatsWindowController: NSWindowController, NSWindowDelegate {
    private(set) var payload: ShareStatsPayload

    init(payload: ShareStatsPayload) {
        self.payload = payload
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 565),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = L("Share AI Usage")
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        self.installContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(payload: ShareStatsPayload) {
        self.payload = payload
        self.installContent()
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        self.showWindow(nil)
        self.window?.makeKeyAndOrderFront(nil)
    }

    private func installContent() {
        self.window?.contentViewController = NSHostingController(rootView: ShareStatsPreviewView(
            payload: self.payload,
            copyImage: { [weak self] in
                guard let self else { return false }
                return ShareStatsExporter.copyImage(self.payload)
            },
            copyText: { [weak self] in
                guard let self else { return }
                ShareStatsExporter.copyText(self.payload)
            },
            saveImage: { [weak self] in
                guard let self else { return false }
                return ShareStatsExporter.saveImage(self.payload)
            }))
    }
}

enum ShareStatsImageCopyFeedback: Equatable {
    case idle
    case copied
    case failed

    var title: String {
        switch self {
        case .idle: L("Copy Image")
        case .copied: L("Image copied")
        case .failed: L("Could not copy image")
        }
    }

    var systemImage: String {
        self == .copied ? "checkmark" : "photo.on.rectangle"
    }
}

private struct ShareStatsPreviewView: View {
    let payload: ShareStatsPayload
    let copyImage: @MainActor () -> Bool
    let copyText: @MainActor () -> Void
    let saveImage: @MainActor () -> Bool

    @State private var statusMessage: String?
    @State private var imageCopyFeedback: ShareStatsImageCopyFeedback = .idle
    @State private var imageCopyResetTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 20) {
            ShareStatsScaledPreview(payload: self.payload)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)

            HStack(spacing: 12) {
                Button {
                    self.copyImageToPasteboard()
                } label: {
                    Label(
                        self.imageCopyFeedback.title,
                        systemImage: self.imageCopyFeedback.systemImage)
                        .contentTransition(self.reduceMotion ? .identity : .symbolEffect(.replace))
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel(self.imageCopyFeedback.title)
                .buttonStyle(SharePreviewButtonStyle(prominent: true))

                Button {
                    self.copyText()
                    self.statusMessage = L("Stats copied")
                } label: {
                    Label(L("Copy Stats"), systemImage: "doc.on.doc")
                }
                .buttonStyle(SharePreviewButtonStyle(prominent: false))

                Button {
                    if self.saveImage() {
                        self.statusMessage = L("Image saved")
                    }
                } label: {
                    Label(L("Save..."), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(SharePreviewButtonStyle(prominent: false))

                Spacer()

                Text(self.statusMessage ?? L("Nothing is uploaded. This image is created on your Mac."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(self
                        .statusMessage ?? L("Nothing is uploaded. This image is created on your Mac."))
            }
        }
        .padding(24)
        .frame(minWidth: 780, minHeight: 525)
        .onDisappear {
            self.imageCopyResetTask?.cancel()
        }
    }

    private func copyImageToPasteboard() {
        self.imageCopyResetTask?.cancel()
        guard self.copyImage() else {
            self.imageCopyFeedback = .failed
            self.statusMessage = self.imageCopyFeedback.title
            self.imageCopyResetTask = self.makeCopyFeedbackResetTask()
            return
        }
        if !self.reduceMotion {
            withAnimation(.easeOut(duration: 0.12)) {
                self.imageCopyFeedback = .copied
            }
        } else {
            self.imageCopyFeedback = .copied
        }
        self.statusMessage = self.imageCopyFeedback.title
        self.imageCopyResetTask = self.makeCopyFeedbackResetTask()
    }

    /// Returns the button to its idle label after a beat. Failure needs this as much as success:
    /// without it a single failed copy leaves "Could not copy image" on the control, and on its
    /// accessibility label, until the window is closed and reopened.
    private func makeCopyFeedbackResetTask() -> Task<Void, Never> {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            if !self.reduceMotion {
                withAnimation(.easeOut(duration: 0.12)) {
                    self.imageCopyFeedback = .idle
                }
            } else {
                self.imageCopyFeedback = .idle
            }
        }
    }
}

private struct SharePreviewButtonStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .foregroundStyle(self.prominent ? Color.white : Color.primary.opacity(0.82))
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(self.prominent
                        ? Color(red: 0.78, green: 0.37, blue: 0.23)
                        : Color.primary.opacity(configuration.isPressed ? 0.11 : 0.055))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(self.prominent ? 0.08 : 0.09), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && !self.reduceMotion ? 0.985 : 1)
            .animation(self.reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct ShareStatsScaledPreview: View {
    let payload: ShareStatsPayload

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / ShareStatsCardView.size.width,
                proxy.size.height / ShareStatsCardView.size.height)
            ShareStatsCardView(payload: self.payload)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(ShareStatsCardView.size.width / ShareStatsCardView.size.height, contentMode: .fit)
    }
}
