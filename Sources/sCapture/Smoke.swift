import AppKit
import SCaptureCore

/// `SCAPTURE_SMOKE=<folder>`: opens a test window, captures it once with
/// every profile into the active case, writes one line per capture to
/// `<folder>/state.txt`, a picture of the Settings window to
/// `<folder>/settings.png`, and quits (SC-602). `scripts/smoke.sh` sets up the
/// config, case and profiles and checks the files.
@MainActor
final class Smoke {
    static let title = "sCapture smoke"
    private let output: URL
    private var window: NSWindow?

    init(output: URL) {
        self.output = output
    }

    func run(
        profiles: [Profile],
        caseID: String?,
        store: CaseStore,
        config: Config,
        service: CaptureService,
        finish: @escaping () async -> Void = {}
    ) {
        // the window list's top-left (100, 100), 800 x 600 points
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Self.title
        window.isReleasedWhenClosed = false
        window.contentView = Pattern()
        window.setFrame(appKitRect(CGRect(x: 100, y: 100, width: 800, height: 600)), display: true)
        window.orderFrontRegardless()
        self.window = window
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            var lines: [String] = []
            for profile in profiles {
                do throws(CaptureError) {
                    let result = try await service.capture(
                        profile,
                        caseID: caseID,
                        store: store,
                        config: config
                    )
                    let warnings = result.warnings.isEmpty ? "" : "\t" + result.warnings.joined(separator: "; ")
                    lines.append("\(profile.name)\t\(result.file.lastPathComponent)\t\(result.pixels)\t\(result.milliseconds)ms\(warnings)")
                } catch {
                    lines.append("\(profile.name)\terror\t\(error.description)")
                }
            }
            try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let permissions = "screen-recording \(Permissions.screenRecording ? "yes" : "no")\naccessibility \(Permissions.accessibility ? "yes" : "no")\n"
            try? Data(permissions.utf8).write(to: output.appendingPathComponent("permissions.txt"))
            await finish()
            try? Data((lines.joined(separator: "\n") + "\n").utf8).write(to: output.appendingPathComponent("state.txt"))
            NSApp.terminate(nil)
        }
    }
}

/// Green and white squares, so a wrong crop or scale shows in the files.
private final class Pattern: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        NSColor(red: 0.12, green: 0.75, blue: 0.46, alpha: 1).setFill()
        let side: CGFloat = 50
        for row in 0..<Int(bounds.height / side) + 1 {
            for column in 0..<Int(bounds.width / side) + 1 where (row + column).isMultiple(of: 2) {
                NSRect(x: CGFloat(column) * side, y: CGFloat(row) * side, width: side, height: side).fill()
            }
        }
    }
}
