import AppKit
import ServiceManagement

final class PreferencesWindow: NSObject {
    var onBindingChanged: ((KeyBinding) -> Void)?

    private var window: NSPanel?
    private var captureField: KeyCaptureField?
    private var startupCheck: NSButton?
    private var currentBinding = KeyBinding.load()

    func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = buildWindow()
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Build

    private func buildWindow() -> NSPanel {
        let w = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        w.title = "SteamControllerMacKana 設定"
        w.isFloatingPanel = true
        w.center()

        let root = w.contentView!
        var y: CGFloat = 130

        // ── トグルキー ──
        label(root, "トグルキー", x: 20, y: y)
        let field = KeyCaptureField(frame: NSRect(x: 130, y: y - 2, width: 120, height: 28))
        field.binding = currentBinding
        field.onCapture = { [weak self] binding in
            self?.currentBinding = binding
        }
        root.addSubview(field)
        captureField = field
        y -= 44

        // ── リセットボタン ──
        let reset = NSButton(title: "デフォルトに戻す", target: self, action: #selector(resetKey))
        reset.frame = NSRect(x: 130, y: y, width: 120, height: 24)
        reset.bezelStyle = .inline
        root.addSubview(reset)
        y -= 44

        // ── スタートアップ ──
        let check = NSButton(checkboxWithTitle: "ログイン時に自動起動", target: self, action: #selector(toggleStartup))
        check.frame = NSRect(x: 20, y: y, width: 260, height: 24)
        check.state = isLoginItemEnabled ? .on : .off
        root.addSubview(check)
        startupCheck = check
        y -= 44

        // ── 保存ボタン ──
        let save = NSButton(title: "保存", target: self, action: #selector(saveAndClose))
        save.frame = NSRect(x: 210, y: 16, width: 88, height: 32)
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        root.addSubview(save)

        return w
    }

    private func label(_ parent: NSView, _ text: String, x: CGFloat, y: CGFloat) {
        let lbl = NSTextField(labelWithString: text)
        lbl.frame = NSRect(x: x, y: y, width: 100, height: 22)
        lbl.alignment = .right
        parent.addSubview(lbl)
    }

    // MARK: - Actions

    @objc private func resetKey() {
        currentBinding = .defaultBinding
        captureField?.binding = .defaultBinding
    }

    @objc private func toggleStartup(_ sender: NSButton) {
        setLoginItem(enabled: sender.state == .on)
    }

    @objc private func saveAndClose() {
        currentBinding.save()
        onBindingChanged?(currentBinding)
        window?.orderOut(nil)
    }

    // MARK: - Startup (SMAppService)

    private var isLoginItemEnabled: Bool {
        if #available(macOS 13, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLoginItem(enabled: Bool) {
        guard #available(macOS 13, *) else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else        { try SMAppService.mainApp.unregister() }
        } catch {
            print("[Startup] エラー:", error)
        }
    }
}

// MARK: - キー入力キャプチャフィールド

final class KeyCaptureField: NSView {
    var binding: KeyBinding = .defaultBinding { didSet { needsDisplay = true } }
    var onCapture: ((KeyBinding) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // 背景
        let bg: NSColor = window?.firstResponder === self
            ? NSColor.selectedControlColor
            : NSColor.controlBackgroundColor
        bg.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()

        // ラベル
        let text = window?.firstResponder === self ? "キーを押してください…" : binding.displayString
        let color: NSColor = window?.firstResponder === self ? .secondaryLabelColor : .labelColor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: color,
        ]
        let astr = NSAttributedString(string: text, attributes: attrs)
        let sz = astr.size()
        astr.draw(at: NSPoint(x: (bounds.width - sz.width) / 2,
                              y: (bounds.height - sz.height) / 2))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        // 修飾キー単体は無視
        let modOnly: [UInt16] = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        guard !modOnly.contains(event.keyCode) else { return }

        let allowed: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let mods = event.modifierFlags.intersection(allowed)
        let newBinding = KeyBinding(keyCode: event.keyCode, modifiers: UInt64(mods.rawValue))
        binding = newBinding
        onCapture?(newBinding)
        window?.makeFirstResponder(nil)
    }
}
