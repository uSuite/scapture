/// Every action a global key or the menu can start; each has the kebab-case
/// name the keymap file uses.
public enum Command: Sendable, Hashable, CustomStringConvertible {
    /// Capture the active profile's window into the active case.
    case captureWindow
    /// Capture the window captured last, without resolving it again.
    case captureRepeat
    /// Place the profile's window at its frame without capturing.
    case position
    /// Open the menu bar item's menu, where the cases and profiles are.
    case openMenu
    /// Show the active case folder in Finder.
    case openCase
    /// Make the profile at this position (1 to 9) in the profiles file active.
    case profile(Int)

    private static let simple: [String: Command] = [
        "capture-window": .captureWindow,
        "capture-repeat": .captureRepeat,
        "position": .position,
        "open-menu": .openMenu,
        "open-case": .openCase,
    ]

    /// Every command name, for messages and the docs.
    public static let names: [String] = Array(simple.keys).sorted() + ["profile <1-9>"]

    /// `name [arg]` as the keymap file writes it; nil when unknown.
    public static func parse(_ text: String) -> Command? {
        let words = text.split(separator: " ").map(String.init)
        guard let name = words.first else {
            return nil
        }
        if words.count == 1, let command = simple[name] {
            return command
        }
        if name == "profile", words.count == 2, let n = Int(words[1]), (1...9).contains(n) {
            return .profile(n)
        }
        return nil
    }

    public var description: String {
        if case .profile(let n) = self {
            return "profile \(n)"
        }
        return Self.simple.first { $0.value == self }!.key
    }
}
