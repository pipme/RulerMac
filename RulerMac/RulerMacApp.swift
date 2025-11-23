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
        overlayWindow.level = .floating
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        overlayWindow.ignoresMouseEvents = false
        overlayWindow.isMovable = false
        overlayWindow.hasShadow = false
        
        // Set cursor
        let cursor = NSCursor.crosshair
        overlayWindow.contentView?.addCursorRect(overlayWindow.contentView!.bounds, cursor: cursor)
        
        // Create the SwiftUI view with controller
        rulerViewController = RulerViewController()
        let hostingView = NSHostingView(rootView: rulerViewController.rulerView)
        overlayWindow.contentView = hostingView
        
        // Set up key monitor for Esc key
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc key
                self?.toggleRuler()
                return nil
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
    }
    
    @objc func setUnitInches() {
        rulerViewController.setUnit(.inches)
        updateMenuCheckmarks(selected: 1)
    }
    
    @objc func setUnitCentimeters() {
        rulerViewController.setUnit(.centimeters)
        updateMenuCheckmarks(selected: 2)
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
