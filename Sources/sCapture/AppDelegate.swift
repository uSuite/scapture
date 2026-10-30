import AppKit
import ServiceManagement
import SCaptureCore
import os

private let log = Logger(subsystem: "io.github.usuite.scapture", category: "app")

/// The menu bar agent: loads config, keymap and profiles, registers the
/// global keys, and runs captures into the active case.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let environment = ProcessInfo.processInfo.environment
    private let paths = ConfigPaths(app: "scapture")
    private var config = Config()
    private var hotkeys = HotkeyMap()
    private var profiles: [Profile] = []
    private var state = State()
    private var problems: [String] = []
    private var refusedKeys: [Hotkey] = []
    private var statusItem: NSStatusItem!
    private var hotKeys: HotKeys!
    private let windows = Windows()
    private lazy var service = CaptureService(
        resolver: windows,
        positioner: windows,
        capturer: SCKCapturer(),
        log: paths.directory.appendingPathComponent("log")
    )
    private let flash = Flash()
    private let toast = Toast()
    private var configWatcher: DirectoryWatcher?
    private var caseWatcher: DirectoryWatcher?
    private var busy = false
    private var settings: SettingsWindowController?
    private var profilesWindow: ProfilesWindowController?

    private var profilesURL: URL { paths.directory.appendingPathComponent("profiles") }
    private var store: CaseStore { CaseStore(root: config.rootURL()) }
    private var profile: Profile? { profiles.first { $0.name == state.profile } ?? profiles.first }

    private static let sView = "io.github.usuite.sview"
    private static let sNotate = "io.github.usuite.snotate"

    func applicationDidFinishLaunching(_ notification: Notification) {
        EditMenu.install()
        toast.onClick = { [weak self] url in
            self?.openFile(url)
        }
        state = State.load(paths.state)
        if let output = environment["SCAPTURE_SMOKE"] {
            loadSettings()
            Smoke(output: URL(fileURLWithPath: output, isDirectory: true)).run(
                profiles: profiles,
                caseID: state.activeCase,
                store: store,
                config: config,
                service: service
            ) { [weak self] in
                let folder = URL(fileURLWithPath: output, isDirectory: true)
                await self?.snapshot("settings.png", to: folder) {
                    self?.openSettings()
                    return self?.settings
                }
                await self?.snapshot("profiles.png", to: folder) {
                    self?.openProfiles()
                    return self?.profilesWindow
                }
            }
            return
        }
        hotKeys = HotKeys { [weak self] command in
            self?.run(command)
        }
        loadSettings()
        buildStatusItem()
        configWatcher = DirectoryWatcher(
            url: paths.directory,
            files: ["config", "keymap", "profiles"]
        ) { [weak self] in
            MainActor.assumeIsolated {
                self?.loadSettings()
            }
        }
        if !Permissions.screenRecording {
            Permissions.requestScreenRecording()
        }
    }

    /// Reads config, keymap and profiles; at launch and whenever one of the
    /// files changes, so edits apply without a restart (SC-505).
    private func loadSettings() {
        problems.removeAll()
        do {
            try paths.ensureDefaults(
                config: Config.defaultText,
                keymap: HotkeyMap.defaultText
            )
            if !FileManager.default.fileExists(atPath: profilesURL.path) {
                try Data(Profiles.defaultText.utf8).write(to: profilesURL, options: .atomic)
            }
        } catch {
            problems.append("config folder: \(error.localizedDescription)")
        }
        let loaded = paths.load(Config.self)
        config = loaded.config
        problems += loaded.issues.map { "config \($0)" }
        let keymapText = (try? String(contentsOf: paths.keymap, encoding: .utf8)) ?? ""
        let overlaid = HotkeyMap.overlaid(keymapText)
        problems += overlaid.issues.map { "keymap \($0)" }
        if let hotKeys, overlaid.map != hotkeys || hotkeys.bindings.isEmpty {
            hotkeys = overlaid.map
            refusedKeys = hotKeys.register(hotkeys)
        } else {
            hotkeys = overlaid.map
        }
        problems += refusedKeys.map { "\($0) is taken by another app" }
        problems += hotkeys.systemConflicts.map { "\($0) is also a macOS screenshot key" }
        let profilesText = (try? String(contentsOf: profilesURL, encoding: .utf8)) ?? ""
        let parsed = Profiles.parse(profilesText)
        profiles = parsed.profiles
        problems += parsed.issues.map { "profiles \($0)" }
        if profiles.isEmpty {
            problems.append("no profile: add one to the profiles file")
        }
        if let name = state.profile, !profiles.contains(where: { $0.name == name }) {
            state.profile = profiles.first?.name
        }
        for problem in problems {
            log.notice("\(problem, privacy: .public)")
        }
        watchCase()
        updateTitle()
        settings?.model.refresh()
        profilesWindow?.model.refresh()
    }

    private func saveState() {
        do {
            try state.save(paths.state)
        } catch {
            log.error("state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg").flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "sCapture")
        icon?.size = NSSize(width: 18, height: 18)
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        updateTitle()
    }

    /// `<case>  7  <profile>` next to the icon; the icon alone and dimmed
    /// when no case is active (SC-101).
    private func updateTitle() {
        guard let button = statusItem?.button else {
            return
        }
        let title = NSMutableAttributedString()
        let font = NSFont.menuBarFont(ofSize: 0)
        if let id = state.activeCase, store.exists(id) {
            title.append(NSAttributedString(string: " \(id)  \(store.count(id))", attributes: [.font: font]))
            if let profile {
                title.append(
                    NSAttributedString(
                        string: "  \(profile.name)",
                        attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
                    )
                )
            }
        }
        button.attributedTitle = title
        button.appearsDisabled = title.length == 0
    }

    /// Keeps the count honest when files are deleted or renamed (SC-105).
    private func watchCase() {
        caseWatcher = nil
        guard let id = state.activeCase, store.exists(id) else {
            return
        }
        caseWatcher = DirectoryWatcher(url: store.url(of: id)) { [weak self] in
            MainActor.assumeIsolated {
                self?.updateTitle()
            }
        }
    }

    func run(_ command: Command) {
        switch command {
        case .captureWindow:
            capture(again: false)
        case .captureRepeat:
            capture(again: true)
        case .position:
            place()
        case .openMenu:
            statusItem.button?.performClick(nil)
        case .openCase:
            openCase(with: nil)
        case .profile(let n):
            guard profiles.indices.contains(n - 1) else {
                toast.show(title: "no profile \(n)", isError: true, seconds: config.toastSeconds)
                return
            }
            pick(profile: profiles[n - 1].name)
            toast.show(title: "profile \(profiles[n - 1].name)", seconds: config.toastSeconds)
        }
    }

    private func capture(again: Bool) {
        guard !busy else {
            return
        }
        guard let profile else {
            fail(.write("no profile: add one to the profiles file"))
            return
        }
        guard Permissions.screenRecording else {
            Permissions.requestScreenRecording()
            fail(.screenRecordingDenied)
            return
        }
        busy = true
        Task { @MainActor in
            defer {
                busy = false
            }
            do throws(CaptureError) {
                let result = try await service.capture(
                    profile,
                    caseID: state.activeCase,
                    store: store,
                    config: config,
                    again: again
                )
                state.captured(result.caseID, with: profile.name)
                saveState()
                if config.flash {
                    flash.show(result.rect)
                }
                toast.show(
                    title: "\(result.caseID)  step \(String(format: "%02d", result.count))  \(result.pixels)",
                    detail: result.warnings,
                    image: result.file,
                    seconds: config.toastSeconds
                )
                updateTitle()
                log.info("\(result.file.lastPathComponent, privacy: .public) \(result.pixels.description, privacy: .public) \(result.milliseconds) ms")
            } catch {
                fail(error)
            }
        }
    }

    private func place() {
        guard let profile else {
            fail(.write("no profile: add one to the profiles file"))
            return
        }
        guard profile.frame != nil else {
            toast.show(title: "\(profile.name) has no origin and size to place", isError: true, seconds: config.toastSeconds)
            return
        }
        if !Permissions.accessibility {
            Permissions.requestAccessibility()
        }
        Task { @MainActor in
            do throws(CaptureError) {
                let placed = try await service.place(profile, config: config)
                toast.show(
                    title: "placed \(placed.window.app)",
                    detail: placed.warnings,
                    seconds: config.toastSeconds
                )
            } catch {
                fail(error)
            }
        }
    }

    private func fail(_ error: CaptureError) {
        log.error("\(error.description, privacy: .public)")
        toast.show(title: error.description, isError: true, seconds: config.toastSeconds)
    }

    private func pick(case id: String) {
        state.pick(id)
        saveState()
        watchCase()
        updateTitle()
    }

    private func pick(profile name: String) {
        state.profile = name
        saveState()
        updateTitle()
    }

    private func newCase() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "poc-demo-vm-stop"
        var message = "Lower-case letters and digits joined by hyphens. The folder is made in \(config.root)."
        NSApp.activate()
        while true {
            let alert = NSAlert()
            alert.messageText = "New Case"
            alert.informativeText = message
            alert.accessoryView = field
            alert.addButton(withTitle: "Create")
            alert.addButton(withTitle: "Cancel")
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn else {
                return
            }
            let id = field.stringValue.trimmingCharacters(in: .whitespaces)
            do {
                try store.create(id)
                pick(case: id)
                return
            } catch {
                message = (error as? CaseStore.CaseError)?.description ?? error.localizedDescription
            }
        }
    }

    private func appURL(_ bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    private func openCase(with bundleID: String?) {
        guard let id = state.activeCase, store.exists(id) else {
            fail(.noCase)
            return
        }
        let url = store.url(of: id)
        if let bundleID, let app = appURL(bundleID) {
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// A toast click: the capture in sNotate, else sView, else the default
    /// app.
    private func openFile(_ url: URL) {
        if let app = appURL(Self.sNotate) ?? appURL(Self.sView) {
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let store = self.store
        let active = state.activeCase.flatMap { store.exists($0) ? $0 : nil }
        if let active {
            let count = store.count(active)
            menu.addItem(disabled("\(active): \(count) capture\(count == 1 ? "" : "s")"))
        } else {
            menu.addItem(disabled("No active case"))
        }
        menu.addItem(item("Capture Window", command: .captureWindow, enabled: active != nil))
        menu.addItem(item("Repeat Last Window", command: .captureRepeat, enabled: active != nil && service.lastWindow != nil))
        menu.addItem(item("Place Window", command: .position, enabled: profile?.frame != nil))

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Cases"))
        let cases = store.cases()
        if cases.isEmpty {
            menu.addItem(disabled("No cases in \(config.root)"))
        }
        for folder in cases.prefix(9) {
            menu.addItem(caseItem(folder.id, active: active))
        }
        if cases.count > 9 {
            let more = NSMenuItem(title: "More Cases", action: nil, keyEquivalent: "")
            more.submenu = NSMenu()
            for folder in cases.dropFirst(9) {
                more.submenu?.addItem(caseItem(folder.id, active: active))
            }
            menu.addItem(more)
        }
        menu.addItem(action("New Case…") { [weak self] in
            self?.newCase()
        })

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Profiles"))
        for (index, profile) in profiles.enumerated() {
            let entry = item(profile.name, command: .profile(index + 1), enabled: true)
            entry.state = profile.name == self.profile?.name ? .on : .off
            entry.toolTip = profileSummary(profile)
            menu.addItem(entry)
        }
        menu.addItem(action("Edit Profiles…") { [weak self] in
            self?.openProfiles()
        })

        menu.addItem(.separator())
        menu.addItem(item("Open Case in Finder", command: .openCase, enabled: active != nil))
        for (name, bundleID) in [("sView", Self.sView), ("sNotate", Self.sNotate)] where appURL(bundleID) != nil {
            let entry = action("Open Case in \(name)") { [weak self] in
                self?.openCase(with: bundleID)
            }
            entry.isEnabled = active != nil
            menu.addItem(entry)
        }
        menu.addItem(action("Open Config Folder") { [weak self] in
            guard let self else {
                return
            }
            NSWorkspace.shared.open(paths.directory)
        })

        var notes: [NSMenuItem] = []
        if !Permissions.screenRecording {
            notes.append(action("Allow Screen Recording…") {
                Permissions.requestScreenRecording()
                Permissions.openSettings("Privacy_ScreenCapture")
            })
        }
        if !Permissions.accessibility, profiles.contains(where: { $0.frame != nil }) {
            notes.append(action("Allow Accessibility to Place Windows…") {
                Permissions.requestAccessibility()
                Permissions.openSettings("Privacy_Accessibility")
            })
        }
        for problem in problems.prefix(6) {
            let entry = disabled(problem)
            entry.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "problem")
            notes.append(entry)
        }
        if !notes.isEmpty {
            menu.addItem(.separator())
            notes.forEach(menu.addItem)
        }

        menu.addItem(.separator())
        let login = action("Launch at Login") {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled {
                    try service.unregister()
                } else {
                    try service.register()
                }
            } catch {
                log.error("launch at login: \(error.localizedDescription, privacy: .public)")
            }
        }
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        let settingsItem = action("Settings…") { [weak self] in
            self?.openSettings()
        }
        settingsItem.keyEquivalent = ","
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        menu.addItem(disabled("sCapture \(version)"))
        menu.addItem(NSMenuItem(title: "Quit sCapture", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func openSettings() {
        if settings == nil {
            let model = SettingsModel(paths: paths)
            model.current = { [weak self] in
                guard let self else {
                    return (Config(), [])
                }
                return (config, problems)
            }
            model.onWrite = { [weak self] in
                self?.loadSettings()
            }
            model.openProfiles = { [weak self] in
                self?.openProfiles()
            }
            settings = SettingsWindowController(model: model)
        }
        settings?.show()
    }

    private func openProfiles() {
        if profilesWindow == nil {
            let model = ProfilesModel(
                url: profilesURL,
                windows: windows,
                service: service
            )
            model.config = { [weak self] in
                self?.config ?? Config()
            }
            model.onWrite = { [weak self] in
                self?.loadSettings()
            }
            profilesWindow = ProfilesWindowController(model: model)
        }
        profilesWindow?.show()
    }

    /// Smoke mode: the Settings or the Profiles window as a PNG, so its
    /// layout is checked without a click.
    private func snapshot(
        _ name: String,
        to folder: URL,
        of open: () -> NSWindowController?
    ) async {
        let controller = open()
        try? await Task.sleep(for: .milliseconds(500))
        guard let view = controller?.window?.contentView,
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else {
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(name))
    }

    private func profileSummary(_ profile: Profile) -> String {
        var parts = [profile.app.description]
        if let window = profile.window {
            parts.append("window '\(window)'")
        }
        if let frame = profile.frame {
            parts.append("\(Int(frame.width)) x \(Int(frame.height)) at \(Int(frame.minX)), \(Int(frame.minY))")
        }
        parts.append("scale \(profile.scale)")
        return parts.joined(separator: ", ")
    }

    private func caseItem(
        _ id: String,
        active: String?
    ) -> NSMenuItem {
        let entry = action(id) { [weak self] in
            self?.pick(case: id)
        }
        entry.state = id == active ? .on : .off
        return entry
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.isEnabled = false
        return entry
    }

    /// An item for a command, showing its global key in the key column.
    private func item(
        _ title: String,
        command: Command,
        enabled: Bool
    ) -> NSMenuItem {
        let entry = action(title) { [weak self] in
            self?.run(command)
        }
        entry.isEnabled = enabled
        if let hotkey = hotkeys.hotkey(for: command), let (key, flags) = HotKeys.keyEquivalent(hotkey) {
            entry.keyEquivalent = key
            entry.keyEquivalentModifierMask = flags
        }
        return entry
    }

    private func action(
        _ title: String,
        _ perform: @escaping () -> Void
    ) -> NSMenuItem {
        let entry = ClosureMenuItem(title: title, perform: perform)
        return entry
    }
}

/// A menu item that runs a closure, so the menu needs no selector per entry.
private final class ClosureMenuItem: NSMenuItem {
    private let perform: () -> Void

    init(
        title: String,
        perform: @escaping () -> Void
    ) {
        self.perform = perform
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("not used")
    }

    @objc private func fire() {
        perform()
    }
}
