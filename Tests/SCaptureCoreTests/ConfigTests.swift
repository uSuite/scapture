import Foundation
import Testing
@testable import SCaptureCore

struct ConfigTests {
    @Test func defaultTextIsTheDefaults() {
        let parsed = Config.parse(Config.defaultText)
        #expect(parsed.issues.isEmpty)
        #expect(parsed.config == Config())
    }

    @Test func readsEveryKey() {
        let text = """
            root /tmp/cases
            name case-step
            auto_position no
            settle_ms 300
            flash off
            toast 0
            """
        let parsed = Config.parse(text)
        #expect(parsed.issues.isEmpty)
        #expect(parsed.config.root == "/tmp/cases")
        #expect(parsed.config.name == .caseStep)
        #expect(!parsed.config.autoPosition)
        #expect(parsed.config.settleMilliseconds == 300)
        #expect(!parsed.config.flash)
        #expect(parsed.config.toastSeconds == 0)
    }

    @Test func badLinesKeepDefaults() {
        let parsed = Config.parse("root cases\nname numbers\nflash maybe\ntoast 11\nsettle_ms -1\ncolour red\n")
        #expect(parsed.config == Config())
        #expect(parsed.issues.map(\.line) == [1, 2, 3, 4, 5, 6])
        #expect(parsed.issues[5].message == "unknown option 'colour'")
        #expect(parsed.issues[1].message == "name: 'numbers' is not timestamp or case-step")
    }

    @Test func rootExpandsTheHome() {
        let home = URL(fileURLWithPath: "/Users/me", isDirectory: true)
        var config = Config()
        #expect(config.rootURL(home: home).path == "/Users/me/Pictures/scapture")
        config.root = "/Volumes/cases"
        #expect(config.rootURL(home: home).path == "/Volumes/cases")
    }
}

struct HotkeyMapTests {
    @Test func defaultsBindTheCommands() {
        let parsed = HotkeyMap.parse(HotkeyMap.defaultText)
        #expect(parsed.issues.isEmpty)
        let map = parsed.map
        #expect(map.bindings[Hotkey.parse("ctrl-shift-5")!] == .captureWindow)
        #expect(map.bindings[Hotkey.parse("ctrl-shift-space")!] == .openMenu)
        #expect(map.bindings[Hotkey.parse("ctrl-alt-9")!] == .profile(9))
        #expect(map.hotkey(for: .captureRepeat)?.description == "ctrl-shift-r")
        #expect(map.systemConflicts.isEmpty)
        #expect(HotkeyMap.default == map)
    }

    @Test func userLinesApplyOverTheDefaults() {
        let parsed = HotkeyMap.overlaid("cmd-shift-4 capture-window\nctrl-shift-5 nop\nctrl-shift-r position\n")
        #expect(parsed.issues.isEmpty)
        #expect(parsed.map.bindings[Hotkey.parse("ctrl-shift-5")!] == nil)
        #expect(parsed.map.bindings[Hotkey.parse("ctrl-shift-r")!] == .position)
        #expect(parsed.map.hotkey(for: .captureWindow)?.description == "cmd-shift-4")
        #expect(parsed.map.systemConflicts.map(\.description) == ["cmd-shift-4"])
    }

    @Test func badLinesAreIssues() {
        let parsed = HotkeyMap.overlaid("r capture-window\nctrl-shift-x shoot\nctrl-shift-y profile 10\n")
        #expect(parsed.map == HotkeyMap.default)
        #expect(parsed.issues.map(\.line) == [1, 2, 3])
        #expect(parsed.issues[1].message == "unknown command 'shoot'")
    }

    @Test func sortedIsStable() {
        let sorted = HotkeyMap.default.sorted.map(\.hotkey.description)
        #expect(sorted == sorted.sorted())
        #expect(sorted.count == 14)
    }
}

struct CommandTests {
    @Test func parsesEveryName() {
        #expect(Command.parse("capture-window") == .captureWindow)
        #expect(Command.parse("capture-repeat") == .captureRepeat)
        #expect(Command.parse("position") == .position)
        #expect(Command.parse("open-menu") == .openMenu)
        #expect(Command.parse("open-case") == .openCase)
        #expect(Command.parse("profile 3") == .profile(3))
        for bad in ["", "profile", "profile 0", "profile x", "position now", "capture"] {
            #expect(Command.parse(bad) == nil, "\(bad)")
        }
    }

    @Test func descriptionRoundTrips() {
        for command in [Command.captureWindow, .captureRepeat, .position, .openMenu, .openCase, .profile(4)] {
            #expect(Command.parse(command.description) == command)
        }
        #expect(Command.names.contains("capture-window"))
    }

    @Test func hotkeys() {
        #expect(Hotkey.parse("ctrl-shift-5") == Hotkey(key: "5", modifiers: [.control, .shift]))
        #expect(Hotkey.parse("ctrl-R") == Hotkey(key: "r", modifiers: [.control, .shift]))
        #expect(Hotkey.parse("f5") == Hotkey(key: "f5", modifiers: []))
        #expect(Hotkey.parse("ctrl-shift-space") == Hotkey(key: "space", modifiers: [.control, .shift]))
        for bad in ["5", "shift-5", "space", "hyper-c", "cmd-", ""] {
            #expect(Hotkey.parse(bad) == nil, "\(bad)")
        }
        #expect(Hotkey.parse("shift-ctrl-5")!.description == "ctrl-shift-5")
    }
}
