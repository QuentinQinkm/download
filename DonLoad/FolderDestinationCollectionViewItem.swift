import Cocoa

class FolderDestinationCollectionViewItem: NSCollectionViewItem, NSDraggingDestination {
    
    static let identifier = NSUserInterfaceItemIdentifier("FolderDestinationCollectionViewItem")
    
    // MARK: - UI Elements
    
    private var containerView: NSView!
    private var iconImageView: NSImageView!
    private var nameLabel: NSTextField!
    private var draggedFile: DownloadFile?
    private var folderItem: FolderItem?
    
    // MARK: - Delegate
    weak var dragCompletionDelegate: DragCompletionDelegate?
    
    // MARK: - Lifecycle
    
    override func loadView() {
        // Use a custom view that handles drag & drop
        let dragView = DragDestinationView()
        dragView.dragDestination = self
        view = dragView
        setupUI()
        setupConstraints()
        
        // Register for drag and drop
        view.registerForDraggedTypes([.fileURL])
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Container view with modern glassmorphism
        containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 10
        containerView.layer?.masksToBounds = true
        
        // Apply glassmorphism effect
        let glassEffect = NSVisualEffectView()
        glassEffect.material = .sidebar
        glassEffect.state = .active
        glassEffect.blendingMode = .withinWindow
        glassEffect.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subtle border and shadow for depth
        containerView.layer?.borderWidth = 0.5
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        containerView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.08).cgColor
        containerView.layer?.shadowOffset = NSSize(width: 0, height: 2)
        containerView.layer?.shadowRadius = 4
        containerView.layer?.shadowOpacity = 0.3
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Icon image view with rounded corners
        iconImageView = NSImageView()
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.imageFrameStyle = .none
        iconImageView.wantsLayer = true
        iconImageView.layer?.cornerRadius = 6
        iconImageView.layer?.masksToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconImageView)
        
        // Name label with modern typography
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.maximumNumberOfLines = 1
        nameLabel.cell?.truncatesLastVisibleLine = true
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(nameLabel)
        
        // Add glass effect with proper layering
        containerView.addSubview(glassEffect)
        containerView.addSubview(iconImageView)
        containerView.addSubview(nameLabel)
        
        // Setup glass effect constraints
        NSLayoutConstraint.activate([
            glassEffect.topAnchor.constraint(equalTo: containerView.topAnchor),
            glassEffect.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            glassEffect.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            glassEffect.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),
            
            // Icon image view (left side)
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            // Name label (right side)
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with folder: FolderItem, draggedFile: DownloadFile?, delegate: DragCompletionDelegate?) {
        folderItem = folder
        self.draggedFile = draggedFile
        self.dragCompletionDelegate = delegate
        
        // Set folder icon with compact size
        let folderIcon = folder.icon
        folderIcon.size = NSSize(width: 20, height: 20)
        iconImageView.image = folderIcon
        
        nameLabel.stringValue = folder.name
        
        // Reset visual state
        containerView.layer?.borderWidth = 0
        containerView.layer?.borderColor = nil
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
    }
    
    // MARK: - NSDraggingDestination
    
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        NSLog("📥 Drag entered folder: \(nameLabel.stringValue)")
        
        // Smooth animation for drag enter
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
            context.allowsImplicitAnimation = true
            
            // Scale up and enhance shadow
            containerView.layer?.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
            containerView.layer?.shadowRadius = 8
            containerView.layer?.shadowOpacity = 0.6
            
            // Enhance border
            containerView.layer?.borderWidth = 1.5
            containerView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
            
        }) {
            NSLog("🎭 Drag enter animation completed")
        }
        
        return .copy
    }
    
    func draggingExited(_ sender: NSDraggingInfo?) {
        NSLog("📤 Drag exited folder: \(nameLabel.stringValue)")
        
        // Smooth animation for drag exit
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0.055, 0.675, 0.19)
            context.allowsImplicitAnimation = true
            
            // Reset scale and shadow
            containerView.layer?.transform = CATransform3DIdentity
            containerView.layer?.shadowRadius = 4
            containerView.layer?.shadowOpacity = 0.3
            
            // Reset border
            containerView.layer?.borderWidth = 0.5
            containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
            
        }) {
            NSLog("🎭 Drag exit animation completed")
        }
    }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        NSLog("🎯 Performing drag operation on folder: \(folderItem?.name ?? "unknown")")
        
        // Get the dragged file from the pasteboard
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let fileURL = urls.first else {
            NSLog("❌ Could not read file URL from pasteboard")
            return false
        }
        
        // Find the corresponding DownloadFile
        guard let draggedFile = DownloadsFileManager.shared.downloadFiles.first(where: { $0.url == fileURL }) else {
            NSLog("❌ Could not find DownloadFile for URL: \(fileURL)")
            return false
        }
        
        guard let folderItem = folderItem else { return false }
        
        NSLog("🚚 Moving file '\(draggedFile.name)' to folder '\(folderItem.name)'")
        
        // Move file to destination folder
        let success = DownloadsFileManager.shared.moveFile(draggedFile, to: folderItem.url)
        
        if success {
            NSLog("✅ File moved successfully")
            // Notify delegate to update UI
            dragCompletionDelegate?.didCompleteFileMove(file: draggedFile, to: folderItem.url)
        } else {
            NSLog("❌ Failed to move file")
        }
        
        // Remove visual feedback
        draggingExited(nil)
        
        return success
    }
    
    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .move
    }
    
    // Removed findViewController - no longer needed
}

// MARK: - Custom Drag Destination View

class DragDestinationView: NSView {
    weak var dragDestination: FolderDestinationCollectionViewItem?
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return dragDestination?.draggingEntered(sender) ?? []
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        dragDestination?.draggingExited(sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return dragDestination?.performDragOperation(sender) ?? false
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return dragDestination?.draggingUpdated(sender) ?? []
    }
}
