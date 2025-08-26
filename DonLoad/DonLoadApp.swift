//
//  DonLoadApp.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Cocoa

class DonLoadApp: NSApplication {
    private var statusBarManager: StatusBarManager?
    
    override func finishLaunching() {
        super.finishLaunching()
        
        // Hide dock icon since this is a menu bar app
        setActivationPolicy(.accessory)
        
        // Initialize status bar manager
        statusBarManager = StatusBarManager()
    }
}

// MARK: - Main Entry Point

@main
struct Main {
    static func main() {
        let app = DonLoadApp.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App setup is handled in DonLoadApp.finishLaunching()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even when no windows are open (menu bar app)
        return false
    }
}
