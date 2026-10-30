import SCommon

/// The global keys from `~/.config/scapture/keymap`: one `<hotkey> <command>`
/// per line, applied over the shipped defaults; `<hotkey> nop` unbinds one.
/// A key holds one command, a command may have several keys.
public struct HotkeyMap: Sendable, Equatable {
    public private(set) var bindings: [Hotkey: Command]

    public init(_ bindings: [Hotkey: Command] = [:]) {
        self.bindings = bindings
    }

    /// The bindings in a stable order, for registering and for the menu.
    public var sorted: [(hotkey: Hotkey, command: Command)] {
        bindings
            .map { (hotkey: $0.key, command: $0.value) }
            .sorted { $0.hotkey.description < $1.hotkey.description }
    }

    /// The first key bound to `command`, for the key column of the menu.
    public func hotkey(for command: Command) -> Hotkey? {
        sorted.first { $0.command == command }?.hotkey
    }

    /// `text` applied over `base`; bad lines become issues and change nothing.
    public static func parse(
        _ text: String,
        over base: HotkeyMap = HotkeyMap()
    ) -> (map: HotkeyMap, issues: [LineIssue]) {
        var map = base
        var issues: [LineIssue] = []
        for entry in KeyValueParser.parse(text) {
            guard let hotkey = Hotkey.parse(entry.key) else {
                issues.append(
                    LineIssue(
                        line: entry.line,
                        message: "'\(entry.key)' is not a global key; it needs cmd, ctrl or alt, such as ctrl-shift-5"
                    )
                )
                continue
            }
            if entry.value == "nop" {
                map.bindings[hotkey] = nil
                continue
            }
            guard let command = Command.parse(entry.value) else {
                issues.append(
                    LineIssue(
                        line: entry.line,
                        message: "unknown command '\(entry.value)'"
                    )
                )
                continue
            }
            map.bindings[hotkey] = command
        }
        return (map, issues)
    }

    /// The user's keymap file applied over the defaults.
    public static func overlaid(_ userText: String) -> (map: HotkeyMap, issues: [LineIssue]) {
        parse(userText, over: .default)
    }

    public static let `default` = parse(defaultText).map

    /// The macOS screenshot keys; binding one of them means two apps answer.
    public static let systemScreenshotKeys: [Hotkey] = ["cmd-shift-3", "cmd-shift-4", "cmd-shift-5"]
        .compactMap(Hotkey.parse)

    /// Bindings that take a key macOS uses for its own screenshots.
    public var systemConflicts: [Hotkey] {
        Self.systemScreenshotKeys.filter { bindings[$0] != nil }
    }

    public static let defaultText = """
        # sCapture keymap. One global key per line: <key> <command>
        # Lines here apply over the built-in defaults; `<key> nop` unbinds one.
        # A key is a character or a named key (space enter tab esc left right
        # up down home end pageup pagedown f1..f12) with cmd- ctrl- alt- shift-
        # modifiers; a character key needs cmd, ctrl or alt.
        # Commands: capture-window capture-repeat position open-menu open-case
        # profile <1-9>

        ctrl-shift-5 capture-window
        ctrl-shift-r capture-repeat
        ctrl-shift-p position
        ctrl-shift-space open-menu
        ctrl-shift-o open-case

        # ctrl-shift-3 and ctrl-shift-4 stay free for display and area capture
        ctrl-alt-1 profile 1
        ctrl-alt-2 profile 2
        ctrl-alt-3 profile 3
        ctrl-alt-4 profile 4
        ctrl-alt-5 profile 5
        ctrl-alt-6 profile 6
        ctrl-alt-7 profile 7
        ctrl-alt-8 profile 8
        ctrl-alt-9 profile 9
        """
}
