import AppKit
import ServiceManagement

final class PreferencesWindow: NSObject {
    var onBindingChanged: ((KeyBinding) -> Void)?

    private var window: NSPanel?

    // 状態
    private var selectedKeyCode: UInt16 = KeyBinding.load().keyCode
    private var modControl  = false
    private var modOption   = false
    private var modShift    = false
    private var modCommand  = false

    // ビュー参照
    private var keyField: SingleKeyCaptureField?
    private var previewLabel: NSTextField?
    private var startupCheck: NSButton?

    func show() {
        if let w = window {
            syncFromBinding(KeyBinding.load())
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        syncFromBinding(KeyBinding.load())
        let w = buildWindow()
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Build

    private func buildWindow() -> NSPanel {
        let w = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 230),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        w.title = "SteamControllerMacKana 設定"
        w.isFloatingPanel = true
        w.center()

        let root = w.contentView!

        // ── セクションヘッダー ──
        let header = sectionLabel("トグルキー", x: 16, y: 192)
        root.addSubview(header)

        // ── 修飾キー チェックボックス ──
        let modRow = NSView(frame: NSRect(x: 100, y: 162, width: 220, height: 24))
        let modDefs: [(String, WritableKeyPath<PreferencesWindow, Bool>)] = [
            ("⌃", \.modControl), ("⌥", \.modOption),
            ("⇧", \.modShift),   ("⌘", \.modCommand),
        ]
        var mx: CGFloat = 0
        for (title, kp) in modDefs {
            let cb = NSButton(checkboxWithTitle: title, target: self, action: #selector(modChanged(_:)))
            cb.frame = NSRect(x: mx, y: 0, width: 48, height: 24)
            cb.state = self[keyPath: kp] ? .on : .off
            cb.tag = modDefs.firstIndex(where: { $0.0 == title })!
            modRow.addSubview(cb)
            mx += 50
        }
        root.addSubview(inlineLabel("修飾キー", x: 16, y: 166))
        root.addSubview(modRow)

        // ── キー入力フィールド ──
        root.addSubview(inlineLabel("キー", x: 16, y: 126))
        let field = SingleKeyCaptureField(frame: NSRect(x: 100, y: 122, width: 180, height: 28))
        field.keyCode = selectedKeyCode
        field.onCapture = { [weak self] kc in
            self?.selectedKeyCode = kc
            self?.updatePreview()
        }
        root.addSubview(field)
        keyField = field

        // ── プレビュー ──
        root.addSubview(inlineLabel("現在の設定", x: 16, y: 90))
        let preview = NSTextField(labelWithString: currentDisplayString)
        preview.frame = NSRect(x: 100, y: 88, width: 200, height: 22)
        preview.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        preview.textColor = .labelColor
        root.addSubview(preview)
        previewLabel = preview

        // ── スタートアップ ──
        let sep = NSBox(frame: NSRect(x: 16, y: 70, width: 308, height: 1))
        sep.boxType = .separator
        root.addSubview(sep)

        let check = NSButton(checkboxWithTitle: "ログイン時に自動起動",
                             target: self, action: #selector(toggleStartup(_:)))
        check.frame = NSRect(x: 16, y: 44, width: 240, height: 24)
        check.state = isLoginItemEnabled ? .on : .off
        root.addSubview(check)
        startupCheck = check

        // ── ボタン ──
        let reset = NSButton(title: "デフォルトに戻す", target: self, action: #selector(resetKey))
        reset.frame = NSRect(x: 16, y: 12, width: 130, height: 28)
        reset.bezelStyle = .rounded
        root.addSubview(reset)

        let save = NSButton(title: "保存", target: self, action: #selector(saveAndClose))
        save.frame = NSRect(x: 240, y: 12, width: 84, height: 28)
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        root.addSubview(save)

        return w
    }

    private func sectionLabel(_ s: String, x: CGFloat, y: CGFloat) -> NSTextField {
        let lbl = NSTextField(labelWithString: s)
        lbl.frame = NSRect(x: x, y: y, width: 300, height: 20)
        lbl.font = NSFont.boldSystemFont(ofSize: 12)
        lbl.textColor = .secondaryLabelColor
        return lbl
    }

    private func inlineLabel(_ s: String, x: CGFloat, y: CGFloat) -> NSTextField {
        let lbl = NSTextField(labelWithString: s)
        lbl.frame = NSRect(x: x, y: y, width: 80, height: 22)
        lbl.alignment = .right
        lbl.font = NSFont.systemFont(ofSize: 13)
        return lbl
    }

    // MARK: - 修飾キー変更

    @objc private func modChanged(_ sender: NSButton) {
        switch sender.tag {
        case 0: modControl = sender.state == .on
        case 1: modOption  = sender.state == .on
        case 2: modShift   = sender.state == .on
        case 3: modCommand = sender.state == .on
        default: break
        }
        updatePreview()
    }

    private func updatePreview() {
        previewLabel?.stringValue = currentDisplayString
    }

    private var currentDisplayString: String {
        var s = ""
        if modControl { s += "⌃" }
        if modOption  { s += "⌥" }
        if modShift   { s += "⇧" }
        if modCommand { s += "⌘" }
        s += KeyBinding(keyCode: selectedKeyCode, modifiers: 0).displayString
            .trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? "—" : s
    }

    private var currentModifiers: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if modControl { f.insert(.control) }
        if modOption  { f.insert(.option) }
        if modShift   { f.insert(.shift) }
        if modCommand { f.insert(.command) }
        return f
    }

    // MARK: - 同期

    private func syncFromBinding(_ b: KeyBinding) {
        selectedKeyCode = b.keyCode
        let f = b.modifierFlags
        modControl = f.contains(.control)
        modOption  = f.contains(.option)
        modShift   = f.contains(.shift)
        modCommand = f.contains(.command)
    }

    // MARK: - Actions

    @objc private func resetKey() {
        syncFromBinding(.defaultBinding)
        keyField?.keyCode = selectedKeyCode
        rebuildModCheckboxes()
        updatePreview()
    }

    @objc private func toggleStartup(_ sender: NSButton) {
        setLoginItem(enabled: sender.state == .on)
    }

    @objc private func saveAndClose() {
        let binding = KeyBinding(keyCode: selectedKeyCode,
                                 modifiers: UInt64(currentModifiers.rawValue))
        binding.save()
        onBindingChanged?(binding)
        window?.orderOut(nil)
    }

    // チェックボックスの状態を再描画
    private func rebuildModCheckboxes() {
        guard let root = window?.contentView else { return }
        let states = [modControl, modOption, modShift, modCommand]
        var idx = 0
        for sub in root.subviews {
            for cb in sub.subviews.compactMap({ $0 as? NSButton }) {
                guard cb.tag >= 0 && cb.tag < 4 else { continue }
                if idx < states.count { cb.state = states[idx] ? .on : .off; idx += 1 }
            }
        }
    }

    // MARK: - Startup (SMAppService)

    private var isLoginItemEnabled: Bool {
        if #available(macOS 13, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    private func setLoginItem(enabled: Bool) {
        guard #available(macOS 13, *) else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else        { try SMAppService.mainApp.unregister() }
        } catch { print("[Startup] エラー:", error) }
    }
}

// MARK: - 単一キーキャプチャフィールド（修飾キーなし）

final class SingleKeyCaptureField: NSView {
    var keyCode: UInt16 = 50 { didSet { needsDisplay = true } }
    var onCapture: ((UInt16) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let isActive = window?.firstResponder === self
        let bg: NSColor = isActive ? .selectedControlColor : .controlBackgroundColor
        bg.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()

        let text = isActive ? "キーを押してください…" : KeyBinding(keyCode: keyCode, modifiers: 0).displayString
        let color: NSColor = isActive ? .secondaryLabelColor : .labelColor
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

    override func resignFirstResponder() -> Bool { needsDisplay = true; return super.resignFirstResponder() }
    override func becomeFirstResponder() -> Bool  { needsDisplay = true; return super.becomeFirstResponder() }

    override func keyDown(with event: NSEvent) {
        // 修飾キー単体は無視
        let modOnlyCodes: [UInt16] = [54,55,56,57,58,59,60,61,62,63]
        guard !modOnlyCodes.contains(event.keyCode) else { return }
        keyCode = event.keyCode
        onCapture?(event.keyCode)
        window?.makeFirstResponder(nil)
    }
}
