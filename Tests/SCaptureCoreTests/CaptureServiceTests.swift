import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SCaptureCore

@MainActor
struct CaptureServiceTests {
    let temp: TempFolder
    let store: CaseStore
    let chrome = Profiles.parse(Profiles.defaultText).profiles[1]
    let front = Profiles.parse(Profiles.defaultText).profiles[0]

    init() throws {
        temp = try TempFolder()
        store = CaseStore(root: temp.url)
        try store.create("poc-demo-vm-stop")
    }

    func service(_ fake: FakeWindows, log: URL? = nil) -> CaptureService {
        CaptureService(
            resolver: fake,
            positioner: fake,
            capturer: fake,
            log: log,
            timeZone: Clock.utc,
            now: { Clock.now },
            sleep: { _ in }
        )
    }

    func pixels(_ url: URL) throws -> PixelSize {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return PixelSize(
            width: properties[kCGImagePropertyPixelWidth] as! Int,
            height: properties[kCGImagePropertyPixelHeight] as! Int
        )
    }

    @Test func placesCropsAndWrites() async throws {
        let fake = FakeWindows()
        let log = temp.url.appendingPathComponent("log")
        let result = try await service(fake, log: log).capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: Config())
        #expect(fake.placed == [CGRect(x: 200, y: 50, width: 1520, height: 980)])
        #expect(fake.captured.first?.crop == CGRect(x: 1, y: 87, width: 1518, height: 892))
        #expect(result.pixels == PixelSize(width: 3036, height: 1784))
        #expect(result.file.lastPathComponent == "scap-2026-10-28-093435.png")
        #expect(try pixels(result.file) == result.pixels)
        #expect(result.count == 1)
        #expect(result.rect == CGRect(x: 201, y: 137, width: 1518, height: 892))
        #expect(result.warnings.isEmpty)
        #expect(try String(contentsOf: log, encoding: .utf8).hasPrefix("2026-10-28T09:34:35Z\tpoc-demo-vm-stop\tconsole-chrome\t"))
    }

    @Test func aWindowInPlaceIsNotMoved() async throws {
        let fake = FakeWindows(frame: CGRect(x: 200.4, y: 50, width: 1520, height: 980))
        _ = try await service(fake).capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: Config())
        #expect(fake.placed.isEmpty)
    }

    @Test func noPositioningWhenOff() async throws {
        let fake = FakeWindows()
        var config = Config()
        config.autoPosition = false
        let result = try await service(fake).capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: config)
        #expect(fake.placed.isEmpty)
        #expect(result.pixels == PixelSize(width: 1596, height: 1024))
    }

    @Test func aProfileWithoutFrameTakesTheWindowAsItIs() async throws {
        let fake = FakeWindows(backingScale: 1)
        let result = try await service(fake).capture(front, caseID: "poc-demo-vm-stop", store: store, config: Config())
        #expect(fake.placed.isEmpty)
        #expect(result.pixels == PixelSize(width: 1600, height: 1200))
        #expect(result.warnings == ["upsampled: the window is on a 1x display"])
    }

    @Test func refusedOrStuckWindowsWarnButCapture() async throws {
        let stuck = FakeWindows()
        stuck.fixedSize = CGSize(width: 1400, height: 900)
        let result = try await service(stuck).capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: Config())
        #expect(result.warnings == ["Chrome kept its window at 1400 x 900, not 1520 x 980"])
        #expect(result.pixels == PixelSize(width: 2796, height: 1624))
        let refused = FakeWindows()
        refused.placeError = .accessibilityDenied
        let second = try await service(refused).capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: Config())
        #expect(second.warnings == [CaptureError.accessibilityDenied.description])
        #expect(second.file.lastPathComponent == "scap-2026-10-28-093435b.png")
        #expect(second.count == 2)
    }

    @Test func repeatUsesTheLastWindow() async throws {
        let fake = FakeWindows()
        let capture = service(fake)
        await #expect(throws: CaptureError.noLastWindow) {
            try await capture.capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: Config(), again: true)
        }
        _ = try await capture.capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: Config())
        _ = try await capture.capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: Config(), again: true)
        #expect(fake.resolved == ["console-chrome", "refresh"])
        var config = Config()
        config.autoPosition = false
        let third = try await capture.capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: config, again: true)
        #expect(fake.resolved.last == "refresh")
        #expect(third.count == 3)
        #expect(capture.lastWindow?.id == 42)
    }

    @Test func caseStepNames() async throws {
        var config = Config()
        config.name = .caseStep
        let capture = service(FakeWindows())
        let first = try await capture.capture(front, caseID: "poc-demo-vm-stop", store: store, config: config)
        let second = try await capture.capture(front, caseID: "poc-demo-vm-stop", store: store, config: config)
        #expect([first.file.lastPathComponent, second.file.lastPathComponent] == ["poc-demo-vm-stop-01.png", "poc-demo-vm-stop-02.png"])
    }

    @Test func refusals() async throws {
        let fake = FakeWindows()
        let capture = service(fake)
        await #expect(throws: CaptureError.noCase) {
            try await capture.capture(chrome, caseID: nil, store: store, config: Config())
        }
        await #expect(throws: CaptureError.caseMissing("poc-gone")) {
            try await capture.capture(chrome, caseID: "poc-gone", store: store, config: Config())
        }
        fake.resolveError = .appNotRunning("com.google.Chrome")
        await #expect(throws: CaptureError.appNotRunning("com.google.Chrome")) {
            try await capture.capture(chrome, caseID: "poc-demo-vm-stop", store: store, config: Config())
        }
        fake.resolveError = nil
        var greedy = front
        greedy.inset = Insets(top: 600, left: 0, bottom: 0, right: 0)
        await #expect(throws: CaptureError.emptyCrop("front-window")) {
            try await capture.capture(greedy, caseID: "poc-demo-vm-stop", store: store, config: Config())
        }
        #expect(store.count("poc-demo-vm-stop") == 0)
    }

    @Test func placeAlone() async throws {
        let fake = FakeWindows()
        let placed = try await service(fake).place(chrome, config: Config())
        #expect(placed.window.frame == CGRect(x: 200, y: 50, width: 1520, height: 980))
        let again = try await service(fake).place(chrome, config: Config())
        #expect(fake.placed.count == 1)
        #expect(again.warnings.isEmpty)
    }

    @Test func testCaptureWritesNothing() async throws {
        let fake = FakeWindows(backingScale: 1)
        let log = temp.url.appendingPathComponent("log")
        let service = service(fake, log: log)
        let result = try await service.test(chrome, config: Config())
        #expect(fake.placed == [CGRect(x: 200, y: 50, width: 1520, height: 980)])
        #expect(result.pixels == PixelSize(width: 3036, height: 1784))
        #expect(result.image.width == 3036)
        #expect(result.rect == CGRect(x: 201, y: 137, width: 1518, height: 892))
        #expect(result.warnings == ["upsampled: the window is on a 1x display"])
        #expect(store.count("poc-demo-vm-stop") == 0)
        #expect(service.lastWindow == nil)
        #expect(!FileManager.default.fileExists(atPath: log.path))
        var config = Config()
        config.autoPosition = false
        let unplaced = try await service.test(front, config: config)
        #expect(fake.placed.count == 1)
        #expect(unplaced.pixels == PixelSize(width: 3040, height: 1960))
    }

    @Test func errorMessages() {
        let all: [CaptureError] = [
            .noCase, .caseMissing("c"), .appNotRunning("a"), .noWindow(app: "a", title: nil),
            .noWindow(app: "a", title: "t"), .noLastWindow, .screenRecordingDenied, .accessibilityDenied,
            .placeRefused("a"), .emptyCrop("p"), .capture("m"), .write("w"),
        ]
        #expect(Set(all.map(\.description)).count == all.count)
    }
}
