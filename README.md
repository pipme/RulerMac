# RulerMac

A lightweight macOS screen ruler application for measuring distances on your screen in any direction.

![RulerMac measuring screen distance](asset/image.png)

## Features

- 📏 Measure screen distances in **any direction**
- 🎯 Real-time distance and angle display
- 📐 **Detailed Measurements**: View Distance, Angle, ΔX (width), and ΔY (height)
- 🔒 **Angle Snapping**: Hold `Shift` to snap to 45° increments (horizontal, vertical, diagonal)
- 📏 Multiple unit support: pixels, inches, and centimeters
- 🖥️ Menu bar integration for easy access
- ⌨️ ESC key to show/hide measurement overlay
- 🎨 Clean, minimal interface with high-contrast visibility

## Installation

1. Download the latest `RulerMac.dmg` from [Releases](https://github.com/pipme/RulerMac/releases)
2. Open the DMG file
3. Drag `RulerMac.app` to your Applications folder
4. **Important**: Since the app is not signed with an Apple Developer certificate, you may need to allow it to run:
    - go to **System Settings** > **Privacy & Security** and click "Open Anyway"
    - Learn more about [opening apps from unidentified developers](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)

## Usage

1. Launch RulerMac - you'll see a ruler icon in your menu bar
2. Click and drag anywhere on the screen to measure
   - **Hold Shift** while dragging to snap to 0°, 45°, 90°, etc.
3. Press **ESC** to hide the measurement overlay
4. Click the menu bar icon to access options:
   - Show/Hide Ruler
   - Change Units (px/in/cm)
   - Quit Application

### Menu Options

- **Show Ruler** / **Hide Ruler**: Toggle the measurement overlay
- **Units**: Switch between pixels, inches, and centimeters
- **Quit**: Exit the application

## Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/pipme/RulerMac.git
   cd RulerMac
   ```

2. Open the project in Xcode:
   ```bash
   open RulerMac.xcodeproj
   ```

3. Build and run:
   - Press `Cmd + R` to build and run

## Contributing

This was a vibe coding project. Feel free to modify and improve it!