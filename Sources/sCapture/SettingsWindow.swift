import AppKit
import SCaptureCore
import ServiceManagement
import SwiftUI

/// What the Settings window shows. The config file stays the truth: each
/// control writes its key's line, and the reload that follows applies it to
/// the app and comes back here.
@MainActor
@Observable
final class SettingsModel {
    var config = Config()
    var issues: [String] = []
    var launchAtLogin = false
    var screenRecording = false
    var accessibility = false
    /// The last thing a control did, under the file buttons.
    var status = ""
    @ObservationIgnored let paths: ConfigPaths
    /// The app's config and its problems, as loaded.
    @ObservationIgnored var current: () -> (config: Config, issues: [String]) = { (Config(), []) }
    /// Reloads the files into the app after a write.
    @ObservationIgnored var onWrite: () -> Void = {}

    init(paths: ConfigPaths) {
        self.paths = paths
    }

    var profilesURL: URL { paths.directory.appendingPathComponent("profiles") }

    func refresh() {
        let now = current()
        config = now.config
        issues = now.issues
        launchAtLogin = SMAppService.mainApp.status == .enabled
        screenRecording = Permissions.screenRecording
        accessibility = Permissions.accessibility
    }

    /// Writes `key` when `change` gives it another value.
    func change(
        _ key: String,
        _ change: (inout Config) -> Void
    ) {
        var changed = config
        change(&changed)
        guard let text = changed.text(for: key), text != config.text(for: key) else {
            return
        }
        do {
            try paths.persist(key, text, as: Config.self)
            status = "\(key) \(text)"
            onWrite()
        } catch {
            status = "\(error)"
        }
        refresh()
    }

    func binding<Value>(
        _ key: String,
        _ path: WritableKeyPath<Config, Value>
    ) -> Binding<Value> {
        Binding(
            get: { self.config[keyPath: path] },
            set: { value in
                self.change(key) { $0[keyPath: path] = value }
            }
        )
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            status = "launch at login: \(error.localizedDescription)"
        }
        refresh()
    }

    /// The folder picker for `root`; a folder in the home folder is written
    /// with `~/`, as the default is.
    func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = config.rootURL()
        panel.message = "Choose the folder whose sub-folders are the cases"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var path = url.path
        if path.hasPrefix(home + "/") {
            path = "~" + path.dropFirst(home.count)
        }
        change("root") { $0.root = path }
    }
}

/// sCapture > Settings…: one window, every config option as a control, the
/// two permissions and the problems in the files.
@MainActor
final class SettingsWindowController: NSWindowController {
    let model: SettingsModel
    private var observer: NSObjectProtocol?

    init(model: SettingsModel) {
        self.model = model
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "sCapture Settings"
        window.setFrameAutosaveName("Settings")
        super.init(window: window)
        // back from System Settings, the permission rows show the new state
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak model] _ in
            MainActor.assumeIsolated {
                model?.refresh()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    func show() {
        model.refresh()
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Section("Cases") {
                LabeledContent("Root folder") {
                    HStack {
                        Text(model.config.root)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") {
                            model.chooseRoot()
                        }
                    }
                }
                Picker("File names", selection: model.binding("name", \.name)) {
                    Text("Capture time: scap-2026-10-30-093435.png").tag(NameStyle.timestamp)
                    Text("Case and step: poc-demo-vm-stop-07.png").tag(NameStyle.caseStep)
                }
            }
            Section("Window") {
                Toggle("Place the window at the profile's frame before each capture", isOn: model.binding("auto_position", \.autoPosition))
                Picker("Wait after a move", selection: model.binding("settle_ms", \.settleMilliseconds)) {
                    Text("none").tag(0)
                    Text("0.1 s").tag(100)
                    Text("0.15 s").tag(150)
                    Text("0.3 s").tag(300)
                    Text("0.5 s").tag(500)
                    if ![0, 100, 150, 300, 500].contains(model.config.settleMilliseconds) {
                        Text("\(model.config.settleMilliseconds) ms").tag(model.config.settleMilliseconds)
                    }
                }
                .disabled(!model.config.autoPosition)
            }
            Section("Feedback") {
                Toggle("Flash the captured rectangle", isOn: model.binding("flash", \.flash))
                Picker("Thumbnail toast", selection: model.binding("toast", \.toastSeconds)) {
                    Text("off").tag(0)
                    Text("1 s").tag(1)
                    Text("2 s").tag(2)
                    Text("3 s").tag(3)
                    Text("5 s").tag(5)
                    if ![0, 1, 2, 3, 5].contains(model.config.toastSeconds) {
                        Text("\(model.config.toastSeconds) s").tag(model.config.toastSeconds)
                    }
                }
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }
            Section {
                permission(
                    "Screen Recording",
                    granted: model.screenRecording,
                    use: "to capture",
                    pane: "Privacy_ScreenCapture"
                ) {
                    Permissions.requestScreenRecording()
                }
                permission(
                    "Accessibility",
                    granted: model.accessibility,
                    use: "to place windows",
                    pane: "Privacy_Accessibility"
                ) {
                    Permissions.requestAccessibility()
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("macOS ties both to the app's signature: after an update, remove sCapture from each list, add it again and reopen it.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Folder") {
                    Text(Self.tilde(model.paths.directory))
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Edit Profiles") {
                        NSWorkspace.shared.open(model.profilesURL)
                    }
                    Button("Edit Keymap") {
                        NSWorkspace.shared.open(model.paths.keymap)
                    }
                    Spacer()
                    Button("Open Config Folder") {
                        NSWorkspace.shared.open(model.paths.directory)
                    }
                }
                if !model.status.isEmpty {
                    Text(model.status)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Config files")
            } footer: {
                Text("config, keymap and profiles are plain text and reload when they change; every control here writes one line of config.")
                    .foregroundStyle(.secondary)
            }
            Section("Problems in the files") {
                if model.issues.isEmpty {
                    Text("No problems")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.issues, id: \.self) { issue in
                        Text(issue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 680)
    }

    private func permission(
        _ name: String,
        granted: Bool,
        use: String,
        pane: String,
        request: @escaping () -> Void
    ) -> some View {
        LabeledContent(name) {
            HStack {
                Label(
                    granted ? "Allowed" : "Not allowed, needed \(use)",
                    systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(granted ? .green : .orange)
                if !granted {
                    Button("Open Settings") {
                        request()
                        Permissions.openSettings(pane)
                    }
                }
            }
        }
    }

    static func tilde(_ url: URL) -> String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
