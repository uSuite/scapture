import SCommon

/// A global key, as the keymap file names it. Unlike sView's keymap keys,
/// `shift-` stays on a letter (`ctrl-shift-r`); an upper-case letter means
/// the same.
public struct Hotkey: Sendable, Hashable, CustomStringConvertible {
    /// A lower-case character, or a name from `Key.names`.
    public let key: String
    public let modifiers: Key.Modifiers

    public init(
        key: String,
        modifiers: Key.Modifiers
    ) {
        self.key = key
        self.modifiers = modifiers
    }

    private static let modifierNames: [(String, Key.Modifiers)] = [
        ("cmd", .command),
        ("ctrl", .control),
        ("alt", .option),
        ("shift", .shift),
    ]

    /// Nil when the text is not a key, or a character key has no cmd, ctrl
    /// or alt and would swallow typing everywhere.
    public static func parse(_ text: String) -> Hotkey? {
        var tokens = text.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard var base = tokens.popLast() else {
            return nil
        }
        if base.isEmpty, tokens.last == "" {
            // `cmd--` binds the minus key
            tokens.removeLast()
            base = "-"
        }
        var modifiers: Key.Modifiers = []
        for token in tokens {
            guard let modifier = modifierNames.first(where: { $0.0 == token.lowercased() })?.1 else {
                return nil
            }
            modifiers.insert(modifier)
        }
        if base.count == 1 {
            if base.first!.isUppercase {
                modifiers.insert(.shift)
            }
            base = base.lowercased()
            guard !modifiers.isDisjoint(with: [.command, .control, .option]) else {
                return nil
            }
        } else {
            base = base.lowercased()
            guard Key.names.contains(base), base.hasPrefix("f") || !modifiers.isDisjoint(with: [.command, .control, .option]) else {
                return nil
            }
        }
        return Hotkey(key: base, modifiers: modifiers)
    }

    public var description: String {
        (Self.modifierNames.filter { modifiers.contains($0.1) }.map(\.0) + [key]).joined(separator: "-")
    }
}

