//
//  DownloadsViewController.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Cocoa
import Combine

// MARK: - Protocols

protocol DragCompletionDelegate: AnyObject {
    func didCompleteFileMove(file: DownloadFile, to destinationURL: URL)
}

// Using DragCompletionDelegate from FolderDestinationCollectionViewItem instead

struct FolderItem {
    let name: String
    let url: URL
    let icon: NSImage
}

class DownloadsViewController: NSViewController, DragCompletionDelegate {
    
    // MARK: - Properties
    
    private var stackView: NSStackView!
    private var headerView: NSView!
    private var titleLabel: NSTextField!
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    
    // Folder grid (expandable)
    private var folderContainerView: NSView!
    private var folderCollectionView: NSCollectionView!
    private var folderScrollView: NSScrollView!
    private var folderTitleLabel: NSTextField!
    
    // Constraints for animation
    private var folderInternalConstraints: [NSLayoutConstraint] = []
    private var folderScrollHeightConstraint: NSLayoutConstraint?
    
    // Compute grid height based on current folders and current window/screen width
    private func computeFolderGridHeight() -> CGFloat {
        let windowWidth: CGFloat = {
            if let w = view.window?.frame.width { return w }
            if let screenWidth = NSScreen.main?.visibleFrame.width { return screenWidth * 0.5 }
            return 800 // sensible fallback
        }()
        let itemWidth: CGFloat = 150
        let itemHeight: CGFloat = 50
        let itemSpacing: CGFloat = 12
        let margins: CGFloat = 32 // 16 left + 16 right
        let availableWidth = windowWidth - margins
        let itemsPerRow = max(1, Int(availableWidth / (itemWidth + itemSpacing)))
        let totalRows = max(1, Int(ceil(Double(folders.count) / Double(itemsPerRow))))
        let totalHeight = CGFloat(totalRows) * itemHeight + CGFloat(totalRows - 1) * itemSpacing + 24 // top/bottom margins
        return totalHeight
    }
    
    // Data
    private lazy var fileManager = DownloadsFileManager.shared
    private var currentFiles: [DownloadFile] = []
    private var folders: [FolderItem] = []
    private var cancellables = Set<AnyCancellable>()
    
    // State
    private var isDragging = false
    private var draggedFile: DownloadFile?
    private var isFolderGridExpanded = false
    
    // Reference to StatusBarManager
    weak var statusBarManager: StatusBarManager?
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        setupUI()
        setupConstraints()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        loadFolders()
        refreshData()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Create main stack view
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.detachesHiddenViews = true // Hidden views won't occupy space
        view.addSubview(stackView)
        
