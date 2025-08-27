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

// Removed view mode switching - always show all downloads

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
    private var viewHeightConstraint: NSLayoutConstraint?
    
    // Individual height constraints for dynamic updates
    private var scrollViewHeightConstraint: NSLayoutConstraint?
    
    // Always show all downloads
    private var fileManager = DownloadsFileManager.shared
    private var currentFiles: [DownloadFile] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Drag and drop state
    private var isDragging = false
    private var draggedFile: DownloadFile?
    private var isAnimating = false
    // Folders moved to separate window - removed local folder UI
    
    // Reference to StatusBarManager for popup animations
    weak var statusBarManager: StatusBarManager?
    
    // Folders now handled by separate FolderWindowViewController
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        
        // Remove solid background - let the window's glass effect show through
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        
        setupUI()
        setupConstraints()
        
        // Set initial height constraint (width will be set by parent window)
        viewHeightConstraint = view.heightAnchor.constraint(equalToConstant: 216)
        viewHeightConstraint?.isActive = true
        
        // Set initial individual heights (constraints will be set in setupConstraints)
        // Note: These constraints are now optional and will be set later
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Apply round corners to main window
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        
        setupBindings()
        
        // Force layout to ensure everything is properly sized
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Only update layout if we're not in the middle of an animation or drag
        if !isDragging && !isAnimating {
            updateCollectionViewLayout()
        }
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
                // Always update since we only show all downloads
                self?.updateCurrentFiles()
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
        
        titleLabel = NSTextField(labelWithString: "Downloads")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Removed action button since we always show all downloads
        
        // Add subviews with proper layering
        topBarView.addSubview(topBarBlur)
        topBarView.addSubview(titleLabel)
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
        
        // Folders now in separate window - removed local folder setup
        
    }
    
    // Removed setupFoldersCollectionView and createFoldersLayout - folders moved to separate window
    
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
        
        // Folders now handled by separate window
    }
    
    private func setupConstraints() {
        
        // Remove all existing constraints to prevent conflicts
        view.removeConstraints(view.constraints)
        topBarView.removeConstraints(topBarView.constraints)
        scrollView.removeConstraints(scrollView.constraints)
        
        
        // Activate basic constraints
        NSLayoutConstraint.activate([
            // Top bar constraints
            topBarView.topAnchor.constraint(equalTo: view.topAnchor),
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 50),
            titleLabel.centerXAnchor.constraint(equalTo: topBarView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            
            // Scroll view constraints - let it fill available space
            scrollView.topAnchor.constraint(equalTo: topBarView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Scroll view fills bottom space (folders moved to separate window)
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        
        // Height constraint for scroll view only (folders moved to separate window)
        scrollViewHeightConstraint = scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150)
        scrollViewHeightConstraint?.isActive = true
        
        
        // Force layout update
        view.needsUpdateConstraints = true
        view.updateConstraints()
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        
    }
    
    // MARK: - Public Methods
    
    // Removed setViewMode - always show all downloads
    
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
        // Always show "Downloads" title
        guard titleLabel != nil else { return }
        titleLabel.stringValue = "Downloads"
    }
    

    

    
    func refreshData() {
        updateCurrentFiles()
    }
    
    // MARK: - Drag Session Management
    
    func startDragSession(for file: DownloadFile) {
        NSLog("🚀 Starting drag session for file: \(file.name)")
        
        isDragging = true
        isAnimating = true
        draggedFile = file
        
        // Show folder window for drag targets
        statusBarManager?.showFolderWindow(for: file)
        
        // Stop animation flag after folder window animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnimating = false
        }
    }
    
    func endDragSession() {
        NSLog("🛑 Ending drag session")
        isDragging = false
        isAnimating = true
        draggedFile = nil
        
        // Hide folder window
        statusBarManager?.hideFolderWindow()
        
        // Stop animation flag after folder window animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isAnimating = false
        }
    }
    
    private func updateCurrentFiles() {
        
        guard let collectionView = collectionView else {
            NSLog("❌ DATA DEBUG: Collection view is nil")
            return
        }
        
        // Skip updates during animation to prevent repositioning
        if isAnimating {
            return
        }
        
        // Always show all downloads (up to 30 files)
        currentFiles = Array(fileManager.downloadFiles.prefix(30))
        
        collectionView.reloadData()
        
        // Force layout update after reload only if not animating
        if !isAnimating {
            DispatchQueue.main.async {
                if !self.isAnimating {
                    collectionView.needsLayout = true
                    collectionView.layoutSubtreeIfNeeded()
                }
            }
        }
    }
    
    // Removed all folder methods - now handled by separate FolderWindowViewController
}

// MARK: - Collection View Data Source

extension DownloadsViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        // Only handle main files collection view (folders moved to separate window)
        return currentFiles.isEmpty ? 1 : currentFiles.count + 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        // Only handle main files collection view (folders moved to separate window)
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
            item.configureForEmptyState()
        } else {
            let downloadFile = currentFiles[indexPath.item]
            item.configure(with: downloadFile)
        }
        
        return item
    }
}

// MARK: - Collection View Delegate

extension DownloadsViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // Only handle main files collection view (folders moved to separate window)
        if let indexPath = indexPaths.first, indexPath.item == currentFiles.count {
            // "Open Downloads Folder" cell was clicked
            NSWorkspace.shared.open(DownloadsFileManager.shared.downloadsURL)
        }
    }
}


