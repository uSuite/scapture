import CoreGraphics
import Testing
@testable import SCaptureCore

struct ProfileTextTests {
    let chrome = Profiles.parse(Profiles.defaultText).profiles[1]

    @Test func linesAreTheFileGrammar() {
        #expect(chrome.lines == [
            "app com.google.Chrome",
            "origin 200 50",
            "size 1520 980",
            "inset 87 1 1 1",
            "scale 2",
        ])
        var front = Profile(name: "front-window")
        #expect(front.lines == ["app frontmost", "scale 2"])
        front.window = "Console"
        front.origin = CGPoint(x: 10.5, y: -20)
        front.size = CGSize(width: 800, height: 600)
        front.scale = 1
        let parsed = Profiles.parse((["profile front-window"] + front.lines).joined(separator: "\n"))
        #expect(parsed.issues.isEmpty)
        #expect(parsed.profiles == [front])
        #expect(front.lines.contains("origin 10.5 -20"))
    }

    @Test func replacingChangesOnlyTheChangedLine() {
        var changed = chrome
        changed.inset.top = 90
        let text = Profiles.replacing("console-chrome", with: changed, in: Profiles.defaultText)
        #expect(text == Profiles.defaultText.replacingOccurrences(of: "inset 87 1 1 1", with: "inset 90 1 1 1"))
    }

    @Test func replacingRenamesRemovesAndAdds() {
        var changed = chrome
        changed.name = "console"
        changed.origin = nil
        changed.size = nil
        changed.window = "Console"
        let text = Profiles.replacing("console-chrome", with: changed, in: Profiles.defaultText)
        let parsed = Profiles.parse(text)
        #expect(parsed.issues.isEmpty)
        #expect(parsed.profiles.map(\.name) == ["front-window", "console"])
        #expect(parsed.profiles[1] == changed)
        #expect(text.hasSuffix("# Chrome without its title bar, tabs and address bar: 3036 x 1784\nprofile console\napp com.google.Chrome\nwindow Console\ninset 87 1 1 1\nscale 2"))
        #expect(text.hasPrefix(Profiles.defaultText.components(separatedBy: "# Chrome without")[0]))
    }

    @Test func addedKeysGoInTheUsualOrder() {
        let front = Profiles.parse(Profiles.defaultText).profiles[0]
        let placed = front.fitted(to: CGRect(x: 10, y: 20, width: 800, height: 600))
        let text = Profiles.replacing("front-window", with: placed, in: Profiles.defaultText)
        #expect(text.contains("profile front-window\napp frontmost\norigin 10 20\nsize 800 600\nscale 2\n"))
        let bare = "profile a\n# keep\nscale 1"
        var only = Profile(name: "a")
        only.scale = 1
        only.app = .name("Safari")
        #expect(Profiles.replacing("a", with: only, in: bare) == "profile a\napp Safari\n# keep\nscale 1")
        #expect(Profiles.replacing("a", with: only, in: "profile a\n# nothing yet") == "profile a\napp Safari\nscale 1\n# nothing yet")
    }

    @Test func replacingKeepsCommentsAndUnknownLinesInTheBlock() {
        let text = "profile a\n# the console\napp frontmost\n  colour red\nscale 2\n"
        var changed = Profile(name: "a")
        changed.scale = 1
        #expect(Profiles.replacing("a", with: changed, in: text) == "profile a\n# the console\napp frontmost\n  colour red\nscale 1\n")
        #expect(Profiles.replacing("b", with: changed, in: text) == text)
    }

    @Test func addingAppendsABlock() {
        let text = Profiles.adding(Profile(name: "new-one"), to: Profiles.defaultText)
        #expect(text == Profiles.defaultText + "\n\nprofile new-one\napp frontmost\nscale 2")
        #expect(Profiles.parse(text).profiles.map(\.name) == ["front-window", "console-chrome", "new-one"])
        #expect(Profiles.adding(Profile(name: "a"), to: "") == "profile a\napp frontmost\nscale 2")
        #expect(Profiles.adding(Profile(name: "b"), to: "profile a\nscale 1\n\n") == "profile a\nscale 1\n\nprofile b\napp frontmost\nscale 2\n")
    }

    @Test func removingDropsTheBlockAndTheCommentAboveIt() {
        let withoutChrome = Profiles.removing("console-chrome", from: Profiles.defaultText)
        #expect(withoutChrome == Profiles.defaultText.components(separatedBy: "\n\n# Chrome without")[0])
        let withoutFront = Profiles.removing("front-window", from: Profiles.defaultText)
        #expect(!withoutFront.contains("front-window\napp"))
        #expect(!withoutFront.contains("\n\n\n"))
        #expect(Profiles.parse(withoutFront).profiles.map(\.name) == ["console-chrome"])
        #expect(Profiles.parse(withoutFront).issues.isEmpty)
        #expect(Profiles.removing("absent", from: Profiles.defaultText) == Profiles.defaultText)
    }

    @Test func checkReportsOnlyWhatTheChangeBreaks() {
        let text = Profiles.defaultText + "\n\nprofile broken\ncolour red"
        #expect(Profiles.check(chrome, replacing: "console-chrome", in: text).isEmpty)
        var taken = chrome
        taken.name = "front-window"
        #expect(Profiles.check(taken, replacing: "console-chrome", in: text) == ["profile 'front-window' is defined twice"])
        var upper = chrome
        upper.name = "Chrome"
        #expect(Profiles.check(upper, replacing: "console-chrome", in: text).first?.contains("lower-case") == true)
        var half = chrome
        half.size = nil
        #expect(Profiles.check(half, replacing: "console-chrome", in: text) == ["profile 'console-chrome' has only one of origin and size; it is not positioned"])
        #expect(Profiles.check(Profile(name: "new-one"), replacing: nil, in: text).isEmpty)
        #expect(Profiles.check(Profile(name: "console-chrome"), replacing: nil, in: text) == ["profile 'console-chrome' is defined twice"])
    }

    @Test func fittedTakesTheWindowsFrameInWholePoints() {
        let fitted = Profile(name: "a").fitted(to: CGRect(x: 200.4, y: 49.6, width: 1519.7, height: 980.2))
        #expect(fitted.origin == CGPoint(x: 200, y: 50))
        #expect(fitted.size == CGSize(width: 1520, height: 980))
        #expect(fitted.name == "a")
    }
}
