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

class StatusBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var popoverWindow: NSWindow?
    private var downloadsViewController: DownloadsViewController?
    private var menu: NSMenu?
    private var isMonitoringStarted = false
    
    override init() {
        super.init()
        setupStatusBar()
        setupPopoverWindow()
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
        NSLog("🎯 WINDOW DEBUG: setupPopoverWindow called")
        
        downloadsViewController = DownloadsViewController()
        guard let downloadsViewController = downloadsViewController else {
            NSLog("❌ WINDOW DEBUG: Failed to create downloadsViewController")
            return
        }
        
        // Pass reference to StatusBarManager for animations
        downloadsViewController.statusBarManager = self
        
        guard let mainScreen = NSScreen.main else {
            NSLog("❌ WINDOW DEBUG: Failed to get main screen")
            return
        }
        
        let screenFrame = mainScreen.visibleFrame
        let panelWidth: CGFloat = screenFrame.width / 2
        let panelHeight: CGFloat = 216  // Updated to match new layout
        
        NSLog("🎯 WINDOW DEBUG: Screen: \(screenFrame), Panel: \(panelWidth) x \(panelHeight)")
        
        // Create window
        popoverWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let window = popoverWindow else {
            NSLog("❌ WINDOW DEBUG: Failed to create popoverWindow")
            return
        }
        
        NSLog("🎯 WINDOW DEBUG: Window created - frame: \(window.frame)")
        
        // Window configuration with simple, visible styling
        window.contentViewController = downloadsViewController
        window.isOpaque = false
        window.backgroundColor = NSColor.controlBackgroundColor
        window.hasShadow = true
        window.level = .floating
        window.animationBehavior = .documentWindow
        window.acceptsMouseMovedEvents = true
        
        NSLog("🎯 WINDOW DEBUG: Window configured - isOpaque: \(window.isOpaque), backgroundColor: \(String(describing: window.backgroundColor))")
        
        // Apply simple, clean window style
        window.isMovableByWindowBackground = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Simple border and shadow effects
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 16
        window.contentView?.layer?.masksToBounds = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        NSLog("🎯 WINDOW DEBUG: Window styling applied")
        
        // Set window size and position
        window.setContentSize(NSSize(width: panelWidth, height: panelHeight))
        let windowX = screenFrame.minX + (screenFrame.width - panelWidth) / 2
        let windowY = screenFrame.maxY - panelHeight - 20
        window.setFrameOrigin(NSPoint(x: windowX, y: windowY))
        
        NSLog("🎯 WINDOW DEBUG: Window positioned at (\(windowX), \(windowY))")
        NSLog("🎯 WINDOW DEBUG: Final window frame: \(window.frame)")
        NSLog("🎯 WINDOW DEBUG: Content view frame: \(window.contentView?.frame ?? NSRect.zero)")
        NSLog("🎯 WINDOW DEBUG: DownloadsViewController view frame: \(downloadsViewController.view.frame)")
        
        NSLog("🎯 WINDOW DEBUG: setupPopoverWindow completed successfully")
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
        showPopover(viewMode: .all)
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
            showPopover(viewMode: .all)
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
    
    func showPopover(viewMode: DownloadsViewMode = .all) {
        NSLog("🎯 POPUP DEBUG: showPopover called")
        
        guard let window = popoverWindow else {
            NSLog("❌ POPUP DEBUG: No popover window available")
            return
        }
        
        NSLog("🎯 POPUP DEBUG: Window exists - frame: \(window.frame), isVisible: \(window.isVisible)")
        
        _ = downloadsViewController?.view
        downloadsViewController?.setViewMode(viewMode)
        
        guard let mainScreen = NSScreen.main else {
            NSLog("❌ POPUP DEBUG: Failed to get main screen")
            return
        }
        
        let screenFrame = mainScreen.visibleFrame
        let windowFrame = window.frame
        let finalX = screenFrame.minX + (screenFrame.width - windowFrame.width) / 2
        let finalY = screenFrame.maxY - windowFrame.height - 20
        let startY = screenFrame.maxY + 50
        
        NSLog("🎯 POPUP DEBUG: Screen: \(screenFrame), Final pos: (\(finalX), \(finalY))")
        
        // Position window above screen initially
        window.setFrameOrigin(NSPoint(x: finalX, y: startY))
        
        // Refresh data before showing
        downloadsViewController?.refreshData()
        
        // Show window with modern method
        window.makeKeyAndOrderFront(nil)
        NSLog("🎯 POPUP DEBUG: makeKeyAndOrderFront called - isVisible: \(window.isVisible)")
        
        // Ensure window is visible and positioned correctly
        window.alphaValue = 1.0
        window.orderFrontRegardless()
        
        // IMPORTANT: Set the final position BEFORE animation to ensure it's visible
        window.setFrameOrigin(NSPoint(x: finalX, y: finalY))
        
        NSLog("🎯 POPUP DEBUG: After orderFront - isVisible: \(window.isVisible), alpha: \(window.alphaValue)")
        NSLog("🎯 POPUP DEBUG: Window frame: \(window.frame)")
        NSLog("🎯 POPUP DEBUG: Content view frame: \(window.contentView?.frame ?? NSRect.zero)")
        
        // Force visibility if needed
        if !window.isVisible {
            NSLog("⚠️ POPUP DEBUG: Window not visible, forcing with orderFront")
            window.orderFront(nil)
        }
        
        // No animation needed since we set the final position directly
        NSLog("🎯 POPUP DEBUG: Popup positioned at final location without animation")
        NSLog("🎯 POPUP DEBUG: Final visibility - isVisible: \(window.isVisible), alpha: \(window.alphaValue)")
        NSLog("🎯 POPUP DEBUG: Popup show sequence completed")
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
            showPopover(viewMode: .recent)
        }
    }
}

// MARK: - Panel Delegate

extension StatusBarManager {
    func panelWillShow() {
        // Refresh file data when panel is shown
        downloadsViewController?.refreshData()
    }
}
