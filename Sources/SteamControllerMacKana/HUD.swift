import AppKit

final class HUD {
    private var panel: NSPanel?
    private var hideTimer: Timer?

    func show(_ text: String) {
        hideTimer?.invalidate()

        if panel == nil { panel = makePanel() }
        guard let p = panel else { return }

        updateLabel(p, text: text)
        p.orderFrontRegardless()

        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
            self?.panel?.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        p.backgroundColor = .clear
        p.isOpaque = false
        p.level = .floating
        p.hasShadow = true
        p.ignoresMouseEvents = true

        let root = NSView(frame: p.contentView!.bounds)
        root.wantsLayer = true
        root.layer?.backgroundColor = CGColor(red: 0.05, green: 0.07, blue: 0.14, alpha: 0.88)
        root.layer?.cornerRadius = 14
        p.contentView = root

        let lbl = NSTextField(labelWithString: "")
        lbl.tag = 1
        lbl.frame = root.bounds
        lbl.alignment = .center
        lbl.font = NSFont.boldSystemFont(ofSize: 28)
        lbl.textColor = .white
        root.addSubview(lbl)

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let wx = sf.midX - 100
            let wy = sf.midY + 80
            p.setFrameOrigin(NSPoint(x: wx, y: wy))
        }
        return p
    }

    private func updateLabel(_ p: NSPanel, text: String) {
        guard let lbl = p.contentView?.viewWithTag(1) as? NSTextField else { return }
        lbl.stringValue = text
    }
}
