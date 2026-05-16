import AppKit
import ServiceManagement

// キー選択肢
private struct KeyOption {
    let label: String
    let keyCode: UInt16
}

private let keyOptions: [(group: String, keys: [KeyOption])] = [
    ("特殊キー", [
        KeyOption(label: "` (バッククォート)", keyCode: 50),
        KeyOption(label: "Space",              keyCode: 49),
        KeyOption(label: "Tab",                keyCode: 48),
        KeyOption(label: "Esc",                keyCode: 53),
        KeyOption(label: "↩ Return",           keyCode: 36),
        KeyOption(label: "⌫ Delete",           keyCode: 51),
    ]),
    ("アルファベット", (0..<26).map { i in
        let c = Character(UnicodeScalar(UInt32(65 + i))!)  // A-Z
        let kcs: [UInt16] = [0,11,8,2,14,3,5,4,34,38,40,37,46,45,31,35,12,15,1,17,32,9,13,7,16,6]
        return KeyOption(label: String(c), keyCode: kcs[i])
    }),
    ("数字", (0...9).map { i in
        let kcs: [UInt16] = [29,18,19,20,21,23,22,26,28,25]
        return KeyOption(label: "\(i)", keyCode: kcs[i])
    }),
    ("記号", [
        KeyOption(label: "- (ハイフン)",   keyCode: 27),
        KeyOption(label: "= (イコール)",   keyCode: 24),
        KeyOption(label: "[ (左ブラケット)", keyCode: 33),
        KeyOption(label: "] (右ブラケット)", keyCode: 30),
        KeyOption(label: "\\ (バックスラッシュ)", keyCode: 42),
        KeyOption(label: "; (セミコロン)", keyCode: 41),
        KeyOption(label: "' (シングルクォート)", keyCode: 39),
        KeyOption(label: ", (カンマ)",     keyCode: 43),
        KeyOption(label: ". (ピリオド)",   keyCode: 47),
        KeyOption(label: "/ (スラッシュ)", keyCode: 44),
    ]),
    ("ファンクションキー", [
        KeyOption(label: "F1",  keyCode: 122), KeyOption(label: "F2",  keyCode: 120),
        KeyOption(label: "F3",  keyCode: 99),  KeyOption(label: "F4",  keyCode: 118),
        KeyOption(label: "F5",  keyCode: 96),  KeyOption(label: "F6",  keyCode: 97),
        KeyOption(label: "F7",  keyCode: 98),  KeyOption(label: "F8",  keyCode: 100),
        KeyOption(label: "F9",  keyCode: 101), KeyOption(label: "F10", keyCode: 109),
        KeyOption(label: "F11", keyCode: 103), KeyOption(label: "F12", keyCode: 111),
    ]),
]

// MARK: -

final class PreferencesWindow: NSObject {
    var onBindingChanged: ((KeyBinding) -> Void)?

    private var window: NSPanel?

    private var selectedKeyCode: UInt16 = KeyBinding.load().keyCode
    private var modControl  = false
    private var modOption   = false
    private var modShift    = false
    private var modCommand  = false

    private var keyPopup: NSPopUpButton?
    private var previewLabel: NSTextField?

