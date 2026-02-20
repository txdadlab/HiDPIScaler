# HiDPI Scaler

A lightweight macOS menu bar app that enables HiDPI (Retina) scaling on external displays that don't natively support it.

Many external monitors — especially ultrawides and budget 4K panels — don't offer HiDPI modes in macOS. HiDPI Scaler fixes this by creating a virtual display with 2x backing resolution and mirroring your physical display onto it, unlocking crisp Retina-quality text and UI.

## Features

- Menu bar app — no dock icon, stays out of your way
- Auto-detects connected displays with native resolution, aspect ratio, and scale info
- Generates resolution presets matched to your display's aspect ratio
- One-click enable/disable
- Supports all aspect ratios: 16:9, 21:9, 32:9, 16:10, 3:2, and more
- Launch at Login via macOS Login Items
- Auto-connect on Launch — automatically re-activates your last configuration
- Settings persistence — display selection and resolution saved across sessions
- Clean teardown on quit — no orphaned virtual displays

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Installation

Grab the latest `.dmg` from [Releases](https://github.com/txdadlab/HiDPIScaler/releases), open it, and drag **HiDPI Scaler** into your Applications folder. No build step required.

<details>
<summary>Build from source (optional)</summary>

Requires Swift 5.9+ toolchain.

```bash
git clone https://github.com/txdadlab/HiDPIScaler.git
cd HiDPIScaler
chmod +x build.sh
./build.sh
cp -r "HiDPI Scaler.app" /Applications/
```
</details>

## Usage

1. Click the sparkles icon in the menu bar
2. Select your target display from the dropdown
3. Pick a resolution preset or enter a custom resolution
4. Click **Enable HiDPI**
5. macOS will apply HiDPI scaling to your display

To disable, click the menu bar icon and press **Disable HiDPI**.

## How it works

HiDPI Scaler uses private CoreGraphics APIs (`CGVirtualDisplay`) to:

1. **Create a virtual display** with 2x pixel backing (e.g. 3840x2160 backing for a 1920x1080 logical resolution)
2. **Mirror your physical display** onto the virtual display using `CGConfigureDisplayMirrorOfDisplay`
3. macOS sees the virtual display's HiDPI modes and applies Retina scaling to the physical panel

This is the same technique used by tools like BetterDisplay, implemented as a focused, single-purpose utility.

## Project structure

```
HiDPIScaler/
├── Package.swift                          # SPM package definition
├── build.sh                               # Build + bundle script
├── HiDPIScaler.png                        # Source icon (1024x1024)
├── Resources/
│   ├── AppIcon.icns                      # App icon bundle
│   └── Info.plist                         # App bundle metadata
└── Sources/
    ├── CGVirtualDisplayBridge/            # Obj-C bridge to private CG APIs
    │   ├── CGVirtualDisplayBridge.m
    │   └── include/
    │       ├── CGVirtualDisplay.h
    │       └── module.modulemap
    └── HiDPIScaler/                       # Swift app
        ├── HiDPIScalerApp.swift           # Entry point (MenuBarExtra)
        ├── Display/
        │   ├── DisplayManager.swift       # Display enumeration
        │   └── MirroringManager.swift     # Mirror configuration
        ├── State/
        │   └── HiDPIState.swift           # App state + presets
        ├── Utilities/
        │   └── Logger.swift
        ├── Views/
        │   └── MenuBarView.swift          # SwiftUI menu bar UI
        └── VirtualDisplay/
            └── VirtualDisplayController.swift
```

## Known limitations

- Uses private Apple APIs — may break with future macOS updates
- Requires ad-hoc code signing (not notarized)
- Some displays may not respond to mirroring configuration

## License

[MIT](LICENSE)

<!-- ## Support

If you find this useful, consider buying me a coffee:

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/YOUR_USERNAME) -->
