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

## Screenshots

### Main Styles

Left-click on the Apple logo to toggle the background style between **Glass** and **Fully Transparent**:

![Transparent Theme](Resources/transparent_theme.png)
![Two-Layer Theme](Resources/two_layer_theme.png)

### Notch Widget

![Notch Widget](Resources/notch.png)

### Volume Control

![Volume Widget](Resources/volume.png)

### Settings Menu

![Settings](Resources/settings.png)
![Window Settings](Resources/windowsettings.png)

---

## Installation / Running

1. **Install Aerospace** and configure it.  
2. **Clone this repository:**


```sh
git clone https://github.com/SacrilegeWasTaken/olovebar.git
```
3. Build the binary via swift
```sh
swift build -c release
```
4. Run the binary
```sh
./.build/release/olovebar
```