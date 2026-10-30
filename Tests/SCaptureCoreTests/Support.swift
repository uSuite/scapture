import CoreGraphics
import Foundation
@testable import SCaptureCore

/// A throwaway directory under the system temp folder, removed on deinit.
final class TempFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scapture-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func touch(
        _ path: String,
        modified: Date? = nil
    ) throws {
        let file = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: file)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: file.path)
        }
    }

    func folder(
        _ path: String,
        modified: Date? = nil
    ) throws {
        let folder = url.appendingPathComponent(path, isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: folder.path)
        }
    }
}

/// A fixed clock in UTC, so names do not depend on the machine's zone.
enum Clock {
    static let utc = TimeZone(identifier: "UTC")!

    /// 2026-10-28 09:34:35 UTC.
    static let now = Date(timeIntervalSince1970: 1_793_180_075)
}

/// A solid image of `width` x `height` pixels in `space`.
func solidImage(
    width: Int,
    height: Int,
    space: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
) -> CGImage {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(red: 0.1, green: 0.75, blue: 0.46, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

@MainActor
final class FakeWindows: WindowResolver, Positioner, Capturer {
    var window: WindowInfo
    var resolveError: CaptureError?
    var placeError: CaptureError?
    /// The size the app lets its window take; nil takes any.
    var fixedSize: CGSize?
    var resolved: [String] = []
    var placed: [CGRect] = []
    var captured: [(crop: CGRect, pixels: PixelSize)] = []

    init(frame: CGRect = CGRect(x: 0, y: 25, width: 800, height: 600), backingScale: Double = 2) {
        window = WindowInfo(
            id: 42,
            pid: 7,
            app: "Chrome",
            title: "console",
            frame: frame,
            backingScale: backingScale
        )
    }

    func resolve(_ profile: Profile) async throws(CaptureError) -> WindowInfo {
        resolved.append(profile.name)
        if let resolveError {
            throw resolveError
        }
        return window
    }

    func refresh(_ window: WindowInfo) async throws(CaptureError) -> WindowInfo {
        resolved.append("refresh")
        return self.window
    }

    func place(
        _ window: WindowInfo,
        at frame: CGRect
    ) async throws(CaptureError) -> CGRect {
        placed.append(frame)
        if let placeError {
            throw placeError
        }
        self.window.frame = CGRect(origin: frame.origin, size: fixedSize ?? frame.size)
        return self.window.frame
    }

    func capture(
        _ window: WindowInfo,
        crop: CGRect,
        pixels: PixelSize
    ) async throws(CaptureError) -> CGImage {
        captured.append((crop, pixels))
        return solidImage(width: pixels.width, height: pixels.height)
    }
}
