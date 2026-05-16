import AppKit

// トグルキーの設定を表すモデル
// keyCode: CGKeyCode (UInt16)、modifiers: NSEvent.ModifierFlags
struct KeyBinding: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt64      // NSEvent.ModifierFlags.rawValue

    // デフォルト: ` キー単体 (keyCode=50, 修飾なし)
    static let defaultBinding = KeyBinding(keyCode: 50, modifiers: 0)

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(modifiers))
    }

    // 表示用文字列 (例: "⌘⇧A", "`")
    var displayString: String {
        var s = ""
        let f = modifierFlags
        if f.contains(.control)  { s += "⌃" }
        if f.contains(.option)   { s += "⌥" }
        if f.contains(.shift)    { s += "⇧" }
        if f.contains(.command)  { s += "⌘" }
        s += keyCodeLabel(keyCode)
        return s
    }

    // MARK: - UserDefaults

    static let udKey = "toggleKeyBinding"

    static func load() -> KeyBinding {
        guard let data = UserDefaults.standard.data(forKey: udKey),
              let binding = try? JSONDecoder().decode(KeyBinding.self, from: data)
        else { return .defaultBinding }
        return binding
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: KeyBinding.udKey)
        }
    }
}

// キーコード → 表示ラベル
private func keyCodeLabel(_ kc: UInt16) -> String {
    let map: [UInt16: String] = [
        50:"`",  36:"↩",  48:"⇥",  49:"Space", 51:"⌫",  53:"Esc",
        123:"←", 124:"→", 125:"↓", 126:"↑",
        122:"F1",120:"F2",99:"F3", 118:"F4",96:"F5", 97:"F6",
        98:"F7", 100:"F8",101:"F9",109:"F10",103:"F11",111:"F12",
        18:"1",  19:"2",  20:"3",  21:"4",  23:"5",
        22:"6",  26:"7",  28:"8",  25:"9",  29:"0",
        0:"A",   11:"B",  8:"C",   2:"D",   14:"E",
        3:"F",   5:"G",   4:"H",   34:"I",  38:"J",
        40:"K",  37:"L",  46:"M",  45:"N",  31:"O",
        35:"P",  12:"Q",  15:"R",  1:"S",   17:"T",
        32:"U",  9:"V",   13:"W",  7:"X",   16:"Y",  6:"Z",
        27:"-",  24:"=",  33:"[",  30:"]",  42:"\\",
        41:";",  39:"'",  43:",",  47:".",  44:"/",
    ]
    return map[kc] ?? "(\(kc))"
}
