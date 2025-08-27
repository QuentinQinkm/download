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
        print("🔧 DonLoadApp.finishLaunching() started...")
        super.finishLaunching()
        print("✅ super.finishLaunching() completed")
        
        // Hide dock icon since this is a menu bar app
        print("🔧 Setting activation policy...")
        setActivationPolicy(.accessory)
        print("✅ Activation policy set")
        
        // Initialize status bar manager
        print("🔧 Creating StatusBarManager...")
        statusBarManager = StatusBarManager()
        print("✅ StatusBarManager created successfully")
        print("🎉 DonLoadApp.finishLaunching() completed!")
    }
}

// MARK: - Main Entry Point

@main
struct Main {
    static func main() {
        print("🔧 Main.main() started...")
        let app = DonLoadApp.shared
        print("✅ DonLoadApp.shared obtained")
        let delegate = AppDelegate()
        print("✅ AppDelegate created")
        app.delegate = delegate
        print("✅ App delegate set")
        print("🔧 Starting app.run()...")
        app.run()
        print("✅ app.run() completed")
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🔧 AppDelegate.applicationDidFinishLaunching() called")
        // App setup is handled in DonLoadApp.finishLaunching()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        print("🔧 AppDelegate.applicationShouldTerminateAfterLastWindowClosed() called")
        // Keep app running even when no windows are open (menu bar app)
        return false
    }
}
