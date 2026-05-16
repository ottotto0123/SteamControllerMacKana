import AppKit
import Carbon

private let INJECT_MARKER: Int64 = 0x5354494D  // "STIM"

final class KeyInterceptor {
    var isJapanese = false
    var onToggle: (() -> Void)?
    var binding: KeyBinding = KeyBinding.load()

    private var tap: CFMachPort?

    func start() {
        guard AXIsProcessTrusted() else {
            print("[KeyInterceptor] アクセシビリティ権限なし — 5秒後にリトライ")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.start() }
            return
        }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyCB,
            userInfo: ptr
        )
        guard let tap else { print("[KeyInterceptor] tap 作成失敗"); return }
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[KeyInterceptor] 開始")
    }

    // MARK: - Handle

    fileprivate func handle(event: CGEvent) -> Unmanaged<CGEvent>? {
        // 自分が注入したイベントはスキップ
        if event.getIntegerValueField(.eventSourceUserData) == INJECT_MARKER {
            return Unmanaged.passRetained(event)
        }

        let kc = event.getIntegerValueField(.keyboardEventKeycode)

        // Unicode文字を取得（SteamはvirtualKey=0固定でunicodeだけ変えて注入する）
        var uLen = 0
        var uBuf = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &uLen, unicodeString: &uBuf)

        // トグルキー判定
        if isToggleKey(kc: UInt16(kc), eventFlags: event.flags, unicode: uLen == 1 ? uBuf[0] : nil) {
            DispatchQueue.main.async { self.onToggle?() }
            return nil
        }

        // 英語モードはそのまま通す
        guard isJapanese else { return Unmanaged.passRetained(event) }

        // 修飾キー付きはそのまま通す
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            return Unmanaged.passRetained(event)
        }

        // 物理キーボード(PID=0)はそのまま通す（正しいキーコードを持つ）
        let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
        if sourcePID == 0 { return Unmanaged.passRetained(event) }

        // Steam注入イベント: unicodeから正しいキーコードを逆引きしてクリーンなイベントに差し替え
        guard uLen == 1,
              let scalar = Unicode.Scalar(uBuf[0]),
              let correctKC = usKeycode(for: Character(scalar)),
              let evSrc = CGEventSource(stateID: .combinedSessionState),
              let clean = CGEvent(keyboardEventSource: evSrc, virtualKey: correctKC, keyDown: true)
        else { return Unmanaged.passRetained(event) }

        clean.flags = flags
        clean.setIntegerValueField(.eventSourceUserData, value: INJECT_MARKER)
        return Unmanaged.passRetained(clean)
    }

    // MARK: - トグルキー判定

    private func isToggleKey(kc: UInt16, eventFlags: CGEventFlags, unicode: UniChar?) -> Bool {
        let b = binding
        let requiredMods = b.modifierFlags

        // 修飾キーマッチ確認
        let allowed: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let eventMods = NSEvent.ModifierFlags(rawValue: UInt(eventFlags.rawValue)).intersection(allowed)
        guard eventMods == requiredMods else { return false }

        // キーコード一致（物理KB）
        if kc == b.keyCode { return true }

        // Steamは virtualKey=0 のため、unicode で判定
        if kc == 0, let u = unicode {
            // unicodeからキーコードを逆引きして比較
            if let scalar = Unicode.Scalar(u),
               let mappedKC = usKeycode(for: Character(scalar)),
               mappedKC == b.keyCode { return true }
            // backtick(96) の特殊対応
            if b.keyCode == 50 && u == 96 { return true }
        }
        return false
    }
}

// MARK: - US キーボード 文字→キーコード逆引き

private func usKeycode(for ch: Character) -> CGKeyCode? {
    let map: [Character: CGKeyCode] = [
        "a":0,  "b":11, "c":8,  "d":2,  "e":14, "f":3,  "g":5,
        "h":4,  "i":34, "j":38, "k":40, "l":37, "m":46, "n":45,
        "o":31, "p":35, "q":12, "r":15, "s":1,  "t":17, "u":32,
        "v":9,  "w":13, "x":7,  "y":16, "z":6,
        "A":0,  "B":11, "C":8,  "D":2,  "E":14, "F":3,  "G":5,
        "H":4,  "I":34, "J":38, "K":40, "L":37, "M":46, "N":45,
        "O":31, "P":35, "Q":12, "R":15, "S":1,  "T":17, "U":32,
        "V":9,  "W":13, "X":7,  "Y":16, "Z":6,
        "0":29, "1":18, "2":19, "3":20, "4":21,
        "5":23, "6":22, "7":26, "8":28, "9":25,
        "-":27, "=":24, "[":33, "]":30, "\\":42,
        ";":41, "'":39, ",":43, ".":47, "/":44,
        " ":49,
    ]
    return map[ch]
}

// MARK: - C callback

private let keyCB: CGEventTapCallBack = { _, type, event, ptr in
    guard type == .keyDown, let ptr else { return Unmanaged.passRetained(event) }
    return Unmanaged<KeyInterceptor>.fromOpaque(ptr).takeUnretainedValue().handle(event: event)
}
