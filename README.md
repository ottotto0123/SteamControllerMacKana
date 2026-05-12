# SteamControllerMacKana

macOS menu bar app that enables Japanese input (IME) when using Steam's built-in on-screen keyboard with a Steam Controller.

## Background

Steam's on-screen keyboard injects key events by embedding Unicode characters directly, bypassing the macOS IME pipeline. SteamControllerMacKana intercepts these events, remaps them to proper keycodes, and re-injects them so that macOS IMEs (Kotoeri, etc.) can process them normally — enabling hiragana input, kanji conversion, and live conversion.

## Features

- **` key**: Toggle between Japanese and English input from anywhere
- **Menu bar icon**: Shows current mode — `日` (Japanese) or `EN` (English), dark/light mode adaptive
- **Live conversion**: Full Kotoeri support including kanji conversion
- **Physical keyboard safe**: Only intercepts software-injected events (Steam), not hardware keyboard input

## Requirements

- macOS 13 or later
- Steam Controller
- **Accessibility permission** required (System Settings → Privacy & Security → Accessibility)

## Build & Run

```bash
git clone https://github.com/YOUR_USERNAME/SteamControllerMacKana.git
cd SteamControllerMacKana
swift build -c release
.build/release/SteamControllerMacKana
```

## Usage

1. Launch SteamControllerMacKana — `EN` appears in the menu bar
2. Open Steam and the Steam on-screen keyboard
3. Press `` ` `` to switch to Japanese mode (`日`)
4. Type romaji with the Steam keyboard → Kotoeri converts to hiragana/kanji
5. Press `` ` `` again to return to English

## How It Works

Steam injects keyboard events with `virtualKey = 0` and the Unicode character pre-set, which bypasses the macOS IME. SteamControllerMacKana intercepts these events via `CGEventTap`, reads the Unicode character, maps it to the correct US keyboard virtual key code, and re-injects a clean event without the pre-set Unicode string. This allows Kotoeri to process the input through its normal pipeline.

## License

MIT
