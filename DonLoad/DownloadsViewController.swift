//
//  DownloadsViewController.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Cocoa
import Combine

// MARK: - Drag Completion Protocol
protocol DragCompletionDelegate: AnyObject {
    func didCompleteFileMove(file: DownloadFile, to destinationURL: URL)
}

enum DownloadsViewMode {
    case recent // Files from last 5 minutes
    case all    // All files (max 30)
}

struct FolderItem {
    let name: String
    let url: URL
    let icon: NSImage
}

class DownloadsViewController: NSViewController, DragCompletionDelegate {
    
    // MARK: - Properties
    
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var topBarView: NSView!
    private var titleLabel: NSTextField!
    private var actionButton: NSButton!
    
    // Height constraint for dynamic resizing
    private var viewHeightConstraint: NSLayoutConstraint!
    
    // Individual height constraints for dynamic updates
    private var scrollViewHeightConstraint: NSLayoutConstraint!
    private var foldersHeightConstraint: NSLayoutConstraint!
    
    private var currentViewMode: DownloadsViewMode = .all
    private var fileManager = DownloadsFileManager.shared
    private var currentFiles: [DownloadFile] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Drag and drop state
    private var isDragging = false
    private var draggedFile: DownloadFile?
    private var foldersCollectionView: NSCollectionView!
    private var foldersScrollView: NSScrollView!
    private var recentFolders: [FolderItem] = []
    
    // Reference to StatusBarManager for popup animations
    weak var statusBarManager: StatusBarManager?
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        NSLog("🎯 VIEW DEBUG: loadView called")
        view = NSView()
        view.wantsLayer = true
        
        NSLog("🎯 VIEW DEBUG: View created - frame: \(view.frame), bounds: \(view.bounds)")
        
        // Use simple, solid background for better visibility
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        
        NSLog("🎯 VIEW DEBUG: Simple background applied")
        
        setupUI()
        setupConstraints()
        
        // Set initial height constraint (width will be set by parent window)
        viewHeightConstraint = view.heightAnchor.constraint(equalToConstant: 216)
        viewHeightConstraint.isActive = true
        
        // Set initial individual heights
        scrollViewHeightConstraint.constant = 150
        foldersHeightConstraint.constant = 0
        
        NSLog("🎯 VIEW DEBUG: Initial constraints set - height: 216, scroll: 150, folders: 0")
        NSLog("🎯 VIEW DEBUG: Final view frame: \(view.frame), bounds: \(view.bounds)")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("🎯 VIEW DEBUG: viewDidLoad called")
        
        setupBindings()
        
        // Load recent folders for the second row
        DispatchQueue.main.async {
            self.loadRecentFolders()
        }
        
