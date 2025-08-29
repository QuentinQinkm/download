//
//  AppMain.swift
//  DonLoad - Main App Entry Point
//

import Cocoa
import SwiftUI

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var window: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupWindow()
    }
    
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "DonLoad")
        statusItem?.button?.action = #selector(toggleWindow)
        statusItem?.button?.target = self
    }
    
    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        
        let visible = screen.visibleFrame
        let width = visible.width * 0.5
        let height: CGFloat = 340
        let x = visible.origin.x + (visible.width - width) / 2
        let verticalInset: CGFloat = 48
        let y = visible.origin.y + visible.height - height - verticalInset
        
        window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        let contentView = MainContentView()
        window?.contentViewController = NSHostingController(rootView: contentView)
        window?.backgroundColor = NSColor.clear
        window?.isOpaque = false
        window?.level = .popUpMenu
        window?.hasShadow = true
    }
    
    @objc func toggleWindow() {
        guard let window = window else { return }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
        }
    }
}

// MARK: - Main App Entry Point

@main
struct DonLoadApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}