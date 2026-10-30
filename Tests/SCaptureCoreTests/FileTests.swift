import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SCaptureCore

struct WriterTests {
    @Test func pngIsSRGBWithTheScalesDPI() throws {
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
        for (scale, space) in [(1, CGColorSpace(name: CGColorSpace.sRGB)!), (2, p3)] {
            let data = try #require(Writer.png(solidImage(width: 30, height: 20, space: space), scale: scale))
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            #expect(properties[kCGImagePropertyPixelWidth] as? Int == 30)
            #expect(properties[kCGImagePropertyPixelHeight] as? Int == 20)
            #expect(properties[kCGImagePropertyDPIWidth] as? Int == 72 * scale)
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.colorSpace?.name == CGColorSpace.sRGB)
        }
    }

    @Test func writeNeverReplaces() throws {
        let temp = try TempFolder()
        try Writer.write(Data("one".utf8), to: temp.url, name: "a.png")
        #expect(throws: Writer.WriteError.exists("a.png")) {
            try Writer.write(Data("two".utf8), to: temp.url, name: "a.png")
        }
        #expect(try String(contentsOf: temp.url.appendingPathComponent("a.png"), encoding: .utf8) == "one")
        #expect(try FileManager.default.contentsOfDirectory(atPath: temp.url.path) == ["a.png"])
    }

    @Test func writeIntoAMissingFolderFails() throws {
        let temp = try TempFolder()
        #expect(throws: Writer.WriteError.self) {
            try Writer.write(Data(), to: temp.url.appendingPathComponent("gone"), name: "a.png")
        }
        #expect(Writer.WriteError.io("a.png", ENOENT).description.contains("a.png"))
        #expect(Writer.WriteError.encode("a.png").description.contains("PNG"))
    }
}

struct StateTests {
    @Test func roundTripsAndRemembersProfiles() throws {
        let temp = try TempFolder()
        let url = temp.url.appendingPathComponent("config/state.json")
        #expect(State.load(url) == State())
        var state = State(activeCase: "poc-a-b", profile: "console-chrome")
        state.captured("poc-a-b", with: "console-chrome")
        state.captured("poc-a-b", with: "front-window")
        state.profile = "front-window"
        state.pick("poc-c-d")
        #expect(state.profile == "front-window")
        state.pick("poc-a-b")
        #expect(state.profile == "console-chrome")
        try state.save(url)
        #expect(State.load(url) == state)
        try Data("{".utf8).write(to: url)
        #expect(State.load(url) == State())
    }
}

struct LogTests {
    @Test func linesAppend() throws {
        let temp = try TempFolder()
        let url = temp.url.appendingPathComponent("config/log")
        let line = Log.line(
            date: Clock.now,
            caseID: "poc-a-b",
            profile: "console-chrome",
            file: "scap-2026-10-28-093435.png",
            size: PixelSize(width: 3036, height: 1784),
            milliseconds: 42
        )
        #expect(line == "2026-10-28T09:34:35Z\tpoc-a-b\tconsole-chrome\tscap-2026-10-28-093435.png\t3036x1784\t42ms")
        try Log.append(line, to: url)
        try Log.append(line, to: url)
        #expect(try String(contentsOf: url, encoding: .utf8) == line + "\n" + line + "\n")
    }
}