        // Force layout to ensure everything is properly sized
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        
        NSLog("🎯 VIEW DEBUG: viewDidLoad completed - view frame: \(view.frame), bounds: \(view.bounds)")
        NSLog("🎯 VIEW DEBUG: Top bar frame: \(topBarView.frame)")
        NSLog("🎯 VIEW DEBUG: Scroll view frame: \(scrollView.frame)")
        NSLog("🎯 VIEW DEBUG: Collection view frame: \(collectionView.frame)")
        NSLog("🎯 VIEW DEBUG: Collection view item count: \(collectionView.numberOfItems(inSection: 0))")
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Update collection view layout for centering when view size changes
        updateCollectionViewLayout()
    }
    
    deinit {
        // Clean up Combine subscriptions
        cancellables.removeAll()
    }
    
    private func setupBindings() {
        NSLog("🔗 Setting up bindings between file manager and view controller")
        
        // Subscribe to file manager updates
        fileManager.$downloadFiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] files in
                NSLog("📥 Received downloadFiles update - count: \(files.count)")
                self?.updateCurrentFiles()
            }
            .store(in: &cancellables)
        
        fileManager.$recentFiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] files in
                NSLog("📥 Received recentFiles update - count: \(files.count)")
                if self?.currentViewMode == .recent {
                    self?.updateCurrentFiles()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        setupTopBar()
        setupCollectionView()
    }
    
    private func setupTopBar() {
        topBarView = NSView()
        topBarView.wantsLayer = true
        topBarView.layer?.cornerRadius = 12
        topBarView.layer?.masksToBounds = true
        
        // Apply glassmorphism effect to top bar
        let topBarBlur = NSVisualEffectView()
        topBarBlur.material = .sidebar
        topBarBlur.state = .active
        topBarBlur.blendingMode = .withinWindow
        topBarBlur.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subtle border and shadow
        topBarView.layer?.borderWidth = 0.5
        topBarView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        topBarView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.1).cgColor
        topBarView.layer?.shadowOffset = NSSize(width: 0, height: 1)
        topBarView.layer?.shadowRadius = 4
        topBarView.layer?.shadowOpacity = 0.3
        
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel = NSTextField(labelWithString: "Recent (5 min)")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        actionButton = NSButton(title: "Show All", target: self, action: #selector(toggleViewMode))
        actionButton.bezelStyle = .inline
        actionButton.controlSize = .regular
        actionButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        
        // Apply glassmorphism to button
        actionButton.wantsLayer = true
        actionButton.layer?.cornerRadius = 8
        actionButton.layer?.masksToBounds = true
        actionButton.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        actionButton.layer?.borderWidth = 1
        actionButton.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
        
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews with proper layering
        topBarView.addSubview(topBarBlur)
        topBarView.addSubview(titleLabel)
        topBarView.addSubview(actionButton)
        view.addSubview(topBarView)
        
        // Setup top bar blur constraints
        NSLayoutConstraint.activate([
            topBarBlur.topAnchor.constraint(equalTo: topBarView.topAnchor),
            topBarBlur.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor),
            topBarBlur.trailingAnchor.constraint(equalTo: topBarView.trailingAnchor),
            topBarBlur.bottomAnchor.constraint(equalTo: topBarView.bottomAnchor)
        ])
    }
    
    private func setupCollectionView() {
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        // Create collection view
        collectionView = NSCollectionView()
        collectionView.wantsLayer = true
        collectionView.backgroundColors = [NSColor.clear]
        collectionView.isSelectable = false
        collectionView.allowsMultipleSelection = false
        
        let layout = createFlowLayout()
        collectionView.collectionViewLayout = layout
        
        // Register the file item and folder item
        collectionView.register(FileCollectionViewItem.self, forItemWithIdentifier: FileCollectionViewItem.identifier)
        collectionView.register(FolderCollectionViewItem.self, forItemWithIdentifier: FolderCollectionViewItem.identifier)
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        scrollView.documentView = collectionView
        view.addSubview(scrollView)
        
        // Setup folders collection view for drag destinations
        setupFoldersCollectionView()
        
        NSLog("🎯 VIEW DEBUG: Collection view setup completed")
    }
    
    private func setupFoldersCollectionView() {
        NSLog("🎯 FOLDER DEBUG: setupFoldersCollectionView called")
        
        // Create scroll view for folders
        foldersScrollView = NSScrollView()
        foldersScrollView.translatesAutoresizingMaskIntoConstraints = false
        foldersScrollView.hasVerticalScroller = false
        foldersScrollView.hasHorizontalScroller = true
        foldersScrollView.autohidesScrollers = true
        
        // Create collection view for folders
        foldersCollectionView = NSCollectionView()
        foldersCollectionView.wantsLayer = true
        foldersCollectionView.backgroundColors = [NSColor.clear]
        foldersCollectionView.isSelectable = false
        foldersCollectionView.allowsMultipleSelection = false
        
        let layout = createFoldersLayout()
        foldersCollectionView.collectionViewLayout = layout
        
        // Register folder destination item
        foldersCollectionView.register(FolderDestinationCollectionViewItem.self, forItemWithIdentifier: FolderDestinationCollectionViewItem.identifier)
        
        foldersCollectionView.dataSource = self
        foldersCollectionView.delegate = self
        
        foldersScrollView.documentView = foldersCollectionView
        view.addSubview(foldersScrollView)
        
        // Initially hide the folders row and make it transparent
        foldersScrollView.isHidden = true
        foldersScrollView.alphaValue = 0.0
        
        NSLog("🎯 FOLDER DEBUG: Folders collection view setup completed")
        NSLog("🎯 FOLDER DEBUG: Folders scroll view frame: \(foldersScrollView.frame)")
        NSLog("🎯 FOLDER DEBUG: Folders collection view frame: \(foldersCollectionView.frame)")
    }
    
    private func createFoldersLayout() -> NSCollectionViewFlowLayout {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = NSSize(width: 120, height: 32) // Horizontal layout: icon + text
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return layout
    }
    
    private func createFlowLayout() -> NSCollectionViewFlowLayout {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = NSSize(width: 120, height: 140)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        
        // Calculate center alignment
        let itemWidth: CGFloat = 120
        let itemSpacing: CGFloat = 12
        let availableWidth = view.bounds.width
        
        // For centering, calculate how many items can fit and adjust side insets
        let itemsPerRow = max(1, Int((availableWidth - 32) / (itemWidth + itemSpacing))) // 32 for min margins
        let totalItemsWidth = CGFloat(itemsPerRow) * itemWidth + CGFloat(max(0, itemsPerRow - 1)) * itemSpacing
        let sideInset = max(16, (availableWidth - totalItemsWidth) / 2)
        
        layout.sectionInset = NSEdgeInsets(top: 4, left: sideInset, bottom: 4, right: sideInset)
        return layout
    }
    
    private func updateCollectionViewLayout() {
        guard let flowLayout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else { return }
        
        // Calculate center alignment based on current view width
        let itemWidth: CGFloat = 120
        let itemSpacing: CGFloat = 12
        let availableWidth = view.bounds.width
        
        // Calculate how many items can fit and adjust side insets for centering
        let itemsPerRow = max(1, Int((availableWidth - 32) / (itemWidth + itemSpacing)))
        let totalItemsWidth = CGFloat(itemsPerRow) * itemWidth + CGFloat(max(0, itemsPerRow - 1)) * itemSpacing
        let sideInset = max(16, (availableWidth - totalItemsWidth) / 2)
        
        flowLayout.sectionInset = NSEdgeInsets(top: 4, left: sideInset, bottom: 4, right: sideInset)
        
        // Also update folder layout if needed
        if let foldersFlowLayout = foldersCollectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
            let folderItemWidth: CGFloat = 120
            let folderItemSpacing: CGFloat = 8
            let foldersPerRow = max(1, Int((availableWidth - 32) / (folderItemWidth + folderItemSpacing)))
            let totalFoldersWidth = CGFloat(foldersPerRow) * folderItemWidth + CGFloat(max(0, foldersPerRow - 1)) * folderItemSpacing
            let folderSideInset = max(16, (availableWidth - totalFoldersWidth) / 2)
            
            foldersFlowLayout.sectionInset = NSEdgeInsets(top: 8, left: folderSideInset, bottom: 8, right: folderSideInset)
        }
    }
    
    private func setupConstraints() {
        NSLog("🎯 CONSTRAINT DEBUG: setupConstraints called")
        
        // Remove all existing constraints to prevent conflicts
        view.removeConstraints(view.constraints)
        topBarView.removeConstraints(topBarView.constraints)
        scrollView.removeConstraints(scrollView.constraints)
        foldersScrollView.removeConstraints(foldersScrollView.constraints)
        
        NSLog("🎯 CONSTRAINT DEBUG: Existing constraints removed")
        
        // Activate basic constraints
        NSLayoutConstraint.activate([
            // Top bar constraints
            topBarView.topAnchor.constraint(equalTo: view.topAnchor),
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 50),
            titleLabel.centerXAnchor.constraint(equalTo: topBarView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            actionButton.trailingAnchor.constraint(equalTo: topBarView.trailingAnchor, constant: -16),
            actionButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            
            // Scroll view constraints - let it fill available space
            scrollView.topAnchor.constraint(equalTo: topBarView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Folders scroll view constraints
            foldersScrollView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            foldersScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            foldersScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            foldersScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
        
        NSLog("🎯 CONSTRAINT DEBUG: Basic constraints activated")
        
        // Create and activate height constraints
        scrollViewHeightConstraint = scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150)
        foldersHeightConstraint = foldersScrollView.heightAnchor.constraint(equalToConstant: 0)
        scrollViewHeightConstraint.isActive = true
        foldersHeightConstraint.isActive = true
        
        NSLog("🎯 CONSTRAINT DEBUG: Height constraints activated - scroll: >=150, folders: 0")
        
        // Force layout update
        view.needsUpdateConstraints = true
        view.updateConstraints()
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        
        NSLog("🎯 CONSTRAINT DEBUG: Layout forced - view frame: \(view.frame)")
        NSLog("🎯 CONSTRAINT DEBUG: Top bar frame: \(topBarView.frame)")
        NSLog("🎯 CONSTRAINT DEBUG: Scroll view frame: \(scrollView.frame)")
        NSLog("🎯 CONSTRAINT DEBUG: Folders frame: \(foldersScrollView.frame)")
    }
    
    // MARK: - Public Methods
    
    func setViewMode(_ mode: DownloadsViewMode) {
        NSLog("🔄 Setting view mode to: \(mode)")
        currentViewMode = mode
        updateTopBar()
        updateCurrentFiles()
    }
    
    // MARK: - Drag Completion Methods
    
    func didCompleteFileMove(file: DownloadFile, to destinationURL: URL) {
        // Simple: just remove the file immediately
        if let index = currentFiles.firstIndex(where: { $0.id == file.id }) {
            currentFiles.remove(at: index)
            collectionView.reloadData()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateTopBar() {
        // Guard against calling this before view is loaded
        guard titleLabel != nil, actionButton != nil else { return }
        
        switch currentViewMode {
        case .recent:
            titleLabel.stringValue = "Recent (5 min)"
            actionButton.title = "Show All"
        case .all:
            titleLabel.stringValue = "All Downloads"
            actionButton.title = "Show Recent"
        }
    }
    
    @objc private func toggleViewMode() {
        let newMode: DownloadsViewMode = currentViewMode == .recent ? .all : .recent
        NSLog("🔄 toggleViewMode called - switching from \(currentViewMode) to \(newMode)")
        setViewMode(newMode)
    }
    

    

    
    func refreshData() {
        updateCurrentFiles()
    }
    
    // MARK: - Drag Session Management
    
    func startDragSession(for file: DownloadFile) {
        NSLog("🚀 Starting drag session for file: \(file.name)")
        
        isDragging = true
        draggedFile = file
        
        // Trigger popup window expansion animation
        statusBarManager?.animatePopoverExpansion()
        
        // Show folders immediately without internal animation
        foldersScrollView.isHidden = false
        foldersScrollView.alphaValue = 1.0
        
        // Set height constraints immediately
        viewHeightConstraint.constant = 300
        scrollViewHeightConstraint.constant = 150
        foldersHeightConstraint.constant = 84
        
        NSLog("🚀 Drag session started - view height: \(self.viewHeightConstraint.constant)")
        NSLog("🎯 FOLDER DEBUG: Folders now visible - isHidden: \(self.foldersScrollView.isHidden), alpha: \(self.foldersScrollView.alphaValue)")
        NSLog("🎯 FOLDER DEBUG: Folders height constraint: \(self.foldersHeightConstraint.constant)")
    }
    
    func endDragSession() {
        NSLog("🛑 Ending drag session")
        isDragging = false
        draggedFile = nil
        
        // Trigger popup window collapse animation
        statusBarManager?.animatePopoverCollapse()
        
        // Hide folders immediately without internal animation
        foldersScrollView.isHidden = true
        foldersScrollView.alphaValue = 0.0
        
        // Set height constraints immediately
        viewHeightConstraint.constant = 216
        scrollViewHeightConstraint.constant = 150
        foldersHeightConstraint.constant = 0
        
        NSLog("🛑 Drag session ended - view height: \(self.viewHeightConstraint.constant)")
    }
    
    private func updateCurrentFiles() {
        NSLog("🎯 DATA DEBUG: updateCurrentFiles called - currentViewMode: \(currentViewMode)")
        
        guard let collectionView = collectionView else {
            NSLog("❌ DATA DEBUG: Collection view is nil")
            return
        }
        
        switch currentViewMode {
        case .recent:
            currentFiles = Array(fileManager.recentFiles.prefix(10))
            NSLog("🎯 DATA DEBUG: Recent mode - showing \(currentFiles.count) files")
        case .all:
            currentFiles = Array(fileManager.downloadFiles.prefix(30))
            NSLog("🎯 DATA DEBUG: All mode - showing \(currentFiles.count) files")
        }
        
        NSLog("🎯 DATA DEBUG: About to reload collection view with \(currentFiles.count) files")
        collectionView.reloadData()
        
        // Force layout update after reload
        DispatchQueue.main.async {
            collectionView.needsLayout = true
            collectionView.layoutSubtreeIfNeeded()
            NSLog("🎯 DATA DEBUG: Collection view reloaded - item count: \(collectionView.numberOfItems(inSection: 0))")
            NSLog("🎯 DATA DEBUG: Collection view frame after reload: \(collectionView.frame)")
        }
    }
    
    private func loadRecentFolders() {
        NSLog("🎯 FOLDER DEBUG: loadRecentFolders called")
        
        // Use only the two most reliable methods for folder discovery
        recentFolders = []
        
        // Method 1: System Standard Directories (most reliable)
        let systemFolders = getSystemStandardFolders()
        recentFolders.append(contentsOf: systemFolders)
        
        // Method 2: User's Custom Recent Places (from our app usage)
        let customRecentPlaces = getCustomRecentPlaces()
        recentFolders.append(contentsOf: customRecentPlaces)
        
        // Remove duplicates and limit to 6 items
        let uniquePaths = Array(Set(recentFolders.map { $0.url.path }))
        let uniqueFolders = uniquePaths.prefix(6).compactMap { path in
            recentFolders.first { $0.url.path == path }
        }
        
        recentFolders = Array(uniqueFolders)
        
        NSLog("🎯 FOLDER DEBUG: Loaded \(recentFolders.count) folders using methods 1 & 2: \(recentFolders.map { $0.name })")
        
        // Reload the folders collection view
        DispatchQueue.main.async {
            self.foldersCollectionView.reloadData()
            NSLog("🎯 FOLDER DEBUG: Folders collection view reloaded with \(self.recentFolders.count) folders")
            NSLog("🎯 FOLDER DEBUG: Folders collection view frame: \(self.foldersCollectionView.frame)")
            NSLog("🎯 FOLDER DEBUG: Folders collection view item count: \(self.foldersCollectionView.numberOfItems(inSection: 0))")
        }
    }
    
    // MARK: - Clever Folder Discovery Methods
    
    private func getSystemStandardFolders() -> [FolderItem] {
        var folders: [FolderItem] = []
        
        // Standard system directories
        let standardDirectories: [(FileManager.SearchPathDirectory, String, FileManager.SearchPathDomainMask)] = [
            (.desktopDirectory, "Desktop", .userDomainMask),
            (.documentDirectory, "Documents", .userDomainMask),
            (.picturesDirectory, "Pictures", .userDomainMask),
            (.moviesDirectory, "Movies", .userDomainMask),
            (.musicDirectory, "Music", .userDomainMask),
            (.applicationDirectory, "Applications", .localDomainMask),
            (.downloadsDirectory, "Downloads", .userDomainMask),
            (.sharedPublicDirectory, "Public", .userDomainMask),
            (.libraryDirectory, "Library", .userDomainMask)
        ]
        
        for (directory, name, domain) in standardDirectories {
            if let url = FileManager.default.urls(for: directory, in: domain).first,
               FileManager.default.fileExists(atPath: url.path) {
                folders.append(FolderItem(
                    name: name,
                    url: url,
                    icon: NSWorkspace.shared.icon(forFile: url.path)
                ))
            }
        }
        
        NSLog("🎯 FOLDER DEBUG: Found \(folders.count) system standard folders")
        return folders
    }
    
    private func getCustomRecentPlaces() -> [FolderItem] {
        var folders: [FolderItem] = []
        
        // Get our app's custom recent places
        let recentPlaces = UserDefaults.standard.stringArray(forKey: "DonLoadRecentPlaces") ?? []
        
        for place in recentPlaces.prefix(3) { // Limit to 3 custom places
            if let url = URL(string: place),
               FileManager.default.fileExists(atPath: url.path) {
                let folderName = url.lastPathComponent.isEmpty ? url.pathComponents.dropLast().last ?? "Custom" : url.lastPathComponent
                
                folders.append(FolderItem(
                    name: folderName,
                    url: url,
                    icon: NSWorkspace.shared.icon(forFile: url.path)
                ))
            }
        }
        
        NSLog("🎯 FOLDER DEBUG: Found \(folders.count) custom recent places")
        return folders
    }
    
    // MARK: - Recent Places Management
    
    private func addToRecentPlaces(_ folderURL: URL) {
        var recentPlaces = UserDefaults.standard.stringArray(forKey: "DonLoadRecentPlaces") ?? []
        
        // Remove if already exists
        recentPlaces.removeAll { $0 == folderURL.absoluteString }
        
        // Add to beginning
        recentPlaces.insert(folderURL.absoluteString, at: 0)
        
        // Keep only the last 10 places
        if recentPlaces.count > 10 {
            recentPlaces = Array(recentPlaces.prefix(10))
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(recentPlaces, forKey: "DonLoadRecentPlaces")
        
        NSLog("🎯 FOLDER DEBUG: Added \(folderURL.lastPathComponent) to recent places")
    }
}

// MARK: - Collection View Data Source

extension DownloadsViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == foldersCollectionView {
            return recentFolders.count
        } else {
            // Add 1 for the "Open Downloads Folder" cell if there are files
            return currentFiles.isEmpty ? 1 : currentFiles.count + 1
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        if collectionView == foldersCollectionView {
            // Folders collection view
            let item = collectionView.makeItem(withIdentifier: FolderDestinationCollectionViewItem.identifier, for: indexPath) as! FolderDestinationCollectionViewItem
            let folder = recentFolders[indexPath.item]
            item.configure(with: folder, draggedFile: draggedFile, delegate: self)
            return item
        } else {
            // Main files collection view
            // Check if this is the last item (Open Downloads Folder)
            if indexPath.item == currentFiles.count {
                let item = collectionView.makeItem(withIdentifier: FolderCollectionViewItem.identifier, for: indexPath) as! FolderCollectionViewItem
                item.configure()
                return item
            }
            
            // Regular file item
            let item = collectionView.makeItem(withIdentifier: FileCollectionViewItem.identifier, for: indexPath) as! FileCollectionViewItem
            
            // Set parent reference for drag operations
            item.downloadsViewController = self
            
            if currentFiles.isEmpty {
                item.configureForEmptyState(mode: currentViewMode)
            } else {
                let downloadFile = currentFiles[indexPath.item]
                item.configure(with: downloadFile)
            }
            
            return item
        }
    }
}

// MARK: - Collection View Delegate

extension DownloadsViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if collectionView == foldersCollectionView {
            // Handle folder selection during drag operation
            if let indexPath = indexPaths.first, let draggedFile = draggedFile {
                let selectedFolder = recentFolders[indexPath.item]
                
                // Move the file
                let success = DownloadsFileManager.shared.moveFile(draggedFile, to: selectedFolder.url)
                if success {
                    NSLog("✅ File successfully moved to \(selectedFolder.name)")
                    addToRecentPlaces(selectedFolder.url) // Add to recent places
                } else {
                    NSLog("❌ Failed to move file to \(selectedFolder.name)")
                }
                
                // End drag session
                endDragSession()
            }
        } else {
            // Main files collection view
            if let indexPath = indexPaths.first, indexPath.item == currentFiles.count {
                // "Open Downloads Folder" cell was clicked
                NSWorkspace.shared.open(DownloadsFileManager.shared.downloadsURL)
            }
        }
    }
}


