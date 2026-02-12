<p align="center">
  <img src="https://em-content.zobj.net/source/apple/391/honey-pot_1f36f.png" width="80" />
</p>

<h1 align="center">JocungCam</h1>

<p align="center">
  <b>Screen capture → GIF, done right. For macOS.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS%2014+-black?logo=apple" />
  <img src="https://img.shields.io/badge/Apple%20Silicon-black?logo=apple" />
  <img src="https://img.shields.io/badge/Swift%205.9+-F05138?logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/license-MIT-333" />
</p>

---

HoneyCam is the go-to GIF recorder on Windows. They're not bringing it to Mac. So here we are.

---

## Install

```bash
git clone https://github.com/Prota100/JocungCam.git /tmp/jc && bash /tmp/jc/install.sh && rm -rf /tmp/jc
```

That's it. Installs deps, builds from source, signs the binary, drops it in `/Applications`. No "damaged file" BS — it's built on your machine.

<details>
<summary>Manual build</summary>

```bash
brew install libimagequant gifski webp
git clone https://github.com/Prota100/JocungCam.git
cd JocungCam
swift build -c release
```
</details>

---

## What it does

**Capture** — Region select, fullscreen, half, quarter. 10–60 FPS. Pause/resume. Cursor highlighting with separate left/right click colors. Countdown timer. Direct save mode.

**Edit** — QuickTime-style trim. Crop with ratio presets. Remove even/odd/similar frames. Speed ±10%. Reverse. Yoyo. Per-frame timing. 30-level undo.

**Export** — GIF (libimagequant + gifski cross-frame optimization), WebP (lossy/lossless), MP4 (H.264), APNG. Full control over quantization, dithering, color count, file size limits.

**Presets** — Discord (<10MB), Telegram (<5MB), Twitter (<15MB), small (<2MB), HQ (unlimited). One click.

**Other** — Clipboard copy, batch convert, drag & drop, global hotkey (⌘⇧G).

---

## Architecture

```
Sources/JocungCam/
├── App/        SwiftUI app, state, dependency check
├── Capture/    ScreenCaptureKit, region select, cursor tracking
├── Editor/     Frame ops, crop, resize, import
├── Encoder/    GIF (LIQ), gifski, WebP, MP4, APNG
└── UI/         Home, editor, recording, export, batch, theme
```

| | |
|---|---|
| UI | SwiftUI + AppKit |
| Capture | ScreenCaptureKit |
| GIF | libimagequant (C binding) + gifski |
| Video | AVFoundation H.264 |
| WebP | libwebp (cwebp/webpmux) |

---

## Roadmap

AI upscaling · interactive crop overlay · transitions · stickers · WebM · text overlays · i18n

---

MIT · For Mac users who got left behind. 🍯
