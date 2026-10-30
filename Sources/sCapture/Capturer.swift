import AppKit
import CoreGraphics
import ScreenCaptureKit
import SCaptureCore

/// One-shot window capture through ScreenCaptureKit (SC-201): the window
/// alone, without shadow or cursor, the kept rect scaled to exactly the
/// profile's pixel size whatever the display's backing scale (SC-303).
@MainActor
final class SCKCapturer: Capturer {
    func capture(
        _ window: WindowInfo,
        crop: CGRect,
        pixels: PixelSize
    ) async throws(CaptureError) -> CGImage {
        guard CGPreflightScreenCaptureAccess() else {
            throw .screenRecordingDenied
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
            guard let target = content.windows.first(where: { $0.windowID == window.id }) else {
                throw CaptureError.noWindow(app: window.app, title: window.title.isEmpty ? nil : window.title)
            }
            let filter = SCContentFilter(desktopIndependentWindow: target)
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = crop
            configuration.width = pixels.width
            configuration.height = pixels.height
            configuration.scalesToFit = false
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            configuration.captureResolution = .best
            configuration.colorSpaceName = CGColorSpace.sRGB
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.shouldBeOpaque = true
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch let error as CaptureError {
            throw error
        } catch let error as SCStreamError where error.code == .userDeclined {
            throw .screenRecordingDenied
        } catch {
            throw .capture(error.localizedDescription)
        }
    }
}

/// The two permissions, checked without prompting and asked for once.
enum Permissions {
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }
    static var accessibility: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt the first time; later calls only answer.
    @discardableResult
    static func requestScreenRecording() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
