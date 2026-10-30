import CoreGraphics
import Testing
@testable import SCaptureCore

struct ProfileTests {
    @Test func defaultTextParses() {
        let parsed = Profiles.parse(Profiles.defaultText)
        #expect(parsed.issues.isEmpty)
        #expect(parsed.profiles.map(\.name) == ["front-window", "console-chrome"])
        let front = parsed.profiles[0]
        #expect(front.app == .frontmost)
        #expect(front.frame == nil)
        #expect(front.scale == 2)
        let chrome = parsed.profiles[1]
        #expect(chrome.app == .bundleID("com.google.Chrome"))
        #expect(chrome.frame == CGRect(x: 200, y: 50, width: 1520, height: 980))
        #expect(chrome.inset == Insets(top: 87, left: 1, bottom: 1, right: 1))
    }

    @Test func chromeWritesTheGuideShotSize() {
        let chrome = Profiles.parse(Profiles.defaultText).profiles[1]
        let size = CGSize(width: 1520, height: 980)
        #expect(chrome.crop(windowSize: size) == CGRect(x: 1, y: 87, width: 1518, height: 892))
        #expect(chrome.pixelSize(windowSize: size) == PixelSize(width: 3036, height: 1784))
        var single = chrome
        single.scale = 1
        #expect(single.pixelSize(windowSize: size)?.description == "1518x892")
    }

    @Test func appTargets() {
        #expect(AppTarget("frontmost") == .frontmost)
        #expect(AppTarget("com.apple.Safari") == .bundleID("com.apple.Safari"))
        #expect(AppTarget("Safari") == .name("Safari"))
        #expect(AppTarget("Google Chrome") == .name("Google Chrome"))
        #expect(AppTarget("Dr. Who") == .name("Dr. Who"))
        #expect(AppTarget.bundleID("a.b").description == "a.b")
        #expect(AppTarget.name("Safari").description == "Safari")
        #expect(AppTarget.frontmost.description == "frontmost")
    }

    @Test func windowTitleAndNames() {
        let parsed = Profiles.parse("profile docs\napp Safari\nwindow Guide\nprofile term\napp com.apple.Terminal\nwindow\n")
        #expect(parsed.issues.isEmpty)
        #expect(parsed.profiles[0].window == "Guide")
        #expect(parsed.profiles[1].window == nil)
    }

    @Test func badLinesAreIssues() {
        let text = """
            scale 2
            profile Bad Name
            app Safari
            profile ok
            app
            origin 1
            size 0 10
            inset 1 2 3
            scale 3
            colour red
            profile ok
            profile half
            origin 10 10
            """
        let parsed = Profiles.parse(text)
        #expect(parsed.profiles.map(\.name) == ["ok", "half"])
        #expect(parsed.profiles[0] == Profile(name: "ok"))
        #expect(parsed.issues.map(\.line) == [1, 2, 5, 6, 7, 8, 9, 10, 11, 12])
        #expect(parsed.issues.last?.message == "profile 'half' has only one of origin and size; it is not positioned")
        #expect(parsed.issues[1].message.contains("lower-case"))
        #expect(parsed.issues[8].message == "profile 'ok' is defined twice")
    }

    @Test func insetThatLeavesNothing() {
        var profile = Profile(name: "p")
        profile.inset = Insets(top: 50, left: 0, bottom: 50, right: 0)
        #expect(profile.crop(windowSize: CGSize(width: 100, height: 100)) == nil)
        #expect(profile.pixelSize(windowSize: CGSize(width: 100, height: 100)) == nil)
        #expect(profile.pixelSize(windowSize: CGSize(width: 100, height: 101)) == PixelSize(width: 200, height: 2))
    }
}