        setupHeader()
        setupFilesCollectionView()
        setupFolderGrid()
    }
    
    private func setupHeader() {
        headerView = NSView()
        headerView.wantsLayer = true
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel = NSTextField(labelWithString: "Downloads")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        stackView.addArrangedSubview(headerView)
        headerView.setContentHuggingPriority(.required, for: .vertical)
        headerView.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    private func setupFilesCollectionView() {
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create collection view
        collectionView = NSCollectionView()
        collectionView.backgroundColors = [NSColor.clear]
        collectionView.isSelectable = false
        collectionView.allowsMultipleSelection = false
        
        // Use flow layout
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = NSSize(width: 120, height: 140)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        collectionView.collectionViewLayout = layout
        
        // Register items
        collectionView.register(FileCollectionViewItem.self, forItemWithIdentifier: FileCollectionViewItem.identifier)
        collectionView.register(FolderCollectionViewItem.self, forItemWithIdentifier: FolderCollectionViewItem.identifier)
        
        // Set data source and delegate
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // Setup drag and drop
        collectionView.registerForDraggedTypes([.fileURL])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        
        scrollView.documentView = collectionView
        
        // Set scroll view to auto-size based on content with a maximum height
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: 172) // Keep fixed height for files section
        ])
        
        stackView.addArrangedSubview(scrollView)
        scrollView.setContentHuggingPriority(.required, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    private func setupFolderGrid() {
        // Create folder container
        folderContainerView = NSView()
        folderContainerView.wantsLayer = true
        folderContainerView.layer?.backgroundColor = NSColor.clear.cgColor
        folderContainerView.layer?.masksToBounds = true  // Clip content to bounds
        folderContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create separator line
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        folderContainerView.addSubview(separator)
        
        // Create folder title
        folderTitleLabel = NSTextField(labelWithString: "Move to Folder")
        folderTitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        folderTitleLabel.textColor = NSColor.secondaryLabelColor
        folderTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        folderContainerView.addSubview(folderTitleLabel)
        
        // Create folder scroll view
        folderScrollView = NSScrollView()
        folderScrollView.hasVerticalScroller = false
        folderScrollView.hasHorizontalScroller = false
        folderScrollView.autohidesScrollers = true
        folderScrollView.borderType = .noBorder
        folderScrollView.backgroundColor = NSColor.clear
        folderScrollView.verticalScrollElasticity = .none
        folderScrollView.horizontalScrollElasticity = .none
        folderScrollView.translatesAutoresizingMaskIntoConstraints = false
        folderContainerView.addSubview(folderScrollView)
        
        // Create folder collection view
        folderCollectionView = NSCollectionView()
        folderCollectionView.backgroundColors = [NSColor.clear]
        folderCollectionView.isSelectable = false
        folderCollectionView.allowsMultipleSelection = false
        
        // Use grid layout with dynamic sizing based on window width
        let folderLayout = NSCollectionViewGridLayout()
        folderLayout.minimumItemSize = NSSize(width: 150, height: 50)
        folderLayout.maximumItemSize = NSSize(width: 150, height: 50)
        folderLayout.minimumInteritemSpacing = 12
        folderLayout.minimumLineSpacing = 12
        folderLayout.margins = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        folderCollectionView.collectionViewLayout = folderLayout
        
        // Set up collection view to size itself properly
        folderCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Register folder item
        folderCollectionView.register(FolderDestinationCollectionViewItem.self, forItemWithIdentifier: FolderDestinationCollectionViewItem.identifier)
        
        // Set data source and delegate
        folderCollectionView.dataSource = self
        folderCollectionView.delegate = self
        
        folderScrollView.documentView = folderCollectionView
        
        // Make collection view size to its content
        folderCollectionView.setContentCompressionResistancePriority(.required, for: .vertical)
        folderCollectionView.setContentHuggingPriority(.required, for: .vertical)
        
        // Ensure folder scroll view also sizes to content  
        folderScrollView.setContentCompressionResistancePriority(.required, for: .vertical)
        folderScrollView.setContentHuggingPriority(.required, for: .vertical)
        
        
        stackView.addArrangedSubview(folderContainerView)
        folderContainerView.setContentHuggingPriority(.required, for: .vertical)
        folderContainerView.setContentCompressionResistancePriority(.required, for: .vertical)
        // Ensure content is anchored to the top of the window during extra space
        stackView.setViews(stackView.arrangedSubviews, in: .top)
        
        // Initially collapsed and hidden
        folderContainerView.isHidden = true
    }
    
    private func setupConstraints() {
        // Main layout constraints (always active)
        NSLayoutConstraint.activate([
            // Stack view fills the entire view
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Header constraints
            headerView.heightAnchor.constraint(equalToConstant: 50),
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        
        let gridHeight = computeFolderGridHeight()
        
        // Folder internal constraints (activated/deactivated during expand/collapse)
        folderInternalConstraints = [
            folderTitleLabel.topAnchor.constraint(equalTo: folderContainerView.topAnchor, constant: 8),
            folderTitleLabel.leadingAnchor.constraint(equalTo: folderContainerView.leadingAnchor, constant: 16),
            
            folderScrollView.topAnchor.constraint(equalTo: folderTitleLabel.bottomAnchor, constant: 8),
            folderScrollView.leadingAnchor.constraint(equalTo: folderContainerView.leadingAnchor),
            folderScrollView.trailingAnchor.constraint(equalTo: folderContainerView.trailingAnchor),
            folderScrollView.bottomAnchor.constraint(equalTo: folderContainerView.bottomAnchor, constant: -8),
            {
                let c = folderScrollView.heightAnchor.constraint(equalToConstant: gridHeight)
                folderScrollHeightConstraint = c
                return c
            }()
        ]
        
        // Initially deactivated since container starts collapsed
        NSLayoutConstraint.deactivate(folderInternalConstraints)
    }
    
    // MARK: - Data Management
    
    private func setupBindings() {
        fileManager.$downloadFiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCurrentFiles()
            }
            .store(in: &cancellables)
        
        fileManager.$recentFiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCurrentFiles()
            }
            .store(in: &cancellables)
    }
    
    private func updateCurrentFiles() {
        print("🔄 DEBUG: updateCurrentFiles() called")
        print("🔄 DEBUG: fileManager.downloadFiles count: \(fileManager.downloadFiles.count)")
        currentFiles = Array(fileManager.downloadFiles.prefix(20)) // Limit to 20 files
        print("🔄 DEBUG: currentFiles count after update: \(currentFiles.count)")
        collectionView.reloadData()
        print("🔄 DEBUG: Main collection view reloaded")
    }
    
    func refreshData() {
        print("🔄 DEBUG: refreshData() called")
        updateCurrentFiles()
        loadFolders()
        folderCollectionView.reloadData()
        print("🔄 DEBUG: refreshData() completed")
    }
    
    // MARK: - Folder Management
    
    private func loadFolders() {
        folders = []
        
        // Add system folders
        let systemFolders = getSystemFolders()
        folders.append(contentsOf: systemFolders)
        
        // Add recent places
        let recentFolders = getRecentPlaces()
        folders.append(contentsOf: recentFolders)
        
        // Remove duplicates
        let uniquePaths = Array(Set(folders.map { $0.url.path }))
        folders = uniquePaths.compactMap { path in
            folders.first { $0.url.path == path }
        }
        
    }
    
    private func getSystemFolders() -> [FolderItem] {
        var systemFolders: [FolderItem] = []
        
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            systemFolders.append(FolderItem(name: "Desktop", url: desktopURL, icon: NSWorkspace.shared.icon(forFile: desktopURL.path)))
        }
        
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            systemFolders.append(FolderItem(name: "Documents", url: documentsURL, icon: NSWorkspace.shared.icon(forFile: documentsURL.path)))
        }
        
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            systemFolders.append(FolderItem(name: "Downloads", url: downloadsURL, icon: NSWorkspace.shared.icon(forFile: downloadsURL.path)))
        }
        
        return systemFolders
    }
    
    private func getRecentPlaces() -> [FolderItem] {
        let recentPlaces = UserDefaults.standard.stringArray(forKey: "RecentPlaces") ?? []
        return recentPlaces.compactMap { path in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            
            let name = url.lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: path)
            return FolderItem(name: name, url: url, icon: icon)
        }
    }
    
    // MARK: - Folder Grid Animation
    
    private func expandFolderGrid() {
        guard !isFolderGridExpanded else { return }
        
        print("🔧 EXPAND: Expanding folder grid")
        isFolderGridExpanded = true
        
        // Prepare: activate constraints and compute target sizes, but do NOT show folder yet
        NSLayoutConstraint.activate(folderInternalConstraints)
        folderCollectionView.reloadData()
        folderCollectionView.collectionViewLayout?.invalidateLayout()
        folderCollectionView.layoutSubtreeIfNeeded()
        
        let targetGridHeight = max(0, (self.folderScrollHeightConstraint != nil ? computeFolderGridHeight() : 0))
        folderScrollHeightConstraint?.constant = targetGridHeight
        
        // Layout to include folder height in fitting size calculation
        // Temporarily unhide with alpha 0 to include in layout but not visible
        let wasHidden = folderContainerView.isHidden
        folderContainerView.isHidden = false
        let previousAlpha = folderContainerView.alphaValue
        folderContainerView.alphaValue = 0.0
        view.layoutSubtreeIfNeeded()
        let targetWindowHeight = view.fittingSize.height
        print("🔧 EXPAND: Calculated new height: \(targetWindowHeight)")
        
        // Restore hidden state before animating if it was hidden
        folderContainerView.isHidden = wasHidden
        folderContainerView.alphaValue = previousAlpha
        
        // Now animate the window expansion
        let newHeight = self.view.fittingSize.height
        print("🔧 EXPAND: Calculated new height: \(newHeight)")
        self.statusBarManager?.expandWindow(to: newHeight)
        
        // 2) After resize completes, show and fade-in folder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { // Assuming 0.22 is the duration of the window expansion
            self.folderContainerView.alphaValue = 0.0
            self.folderContainerView.isHidden = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.folderContainerView.animator().alphaValue = 1.0
            }
        }
        
    }
    
    private func collapseFolderGrid() {
        guard isFolderGridExpanded else { return }
        
        print("🔧 COLLAPSE: Collapsing folder grid")
        isFolderGridExpanded = false
        
        // 1) Fade out and hide folder first (no window resize yet)
        let fadeDuration: TimeInterval = 0.18
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.folderContainerView.animator().alphaValue = 0.0
        }, completionHandler: {
            // After fade completes, hide and deactivate constraints
            self.folderContainerView.isHidden = true
            NSLayoutConstraint.deactivate(self.folderInternalConstraints)
            self.folderScrollHeightConstraint?.constant = 0
            // Layout to measure collapsed height
            self.view.layoutSubtreeIfNeeded()
            let collapseHeight: CGFloat = self.view.fittingSize.height
            print("🔧 COLLAPSE: Collapsing to height: \(collapseHeight)")
            // 2) Now animate window resize ONLY
            let resizeDuration: TimeInterval = 0.22
            self.statusBarManager?.collapseWindow(to: collapseHeight)
        })
    }
    
    // MARK: - Drag Session Management
    
    func startDragSession(for file: DownloadFile) {
        print("🔧 DRAG STATE: Starting drag session for file: \(file.name)")
        isDragging = true
        draggedFile = file
        expandFolderGrid()
    }
    
    func endDragSession() {
        print("🔧 DRAG STATE: Ending drag session")
        isDragging = false
        draggedFile = nil
        collapseFolderGrid()
    }
    
    // MARK: - Delegate Methods
    
    func didCompleteFileMove(file: DownloadFile, to destinationURL: URL) {
        if let index = currentFiles.firstIndex(where: { $0.id == file.id }) {
            currentFiles.remove(at: index)
        collectionView.reloadData()
        }
    }
    

}

