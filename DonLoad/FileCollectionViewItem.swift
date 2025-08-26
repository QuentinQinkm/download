//
//  FileCollectionViewItem.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Cocoa
import QuickLook
import QuickLookThumbnailing

class FileCollectionViewItem: NSCollectionViewItem, NSDraggingSource {
    
    static let identifier = NSUserInterfaceItemIdentifier("FileCollectionViewItem")
    
    // MARK: - UI Elements
    
    private var containerView: NSView!
    private var thumbnailImageView: NSImageView!
    private var fileNameLabel: NSTextField!
    private var ageLabel: NSTextField!
    private var hoverView: NSView!
    
    // MARK: - Properties
    
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var currentFile: DownloadFile?
    
    // Direct reference to parent controller - set during configuration
    weak var downloadsViewController: DownloadsViewController?
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        setupUI()
        setupConstraints()
        setupTrackingArea()
        
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Container view with modern styling (no glassmorphism background)
        containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 12
        containerView.layer?.masksToBounds = true
        
        // Remove glassmorphism - just use transparent background
        // Add subtle border and shadow for depth
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        containerView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.08).cgColor
        containerView.layer?.shadowOffset = NSSize(width: 0, height: 2)
        containerView.layer?.shadowRadius = 6
        containerView.layer?.shadowOpacity = 0.4
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Thumbnail image view with rounded corners
        thumbnailImageView = NSImageView()
        thumbnailImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 8
        thumbnailImageView.layer?.masksToBounds = true
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // File name label with modern typography
        fileNameLabel = NSTextField(labelWithString: "")
        fileNameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        fileNameLabel.textColor = NSColor.labelColor
        fileNameLabel.alignment = .center
        fileNameLabel.maximumNumberOfLines = 2
        fileNameLabel.cell?.truncatesLastVisibleLine = true
        fileNameLabel.cell?.lineBreakMode = .byTruncatingMiddle
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Age label with subtle styling
        ageLabel = NSTextField(labelWithString: "")
        ageLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        ageLabel.textColor = NSColor.secondaryLabelColor
        ageLabel.alignment = .center
        ageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Hover view with action buttons (initially hidden)
        setupHoverView()
        
        // Add subviews with proper layering - IMPORTANT: hover view must be last to be on top
        containerView.addSubview(thumbnailImageView)
        containerView.addSubview(fileNameLabel)
        containerView.addSubview(ageLabel)
        containerView.addSubview(hoverView)
        view.addSubview(containerView)
    }
    
    private func setupHoverView() {
        hoverView = NSView()
        hoverView.wantsLayer = true
        hoverView.layer?.cornerRadius = 10
        hoverView.layer?.masksToBounds = true
        hoverView.alphaValue = 0.0
        hoverView.isHidden = false  // Ensure it's not hidden
        hoverView.translatesAutoresizingMaskIntoConstraints = false
        
        // Use transparent background - we'll darken the main container instead
        hoverView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create icon-only action buttons positioned at top-left and top-right
        let deleteButton = createIconOnlyButton(systemImage: "trash", color: NSColor.white)
        let moveButton = createIconOnlyButton(systemImage: "arrow.up.right", color: NSColor.white)
        
        // Add subviews with proper layering
        hoverView.addSubview(deleteButton)
        hoverView.addSubview(moveButton)
        
        // Setup button constraints - positioned at top-left and top-right
        NSLayoutConstraint.activate([
            // Delete button at top-left
            deleteButton.topAnchor.constraint(equalTo: hoverView.topAnchor, constant: 8),
            deleteButton.leadingAnchor.constraint(equalTo: hoverView.leadingAnchor, constant: 8),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Move button at top-right
            moveButton.topAnchor.constraint(equalTo: hoverView.topAnchor, constant: 8),
            moveButton.trailingAnchor.constraint(equalTo: hoverView.trailingAnchor, constant: -8),
            moveButton.widthAnchor.constraint(equalToConstant: 24),
            moveButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        NSLog("🎭 Hover view setup complete - alpha: \(hoverView.alphaValue), isHidden: \(hoverView.isHidden)")
    }
    
    private func createActionButton(title: String, systemImage: String, color: NSColor) -> NSButton {
        let button = NSButton()
        button.title = title
        button.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        button.imagePosition = .imageLeft
        button.bezelStyle = .inline
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        
        // Apply modern glassmorphism styling
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.masksToBounds = true
        button.layer?.backgroundColor = color.withAlphaComponent(0.1).cgColor
        button.layer?.borderWidth = 1
        button.layer?.borderColor = color.withAlphaComponent(0.3).cgColor
        
        // Set button colors
        button.contentTintColor = color
        
        // Add actions
        if title == "Delete" {
            button.target = self
            button.action = #selector(deleteAction)
        } else if title == "Move" {
            button.target = self
            button.action = #selector(moveAction)
        }
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func createIconOnlyButton(systemImage: String, color: NSColor) -> NSButton {
        let button = NSButton()
        button.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: systemImage)
        button.imageScaling = .scaleProportionallyUpOrDown
        button.imagePosition = .imageOnly
        button.bezelStyle = .circular
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        
        // Simple solid white icon styling
        button.wantsLayer = true
        button.layer?.cornerRadius = 12
        button.layer?.masksToBounds = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Set button colors to solid white
        button.contentTintColor = color
        
        // Add actions
        if systemImage == "trash" {
            button.target = self
            button.action = #selector(deleteAction)
        } else if systemImage == "arrow.up.right" {
            button.target = self
            button.action = #selector(moveAction)
        }
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            
            // Thumbnail image view
            thumbnailImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            thumbnailImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 64),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 64),
            
            // File name label
            fileNameLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 8),
            fileNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            fileNameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            // Age label
            ageLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 4),
            ageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            ageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            ageLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8),
            
            // Hover view
            hoverView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hoverView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hoverView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hoverView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    private func setupTrackingArea() {
        NSLog("🎭 Setting up tracking area for view bounds: \(view.bounds)")
        trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea!)
        NSLog("🎭 Tracking area added successfully")
    }
    
    func updateTrackingAreas() {
        NSLog("🎭 Updating tracking areas")
        if let trackingArea = trackingArea {
            view.removeTrackingArea(trackingArea)
        }
        setupTrackingArea()
        NSLog("🎭 Tracking areas updated")
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSLog("🎭 MOUSE ENTERED - Starting hover animation")
        isHovered = true
        
        // Smooth hover animation with spring physics
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
            context.allowsImplicitAnimation = true
            
            // Animate hover view appearance
            hoverView.alphaValue = 1.0
            
            // Darken the main container background instead of overlay
            containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
            
            // Subtle scale animation for container
            containerView.layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
            
            // Enhance shadow for depth
            containerView.layer?.shadowRadius = 8
            containerView.layer?.shadowOpacity = 0.6
            
        }) {
            NSLog("🎭 Hover animation completed - hoverView.alphaValue: \(self.hoverView.alphaValue)")
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSLog("🎭 MOUSE EXITED - Starting exit animation")
        isHovered = false
        
        // Smooth hover exit animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0.055, 0.675, 0.19)
            context.allowsImplicitAnimation = true
            
            // Animate hover view disappearance
            hoverView.alphaValue = 0.0
            
            // Reset container background to transparent
            containerView.layer?.backgroundColor = NSColor.clear.cgColor
            
            // Reset container scale
            containerView.layer?.transform = CATransform3DIdentity
            
            // Reset shadow
            containerView.layer?.shadowRadius = 6
            containerView.layer?.shadowOpacity = 0.4
            
        }) {
            NSLog("🎭 Exit animation completed - hoverView.alphaValue: \(self.hoverView.alphaValue)")
        }
    }
    
    // MARK: - Configuration
    
        func configure(with file: DownloadFile) {
        currentFile = file // Store reference for actions
        fileNameLabel.stringValue = file.name
        ageLabel.stringValue = file.age

        // Check if file still exists before loading thumbnail
        if FileManager.default.fileExists(atPath: file.url.path) {
            // Load thumbnail asynchronously
            loadThumbnail(for: file.url)
        } else {
            // File no longer exists - remove from cache immediately
            NSLog("⚠️ File no longer exists, removing from cache: \(file.name)")
            DownloadsFileManager.shared.removeFileFromCache(file)
            // Set a placeholder for now (this item will be removed on next update)
            thumbnailImageView.image = NSImage(systemSymbolName: "doc", accessibilityDescription: "Missing file")
        }

        // Reset to normal state
        containerView.layer?.borderWidth = 0
        containerView.layer?.borderColor = nil
        // Don't hide hover view - it should be controlled by alphaValue for animations
        // hoverView.isHidden = true
    }
    
    func configureForEmptyState(mode: DownloadsViewMode) {
        switch mode {
        case .recent:
            fileNameLabel.stringValue = "No recent downloads"
            ageLabel.stringValue = "Files from the last 5 minutes will appear here"
        case .all:
            fileNameLabel.stringValue = "No downloads found"
            ageLabel.stringValue = "Downloaded files will appear here"
        }
        
        // Set empty state icon
        thumbnailImageView.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "Empty")
        
        // Style as empty state
        containerView.layer?.borderWidth = 2
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Hide hover actions for empty state - but keep view visible for consistency
        hoverView.alphaValue = 0.0
        isHovered = false
    }
    
    private func loadThumbnail(for url: URL) {
        // Set default icon based on file type
        setDefaultIcon(for: url)
        
        // Generate thumbnail asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            self.generateThumbnail(for: url) { image in
                DispatchQueue.main.async {
                    if let thumbnail = image {
                        self.thumbnailImageView.image = thumbnail
                    }
                }
            }
        }
    }
    
    private func setDefaultIcon(for url: URL) {
        let workspace = NSWorkspace.shared
        let icon = workspace.icon(forFile: url.path)
        icon.size = NSSize(width: 64, height: 64)
        thumbnailImageView.image = icon
    }
    
    private func generateThumbnail(for url: URL, completion: @escaping (NSImage?) -> Void) {
        let size = CGSize(width: 64, height: 64)
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        
        QLThumbnailGenerator.shared.generateRepresentations(for: request) { thumbnail, type, error in
            if let thumbnail = thumbnail {
                let image = NSImage(cgImage: thumbnail.cgImage, size: NSSize(width: 64, height: 64))
                completion(image)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - Drag and Drop
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let file = currentFile else { 
            NSLog("❌ mouseDragged: No current file")
            return 
        }
        
        NSLog("🖱️ MOUSE DRAGGED started for file: \(file.name)")
        
        // Use direct parent reference - much simpler and reliable!
        guard let downloadsViewController = downloadsViewController else {
            NSLog("❌ No downloads view controller reference")
            return
        }
        
        NSLog("✅ Found parent controller, starting drag session...")
        downloadsViewController.startDragSession(for: file)
        
        // Create dragging item
        let draggingItem = NSDraggingItem(pasteboardWriter: file.url as NSURL)
        
        // Simple drag frame - just use a standard size to avoid crashes
        let dragFrame = NSRect(x: 0, y: 0, width: 64, height: 64)
        let dragImage = thumbnailImageView.image ?? NSWorkspace.shared.icon(forFile: file.url.path)
        
        draggingItem.setDraggingFrame(dragFrame, contents: dragImage)
        
        // Begin dragging
        NSLog("🚀 Beginning drag session...")
        view.beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    
    // Removed findViewController - now using direct parentViewController reference
    
    // MARK: - Actions
    
    @objc private func revealAction() {
        guard let file = currentFile else { return }
        DownloadsFileManager.shared.revealInFinder(file)
    }
    
    @objc private func deleteAction() {
        guard let file = currentFile else { return }
        
        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Move to Trash"
        alert.informativeText = "Are you sure you want to move \"\(file.name)\" to the Trash?"
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            let success = DownloadsFileManager.shared.deleteFile(file)
            if success {
                // The file manager will automatically update the UI through Combine publishers
                NSLog("✅ File successfully moved to trash")
            } else {
                // Show error alert
                let errorAlert = NSAlert()
                errorAlert.messageText = "Unable to Delete File"
                errorAlert.informativeText = "The file could not be moved to the Trash."
                errorAlert.addButton(withTitle: "OK")
                errorAlert.alertStyle = .critical
                errorAlert.runModal()
            }
        }
    }
    
    @objc private func quickLookAction() {
        guard let file = currentFile else { return }
        DownloadsFileManager.shared.openWithQuickLook(file)
    }
    
    @objc private func moveAction() {
        guard let file = currentFile else { return }
        
        // Start the inline drag session using direct reference
        downloadsViewController?.startDragSession(for: file)
    }
}

// MARK: - NSDraggingSource

extension FileCollectionViewItem {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // End drag session using direct reference
        downloadsViewController?.endDragSession()
        
        // If the move operation succeeded (external drop), remove file from cache immediately
        if operation == .move, let file = currentFile {
            NSLog("🚚 External drag completed successfully - removing file from cache")
            DownloadsFileManager.shared.removeFileFromCache(file)
        }
    }
}
