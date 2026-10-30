import AppKit
import ApplicationServices
import SCaptureCore

/// Finds a profile's window in the window list and places it through the
/// Accessibility API. The window list gives ids and frames without any
/// permission; titles need Screen Recording, which capture needs anyway.
@MainActor
final class Windows: WindowResolver, Positioner {
    func resolve(_ profile: Profile) async throws(CaptureError) -> WindowInfo {
        let apps = try Self.apps(profile.app)
        let app = apps[0]
        // every copy of the app counts: a second copy of sCapture, as the
        // smoke test runs beside an installed one, has the window wanted
        let pids = Set(apps.map(\.processIdentifier))
        var candidates = Self.list().filter { pids.contains($0.pid) }
        if let title = profile.window {
            candidates = candidates.filter { $0.title.localizedCaseInsensitiveContains(title) }
        }
        // apps keep small untitled helper windows in front of their real ones
        // (Chrome has several), so a titled window of a usable size wins
        guard let match = candidates.first(where: Self.isDocument) ?? candidates.first else {
            throw .noWindow(app: app.localizedName ?? profile.app.description, title: profile.window)
        }
        return match
    }

    func refresh(_ window: WindowInfo) async throws(CaptureError) -> WindowInfo {
        guard let current = Self.list(only: window.id).first else {
            throw .noWindow(app: window.app, title: window.title.isEmpty ? nil : window.title)
        }
        return current
    }

    func place(
        _ window: WindowInfo,
        at frame: CGRect
    ) async throws(CaptureError) -> CGRect {
        guard AXIsProcessTrusted() else {
            throw .accessibilityDenied
        }
        guard let element = Self.element(of: window) else {
            throw .placeRefused(window.app)
        }
        // size, position, size: a window that would leave the screen at its
        // old size is clamped, so the size goes once more after the move
        Self.set(element, kAXSizeAttribute, frame.size)
        Self.set(element, kAXPositionAttribute, frame.origin)
        Self.set(element, kAXSizeAttribute, frame.size)
        guard let placed = Self.list(only: window.id).first else {
            throw .placeRefused(window.app)
        }
        return placed.frame
    }

    static func isDocument(_ window: WindowInfo) -> Bool {
        !window.title.isEmpty && window.frame.width >= 160 && window.frame.height >= 120
    }

    private static func apps(_ target: AppTarget) throws(CaptureError) -> [NSRunningApplication] {
        let apps = NSWorkspace.shared.runningApplications
        let found: [NSRunningApplication]
        switch target {
        case .frontmost:
            found = NSWorkspace.shared.frontmostApplication.map { [$0] } ?? []
        case .bundleID(let id):
            found = apps.filter { $0.bundleIdentifier == id }
        case .name(let name):
            found = apps.filter { $0.localizedName?.caseInsensitiveCompare(name) == .orderedSame }
        }
        guard !found.isEmpty else {
            throw .appNotRunning(target.description)
        }
        return found
    }

    /// Normal windows on screen, front to back, or the one with `id`.
    static func list(only id: UInt32? = nil) -> [WindowInfo] {
        let options: CGWindowListOption = id == nil ? [.optionOnScreenOnly, .excludeDesktopElements] : [.optionIncludingWindow]
        let raw = CGWindowListCopyWindowInfo(options, id ?? kCGNullWindowID) as? [[String: Any]] ?? []
        return raw.compactMap { info -> WindowInfo? in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                let number = info[kCGWindowNumber as String] as? UInt32,
                let pid = info[kCGWindowOwnerPID as String] as? Int32,
                let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                let frame = CGRect(dictionaryRepresentation: bounds),
                frame.width > 1,
                frame.height > 1
            else {
                return nil
            }
            return WindowInfo(
                id: number,
                pid: pid,
                app: info[kCGWindowOwnerName as String] as? String ?? "",
                title: info[kCGWindowName as String] as? String ?? "",
                frame: frame,
                backingScale: backingScale(of: frame)
            )
        }
    }

    /// The scale of the display that holds most of `frame` (top-left points).
    static func backingScale(of frame: CGRect) -> Double {
        let screens = NSScreen.screens
        guard let main = screens.first else {
            return 2
        }
        let flipped = CGRect(
            x: frame.minX,
            y: main.frame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
        let best = screens.max { a, b in
            area(a.frame.intersection(flipped)) < area(b.frame.intersection(flipped))
        }
        return Double(best?.backingScaleFactor ?? main.backingScaleFactor)
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }

    /// The AX window with the same frame (and title, when there is one) as
    /// the window-list entry; AX has no public window id.
    private static func element(of window: WindowInfo) -> AXUIElement? {
        let app = AXUIElementCreateApplication(window.pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
            let elements = value as? [AXUIElement]
        else {
            return nil
        }
        let framed = elements.filter { element in
            guard let origin: CGPoint = get(element, kAXPositionAttribute),
                let size: CGSize = get(element, kAXSizeAttribute)
            else {
                return false
            }
            let frame = CGRect(origin: origin, size: size)
            return abs(frame.minX - window.frame.minX) < 1 && abs(frame.minY - window.frame.minY) < 1
                && abs(frame.width - window.frame.width) < 1 && abs(frame.height - window.frame.height) < 1
        }
        if framed.count > 1, !window.title.isEmpty {
            return framed.first { title(of: $0) == window.title } ?? framed.first
        }
        return framed.first
    }

    private static func title(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func get<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        let axValue = value as! AXValue
        if T.self == CGPoint.self {
            var point = CGPoint.zero
            return AXValueGetValue(axValue, .cgPoint, &point) ? point as? T : nil
        }
        if T.self == CGSize.self {
            var size = CGSize.zero
            return AXValueGetValue(axValue, .cgSize, &size) ? size as? T : nil
        }
        return nil
    }

    private static func set(
        _ element: AXUIElement,
        _ attribute: String,
        _ point: CGPoint
    ) {
        var point = point
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(element, attribute as CFString, value)
        }
    }

    private static func set(
        _ element: AXUIElement,
        _ attribute: String,
        _ size: CGSize
    ) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, attribute as CFString, value)
        }
    }
}
