import CoreGraphics
import Foundation

/// A window on screen as the app layer finds it.
public struct WindowInfo: Sendable, Equatable {
    /// The `CGWindowID`.
    public var id: UInt32
    public var pid: Int32
    public var app: String
    public var title: String
    /// In points, top-left origin, from the top-left of the main display.
    public var frame: CGRect
    /// Pixels per point of the display the window is on.
    public var backingScale: Double

    public init(
        id: UInt32,
        pid: Int32,
        app: String,
        title: String,
        frame: CGRect,
        backingScale: Double
    ) {
        self.id = id
        self.pid = pid
        self.app = app
        self.title = title
        self.frame = frame
        self.backingScale = backingScale
    }
}

/// Finds a profile's window; Accessibility and the window list in the app.
@MainActor
public protocol WindowResolver {
    func resolve(_ profile: Profile) async throws(CaptureError) -> WindowInfo
    /// The same window again, with its current frame.
    func refresh(_ window: WindowInfo) async throws(CaptureError) -> WindowInfo
}

/// Moves and resizes another app's window; Accessibility in the app.
@MainActor
public protocol Positioner {
    /// Returns the frame the window ended up with.
    func place(
        _ window: WindowInfo,
        at frame: CGRect
    ) async throws(CaptureError) -> CGRect
}

/// Takes the picture; ScreenCaptureKit in the app.
@MainActor
public protocol Capturer {
    /// `crop` is in points from the window's top-left; the image is exactly
    /// `pixels`.
    func capture(
        _ window: WindowInfo,
        crop: CGRect,
        pixels: PixelSize
    ) async throws(CaptureError) -> CGImage
}

public enum CaptureError: Error, Equatable, CustomStringConvertible {
    case noCase
    case caseMissing(String)
    case appNotRunning(String)
    case noWindow(app: String, title: String?)
    case noLastWindow
    case screenRecordingDenied
    case accessibilityDenied
    case placeRefused(String)
    case emptyCrop(String)
    case capture(String)
    case write(String)

    public var description: String {
        switch self {
        case .noCase:
            return "no active case: pick or create one in the menu"
        case .caseMissing(let id):
            return "the case folder \(id) is gone"
        case .appNotRunning(let app):
            return "\(app) is not running"
        case .noWindow(let app, let title):
            return title.map { "\(app) has no window titled '\($0)'" } ?? "\(app) has no window to capture"
        case .noLastWindow:
            return "nothing captured yet to repeat"
        case .screenRecordingDenied:
            return "sCapture needs Screen Recording: System Settings > Privacy & Security"
        case .accessibilityDenied:
            return "placing windows needs Accessibility: System Settings > Privacy & Security"
        case .placeRefused(let app):
            return "\(app) did not let its window be placed"
        case .emptyCrop(let profile):
            return "the inset of \(profile) leaves nothing of the window"
        case .capture(let message):
            return "capture failed: \(message)"
        case .write(let message):
            return message
        }
    }
}

public struct CaptureResult: Sendable, Equatable {
    public var file: URL
    public var caseID: String
    /// Images in the case after this one.
    public var count: Int
    public var pixels: PixelSize
    /// The captured part of the screen in points, for the flash.
    public var rect: CGRect
    public var warnings: [String]
    public var milliseconds: Int
}

public struct PlaceResult: Sendable, Equatable {
    public var window: WindowInfo
    public var warnings: [String]
}

/// A capture kept in memory, for trying a profile in the Profiles window.
public struct TestResult {
    public var image: CGImage
    public var pixels: PixelSize
    /// The captured part of the screen in points, for the flash.
    public var rect: CGRect
    public var warnings: [String]
    public var milliseconds: Int
}

/// What a capture and a test capture share: the window, where it was, the
/// image and what to warn about.
private struct Shot {
    var window: WindowInfo
    var crop: CGRect
    var pixels: PixelSize
    var image: CGImage
    var warnings: [String]

    var rect: CGRect {
        crop.offsetBy(dx: window.frame.minX, dy: window.frame.minY)
    }
}

/// One capture from key press to file: resolve the window, place it, capture
/// the kept part at the profile's pixel size, write it under a new name, log.
@MainActor
public final class CaptureService {
    private let resolver: any WindowResolver
    private let positioner: any Positioner
    private let capturer: any Capturer
    private let now: () -> Date
    private let sleep: (Int) async -> Void
    private let timeZone: TimeZone
    public var log: URL?
    public private(set) var lastWindow: WindowInfo?

