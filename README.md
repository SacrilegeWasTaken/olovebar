# Olovebar

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green.svg)

**Olovebar** is a Swift-based, fully customizable menu bar inspired by Apple's **Liquid Glass** design philosophy.

All widgets are clickable and behave like native macOS menu bar widgets. You can customize the glass style of the menu bar via the **config menu** (right-click on the Apple logo widget), including:

- Widget types  
- Widget arrangement  
- Widget width  
- Corner rounding  

The **Aerospace widget** is updated via shell only, but it will be fully configurable soon.  

---

## Roadmap

### Completed

- [x] Notch View
- [x] Menu items
- [x] Configurations
- [x] Volume controls like native
- [x] Aerospace fancy UI
- [x] Migration from timers to system notifications
- [x] Good performance
- [x] Power widget like native
- [x] Notch fancy animations
- [x] No notch background while expanded
- [x] Invisible notch on screenshots
- [x] Notch menu items centered below button like in native bar
- [x] Aerospace updates through notifications

### Planned

- [ ] Notch Player Widget
- [ ] WiFi controls like native menu bar
- [ ] Battery controls like native menu bar
- [ ] Aerospace widget color configurations
- [ ] Notch window configurations
- [ ] Notch all control center widgets
- [ ] Tinting app icons
- [ ] Better and fast animations
- [ ] WiFi widget optional name configuration
- [ ] CPU widget
- [ ] Memory Widget
- [ ] NetLoad Widget
- [ ] Widget reordering
- [ ] Removing/Adding widgets into the bar
- [ ] Migrate from `SwiftUI` popover to `NSMenu` everywhere
- [ ] Deep Aerospace integration with Aerospace to increase UI reaction speed.

## Screenshots

### Main Styles

Left-click on the Apple logo to toggle the background style between **Glass** and **Fully Transparent**:

![Transparent Theme](Assets/transparent_theme.png)
![Two-Layer Theme](Assets/two_layer_theme.png)

### Notch Widget

![Notch Widget](Assets/notch.png)

### Volume Control

![Volume Widget](Assets/volume.png)

### Settings Menu

![Settings](Assets/settings.png)
![Window Settings](Assets/windowsettings.png)

---

## Requirements

- macOS 26+
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) window manager

---

# Installation by downloading the binary

1. **Download the [latest release binary](https://github.com/SacrilegeWasTaken/olovebar/releases).**

2. **Paste following command into the terminal**
```sh
sudo xattr -d com.apple.quarantine /path/to/olovebar
```
You can drag-n-drop binary into the terminal to insert the path.
I'll setup signing later. Have not purchased Apple Developer yet.
---

## Installation by building the source

1. **Clone the repository:**

```sh
git clone https://github.com/SacrilegeWasTaken/olovebar.git
cd olovebar
```

2. **Install to system:**

```sh
make install-cli # `install` is buggy (app bundle)
```

This will:
- Check and install dependencies (Homebrew, Swift, uv)
- Build the release binary
- Install to `/usr/local/bin/olovebar`

3. **Add to `~/.config/aerospace/aerospace.toml`**
```toml
exec-on-workspace-change = [
  "/bin/zsh",
  "-c",
  "curl -s localhost:43551"
]
```

4. **Run:**

```sh
olovebar
```

---

## Development

```sh
make setup    # Check/install dependencies
make build    # Build debug version
make run      # Build and run debug version
make release  # Build release version
```

---

## Uninstall

```sh
make uninstall
```

