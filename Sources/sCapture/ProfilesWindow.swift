import AppKit
import SCaptureCore
import SwiftUI

/// What the Profiles window shows (SC-309). The profiles file stays the
/// truth: a committed field rewrites its profile's block, the parser judges
/// it first, and the reload that follows comes back here.
@MainActor
@Observable
final class ProfilesModel {
    var profiles: [Profile] = []
    var selection: String?
    /// The selected profile as the form has it, saved on each commit.
    var draft = Profile(name: "")
    /// The app field's text, applied on Return or when the field is left.
    var appText = ""
    var issues: [String] = []
    var status = ""
    var busy = false
    var shot: Shot?
    @ObservationIgnored let url: URL
    @ObservationIgnored let windows: Windows
    @ObservationIgnored let service: CaptureService
    @ObservationIgnored var config: () -> Config = { Config() }
    /// Reloads the files into the app after a write.
    @ObservationIgnored var onWrite: () -> Void = {}
    @ObservationIgnored private var text = ""
    @ObservationIgnored private var saved: Profile?
    /// The app in front before this window, for profiles of the front app.
    @ObservationIgnored private var lastApp: NSRunningApplication?
    @ObservationIgnored private var observer: NSObjectProtocol?

    /// A test capture, shown in a sheet and never saved.
    struct Shot: Identifiable {
        let id = UUID()
        let image: NSImage
        let caption: String
        let warnings: [String]
    }

    struct RunningApp: Identifiable {
        var id: String { bundleID }
        let name: String
        let bundleID: String
        let icon: NSImage?
    }

    init(
        url: URL,
        windows: Windows,
        service: CaptureService
    ) {
        self.url = url
        self.windows = windows
        self.service = service
        lastApp = Self.other(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                if let app = Self.other(app) {
                    self?.lastApp = app
                }
            }
        }
    }

    var running: [RunningApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app in
                app.bundleIdentifier.map { RunningApp(name: app.localizedName ?? $0, bundleID: $0, icon: app.icon) }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Where the selected profile's app stands, under the app field.
    var appNote: String {
        switch draft.app {
        case .frontmost:
            return "the app in front when you press the key; here, \(lastApp?.localizedName ?? "none")"
        case .bundleID(let id):
            let app = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == id }
            return app.map { "\($0.localizedName ?? id), running" } ?? "not running"
        case .name(let name):
            let running = NSWorkspace.shared.runningApplications.contains { $0.localizedName?.caseInsensitiveCompare(name) == .orderedSame }
            return running ? "running" : "not running"
        }
    }

    var output: String {
        guard let size = draft.size else {
            return "the window's own size, less the inset, times \(draft.scale)"
        }
        guard let pixels = draft.pixelSize(windowSize: size) else {
            return "nothing: the inset is larger than the window"
        }
        return "\(pixels.width) x \(pixels.height) pixels"
    }

    /// Reads the file; a draft with no uncommitted change follows it.
    func refresh() {
        text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        profiles = Profiles.parse(text).profiles
        if selection == nil || !profiles.contains(where: { $0.name == selection }) {
            selection = profiles.first?.name
        }
        let current = profiles.first { $0.name == selection }
        if saved == nil || draft == saved || draft.name != selection {
            draft = current ?? Profile(name: "")
            appText = draft.app.description
        }
        saved = current
    }

    func select(_ name: String?) {
        commit()
        selection = name
        saved = nil
        refresh()
        issues = []
    }

    /// Saves the draft when it differs from the file and the parser finds
    /// nothing new wrong with it.
    func commit() {
        guard let name = selection, let saved, draft != saved else {
            return
        }
        issues = Profiles.check(draft, replacing: name, in: text)
        guard issues.isEmpty else {
            status = "not saved"
            return
        }
        let changed = Profiles.replacing(name, with: draft, in: text)
        // a renamed profile stays selected through the reload
        selection = draft.name
        write(changed, "saved \(draft.name)")
    }

    func commitApp() {
        let value = appText.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else {
            appText = draft.app.description
            return
        }
        draft.app = AppTarget(value)
        commit()
    }

    func chooseApp(_ value: String) {
        appText = value
        commitApp()
    }

    func update(_ change: (inout Profile) -> Void) {
        change(&draft)
        commit()
    }

    func add() {
        commit()
        let names = Set(profiles.map(\.name))
        let name = (1...).lazy.map { "profile-\($0)" }.first { !names.contains($0) }!
        write(Profiles.adding(Profile(name: name), to: text), "added \(name)")
        select(name)
    }

    func remove() {
        guard let name = selection else {
            return
        }
        let alert = NSAlert()
        alert.messageText = "Remove the profile \(name)?"
        alert.informativeText = "Its block and the comment above it leave the profiles file."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }
        let index = profiles.firstIndex { $0.name == name } ?? 0
        write(Profiles.removing(name, from: text), "removed \(name)")
        let left = profiles.map(\.name)
        select(left.isEmpty ? nil : left[min(index, left.count - 1)])
    }

    func openFile() {
        NSWorkspace.shared.open(url)
    }

    /// Takes origin and size from where the profile's window is now.
    func useCurrentWindow() {
        run { model throws(CaptureError) in
            let window = try await model.windows.resolve(model.target)
            model.update { $0 = $0.fitted(to: window.frame) }
            model.status = "took \(window.app)'s window at \(Int(window.frame.minX)), \(Int(window.frame.minY))"
        }
    }

    func place() {
        if !Permissions.accessibility {
            Permissions.requestAccessibility()
        }
        run { model throws(CaptureError) in
            let placed = try await model.service.place(model.target, config: model.config())
            let frame = placed.window.frame
            model.status = (["placed \(placed.window.app) at \(Int(frame.minX)), \(Int(frame.minY)), \(Int(frame.width)) x \(Int(frame.height))"] + placed.warnings).joined(separator: "; ")
        }
    }

    func test() {
        run { model throws(CaptureError) in
            let result = try await model.service.test(model.target, config: model.config())
            model.shot = Shot(
                image: NSImage(cgImage: result.image, size: NSSize(width: result.image.width, height: result.image.height)),
                caption: "\(result.pixels.width) x \(result.pixels.height) pixels, \(result.milliseconds) ms",
                warnings: result.warnings
            )
            model.status = "test capture \(result.pixels), not saved"
        }
    }

    /// The draft as the buttons use it: the front app is the one that was in
    /// front before this window, not sCapture.
    private var target: Profile {
        var profile = draft
        if profile.app == .frontmost, let id = lastApp?.bundleIdentifier {
            profile.app = .bundleID(id)
        }
        return profile
    }

    private func run(_ body: @escaping (ProfilesModel) async throws(CaptureError) -> Void) {
        commit()
        guard !busy else {
            return
        }
        busy = true
        status = ""
        Task { @MainActor in
            do throws(CaptureError) {
                try await body(self)
            } catch {
                status = error.description
            }
            busy = false
        }
    }

    private func write(
        _ changed: String,
        _ message: String
    ) {
        do {
            try Data(changed.utf8).write(to: url, options: .atomic)
            status = message
            issues = []
            onWrite()
        } catch {
            status = error.localizedDescription
        }
        saved = nil
        refresh()
    }

    private static func other(_ app: NSRunningApplication?) -> NSRunningApplication? {
        app?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : app
    }
}

