//
//  StatusBarManager.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Cocoa

class StatusBarManager: NSObject {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem?
    private var popoverWindow: NSWindow?
    private var downloadsViewController: DownloadsViewController?
    
    // MARK: - Initialization
    
    override init() {
        print("🔧 StatusBarManager init started...")
        super.init()
        print("✅ super.init() completed")
        
        setupStatusBar()
        print("✅ setupStatusBar() completed")
        
        setupWindow()
        print("✅ setupWindow() completed")
        
        startFileMonitoring()
        print("✅ startFileMonitoring() completed")
        print("🎉 StatusBarManager init completed successfully!")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        DownloadsFileManager.shared.stopMonitoring()
        
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
    
    // MARK: - Setup
    
    private func setupStatusBar() {
        print("🔧 Setting up status bar...")
        
        print("🔧 Getting status item from NSStatusBar.system...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        print("✅ Status item created: \(statusItem != nil)")
        
        guard let statusItem = statusItem else { 
            print("❌ Failed to create status item")
            return 
        }
        
        print("🔧 Setting up status bar button...")
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "DonLoad")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.toolTip = "DonLoad - Downloads Manager"
            print("✅ Status bar button configured")
        } else {
            print("❌ Status bar button is nil")
        }
        print("✅ Status bar setup completed")
    }
    
    private func setupWindow() {
        print("🔧 Starting window setup...")
        
        // Create downloads view controller
        print("🔧 Creating DownloadsViewController...")
        downloadsViewController = DownloadsViewController()
        print("✅ DownloadsViewController instance created")
        
        downloadsViewController?.statusBarManager = self
        print("✅ StatusBarManager reference set")
        
        guard let mainScreen = NSScreen.main else {
            print("❌ No main screen found")
            return
        }
        
        let screenFrame = mainScreen.visibleFrame
        // Calculate width to fit 5 items: 5×150 + 4×12 + 32 = 830px
        let idealWidth: CGFloat = 5 * 150 + 4 * 12 + 32  // 830px
        let maxWidth = screenFrame.width * 0.6  // Don't exceed 60% of screen
        let windowWidth: CGFloat = min(idealWidth, maxWidth)
        let windowHeight: CGFloat = 222 // Initial height: header(50) + files(172) = 222
        
        print("Setting up window with screen frame: \(screenFrame)")
        print("Calculated window size: \(windowWidth) x \(windowHeight)")
        
        // Create window with safe defaults first
        print("🔧 Creating NSWindow...")
        popoverWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 300, height: 200), // Safe initial size
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let window = popoverWindow, let viewController = downloadsViewController else { 
            print("❌ Missing window or view controller")
            return
        }
        print("✅ NSWindow created successfully")
        
        // Configure window properties first
        print("🔧 Configuring window properties...")
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.level = NSWindow.Level.popUpMenu
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        // Enable smooth animations
        window.animationBehavior = .default
        print("✅ Window properties configured")
        
        // Set content view controller
        print("🔧 Setting content view controller...")
        window.contentViewController = viewController
        print("✅ Content view controller set")
        
        // Force the view to load
        print("🔧 Loading view...")
        let view = viewController.view
        print("✅ View loaded with frame: \(view.frame)")
        
        // Layout the view
        print("🔧 Laying out view...")
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        print("✅ View laid out with frame: \(view.frame)")
        
        // Now safely resize the window
        print("🔧 Resizing window to target size...")
        let validWidth = max(windowWidth, 100)
        let validHeight = max(windowHeight, 50)
        
        // Use a safer approach - set frame instead of content size
        let newFrame = NSRect(
            x: window.frame.origin.x,
            y: window.frame.origin.y,
            width: validWidth,
            height: validHeight
        )
        
        print("Setting window frame to: \(newFrame)")
        window.setFrame(newFrame, display: false, animate: false)
        print("✅ Window resized to: \(window.frame)")
        
        // Add visual effect view for glass background
        print("🔧 Adding visual effects...")
        addVisualEffects(to: window)
        print("✅ Visual effects added")
        
        // Position window
        print("🔧 Positioning window...")
        positionWindow()
        print("✅ Window positioned")
        
        print("🎉 Window setup completed successfully!")
    }
    
    private func addVisualEffects(to window: NSWindow) {
        guard let contentView = window.contentView else { return }
        
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .underWindowBackground
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        
        // Insert visual effect as background
        contentView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: contentView.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    private func positionWindow() {
        guard let window = popoverWindow, let statusItem = statusItem, let button = statusItem.button else { return }
        
        // Get status bar button position
        let buttonFrame = button.convert(button.bounds, to: nil)
        guard let buttonWindow = button.window else { return }
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)
        
        // Get main screen bounds
        guard let mainScreen = NSScreen.main else { return }
        let screenBounds = mainScreen.visibleFrame
        
        // Calculate position
        let windowFrame = window.frame
        let x = max(screenBounds.minX, min(screenFrame.midX - windowFrame.width / 2, screenBounds.maxX - windowFrame.width))
        let y = screenFrame.minY - windowFrame.height - 8
        
        // Ensure window is within screen bounds
        let finalY = max(screenBounds.minY, min(y, screenBounds.maxY - windowFrame.height))
        
        window.setFrameOrigin(NSPoint(x: x, y: finalY))
        print("Positioned window at: (\(x), \(finalY)), screen bounds: \(screenBounds)")
    }
    
    // MARK: - Actions
    
    @objc private func statusBarButtonClicked() {
        toggleWindow()
    }
    
    private func toggleWindow() {
        guard let window = popoverWindow else { return }
        
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    private func showWindow() {
        guard let window = popoverWindow else { return }
        
        positionWindow()
        
        // Ensure window is visible
        window.alphaValue = 0.0
        window.orderFront(nil)
        window.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        }
        
        // Refresh data when showing
        downloadsViewController?.refreshData()
        
        print("Window shown with frame: \(window.frame)")
    }
    
    private func hideWindow() {
        guard let window = popoverWindow else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0.0
        }) {
            window.orderOut(nil)
            window.alphaValue = 1.0
        }
    }
    
    // MARK: - Window Resize (Simple & Direct)
    
    func expandWindow(to height: CGFloat) {
        guard let window = popoverWindow else { return }
        
        let currentFrame = window.frame
        let topEdge = currentFrame.maxY
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: topEdge - height,
            width: currentFrame.width,
            height: height
        )
        
        print("🔧 RESIZE: \(currentFrame.height) → \(height), top stays at \(topEdge)")
        
        // Simple animated resize
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }
    
    func collapseWindow(to height: CGFloat) {
        expandWindow(to: height)
    }
    
    // MARK: - File Monitoring
    
    private func startFileMonitoring() {
        DownloadsFileManager.shared.startMonitoring()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewDownload),
            name: .newDownloadDetected,
            object: nil
        )
    }
    
    @objc private func handleNewDownload() {
        // Auto-show window when new download is detected
        if popoverWindow?.isVisible != true {
            showWindow()
        }
    }
}