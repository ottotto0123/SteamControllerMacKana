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

        // NSTextField は垂直方向が上揃えになるため、
        // テキストサイズを計算してフレームを動的にセットするカスタムビューを使う
        let lbl = CenteredLabel(frame: root.bounds)
        lbl.autoresizingMask = [.width, .height]
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
        guard let lbl = p.contentView?.subviews.first(where: { $0 is CenteredLabel }) as? CenteredLabel else { return }
        lbl.text = text
    }
}

// テキストを水平・垂直ともに正確に中央配置するビュー
private final class CenteredLabel: NSView {
    var text: String = "" { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let font = NSFont.boldSystemFont(ofSize: 28)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let astr = NSAttributedString(string: text, attributes: attrs)
        let sz = astr.size()
        let x = (bounds.width  - sz.width)  / 2
        let y = (bounds.height - sz.height) / 2
        astr.draw(at: NSPoint(x: x, y: y))
    }
}
