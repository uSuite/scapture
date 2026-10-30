import Foundation
import SCommon

/// How capture files are named (SC-401, SC-402).
public enum NameStyle: String, Sendable, Equatable {
    /// `scap-YYYY-MM-DD-HHMMSS.png`, renamed later by an evidence script.
    case timestamp
    /// `<case-id>-<nn>.png`, final at once.
    case caseStep = "case-step"
}

/// Settings from `~/.config/scapture/config`. Unknown keys and bad values are
/// reported as issues and leave the default in place, so a typo never stops
/// the app from starting.
public struct Config: KeyValueSettings, Equatable {
    /// The folder whose sub-folders are the cases, `~` expanded on use.
    public var root = "~/Pictures/scapture"
    public var name = NameStyle.timestamp
    /// Place the window at the profile's frame before every capture.
    public var autoPosition = true
    /// Time for a moved window to redraw before it is captured.
    public var settleMilliseconds = 150
    public var flash = true
    /// Seconds the toast stays; 0 shows none.
    public var toastSeconds = 2

    public init() {}

    public enum SetError: Error, Equatable, CustomStringConvertible {
        case unknownKey(String)
        case badValue(key: String, value: String, expected: String)

        public var description: String {
            switch self {
            case .unknownKey(let key):
                return "unknown option '\(key)'"
            case .badValue(let key, let value, let expected):
                return "\(key): '\(value)' is not \(expected)"
            }
        }
    }

    public mutating func set(
        _ key: String,
        _ value: String
    ) throws(SetError) {
        switch key {
        case "root":
            guard value.hasPrefix("/") || value.hasPrefix("~/") else {
                throw .badValue(key: key, value: value, expected: "an absolute path or one starting with ~/")
            }
            root = value
        case "name":
            guard let style = NameStyle(rawValue: value) else {
                throw .badValue(key: key, value: value, expected: "timestamp or case-step")
            }
            name = style
        case "auto_position":
            autoPosition = try Self.bool(key, value)
        case "settle_ms":
            settleMilliseconds = try Self.int(key, value, range: 0...2000)
        case "flash":
            flash = try Self.bool(key, value)
        case "toast":
            toastSeconds = try Self.int(key, value, range: 0...10)
        default:
            throw .unknownKey(key)
        }
    }

    /// `root` with `~` replaced by `home`.
    public func rootURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        if root.hasPrefix("~/") {
            return home.appendingPathComponent(String(root.dropFirst(2)), isDirectory: true)
        }
        return URL(fileURLWithPath: root, isDirectory: true)
    }

    static func int(
        _ key: String,
        _ value: String,
        range: ClosedRange<Int>
    ) throws(SetError) -> Int {
        guard let n = Int(value), range.contains(n) else {
            throw .badValue(key: key, value: value, expected: "a number from \(range.lowerBound) to \(range.upperBound)")
        }
        return n
    }

    static func bool(
        _ key: String,
        _ value: String
    ) throws(SetError) -> Bool {
        switch value.lowercased() {
        case "yes", "true", "on":
            return true
        case "no", "false", "off":
            return false
        default:
            throw .badValue(key: key, value: value, expected: "yes or no")
        }
    }

    public static let defaultText = """
        # sCapture config. One setting per line: <key> <value>. Lines starting
        # with # are comments. Problems show in the menu.

        # the folder whose sub-folders are the cases
        root ~/Pictures/scapture

        # file names: timestamp (scap-2026-10-30-093435.png) or case-step
        # (<case-id>-07.png)
        name timestamp

        # place the window at the profile's frame before every capture
        auto_position yes

        # milliseconds a moved window gets to redraw before the capture
        settle_ms 150

        # flash the captured rectangle
        flash yes

        # seconds the thumbnail toast stays; 0 for none
        toast 2
        """
}
