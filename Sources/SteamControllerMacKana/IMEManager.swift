import Carbon
import Foundation

final class IMEManager {
    var onChanged: ((Bool) -> Void)?   // true = Japanese active

    private let jaSourceID = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
    private let enSourceID = "com.apple.keylayout.ABC"

    // MARK: - Query

    var isJapanese: Bool {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
        guard let idRef = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return false }
        let id = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
        return id.contains("Japanese") || id.contains("Kotoeri") || id.contains("hiragana") || id.contains("katakana")
    }

    // MARK: - Switch

    func toggle() {
        if isJapanese { switchToEnglish() } else { switchToJapanese() }
    }

    func switchToJapanese() {
        if !activate(containing: "Japanese") { activate(containing: "Kotoeri") }
    }

    func switchToEnglish() {
        if !activate(id: enSourceID) { if !activate(containing: "ABC") { activate(containing: "US") } }
    }

    // MARK: - Observe

    func startObserving() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(imeChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    @objc private func imeChanged() {
        DispatchQueue.main.async { self.onChanged?(self.isJapanese) }
    }

    // MARK: - Helpers

    @discardableResult
    private func activate(id: String) -> Bool {
        guard let list = TISCreateInputSourceList(
            [kTISPropertyInputSourceID: id] as CFDictionary, false
        )?.takeRetainedValue() as? [TISInputSource], let src = list.first else { return false }
        return TISSelectInputSource(src) == noErr
    }

    @discardableResult
    private func activate(containing substring: String) -> Bool {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else { return false }
        for src in list {
            guard let idRef = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(idRef).takeUnretainedValue() as String
            if id.contains(substring) {
                return TISSelectInputSource(src) == noErr
            }
        }
        return false
    }
}
