import CoreGraphics
import SCommon

/// The app whose window a profile captures (SC-301).
public enum AppTarget: Sendable, Equatable, CustomStringConvertible {
    /// Whatever app is in front when the key is pressed.
    case frontmost
    /// A bundle id such as `com.google.Chrome`.
    case bundleID(String)
    /// An app name as the Dock shows it, such as `Safari`.
    case name(String)

    /// A value with a dot and no space is a bundle id, `frontmost` is the
    /// front app, anything else is a name.
    public init(_ text: String) {
        if text == "frontmost" {
            self = .frontmost
        } else if text.contains("."), !text.contains(" ") {
            self = .bundleID(text)
        } else {
            self = .name(text)
        }
    }

    public var description: String {
        switch self {
        case .frontmost:
            return "frontmost"
        case .bundleID(let id):
            return id
        case .name(let name):
            return name
        }
    }
}

/// Points cut off each side of the window before the capture.
public struct Insets: Sendable, Equatable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public static let zero = Insets(top: 0, left: 0, bottom: 0, right: 0)

    public init(
        top: Double,
        left: Double,
        bottom: Double,
        right: Double
    ) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

/// One block of the profiles file: which window, where it goes, what part of
/// it is kept and at what scale. The output is always `(size - inset) x scale`
/// pixels, whatever the display's backing scale (SC-303).
public struct Profile: Sendable, Equatable {
    public var name: String
    public var app = AppTarget.frontmost
    /// A substring of the window title; nil takes the app's front window.
    public var window: String?
    /// Top-left of the window in points, from the top-left of the main display.
    public var origin: CGPoint?
    /// Window size in points; nil captures the window at whatever size it has.
    public var size: CGSize?
    public var inset = Insets.zero
    /// Output pixels per point, 1 or 2.
    public var scale = 2

    public init(name: String) {
        self.name = name
    }

    /// The frame the window is placed at, when the profile gives one.
    public var frame: CGRect? {
        guard let origin, let size else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    /// The kept part of a window of `windowSize`, in points from its top-left;
    /// nil when the inset leaves nothing.
    public func crop(windowSize: CGSize) -> CGRect? {
        let rect = CGRect(
            x: inset.left,
            y: inset.top,
            width: windowSize.width - inset.left - inset.right,
            height: windowSize.height - inset.top - inset.bottom
        )
        guard rect.width >= 1, rect.height >= 1 else {
            return nil
        }
        return rect
    }

    /// Output pixels for a window of `windowSize`.
    public func pixelSize(windowSize: CGSize) -> PixelSize? {
        guard let crop = crop(windowSize: windowSize) else {
            return nil
        }
        return PixelSize(
            width: Int((crop.width * Double(scale)).rounded()),
            height: Int((crop.height * Double(scale)).rounded())
        )
    }
}

public struct PixelSize: Sendable, Hashable, CustomStringConvertible {
    public var width: Int
    public var height: Int

    public init(
        width: Int,
        height: Int
    ) {
        self.width = width
        self.height = height
    }

    public var description: String { "\(width)x\(height)" }
}

/// The profiles file, `~/.config/scapture/profiles`: blocks that start with
/// `profile <name>`, each followed by `key value` lines. Bad lines are issues;
/// a profile keeps its other lines.
public enum Profiles {
    public static func parse(_ text: String) -> (profiles: [Profile], issues: [LineIssue]) {
        var profiles: [Profile] = []
        var issues: [LineIssue] = []
        var starts: [Int] = []
        func issue(_ line: Int, _ message: String) {
            issues.append(LineIssue(line: line, message: message))
        }
        for entry in KeyValueParser.parse(text) {
            if entry.key == "profile" {
                if !CaseStore.isValidID(entry.value) {
                    issue(entry.line, "profile name '\(entry.value)' should be lower-case words joined by hyphens")
                } else if profiles.contains(where: { $0.name == entry.value }) {
                    issue(entry.line, "profile '\(entry.value)' is defined twice")
                }
                profiles.append(Profile(name: entry.value))
                starts.append(entry.line)
                continue
            }
            guard !profiles.isEmpty else {
                issue(entry.line, "'\(entry.key)' comes before any 'profile <name>' line")
                continue
            }
            let numbers = entry.value.split(separator: " ").map { Double($0) }
            let values = numbers.compactMap { $0 }
            let allNumbers = !numbers.isEmpty && values.count == numbers.count
            switch entry.key {
            case "app":
                guard !entry.value.isEmpty else {
                    issue(entry.line, "app needs a bundle id, a name or frontmost")
                    continue
                }
                profiles[profiles.count - 1].app = AppTarget(entry.value)
            case "window":
                profiles[profiles.count - 1].window = entry.value.isEmpty ? nil : entry.value
            case "origin":
                guard allNumbers, values.count == 2 else {
                    issue(entry.line, "origin takes two numbers, x y in points")
                    continue
                }
                profiles[profiles.count - 1].origin = CGPoint(x: values[0], y: values[1])
            case "size":
                guard allNumbers, values.count == 2, values[0] >= 1, values[1] >= 1 else {
                    issue(entry.line, "size takes two positive numbers, width height in points")
                    continue
                }
                profiles[profiles.count - 1].size = CGSize(width: values[0], height: values[1])
            case "inset":
                guard allNumbers, values.count == 4, values.allSatisfy({ $0 >= 0 }) else {
                    issue(entry.line, "inset takes four numbers, top left bottom right in points")
                    continue
                }
                profiles[profiles.count - 1].inset = Insets(top: values[0], left: values[1], bottom: values[2], right: values[3])
            case "scale":
                guard entry.value == "1" || entry.value == "2" else {
                    issue(entry.line, "scale is 1 or 2")
                    continue
                }
                profiles[profiles.count - 1].scale = Int(entry.value)!
            default:
                issue(entry.line, "unknown profile key '\(entry.key)'")
            }
        }
        for (profile, line) in zip(profiles, starts) where (profile.origin == nil) != (profile.size == nil) {
            issue(line, "profile '\(profile.name)' has only one of origin and size; it is not positioned")
        }
        issues.sort { $0.line < $1.line }
        let unique = profiles.reduce(into: [Profile]()) { kept, profile in
            if CaseStore.isValidID(profile.name), !kept.contains(where: { $0.name == profile.name }) {
                kept.append(profile)
            }
        }
        return (unique, issues)
    }

    public static let defaultText = """
        # sCapture profiles. A block starts with `profile <name>`; the lines
        # after it describe one window. Every capture of a profile has the same
        # pixel size: (size - inset) x scale.
        #
        #   app      bundle id (com.google.Chrome), app name (Safari) or frontmost
        #   window   part of the window title; without it the app's front window
        #   origin   x y of the window's top-left in points, from the main display's
        #   size     width height of the window in points
        #   inset    top left bottom right, points cut off the window (title bar,
        #            tabs, toolbar, border)
        #   scale    1 or 2 output pixels per point
        #
        # Without origin and size the window is captured where and as it is.
        # The first nine profiles have keys ctrl-alt-1 to ctrl-alt-9.

        profile front-window
        app frontmost
        scale 2

        # Chrome without its title bar, tabs and address bar: 3036 x 1784
        profile console-chrome
        app com.google.Chrome
        origin 200 50
        size 1520 980
        inset 87 1 1 1
        scale 2
        """
}