/// sCapture > Edit Profiles…: the profiles as a list and a form, with Place
/// and Test Capture to try one before it is used.
@MainActor
final class ProfilesWindowController: NSWindowController {
    let model: ProfilesModel
    private var observer: NSObjectProtocol?

    init(model: ProfilesModel) {
        self.model = model
        let hosting = NSHostingController(rootView: ProfilesView(model: model))
        hosting.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "sCapture Profiles"
        window.setFrameAutosaveName("Profiles")
        super.init(window: window)
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

struct ProfilesView: View {
    @Bindable var model: ProfilesModel
    @FocusState private var focus: Field?

    private enum Field {
        case name
        case app
        case window
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 210)
            Divider()
            form
        }
        .frame(width: 780, height: 680)
        .onChange(of: focus) { old, _ in
            if old == .app {
                model.commitApp()
            } else if old != nil {
                model.commit()
            }
        }
        .sheet(item: $model.shot) { shot in
            ShotView(shot: shot) {
                model.shot = nil
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(
                selection: Binding(
                    get: { model.selection },
                    set: { model.select($0) }
                )
            ) {
                ForEach(Array(model.profiles.enumerated()), id: \.element.name) { index, profile in
                    HStack {
                        Text(profile.name)
                        Spacer()
                        if index < 9 {
                            Text("ctrl-alt-\(index + 1)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .tag(profile.name)
                }
            }
            Divider()
            HStack(spacing: 4) {
                Button {
                    model.add()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .help("Add a profile")
                Button {
                    model.remove()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .help("Remove the selected profile")
                .disabled(model.selection == nil)
                Spacer()
                Button("Open File") {
                    model.openFile()
                }
            }
            .buttonStyle(.borderless)
            .padding(8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    @ViewBuilder
    private var form: some View {
        if model.selection == nil {
            Text("No profile. Add one with +.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Form {
                Section("Window") {
                    TextField("Name", text: $model.draft.name)
                        .focused($focus, equals: .name)
                        .onSubmit { model.commit() }
                    LabeledContent("App") {
                        HStack {
                            TextField("App", text: $model.appText, prompt: Text("bundle id, app name or frontmost"))
                                .labelsHidden()
                                .focused($focus, equals: .app)
                                .onSubmit { model.commitApp() }
                            Menu("Choose") {
                                Button("Front app (frontmost)") {
                                    model.chooseApp("frontmost")
                                }
                                Divider()
                                ForEach(model.running) { app in
                                    Button {
                                        model.chooseApp(app.bundleID)
                                    } label: {
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                        }
                                        Text(app.name)
                                    }
                                }
                            }
                            .fixedSize()
                        }
                    }
                    LabeledContent("") {
                        Text(model.appNote)
                            .foregroundStyle(.secondary)
                    }
                    TextField(
                        "Title contains",
                        text: Binding(
                            get: { model.draft.window ?? "" },
                            set: { model.draft.window = $0.isEmpty ? nil : $0 }
                        ),
                        prompt: Text("any title")
                    )
                    .focused($focus, equals: .window)
                    .onSubmit { model.commit() }
                }
                Section("Place and size") {
                    Toggle(
                        "Place the window before each capture",
                        isOn: Binding(
                            get: { model.draft.frame != nil },
                            set: { on in
                                model.update { profile in
                                    profile.origin = on ? profile.origin ?? CGPoint(x: 100, y: 100) : nil
                                    profile.size = on ? profile.size ?? CGSize(width: 1280, height: 800) : nil
                                }
                            }
                        )
                    )
                    if model.draft.frame != nil {
                        pair(
                            "Origin",
                            "x",
                            "y",
                            Binding(
                                get: { Double(model.draft.origin?.x ?? 0) },
                                set: { value in model.update { $0.origin?.x = value } }
                            ),
                            Binding(
                                get: { Double(model.draft.origin?.y ?? 0) },
                                set: { value in model.update { $0.origin?.y = value } }
                            )
                        )
                        pair(
                            "Size",
                            "width",
                            "height",
                            Binding(
                                get: { Double(model.draft.size?.width ?? 0) },
                                set: { value in model.update { $0.size?.width = value } }
                            ),
                            Binding(
                                get: { Double(model.draft.size?.height ?? 0) },
                                set: { value in model.update { $0.size?.height = value } }
                            )
                        )
                    }
                }
                Section {
                    LabeledContent {
                        HStack {
                            number("top", \.top)
                            number("left", \.left)
                            number("bottom", \.bottom)
                            number("right", \.right)
                        }
                    } label: {
                        Text("Inset")
                        Text("top, left, bottom, right in points")
                    }
                    Picker(
                        "Scale",
                        selection: Binding(
                            get: { model.draft.scale },
                            set: { value in model.update { $0.scale = value } }
                        )
                    ) {
                        Text("1x").tag(1)
                        Text("2x").tag(2)
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Output") {
                        Text(model.output)
                            .monospacedDigit()
                    }
                } header: {
                    Text("Capture")
                } footer: {
                    Text("Points cut off each side of the window, such as a title bar, tabs or a toolbar. Every capture of the profile is (size - inset) x scale pixels.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    HStack {
                        Button("Use Current Window") {
                            model.useCurrentWindow()
                        }
                        .help("Take origin and size from where the window is now")
                        Button("Place") {
                            model.place()
                        }
                        .disabled(model.draft.frame == nil)
                        .help("Move and resize the window to the profile's frame")
                        Spacer()
                        Button("Test Capture") {
                            model.test()
                        }
                        .keyboardShortcut("t", modifiers: .command)
                        .help("Capture as the key would, without saving")
                    }
                    .disabled(model.busy)
                    ForEach(model.issues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    if !model.status.isEmpty {
                        Text(model.status)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Try it")
                } footer: {
                    Text("Changes are written to the profiles file when you press Return or leave a field. Place needs Accessibility; Test Capture needs Screen Recording and saves nothing.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }

    private func pair(
        _ label: String,
        _ first: String,
        _ second: String,
        _ a: Binding<Double>,
        _ b: Binding<Double>
    ) -> some View {
        LabeledContent {
            HStack {
                TextField(first, value: a, format: .number.grouping(.never), prompt: Text(first))
                TextField(second, value: b, format: .number.grouping(.never), prompt: Text(second))
            }
            .labelsHidden()
            .frame(width: 200)
        } label: {
            Text(label)
            Text("\(first), \(second) in points")
        }
    }

    private func number(
        _ label: String,
        _ path: WritableKeyPath<Insets, Double>
    ) -> some View {
        TextField(
            label,
            value: Binding(
                get: { model.draft.inset[keyPath: path] },
                set: { value in model.update { $0.inset[keyPath: path] = max(0, value) } }
            ),
            format: .number.grouping(.never),
            prompt: Text(label)
        )
        .labelsHidden()
        .frame(width: 56)
    }
}

/// A test capture at the size the sheet allows, with its pixel size.
private struct ShotView: View {
    let shot: ProfilesModel.Shot
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(nsImage: shot.image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: 720, maxHeight: 460)
                .border(.separator)
            Text(shot.caption)
                .monospacedDigit()
            ForEach(shot.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            HStack {
                Text("Not saved. Captures go into the case with the capture key.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480)
    }
}
