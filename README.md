<p align="center">
  <img src="https://em-content.zobj.net/source/apple/391/honey-pot_1f36f.png" width="80" />
</p>

<h1 align="center">🏆 JochungCam Ultimate</h1>

<p align="center">
  <b>Screen capture → GIF, done right. For macOS. Now with GPU acceleration & beautiful UI.</b>
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
git clone https://github.com/Prota100/JochungCam.git /tmp/jc && bash /tmp/jc/install.sh && rm -rf /tmp/jc
```

That's it. Installs deps, builds from source, signs the binary, drops it in `/Applications`. No "damaged file" BS — it's built on your machine.

<details>
<summary>Manual build</summary>

```bash
brew install libimagequant gifski webp
git clone https://github.com/Prota100/JochungCam.git
cd JochungCam
swift build -c release
```
</details>

---

## What it does

**Capture** — Region select, fullscreen, half, quarter. 10–60 FPS. Pause/resume. Cursor highlighting with separate left/right click colors. Countdown timer. Direct save mode.

**Edit** — Revolutionary SpeedControlView with 0.25x–4x precision. QuickTime-style trim. Crop with ratio presets. Remove even/odd/similar frames. Reverse. Yoyo. Per-frame timing. **Complete Undo/Redo system** with full state restoration.

**Export** — GIF (libimagequant + gifski cross-frame optimization), WebP (lossy/lossless), MP4 (H.264), APNG. **Smart preview with size prediction**. Full control over quantization, dithering, color count, file size limits. **Professional batch processing**.

**🎨 Ultimate UI** — 6 beautiful themes (System, Dark, Light, Midnight, Purple, Green). Smooth animations with pulse, shimmer, breathing effects. **Complete dark mode support**. Modern navigation-based interface.

**⚡ GPU Acceleration** — Metal-powered high-performance processing. CPU/GPU hybrid optimization. Real-time performance monitoring. Memory-efficient frame handling.

**Presets** — Discord (<10MB), Telegram (<5MB), Twitter (<15MB), small (<2MB), HQ (unlimited). One click.

**Other** — Clipboard copy, batch convert, drag & drop, global hotkey (⌘⇧G).

---

## Architecture

```
Sources/JochungCam/
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

## Release (reproducible baseline)

```bash
./scripts/release_pipeline.sh 1.0.1
```

Outputs:
- `release/JochungCam.app`
- `release/JochungCam-v1.0.1-macOS-arm64.zip`
- `release/SHA256SUMS.txt`
- logs in `release/logs/`

## Roadmap

AI upscaling · interactive crop overlay · transitions · stickers · WebM · text overlays · i18n

---

MIT · For Mac users who got left behind. 🍯
