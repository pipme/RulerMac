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

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow!
    var statusItem: NSStatusItem!
    var rulerViewController: RulerViewController!
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
        
        // Create the overlay window
        setupOverlayWindow()
        
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
    }
    
    func setupOverlayWindow() {
        guard let screen = NSScreen.main else { return }
        
        // Create a borderless, transparent window that covers the entire screen
        overlayWindow = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = .clear
        overlayWindow.level = .screenSaver
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        overlayWindow.ignoresMouseEvents = false
        overlayWindow.isMovable = false
        overlayWindow.hasShadow = false
        
        // Set cursor
        let cursor = NSCursor.crosshair
        overlayWindow.contentView?.addCursorRect(overlayWindow.contentView!.bounds, cursor: cursor)
        
        // Create the SwiftUI view with controller
        rulerViewController = RulerViewController()
        let rulerView = RulerOverlayView(controller: rulerViewController)
        let hostingView = NSHostingView(rootView: rulerView)
        overlayWindow.contentView = hostingView
        
        // Set up key monitor for Esc key and Arrow keys
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.keyCode == 53 { // Esc key
                self.toggleRuler()
                return nil
            }
            
            // Space key to toggle active point
            if event.keyCode == 49 {
                if self.overlayWindow.isVisible && self.rulerViewController.endPoint != nil {
                    self.rulerViewController.toggleActivePoint()
                    return nil
                }
            }
            
            // Arrow keys for nudging
            // Left: 123, Right: 124, Down: 125, Up: 126
            if self.overlayWindow.isVisible && self.rulerViewController.endPoint != nil {
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
                
                if self.rulerViewController.activePoint == .start {
                    self.rulerViewController.nudgeStartPoint(dx: dx, dy: dy, in: self.overlayWindow.frame.size, isShiftPressed: event.modifierFlags.contains(.shift))
                } else {
                    self.rulerViewController.nudgeEndPoint(dx: dx, dy: dy, in: self.overlayWindow.frame.size, isShiftPressed: event.modifierFlags.contains(.shift))
                }
                
                return nil // Consume event
            }
            
            return event
        }
        
        overlayWindow.orderFrontRegardless()
    }
    
    @objc func toggleRuler() {
        if overlayWindow.isVisible {
            overlayWindow.orderOut(nil)
        } else {
            overlayWindow.orderFrontRegardless()
        }
    }
    
    @objc func setUnitPixels() {
        rulerViewController.setUnit(.pixels)
        updateMenuCheckmarks(selected: 0)
        overlayWindow.orderFrontRegardless()
    }
    
    @objc func setUnitInches() {
        rulerViewController.setUnit(.inches)
        updateMenuCheckmarks(selected: 1)
        overlayWindow.orderFrontRegardless()
    }
    
    @objc func setUnitCentimeters() {
        rulerViewController.setUnit(.centimeters)
        updateMenuCheckmarks(selected: 2)
        overlayWindow.orderFrontRegardless()
    }
    
    @objc func toggleTurntable() {
        rulerViewController.toggleAngleDial()
        
        if !overlayWindow.isVisible {
            overlayWindow.orderFrontRegardless()
        }
        
        updateTurntableMenuState()
    }
    
    func updateTurntableMenuState() {
        guard let menu = statusItem.menu,
              let item = menu.item(withTitle: "Turntable") else { return }
        item.state = rulerViewController.showAngleDial ? .on : .off
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
