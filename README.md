# RulerMac

A lightweight macOS screen ruler application for measuring distances on your screen in any direction.

## Features

- 📏 Measure screen distances in **any direction**
- 🎯 Real-time distance and angle display
- 📐 Multiple unit support: pixels, inches, and centimeters
- 🖥️ Menu bar integration for easy access
- ⌨️ ESC key to show/hide measurement overlay
- 🎨 Clean, minimal interface

## Installation

1. Download the latest `RulerMac.dmg` from [Releases](https://github.com/pipme/RulerMac/releases)
2. Open the DMG file
3. Drag `RulerMac.app` to your Applications folder
4. **Important**: Since the app is not signed with an Apple Developer certificate, you need to:
   - Right-click (or Control-click) on `RulerMac.app`
   - Select "Open" from the context menu
   - Click "Open" in the dialog that appears
   - This only needs to be done once

## Usage

1. Launch RulerMac - you'll see a ruler icon in your menu bar
2. Click and drag anywhere on the screen to measure
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