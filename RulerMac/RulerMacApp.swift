//
//  RulerMacApp.swift
//  RulerMac
//
//  Created by Li, Chengkun on 21.11.2025.
//

import SwiftUI

@main
struct RulerMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class RulerWindow {
    let window: NSWindow
    let controller: RulerViewController
    
    init(screen: NSScreen) {
        window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.isMovable = false
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false
        
        // Set cursor
        let cursor = NSCursor.crosshair
        window.contentView?.addCursorRect(window.contentView!.bounds, cursor: cursor)
        
        // Create controller and view
        controller = RulerViewController()
        let rulerView = RulerOverlayView(controller: controller)
        let hostingView = NSHostingView(rootView: rulerView)
        hostingView.sizingOptions = [.minSize, .maxSize]
        window.contentView = hostingView
    }
    
    func updateFrame(screen: NSScreen) {
        window.setFrame(screen.frame, display: true)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var rulerWindows: [CGDirectDisplayID: RulerWindow] = [:]
    var statusItem: NSStatusItem!
    var accelerationFactor: CGFloat = 1.0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock, show only in menu bar
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "ruler", accessibilityDescription: "Ruler")
            button.action = #selector(toggleRuler)
            button.target = self
        }
        
        // Create the overlay windows
        setupOverlayWindows()
        
        // Add menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide Ruler", action: #selector(toggleRuler), keyEquivalent: ""))
        
        // Units submenu
        let unitsMenu = NSMenu()
        let pixelsItem = NSMenuItem(title: "Pixels", action: #selector(setUnitPixels), keyEquivalent: "")
        let inchesItem = NSMenuItem(title: "Inches", action: #selector(setUnitInches), keyEquivalent: "")
        let centimetersItem = NSMenuItem(title: "Centimeters", action: #selector(setUnitCentimeters), keyEquivalent: "")
        pixelsItem.target = self
        inchesItem.target = self
        centimetersItem.target = self
        pixelsItem.state = .on
        unitsMenu.addItem(pixelsItem)
        unitsMenu.addItem(inchesItem)
        unitsMenu.addItem(centimetersItem)
        
        let unitsMenuItem = NSMenuItem(title: "Units", action: nil, keyEquivalent: "")
        unitsMenuItem.submenu = unitsMenu
        menu.addItem(unitsMenuItem)
        
        // Turntable toggle
        let turntableItem = NSMenuItem(title: "Turntable", action: #selector(toggleTurntable), keyEquivalent: "")
        turntableItem.target = self
        menu.addItem(turntableItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        statusItem.menu = menu
        
        // Listen for screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // Monitor mouse movement to activate the correct screen
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateActiveScreen()
        }
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.updateActiveScreen()
            return event
        }
        
        // Set up key monitor for Esc key and Arrow keys
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.keyCode == 53 { // Esc key
                self.toggleRuler()
                return nil
            }
            
            // Find which screen the mouse is on
            let mouseLoc = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }),
                  let id = screen.displayID,
                  let rulerWindow = self.rulerWindows[id] else {
                return event
            }
            
            let controller = rulerWindow.controller
            let window = rulerWindow.window
            
            if !window.isVisible { return event }
            
            // Space key to toggle active point
            if event.keyCode == 49 {
                if controller.endPoint != nil {
                    controller.toggleActivePoint()
                    return nil
                }
            }
            
            // Arrow keys for nudging
            // Left: 123, Right: 124, Down: 125, Up: 126
            if controller.endPoint != nil {
                var dx: CGFloat = 0
                var dy: CGFloat = 0
                
                switch event.keyCode {
                case 123: dx = -1 // Left
                case 124: dx = 1  // Right
                case 125: dy = 1  // Down
                case 126: dy = -1 // Up
                default: return event
                }
                
                // Apply multiplier if Option is held
                var step: CGFloat = 1.0
                
                if event.isARepeat {
                    self.accelerationFactor = min(self.accelerationFactor + 1.5, 30.0)
                } else {
                    self.accelerationFactor = 1.0
                }
                
                if event.modifierFlags.contains(.option) {
                    step = 10.0 * self.accelerationFactor
                } else {
                    step = 1.0 * self.accelerationFactor
                }
                
                dx *= step
                dy *= step
                
                if controller.activePoint == .start {
                    controller.nudgeStartPoint(dx: dx, dy: dy, in: window.frame.size, isShiftPressed: event.modifierFlags.contains(.shift))
                } else {
                    controller.nudgeEndPoint(dx: dx, dy: dy, in: window.frame.size, isShiftPressed: event.modifierFlags.contains(.shift))
                }
                
                return nil // Consume event
            }
            
            return event
        }
    }
    
    var screenChangeWorkItem: DispatchWorkItem?
    var isReconfiguring = false
    
    @objc func handleScreenChange() {
        // Debounce screen changes to avoid hanging during reconfiguration
        isReconfiguring = true
        screenChangeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.setupOverlayWindows()
        }
        screenChangeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }
    
    func updateActiveScreen() {
        if isReconfiguring { return }
        
        let mouseLoc = NSEvent.mouseLocation
        let currentIDs = Set(NSScreen.screens.compactMap { $0.displayID })
        
        for (id, rulerWindow) in rulerWindows {
            if !currentIDs.contains(id) { continue }
            
            // Check if mouse is inside this screen's frame
            // Note: NSEvent.mouseLocation is in global screen coordinates (0,0 at bottom-left of primary screen)
            // NSScreen.frame is also in global coordinates.
            // We use an inclusive check because NSPointInRect excludes the max edge, but mouse can be at the edge.
            let frame = rulerWindow.window.frame
            let contains = mouseLoc.x >= frame.minX && mouseLoc.x <= frame.maxX &&
                           mouseLoc.y >= frame.minY && mouseLoc.y <= frame.maxY
            
            if contains {
                if !rulerWindow.controller.isActive {
                    rulerWindow.controller.isActive = true
                }
            } else {
                if rulerWindow.controller.isActive {
                    rulerWindow.controller.isActive = false
                }
            }
        }
    }
    
    func setupOverlayWindows() {
        let screens = NSScreen.screens
        var activeIDs = Set<CGDirectDisplayID>()
        
        for screen in screens {
            guard let id = screen.displayID else { continue }
            activeIDs.insert(id)
            
            if let existing = rulerWindows[id] {
                existing.updateFrame(screen: screen)
            } else {
                let newWindow = RulerWindow(screen: screen)
                rulerWindows[id] = newWindow
                newWindow.window.orderFrontRegardless()
            }
        }
        
        // Remove disconnected screens safely
        let currentIDs = Array(rulerWindows.keys)
        for id in currentIDs {
            if !activeIDs.contains(id) {
                rulerWindows[id]?.window.close()
                rulerWindows[id] = nil
            }
        }
        
        isReconfiguring = false
    }
    
    @objc func toggleRuler() {
        let anyVisible = rulerWindows.values.contains { $0.window.isVisible }
        
        for rulerWindow in rulerWindows.values {
            if anyVisible {
                rulerWindow.window.orderOut(nil)
            } else {
                rulerWindow.window.orderFrontRegardless()
            }
        }
    }
    
    @objc func setUnitPixels() {
        rulerWindows.values.forEach { $0.controller.setUnit(.pixels) }
        updateMenuCheckmarks(selected: 0)
        rulerWindows.values.forEach { $0.window.orderFrontRegardless() }
    }
    
    @objc func setUnitInches() {
        rulerWindows.values.forEach { $0.controller.setUnit(.inches) }
        updateMenuCheckmarks(selected: 1)
        rulerWindows.values.forEach { $0.window.orderFrontRegardless() }
    }
    
    @objc func setUnitCentimeters() {
        rulerWindows.values.forEach { $0.controller.setUnit(.centimeters) }
        updateMenuCheckmarks(selected: 2)
        rulerWindows.values.forEach { $0.window.orderFrontRegardless() }
    }
    
    @objc func toggleTurntable() {
        // Toggle based on the first one, or just toggle all
        let newState = !(rulerWindows.values.first?.controller.showAngleDial ?? false)
        
        rulerWindows.values.forEach { rulerWindow in
            rulerWindow.controller.showAngleDial = newState
            if !rulerWindow.window.isVisible {
                rulerWindow.window.orderFrontRegardless()
            }
        }
        
        updateTurntableMenuState()
    }
    
    func updateTurntableMenuState() {
        guard let menu = statusItem.menu,
              let item = menu.item(withTitle: "Turntable") else { return }
        // Check state of first controller
        item.state = (rulerWindows.values.first?.controller.showAngleDial ?? false) ? .on : .off
    }
    
    func updateMenuCheckmarks(selected: Int) {
        guard let menu = statusItem.menu,
              let unitsMenuItem = menu.item(withTitle: "Units"),
              let unitsMenu = unitsMenuItem.submenu else { return }
        
        for (index, item) in unitsMenu.items.enumerated() {
            item.state = (index == selected) ? .on : .off
        }
    }
}
