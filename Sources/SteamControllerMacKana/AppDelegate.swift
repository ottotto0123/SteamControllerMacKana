import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let ime = IMEManager()
    private let hud = HUD()
    private let interceptor = KeyInterceptor()
    private let prefs = PreferencesWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibility()
        buildStatusItem()
        ime.onChanged = { [weak self] isJP in self?.refresh(isJP) }
        ime.startObserving()
        interceptor.onToggle = { [weak self] in self?.ime.toggle() }
        prefs.onBindingChanged = { [weak self] binding in
            self?.interceptor.binding = binding
        }
        interceptor.start()
        refresh(ime.isJapanese)
    }

    private func requestAccessibility() {
        if !AXIsProcessTrusted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
        }
    }

    // MARK: - Status Item

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let btn = statusItem.button else { return }
        btn.title  = "EN"
        btn.font   = NSFont.boldSystemFont(ofSize: 14)
        btn.action = #selector(handleClick)
        btn.target = self
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: - Click

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            ime.toggle()
        }
    }

    private func showMenu() {
        let m = NSMenu()
        addItem(m, "日本語に切り替え", #selector(switchJP))
        addItem(m, "英語に切り替え",   #selector(switchEN))
        m.addItem(.separator())
        addItem(m, "設定...", #selector(openPrefs))
        m.addItem(.separator())
        addItem(m, "終了", #selector(quit))

        statusItem.menu = m
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ sel: Selector) {
        let item = menu.addItem(withTitle: title, action: sel, keyEquivalent: "")
        item.target = self
    }

    @objc private func switchJP()   { ime.switchToJapanese() }
    @objc private func switchEN()   { ime.switchToEnglish() }
    @objc private func openPrefs()  { prefs.show() }
    @objc private func quit()       { NSApp.terminate(nil) }

    // MARK: - Refresh

    private func refresh(_ isJP: Bool) {
        guard let btn = statusItem.button else { return }
        let text = isJP ? "日" : "EN"
        let color: NSColor = isJP
            ? NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return isDark
                    ? NSColor(red: 0.45, green: 1.00, blue: 0.55, alpha: 1.0)
                    : NSColor(red: 0.10, green: 0.65, blue: 0.25, alpha: 1.0)
              }
            : .controlTextColor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: color,
        ]
        btn.attributedTitle = NSAttributedString(string: text, attributes: attrs)
        interceptor.isJapanese = isJP
        hud.show(isJP ? "日本語" : "English")
    }
}