// MARK: - Collection View Data Source

extension DownloadsViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.collectionView {
            return currentFiles.isEmpty ? 1 : currentFiles.count + 1 // +1 for "Open Downloads Folder"
        } else if collectionView == self.folderCollectionView {
            return folders.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        if collectionView == self.collectionView {
            if indexPath.item == currentFiles.count {
                // "Open Downloads Folder" item
                let item = collectionView.makeItem(withIdentifier: FolderCollectionViewItem.identifier, for: indexPath) as! FolderCollectionViewItem
                item.configure()
                return item
            } else {
                // Regular file item
                let item = collectionView.makeItem(withIdentifier: FileCollectionViewItem.identifier, for: indexPath) as! FileCollectionViewItem
                item.downloadsViewController = self
                
                if currentFiles.isEmpty {
                    item.configureForEmptyState()
                } else {
                    let file = currentFiles[indexPath.item]
                    item.configure(with: file)
                }
                
                return item
            }
        } else if collectionView == self.folderCollectionView {
            // Folder item
            let item = collectionView.makeItem(withIdentifier: FolderDestinationCollectionViewItem.identifier, for: indexPath) as! FolderDestinationCollectionViewItem
            let folder = folders[indexPath.item]
            item.configure(with: folder, draggedFile: draggedFile, delegate: self)
            return item
        }
        
        return NSCollectionViewItem()
    }
}

// MARK: - Collection View Delegate

extension DownloadsViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if collectionView == self.collectionView {
        if let indexPath = indexPaths.first, indexPath.item == currentFiles.count {
                // "Open Downloads Folder" was clicked
            NSWorkspace.shared.open(DownloadsFileManager.shared.downloadsURL)
            }
        }
    }
}