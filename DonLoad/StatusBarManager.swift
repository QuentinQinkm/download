//
//  StatusBarManager.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Cocoa

// Custom window that accepts mouse events and can handle drags
class PopoverPanel: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

class StatusBarManager: NSObject, FolderWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popoverWindow: NSWindow?
    private var folderWindow: NSWindow?
    private var downloadsViewController: DownloadsViewController?
    private var foldersViewController: FolderWindowViewController?
    private var menu: NSMenu?
    private var isMonitoringStarted = false
    
    override init() {
        super.init()
        setupStatusBar()
        setupPopoverWindow()
        setupFolderWindow()
        startFileMonitoring()
    }
    
    deinit {
        // Clean up observers and resources
        NotificationCenter.default.removeObserver(self)
        DownloadsFileManager.shared.stopMonitoring()
        
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
    
    // MARK: - Status Bar Setup
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        guard let statusItem = statusItem else { return }
        
        // Set the status bar icon
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "DonLoad")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Enable right-click for menu
            button.toolTip = "DonLoad - Downloads Manager\nLeft click: Open popup\nRight click: Menu"
        }
        
        // Create the menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Popup", action: #selector(openPopup), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit DonLoad", action: #selector(quitApp), keyEquivalent: "q"))
        
        // Set targets for menu items
        for item in menu.items {
            item.target = self
        }
        
        // Store menu for manual popup (don't set statusItem.menu to avoid automatic behavior)
        self.menu = menu
    }
    
    // MARK: - Popover Window Setup
    
    private func setupPopoverWindow() {
        
        // Create downloads view controller with proper error handling
        let newDownloadsViewController = DownloadsViewController()
        
        guard newDownloadsViewController != nil else {
            NSLog("❌ WINDOW DEBUG: Failed to create downloadsViewController")
            return
        }
        
        // Assign to instance variable
        downloadsViewController = newDownloadsViewController
        
        // Pass reference to StatusBarManager for animations
        downloadsViewController?.statusBarManager = self
        
        guard let mainScreen = NSScreen.main else {
            NSLog("❌ WINDOW DEBUG: Failed to get main screen")
            return
        }
        
        let screenFrame = mainScreen.visibleFrame
        let panelWidth: CGFloat = screenFrame.width / 2
        let panelHeight: CGFloat = 216  // Updated to match new layout
        
        
        // Create window with proper style for transparency
        popoverWindow = FocusableWindow(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .nonretained,
            defer: false
        )
        
        guard let window = popoverWindow else {
            NSLog("❌ WINDOW DEBUG: Failed to create popoverWindow")
            return
        }
        
        
        // Window configuration with simple, visible styling
        guard newDownloadsViewController != nil else {
            NSLog("❌ WINDOW DEBUG: downloadsViewController is nil when setting content")
            return
        }
        
        // Ensure the view controller's view is loaded before setting it
        _ = newDownloadsViewController.view
        
        window.contentViewController = newDownloadsViewController
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.level = .popUpMenu
        window.animationBehavior = .documentWindow
        window.acceptsMouseMovedEvents = true
        
        // Enable immediate focus and interaction
        window.ignoresMouseEvents = false
        
        
        // Apply simple, clean window style
        window.isMovableByWindowBackground = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Set window size and position first
        window.setContentSize(NSSize(width: panelWidth, height: panelHeight))
        let windowX = screenFrame.minX + (screenFrame.width - panelWidth) / 2
        let windowY = screenFrame.maxY - panelHeight - 20
        window.setFrameOrigin(NSPoint(x: windowX, y: windowY))
        
        // Add glass material effect to main window after sizing
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .withinWindow
        visualEffect.material = .underWindowBackground
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        
        // Insert glass effect as background and ensure it covers the entire window
        if let contentView = window.contentView {
            contentView.addSubview(visualEffect, positioned: .below, relativeTo: nil)
            
            // Use autoresizing mask for better performance and reliability
            visualEffect.translatesAutoresizingMaskIntoConstraints = false
            visualEffect.frame = contentView.bounds
            visualEffect.autoresizingMask = [.width, .height]
            
            // Also add constraints as backup to ensure proper positioning
            NSLayoutConstraint.activate([
                visualEffect.topAnchor.constraint(equalTo: contentView.topAnchor),
                visualEffect.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                visualEffect.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                visualEffect.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        
        // Ensure content view is transparent - let the visual effect view handle the appearance
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        
    }
    
    // MARK: - Folder Window Setup
    
    private func setupFolderWindow() {
        NSLog("🔍 DEBUG: setupFolderWindow called")
        
        guard let mainScreen = NSScreen.main else {
            NSLog("❌ DEBUG: No main screen available")
            return
        }
        
        let screenFrame = mainScreen.visibleFrame
        let panelWidth: CGFloat = screenFrame.width / 2  // Same width as download window
        let panelHeight: CGFloat = 80  // Minimal initial height, will be overridden by grid content
        
        NSLog("📐 DEBUG: Screen frame: \(screenFrame)")
        NSLog("📐 DEBUG: Panel size: \(panelWidth) x \(panelHeight)")
        
        // Create folder window
        NSLog("🔧 DEBUG: Creating FocusableWindow...")
        NSLog("🔧 DEBUG: Creating window with size: \(panelWidth) x \(panelHeight)")
        folderWindow = FocusableWindow(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let window = folderWindow else {
            NSLog("❌ DEBUG: Failed to create folder window")
            return
        }
        
        NSLog("✅ DEBUG: Folder window created successfully")
        NSLog("🔍 DEBUG: Window properties - isVisible: \(window.isVisible), alphaValue: \(window.alphaValue)")
        
        // Window configuration with glass material
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.level = .popUpMenu
        
        NSLog("🔧 DEBUG: Window configured - level: \(window.level), hasShadow: \(window.hasShadow)")
        
        // Ensure content view is transparent first
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Add glass material effect after content view is configured
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .withinWindow
        visualEffect.material = .underWindowBackground
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        
        // Insert glass effect as background and ensure it covers the entire window
        if let contentView = window.contentView {
            contentView.addSubview(visualEffect, positioned: .below, relativeTo: nil)
            
            // Use autoresizing mask for better performance and reliability
            visualEffect.translatesAutoresizingMaskIntoConstraints = false
            visualEffect.frame = contentView.bounds
            visualEffect.autoresizingMask = [.width, .height]
            
            // Also add constraints as backup to ensure proper positioning
            NSLayoutConstraint.activate([
                visualEffect.topAnchor.constraint(equalTo: contentView.topAnchor),
                visualEffect.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                visualEffect.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                visualEffect.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            
            NSLog("✅ DEBUG: Visual effect added to content view")
        } else {
            NSLog("❌ DEBUG: No content view available")
        }
        
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        
        // Explicitly set the content size to ensure proper dimensions
        window.setContentSize(NSSize(width: panelWidth, height: panelHeight))
        NSLog("📐 DEBUG: Set content size to: \(panelWidth) x \(panelHeight)")
        
        // Position window initially (will be repositioned when shown)
        let windowX = screenFrame.minX + (screenFrame.width - panelWidth) / 2
        let windowY = screenFrame.maxY - panelHeight - 300  // Start hidden
        window.setFrameOrigin(NSPoint(x: windowX, y: windowY))
        NSLog("📍 DEBUG: Set initial position: (\(windowX), \(windowY))")
        
        // Create view controller for folders
        NSLog("🔧 DEBUG: Creating FolderWindowViewController...")
        foldersViewController = FolderWindowViewController()
        foldersViewController?.view.wantsLayer = true
        foldersViewController?.view.layer?.backgroundColor = NSColor.clear.cgColor
        foldersViewController?.view.layer?.cornerRadius = 16
        foldersViewController?.view.layer?.masksToBounds = true
        
        // Set delegate to handle folder selection
        foldersViewController?.delegate = self
        
        NSLog("🔧 DEBUG: Setting content view controller...")
        window.contentViewController = foldersViewController
        
        // Force the window to update its frame after setting content view controller
        NSLog("🔧 DEBUG: Forcing window frame update...")
        window.setFrame(window.frame, display: true)
        NSLog("📐 DEBUG: Window frame after content view controller: \(window.frame)")
        
        // Verify the window size after setup
        NSLog("📐 DEBUG: Final window frame after setup: \(window.frame)")
        NSLog("🔍 DEBUG: Window content view frame: \(window.contentView?.frame ?? NSRect.zero)")
        
        // Check if window has proper dimensions - only fix width, let height be determined by content
        if window.frame.width <= 0 {
            NSLog("❌ DEBUG: WARNING: Window has invalid width after setup!")
            NSLog("🔧 DEBUG: Fixing width only, height will be determined by grid content...")
            let fixedFrame = NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: panelWidth, height: window.frame.height)
            window.setFrame(fixedFrame, display: true)
            NSLog("🔧 DEBUG: Fixed window width to: \(panelWidth)")
        }
        
        // Initially hidden
        window.alphaValue = 0.0
        window.orderOut(nil)
        
        NSLog("✅ DEBUG: Folder window setup completed")
        NSLog("🔍 DEBUG: Final window state - isVisible: \(window.isVisible), alphaValue: \(window.alphaValue), frame: \(window.frame)")
    }
    
    // MARK: - Actions
    
    @objc private func statusBarButtonClicked() {
        NSLog("🖱️ Status bar button clicked")
        guard let event = NSApp.currentEvent else { 
            NSLog("❌ No current event")
            return 
        }
        
        if event.type == .rightMouseUp {
            NSLog("👆 Right click - showing menu")
            showMenu()
        } else {
            NSLog("👆 Left click - toggling popover")
            togglePopover()
        }
        
        // Removed test code - folder window shows only during drag operations
    }
    
    private func showMenu() {
        guard let statusItem = statusItem else { return }
        
        // Hide window if it's showing
        if popoverWindow?.isVisible == true {
            hidePopover()
        }
        
        // Show menu using modern API (macOS 10.14+)
        if let menu = menu {
            statusItem.menu = menu
            // Manually trigger menu display at button location
            if let button = statusItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
            // Clear menu immediately to prevent automatic behavior
            statusItem.menu = nil
        }
    }
    
    @objc private func openPopup() {
        showPopover()
    }
    

    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Popover Management
    
    private func togglePopover() {
        guard let window = popoverWindow else { 
            NSLog("❌ No popover window")
            return 
        }
        
        NSLog("🔄 Toggle popover - current visible: \(window.isVisible)")
        if window.isVisible {
            NSLog("🙈 Hiding popover")
            hidePopover()
        } else {
            NSLog("👁️ Showing popover")
            showPopover()
        }
    }
    
    func animatePopoverExpansion() {
        guard let window = popoverWindow, window.isVisible else { return }
        
        NSLog("🎭 POPUP DEBUG: Starting expansion animation")
        
        // Animate window height expansion with smooth transition
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
            context.allowsImplicitAnimation = true
            
            // Get current frame and expand height
            let currentFrame = window.frame
            let expandedHeight: CGFloat = 300
            let expandedFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y - (expandedHeight - currentFrame.height), // Adjust Y to keep bottom aligned
                width: currentFrame.width,
                height: expandedHeight
            )
            
            // Animate to expanded size
            window.animator().setFrame(expandedFrame, display: true)
            
        }) {
            NSLog("🎭 POPUP DEBUG: Expansion animation completed")
        }
    }
    
    func animatePopoverCollapse() {
        guard let window = popoverWindow, window.isVisible else { return }
        
        NSLog("🎭 POPUP DEBUG: Starting collapse animation")
        
        // Animate window height collapse with smooth transition
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0.055, 0.675, 0.19)
            context.allowsImplicitAnimation = true
            
            // Get current frame and collapse height
            let currentFrame = window.frame
            let collapsedHeight: CGFloat = 216
            let collapsedFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y + (currentFrame.height - collapsedHeight), // Adjust Y to keep bottom aligned
                width: currentFrame.width,
                height: collapsedHeight
            )
            
            // Animate to collapsed size
            window.animator().setFrame(collapsedFrame, display: true)
            
        }) {
            NSLog("🎭 POPUP DEBUG: Collapse animation completed")
        }
    }
    
    func showPopover() {
        
        guard let window = popoverWindow else {
            NSLog("❌ POPUP DEBUG: No popover window available")
            return
        }
        
        NSLog("🎯 POPUP DEBUG: showPopover called")
        NSLog("🎯 POPUP DEBUG: Window frame before: \(window.frame)")
        
        _ = downloadsViewController?.view
        // Always show all downloads
        
        guard let mainScreen = NSScreen.main else {
            NSLog("❌ POPUP DEBUG: Failed to get main screen")
            return
        }
        
        let screenFrame = mainScreen.visibleFrame
        let windowFrame = window.frame
        let finalX = screenFrame.minX + (screenFrame.width - windowFrame.width) / 2
        let finalY = screenFrame.maxY - windowFrame.height - 20
        let startY = screenFrame.maxY + 50
        
        
        NSLog("🎯 POPUP DEBUG: Screen frame: \(screenFrame)")
        NSLog("🎯 POPUP DEBUG: Final position calculated: (\(finalX), \(finalY))")
        
        // Position window above screen initially for slide-in animation
        window.setFrameOrigin(NSPoint(x: finalX, y: startY))
        NSLog("🎯 POPUP DEBUG: Window positioned at start: \(window.frame)")
        
        // Refresh data before showing
        downloadsViewController?.refreshData()
        
        // Show window with immediate focus
        window.makeKeyAndOrderFront(nil)
        
        // Force the window to become key and accept first responder immediately
        window.makeKey()
        window.makeFirstResponder(window.contentView)
        
        // Ensure window is visible and accepts interaction
        window.alphaValue = 1.0
        window.orderFrontRegardless()
        window.acceptsMouseMovedEvents = true
        
        // Force the app to activate if needed (brings to front)
        NSApp.activate(ignoringOtherApps: true)
        
        
        NSLog("🎯 POPUP DEBUG: Starting animation to: (\(finalX), \(finalY))")
        
        // Animate window sliding down with smooth transition
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
            context.allowsImplicitAnimation = true
            
            // Animate to final position using setFrame for more explicit control
            let finalFrame = NSRect(x: finalX, y: finalY, width: windowFrame.width, height: windowFrame.height)
            NSLog("🎯 POPUP DEBUG: About to animate to frame: \(finalFrame)")
            window.animator().setFrame(finalFrame, display: true)
            NSLog("🎯 POPUP DEBUG: Animator called - current frame: \(window.frame)")
            
        }) {
            NSLog("🎯 POPUP DEBUG: Animation completed - final frame: \(window.frame)")
        }
    }
    
    private func hidePopover() {
        guard let window = popoverWindow else { return }
        
        // Animate window exit with smooth transition
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0.055, 0.675, 0.19)
            context.allowsImplicitAnimation = true
            
            // Animate window up and fade out
            let currentFrame = window.frame
            let exitY = currentFrame.origin.y + 100
            window.animator().setFrameOrigin(NSPoint(x: currentFrame.origin.x, y: exitY))
            window.animator().alphaValue = 0.0
            
        }) {
            // Hide window after animation completes
            window.orderOut(nil)
            window.alphaValue = 1.0
            NSLog("🙈 Popover hidden with animation")
        }
    }
    
    // MARK: - Folder Window Management
    
    func showFolderWindow(for draggedFile: DownloadFile) {
        NSLog("🔍 DEBUG: showFolderWindow called for file: \(draggedFile.name)")
        
        guard let folderWindow = folderWindow else {
            NSLog("❌ DEBUG: folderWindow is nil")
            return
        }
        
        guard let popoverWindow = popoverWindow else {
            NSLog("❌ DEBUG: popoverWindow is nil")
            return
        }
        
        NSLog("✅ DEBUG: Both windows exist, proceeding...")
        
        // Configure folder view controller with dragged file
        NSLog("🔧 DEBUG: Configuring folder view controller...")
        foldersViewController?.configureDrag(for: draggedFile)
        
        // Wait a moment for the view controller to update the window size
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSLog("⏰ DEBUG: Async delay completed, positioning window...")
            
            // Check if window has proper dimensions - only fix width, let height be determined by grid content
            if folderWindow.frame.width <= 0 {
                NSLog("❌ DEBUG: Window has invalid width: \(folderWindow.frame)")
                NSLog("🔧 DEBUG: Fixing width only, height will be determined by grid content...")
                
                // Force window to have proper width only
                let mainFrame = popoverWindow.frame
                let newFrame = NSRect(x: folderWindow.frame.origin.x, y: folderWindow.frame.origin.y, width: mainFrame.width, height: folderWindow.frame.height)
                folderWindow.setFrame(newFrame, display: true)
                NSLog("🔧 DEBUG: Fixed window width to: \(mainFrame.width)")
            }
            
            // Position folder window below main window
            let mainFrame = popoverWindow.frame
            let spacing: CGFloat = 8
            
            NSLog("📐 DEBUG: Main window frame: \(mainFrame)")
            NSLog("📐 DEBUG: Folder window frame: \(folderWindow.frame)")
            
            // Center the folder window under the main window
            let targetX = mainFrame.origin.x
            let targetY = mainFrame.origin.y - folderWindow.frame.height - spacing
            
            NSLog("🎯 DEBUG: Target position calculated: (\(targetX), \(targetY))")
            
            // Set initial position slightly lower for slide-up effect
            let startY = targetY - 20
            folderWindow.setFrameOrigin(NSPoint(x: targetX, y: startY))
            NSLog("📍 DEBUG: Set initial position: (\(targetX), \(startY))")
            
            folderWindow.alphaValue = 0.0
            NSLog("👁️ DEBUG: Set alpha to 0.0")
            
            folderWindow.makeKeyAndOrderFront(nil)
            NSLog("🪟 DEBUG: Called makeKeyAndOrderFront")
            
            // Animate folder window sliding up and fading in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
                context.allowsImplicitAnimation = true
                
                NSLog("🎭 DEBUG: Starting animation to final position: (\(targetX), \(targetY))")
                folderWindow.animator().setFrameOrigin(NSPoint(x: targetX, y: targetY))
                folderWindow.animator().alphaValue = 1.0
            }) {
                NSLog("✅ DEBUG: Animation completed, final frame: \(folderWindow.frame)")
                NSLog("✅ DEBUG: Final alpha: \(folderWindow.alphaValue)")
                NSLog("✅ DEBUG: Window is visible: \(folderWindow.isVisible)")
                //NSLog("✅ DEBUG: Window is ordered front: \(folderWindow.isOrderedFront)")
            }
        }
    }
    
    func hideFolderWindow() {
        guard let folderWindow = folderWindow else { return }
        
        // Animate folder window sliding down and fading out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0.055, 0.675, 0.19)
            context.allowsImplicitAnimation = true
            
            let currentFrame = folderWindow.frame
            folderWindow.animator().setFrameOrigin(NSPoint(x: currentFrame.origin.x, y: currentFrame.origin.y - 20))
            folderWindow.animator().alphaValue = 0.0
        }) {
            folderWindow.orderOut(nil)
        }
    }
    
    // MARK: - File Monitoring
    
    private func startFileMonitoring() {
        // Only start monitoring once
        guard !isMonitoringStarted else { return }
        
        DownloadsFileManager.shared.startMonitoring()
        
        // Subscribe to new download notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewDownload),
            name: .newDownloadDetected,
            object: nil
        )
        
        isMonitoringStarted = true
    }
    
    @objc private func handleNewDownload() {
        // Auto-open popover showing recent files when new download is detected
        if popoverWindow?.isVisible != true {
            showPopover()
        }
    }
}

// MARK: - Panel Delegate

extension StatusBarManager {
    func panelWillShow() {
        // Refresh file data when panel is shown
        downloadsViewController?.refreshData()
    }
    
    // MARK: - FolderWindowDelegate
    
    func folderSelected(_ folder: FolderItem, for file: DownloadFile) {
        NSLog("📁 Folder selected: \(folder.name) for file: \(file.name)")
        
        // Move the file to selected folder
        let success = DownloadsFileManager.shared.moveFile(file, to: folder.url)
        if success {
            NSLog("✅ File successfully moved to \(folder.name)")
            
            // Add to recent places
            var recentPlaces = UserDefaults.standard.stringArray(forKey: "DonLoadRecentPlaces") ?? []
            recentPlaces.removeAll { $0 == folder.url.absoluteString }
            recentPlaces.insert(folder.url.absoluteString, at: 0)
            if recentPlaces.count > 10 {
                recentPlaces = Array(recentPlaces.prefix(10))
            }
            UserDefaults.standard.set(recentPlaces, forKey: "DonLoadRecentPlaces")
        } else {
            NSLog("❌ Failed to move file to \(folder.name)")
        }
        
        // End drag session
        downloadsViewController?.endDragSession()
    }
}
