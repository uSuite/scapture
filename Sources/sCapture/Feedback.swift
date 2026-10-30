import AppKit
import SCaptureCore

/// AppKit's bottom-left screen rect for a top-left one from the window list.
func appKitRect(_ rect: CGRect) -> NSRect {
    let height = NSScreen.screens.first?.frame.maxY ?? 0
    return NSRect(
        x: rect.minX,
        y: height - rect.maxY,
        width: rect.width,
        height: rect.height
    )
}

/// A floating panel that never takes focus, so the captured app stays in
/// front.
private func overlayPanel(_ frame: NSRect) -> NSPanel {
    let panel = NSPanel(
        contentRect: frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.level = .statusBar
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    return panel
}

/// The 150 ms flash on the captured rect (SC-403), drawn after the capture
/// so it is never in the picture.
@MainActor
final class Flash {
    private var panel: NSPanel?

    func show(_ rect: CGRect) {
        panel?.orderOut(nil)
        let panel = overlayPanel(appKitRect(rect))
        panel.ignoresMouseEvents = true
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.45).cgColor
        panel.contentView = view
        panel.orderFrontRegardless()
        self.panel = panel
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                panel.orderOut(nil)
            }
        }
    }
}

/// The corner toast: thumbnail, `<case>  step 07  3036x1784`, warnings in
/// orange, errors in red; it fades after the configured seconds, and a click
/// opens the file (SC-403).
@MainActor
final class Toast {
    private var panel: NSPanel?
    private var hide: DispatchWorkItem?
    var onClick: ((URL) -> Void)?

    func show(
        title: String,
        detail: [String] = [],
        image: URL? = nil,
        isError: Bool = false,
        seconds: Int
    ) {
        guard seconds > 0 || isError else {
            return
        }
        hide?.cancel()
        panel?.orderOut(nil)
        let content = ToastView(file: image) { [weak self] url in
            self?.panel?.orderOut(nil)
            self?.onClick?(url)
        }
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 14)
        if let image, let thumbnail = NSImage(contentsOf: image) {
            let view = NSImageView(image: thumbnail)
            view.imageScaling = .scaleProportionallyUpOrDown
            view.wantsLayer = true
            view.layer?.cornerRadius = 4
            view.layer?.masksToBounds = true
            let ratio = thumbnail.size.height / max(thumbnail.size.width, 1)
            view.widthAnchor.constraint(equalToConstant: 96).isActive = true
            view.heightAnchor.constraint(equalToConstant: min(96 * ratio, 72)).isActive = true
            stack.addArrangedSubview(view)
        }
        let lines = NSStackView()
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = 2
        let head = NSTextField(labelWithString: title)
        head.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        head.textColor = isError ? .systemRed : .labelColor
        lines.addArrangedSubview(head)
        for line in detail {
            let label = NSTextField(wrappingLabelWithString: line)
            label.font = .systemFont(ofSize: 11)
            label.textColor = isError ? .secondaryLabelColor : .systemOrange
            label.preferredMaxLayoutWidth = 260
            lines.addArrangedSubview(label)
        }
        stack.addArrangedSubview(lines)
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        content.addSubview(effect)
        effect.addSubview(stack)
        for (view, parent) in [(effect, content as NSView), (stack, effect)] {
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
                view.topAnchor.constraint(equalTo: parent.topAnchor),
                view.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            ])
        }
        let size = content.fittingSize
        let screen = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        let frame = NSRect(
            x: screen.maxX - size.width - 16,
            y: screen.minY + 16,
            width: size.width,
            height: size.height
        )
        let panel = overlayPanel(frame)
        panel.hasShadow = true
        panel.contentView = content
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        self.panel = panel
        let work = DispatchWorkItem { [weak panel] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel?.animator().alphaValue = 0
            } completionHandler: {
                MainActor.assumeIsolated {
                    panel?.orderOut(nil)
                }
            }
        }
        hide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(isError ? max(seconds, 4) : seconds), execute: work)
    }

    var isVisible: Bool { panel?.isVisible == true }
}

private final class ToastView: NSView {
    private let file: URL?
    private let click: (URL) -> Void

    init(
        file: URL?,
        click: @escaping (URL) -> Void
    ) {
        self.file = file
        self.click = click
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if let file {
            click(file)
        }
    }
}
