# RulerMac

A lightweight macOS screen ruler for measuring distances and angles in any direction.

![RulerMac measuring screen distance](asset/image.png)

## Features

- 📏 **Freeform Measurement**: Measure distances and angles in **any direction** across your screen.
- 🎯 **Detailed Data**: Real-time display of Distance, Angle, ΔX (width), and ΔY (height).
- 🔒 **Smart Snapping**: Hold `Shift` to snap your measurement line to specific angles.
- 🎛️ **Turntable Control**: Use the on-screen "Turntable" dial to customize the snap angle increment (e.g., 45°, 30°, 15°).
- ⌨️ **Keyboard Precision**:
    - **Arrow Keys**: Nudge the active point by 1px.
    - **Option + Arrow**: Nudge by 10px.
    - **Shift + (Option) + Arrow**: Slide the point along the snapped angle vector (perfect for extending lines while maintaining the angle).
    - **Acceleration**: Holding option + arrow keys accelerates movement for covering large distances quickly.
- 📍 **Dual Point Control**: Press **Space** to toggle between adjusting the Start Point and End Point.
- 📏 **Multi-Unit Support**: Switch between pixels (px), inches (in), and centimeters (cm).
- 🖥️ **System Integration**: Unobtrusive menu bar app with global hotkeys.


## Installation

1. Download the latest `RulerMac.dmg` from [Releases](https://github.com/pipme/RulerMac/releases).
2. Open the DMG and drag `RulerMac.app` to your Applications folder.
3. **Important**: Since the app is not signed with an Apple Developer certificate, you may need to allow it to run:
    - go to **System Settings** > **Privacy & Security** and click "Open Anyway"
    - Learn more about [opening apps from unidentified developers](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac)

## Usage

1. **Start Measuring**: Launch the app.
2. **Draw Line**: Click and drag anywhere on the screen.
3. **Fine-Tune**:
   - **Arrow Keys**: Move the active point pixel-by-pixel.
   - **Space**: Switch control between the Start (Green) and End (Red) points.
   - **Shift + Arrow**: Extend or retract the line while locking the angle.

4. **Configure Snapping**:
   - Enable "Turntable" from the menu bar.
   - Drag the on-screen dial to set your preferred snap increment (e.g., set to 45° to snap to 0°, 45°, 90°...).
5. **Dismiss**: Press **ESC** to hide the overlay; reopen by pressing **Esc** again or clicking the menu bar icon and select "Show/Hide Ruler".

## Menu Options

Click the menu bar icon to access:

- **Show/Hide Ruler**: Toggle the overlay.
- **Units**: Choose between Pixels, Inches, or Centimeters.
- **Turntable**: Show/Hide the on-screen angle selector dial.
- **Quit**: Exit the application.

## Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/pipme/RulerMac.git
   cd RulerMac
   ```

2. Open `RulerMac.xcodeproj` in Xcode.
3. Build and run (`Cmd + R`).

## Contributing

This project was built with "vibe coding" (AI-assisted development). Feel free to fork, modify, and improve it!
