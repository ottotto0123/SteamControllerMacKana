import AppKit
import Carbon

// CGEventTap でキーボード入力を監視する。
//
// ` キー: 常にIMEトグル（英語/日本語モード問わず）
//
// 日本語モード時の問題:
//   Steam は CGEvent にUnicode文字列を直接埋め込んで注入するため、
//   システムIMEを素通りして英字が入力されてしまう。
//   対策: イベントのUnicode文字列を除去し、キーコードだけを持つ
//   クリーンなイベントに差し替える。これによりKotoeri等のシステムIMEが
//   正規のルートで処理でき、ライブ変換・かな漢字変換が有効になる。
//
// アクセシビリティ権限が必要。

private let INJECT_MARKER: Int64 = 0x5354494D  // "STIM"

final class KeyInterceptor {
    var isJapanese = false
    var onToggle: (() -> Void)?

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

        // ` キー (kc=50): 常にトグル（英語モードでも日本語モードでも）
        if kc == 50 {
            DispatchQueue.main.async { self.onToggle?() }
            return nil  // ` 自体は入力しない
        }

        // 英語モードはそのまま通す
        guard isJapanese else { return Unmanaged.passRetained(event) }

        // 修飾キー付きはそのまま通す
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            return Unmanaged.passRetained(event)
        }

        // 物理キーボードのイベントはPID=0（カーネル/IOKit由来）。
        // 正しいキーコードを持つためそのまま通す（システムIMEが自然に処理）。
        let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
        if sourcePID == 0 { return Unmanaged.passRetained(event) }

        // 日本語モード: SteamはvirtualKey=0固定でUnicode文字列だけ変えて注入する。
        // そのままではIMEがすべて 'a' として受け取るため、
        // Steamが設定したUnicode文字から正しいキーコードを逆引きして差し替える。
        var uLen = 0
        var uBuf = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &uLen, unicodeString: &uBuf)
        guard uLen == 1,
              let scalar = Unicode.Scalar(uBuf[0]),
              let correctKC = usKeycode(for: Character(scalar)),
              let evSrc = CGEventSource(stateID: .combinedSessionState),
              let clean = CGEvent(keyboardEventSource: evSrc,
                                  virtualKey: correctKC,
                                  keyDown: true) else {
            return Unmanaged.passRetained(event)
        }
        clean.flags = flags
        clean.setIntegerValueField(.eventSourceUserData, value: INJECT_MARKER)
        return Unmanaged.passRetained(clean)
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
