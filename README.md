# SteamControllerMacKana

Steamコントローラーのスクリーンキーボードを使って日本語入力（IME）を可能にするmacOSメニューバーアプリです。

## 背景

SteamのスクリーンキーボードはキーイベントにあらかじめUnicode文字を埋め込んで注入するため、macOSのIMEパイプラインを素通りしてしまい、日本語入力ができません。SteamControllerMacKanaはこのイベントを横取りして正しいキーコードに変換し直すことで、Kotoeriなどのシステムで通常通り処理できるようにします。これによりひらがな入力・漢字変換・ライブ変換が使えるようになります。

## 機能

- **`` ` `` キー**: 日本語・英語入力をどこからでもトグル切り替え
- **メニューバーアイコン**: 現在のモードを表示 — `日`（日本語）または `EN`（英語）、ダーク/ライトモード自動対応
- **ライブ変換対応**: 漢字変換を含むKotoeriのフル機能が使用可能
- **物理キーボード非干渉**: ソフトウェアが注入したイベント（Steam）のみを処理し、物理キーボードには影響しない

## 動作環境

- macOS 13 以降
- Steam Controller
- **アクセシビリティ権限**が必要（システム設定 → プライバシーとセキュリティ → アクセシビリティ）

## ビルド・実行

```bash
git clone https://github.com/ottotto0123/SteamControllerMacKana.git
cd SteamControllerMacKana
swift build -c release
.build/release/SteamControllerMacKana
```

## 使い方

1. SteamControllerMacKanaを起動 — メニューバーに `EN` が表示される
2. Steamを起動してスクリーンキーボードを開く
3. `` ` `` キーを押して日本語モードに切り替え（`日` に変わる）
4. Steamキーボードでローマ字入力 → Kotoeriがひらがな・漢字に変換
5. もう一度 `` ` `` キーを押すと英語モードに戻る

## 仕組み

Steamは `virtualKey = 0` にUnicode文字を直接セットしてキーイベントを注入するため、macOSのIMEが機能しません。SteamControllerMacKanaは `CGEventTap` でこのイベントを捕捉し、Unicode文字から正しいUSキーボードのキーコードを逆引きして、Unicode文字列を持たないクリーンなイベントに差し替えて再注入します。これによりKotoeriが通常のパイプラインで入力を処理できるようになります。

## ライセンス

MIT
