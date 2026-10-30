import AppKit
import Carbon.HIToolbox
import SCaptureCore

/// The global keys, through Carbon's `RegisterEventHotKey`: no permission
/// needed, and a key reaches sCapture whichever app is in front.
final class HotKeys {
    private var references: [EventHotKeyRef] = []
    private var commands: [UInt32: Command] = [:]
    private var handler: EventHandlerRef?
    private let action: (Command) -> Void

    private static let codes: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
        "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
        "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
        "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
        "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal, "[": kVK_ANSI_LeftBracket,
        "]": kVK_ANSI_RightBracket, ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
        ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period, "/": kVK_ANSI_Slash,
        "\\": kVK_ANSI_Backslash, "`": kVK_ANSI_Grave,
        "space": kVK_Space, "enter": kVK_Return, "tab": kVK_Tab, "esc": kVK_Escape,
        "backspace": kVK_Delete, "delete": kVK_ForwardDelete,
        "left": kVK_LeftArrow, "right": kVK_RightArrow, "up": kVK_UpArrow, "down": kVK_DownArrow,
        "home": kVK_Home, "end": kVK_End, "pageup": kVK_PageUp, "pagedown": kVK_PageDown,
        "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4, "f5": kVK_F5, "f6": kVK_F6,
        "f7": kVK_F7, "f8": kVK_F8, "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
    ]

    init(action: @escaping (Command) -> Void) {
        self.action = action
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else {
                    return noErr
                }
                var id = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                let hotKeys = Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async {
                    if let command = hotKeys.commands[id.id] {
                        hotKeys.action(command)
                    }
                }
                return noErr
            },
            1,
            &spec,
            context,
            &handler
        )
    }

    /// Replaces every registration with `map`; returns the keys macOS refused
    /// or that have no key code, usually because another app holds them.
    func register(_ map: HotkeyMap) -> [Hotkey] {
        unregisterAll()
        var refused: [Hotkey] = []
        for (index, binding) in map.sorted.enumerated() {
            guard let code = Self.codes[binding.hotkey.key] else {
                refused.append(binding.hotkey)
                continue
            }
            var reference: EventHotKeyRef?
            let id = UInt32(index + 1)
            let status = RegisterEventHotKey(
                UInt32(code),
                UInt32(Self.carbonModifiers(binding.hotkey.modifiers)),
                EventHotKeyID(signature: OSType(0x7343_6170), id: id),
                GetApplicationEventTarget(),
                0,
                &reference
            )
            guard status == noErr, let reference else {
                refused.append(binding.hotkey)
                continue
            }
            references.append(reference)
            commands[id] = binding.command
        }
        return refused
    }

    func unregisterAll() {
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
        commands.removeAll()
    }

    private static func carbonModifiers(_ modifiers: Key.Modifiers) -> Int {
        var carbon = 0
        if modifiers.contains(.command) {
            carbon |= cmdKey
        }
        if modifiers.contains(.shift) {
            carbon |= shiftKey
        }
        if modifiers.contains(.option) {
            carbon |= optionKey
        }
        if modifiers.contains(.control) {
            carbon |= controlKey
        }
        return carbon
    }

    /// The menu's key column: the key as an AppKit key equivalent.
    static func keyEquivalent(_ hotkey: Hotkey) -> (String, NSEvent.ModifierFlags)? {
        let named: [String: Int] = [
            "space": 0x20, "enter": 0x0d, "tab": 0x09, "esc": 0x1b, "backspace": 0x08,
            "delete": NSDeleteFunctionKey, "left": NSLeftArrowFunctionKey, "right": NSRightArrowFunctionKey,
            "up": NSUpArrowFunctionKey, "down": NSDownArrowFunctionKey, "home": NSHomeFunctionKey,
            "end": NSEndFunctionKey, "pageup": NSPageUpFunctionKey, "pagedown": NSPageDownFunctionKey,
        ]
        var flags: NSEvent.ModifierFlags = []
        if hotkey.modifiers.contains(.command) {
            flags.insert(.command)
        }
        if hotkey.modifiers.contains(.shift) {
            flags.insert(.shift)
        }
        if hotkey.modifiers.contains(.option) {
            flags.insert(.option)
        }
        if hotkey.modifiers.contains(.control) {
            flags.insert(.control)
        }
        if hotkey.key.count == 1 {
            return (hotkey.key, flags)
        }
        if let code = named[hotkey.key], let scalar = UnicodeScalar(code) {
            return (String(Character(scalar)), flags)
        }
        if hotkey.key.hasPrefix("f"), let n = Int(hotkey.key.dropFirst()), let scalar = UnicodeScalar(NSF1FunctionKey + n - 1) {
            return (String(Character(scalar)), flags)
        }
        return nil
    }
}