    public init(
        resolver: any WindowResolver,
        positioner: any Positioner,
        capturer: any Capturer,
        log: URL? = nil,
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Int) async -> Void = { try? await Task.sleep(for: .milliseconds($0)) }
    ) {
        self.resolver = resolver
        self.positioner = positioner
        self.capturer = capturer
        self.log = log
        self.timeZone = timeZone
        self.now = now
        self.sleep = sleep
    }

    /// Places the profile's window at its frame (SC-302); a window already in
    /// place is not touched.
    public func place(
        _ profile: Profile,
        config: Config,
        window given: WindowInfo? = nil
    ) async throws(CaptureError) -> PlaceResult {
        var window = try await (given == nil ? resolver.resolve(profile) : resolver.refresh(given!))
        var warnings: [String] = []
        guard let frame = profile.frame, !Self.same(window.frame, frame) else {
            return PlaceResult(window: window, warnings: warnings)
        }
        do {
            window.frame = try await positioner.place(window, at: frame)
            if !Self.same(window.frame.size, frame.size) {
                warnings.append("\(window.app) kept its window at \(Self.points(window.frame.size)), not \(Self.points(frame.size))")
            }
        } catch {
            warnings.append(error.description)
        }
        await sleep(config.settleMilliseconds)
        return PlaceResult(window: window, warnings: warnings)
    }

    /// Captures into `caseID`; `again` reuses the window captured last
    /// (SC-203) instead of resolving the profile's.
    public func capture(
        _ profile: Profile,
        caseID: String?,
        store: CaseStore,
        config: Config,
        again: Bool = false
    ) async throws(CaptureError) -> CaptureResult {
        let start = now()
        guard let caseID else {
            throw .noCase
        }
        guard store.exists(caseID) else {
            throw .caseMissing(caseID)
        }
        if again, lastWindow == nil {
            throw .noLastWindow
        }
        let shot = try await shoot(profile, config: config, again: again)
        guard let data = Writer.png(shot.image, scale: profile.scale) else {
            throw .write("could not encode the capture as PNG")
        }
        let namer = Namer(style: config.name, timeZone: timeZone)
        let folder = store.url(of: caseID)
        var written: String?
        for _ in 0..<3 where written == nil {
            guard let name = namer.name(at: start, caseID: caseID, existing: store.names(caseID)) else {
                break
            }
            do {
                try Writer.write(data, to: folder, name: name)
                written = name
            } catch .exists {
                continue
            } catch {
                throw .write(error.description)
            }
        }
        guard let written else {
            throw .write("no free file name in \(caseID) this second")
        }
        lastWindow = shot.window
        let milliseconds = Int((now().timeIntervalSince(start) * 1000).rounded())
        if let log {
            let line = Log.line(
                date: start,
                caseID: caseID,
                profile: profile.name,
                file: written,
                size: shot.pixels,
                milliseconds: milliseconds
            )
            try? Log.append(line, to: log)
        }
        return CaptureResult(
            file: folder.appendingPathComponent(written),
            caseID: caseID,
            count: store.count(caseID),
            pixels: shot.pixels,
            rect: shot.rect,
            warnings: shot.warnings,
            milliseconds: milliseconds
        )
    }

    /// Captures `profile` as a real capture would, placing the window when
    /// `auto_position` is on, but keeps the image: no case, no file, no log
    /// line, and the repeat key still takes the last real capture's window.
    public func test(
        _ profile: Profile,
        config: Config
    ) async throws(CaptureError) -> TestResult {
        let start = now()
        let shot = try await shoot(profile, config: config, again: false)
        return TestResult(
            image: shot.image,
            pixels: shot.pixels,
            rect: shot.rect,
            warnings: shot.warnings,
            milliseconds: Int((now().timeIntervalSince(start) * 1000).rounded())
        )
    }

    /// Resolves (or refreshes, for `again`) and places the window, then
    /// captures its kept part at the profile's pixel size.
    private func shoot(
        _ profile: Profile,
        config: Config,
        again: Bool
    ) async throws(CaptureError) -> Shot {
        var window: WindowInfo
        var warnings: [String] = []
        if config.autoPosition {
            let placed = try await place(profile, config: config, window: again ? lastWindow : nil)
            window = placed.window
            warnings = placed.warnings
        } else {
            window = try await (again ? resolver.refresh(lastWindow!) : resolver.resolve(profile))
        }
        guard let crop = profile.crop(windowSize: window.frame.size),
            let pixels = profile.pixelSize(windowSize: window.frame.size)
        else {
            throw .emptyCrop(profile.name)
        }
        if window.backingScale < Double(profile.scale) {
            warnings.append("upsampled: the window is on a \(Int(window.backingScale))x display")
        }
        let image = try await capturer.capture(window, crop: crop, pixels: pixels)
        return Shot(
            window: window,
            crop: crop,
            pixels: pixels,
            image: image,
            warnings: warnings
        )
    }

    static func same(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1 && same(a.size, b.size)
    }

    static func same(_ a: CGSize, _ b: CGSize) -> Bool {
        abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
    }

    static func points(_ size: CGSize) -> String {
        "\(Int(size.width.rounded())) x \(Int(size.height.rounded()))"
    }
}