    func show() {
        if let w = window {
            syncFromBinding(KeyBinding.load())
            refreshUI()
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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 230),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        w.title = "SteamControllerMacKana 設定"
        w.isFloatingPanel = true
        w.center()

        let root = w.contentView!

        // ── トグルキー セクション ──
        root.addSubview(sectionLabel("トグルキー", x: 16, y: 192))

        // 修飾キー
        root.addSubview(inlineLabel("修飾キー", x: 16, y: 162))
        let modRow = NSView(frame: NSRect(x: 100, y: 158, width: 240, height: 28))
        let modDefs = [("⌃", 0), ("⌥", 1), ("⇧", 2), ("⌘", 3)]
        var mx: CGFloat = 0
        for (title, tag) in modDefs {
            let cb = NSButton(checkboxWithTitle: title, target: self, action: #selector(modChanged(_:)))
            cb.frame = NSRect(x: mx, y: 0, width: 52, height: 28)
            cb.tag = tag
            let states = [modControl, modOption, modShift, modCommand]
            cb.state = states[tag] ? .on : .off
            modRow.addSubview(cb)
            mx += 54
        }
        root.addSubview(modRow)

        // キー選択ポップアップ
        root.addSubview(inlineLabel("キー", x: 16, y: 122))
        let popup = NSPopUpButton(frame: NSRect(x: 100, y: 118, width: 230, height: 28), pullsDown: false)
        for group in keyOptions {
            let header = NSMenuItem(title: group.group, action: nil, keyEquivalent: "")
            header.isEnabled = false
            popup.menu?.addItem(header)
            for key in group.keys {
                let item = NSMenuItem(title: key.label, action: nil, keyEquivalent: "")
                item.tag = Int(key.keyCode)
                popup.menu?.addItem(item)
            }
            popup.menu?.addItem(.separator())
        }
        popup.target = self
        popup.action = #selector(keyPopupChanged(_:))
        root.addSubview(popup)
        keyPopup = popup
        selectPopupItem(keyCode: selectedKeyCode)

        // プレビュー
        root.addSubview(inlineLabel("現在の設定", x: 16, y: 86))
        let preview = NSTextField(labelWithString: currentDisplayString)
        preview.frame = NSRect(x: 100, y: 84, width: 230, height: 22)
        preview.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        preview.textColor = .labelColor
        root.addSubview(preview)
        previewLabel = preview

        // ── スタートアップ ──
        let sep = NSBox(frame: NSRect(x: 16, y: 66, width: 328, height: 1))
        sep.boxType = .separator
        root.addSubview(sep)

        let check = NSButton(checkboxWithTitle: "ログイン時に自動起動",
                             target: self, action: #selector(toggleStartup(_:)))
        check.frame = NSRect(x: 16, y: 40, width: 260, height: 24)
        check.state = isLoginItemEnabled ? .on : .off
        root.addSubview(check)

        // ── ボタン ──
        let reset = NSButton(title: "デフォルトに戻す", target: self, action: #selector(resetKey))
        reset.frame = NSRect(x: 16, y: 10, width: 130, height: 28)
        reset.bezelStyle = .rounded
        root.addSubview(reset)

        let save = NSButton(title: "保存", target: self, action: #selector(saveAndClose))
        save.frame = NSRect(x: 260, y: 10, width: 84, height: 28)
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

    // MARK: - Actions

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

    @objc private func keyPopupChanged(_ sender: NSPopUpButton) {
        guard let item = sender.selectedItem, item.isEnabled else { return }
        selectedKeyCode = UInt16(item.tag)
        updatePreview()
    }

    @objc private func resetKey() {
        syncFromBinding(.defaultBinding)
        refreshUI()
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

    // MARK: - Helpers

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
        return s
    }

    private var currentModifiers: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if modControl { f.insert(.control) }
        if modOption  { f.insert(.option) }
        if modShift   { f.insert(.shift) }
        if modCommand { f.insert(.command) }
        return f
    }

    private func syncFromBinding(_ b: KeyBinding) {
        selectedKeyCode = b.keyCode
        let f = b.modifierFlags
        modControl = f.contains(.control)
        modOption  = f.contains(.option)
        modShift   = f.contains(.shift)
        modCommand = f.contains(.command)
    }

    private func refreshUI() {
        selectPopupItem(keyCode: selectedKeyCode)
        updatePreview()
        // チェックボックス更新
        guard let root = window?.contentView else { return }
        let states = [modControl, modOption, modShift, modCommand]
        for sub in root.subviews {
            for cb in sub.subviews.compactMap({ $0 as? NSButton }) where cb.tag >= 0 && cb.tag < 4 {
                cb.state = states[cb.tag] ? .on : .off
            }
        }
    }

    private func selectPopupItem(keyCode: UInt16) {
        guard let popup = keyPopup else { return }
        for item in popup.menu?.items ?? [] {
            if item.tag == Int(keyCode) && item.isEnabled {
                popup.select(item)
                return
            }
        }
    }

    // MARK: - Startup

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
