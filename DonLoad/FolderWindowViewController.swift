//
//  FolderWindowViewController.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Cocoa

protocol FolderWindowDelegate: AnyObject {
    func folderSelected(_ folder: FolderItem, for file: DownloadFile)
}

class FolderWindowViewController: NSViewController {
    
    // MARK: - Properties
    
    private var collectionView: NSCollectionView!
    
    private var folders: [FolderItem] = []
    private var draggedFile: DownloadFile?
    
    weak var delegate: FolderWindowDelegate?
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        // Let AppKit handle the sizing - it will adapt to window size
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        
        NSLog("🔍 DEBUG: FolderWindowViewController view created")
        NSLog("🔍 DEBUG: View frame: \(view.frame), bounds: \(view.bounds)")
        setupUI()
        setupConstraints()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("🔍 DEBUG: viewDidLoad called")
        loadFolders()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        NSLog("🔧 DEBUG: Setting up UI components...")
        
        // Create collection view directly
        collectionView = NSCollectionView()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.wantsLayer = true
        collectionView.backgroundColors = [NSColor.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        
        NSLog("🔧 DEBUG: Collection view created")
        
        let layout = createSimpleLayout()
        collectionView.collectionViewLayout = layout
        
        NSLog("🔧 DEBUG: Layout set: \(type(of: layout))")
        
        // Register folder destination item
        collectionView.register(FolderDestinationCollectionViewItem.self, forItemWithIdentifier: FolderDestinationCollectionViewItem.identifier)
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        view.addSubview(collectionView)
        
        NSLog("✅ DEBUG: UI setup completed")
    }
    
    private func createSimpleLayout() -> NSCollectionViewGridLayout {
        let layout = NSCollectionViewGridLayout()
        
        // Grid configuration with your specified icon size
        layout.minimumItemSize = NSSize(width: 150, height: 50)
        layout.maximumItemSize = NSSize(width: 150, height: 50)
        
        // AppKit automatically handles spacing and responsive sizing
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.margins = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        return layout
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Collection view fills entire view
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Public Methods
    
    func configureDrag(for file: DownloadFile) {
        draggedFile = file
        collectionView.reloadData()
        
        // Calculate and update window height based on content
        updateWindowHeight()
    }
    
    private func updateWindowHeight() {
        NSLog("🔧 DEBUG: updateWindowHeight called")
        
        // Let AppKit calculate the required height automatically
        guard let layout = collectionView.collectionViewLayout else { 
            NSLog("❌ DEBUG: No collection view layout available")
            return 
        }
        
        let contentSize = layout.collectionViewContentSize
        NSLog("📐 DEBUG: Content size: \(contentSize)")
        
        let requiredHeight = contentSize.height + 40 // Add some padding
        NSLog("📐 DEBUG: Required height: \(requiredHeight)")
        
        // Update window size
        if let window = view.window {
            let currentFrame = window.frame
            NSLog("📐 DEBUG: Current window frame: \(currentFrame)")
            
            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y + (currentFrame.height - requiredHeight),
                width: currentFrame.width,
                height: requiredHeight
            )
            NSLog("📐 DEBUG: New window frame: \(newFrame)")
            
            window.setFrame(newFrame, display: true)
            NSLog("✅ DEBUG: Window frame updated")
        } else {
            NSLog("❌ DEBUG: No window available for view")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadFolders() {
        NSLog("🔧 DEBUG: Loading folders...")
        folders = []
        
        // Get standard system directories
        let systemFolders = getSystemStandardFolders()
        folders.append(contentsOf: systemFolders)
        
        // Get custom recent places
        let customRecentPlaces = getCustomRecentPlaces()
        folders.append(contentsOf: customRecentPlaces)
        
        // Remove duplicates but keep all folders
        let uniquePaths = Array(Set(folders.map { $0.url.path }))
        let uniqueFolders = uniquePaths.compactMap { path in
            folders.first { $0.url.path == path }
        }
        
        folders = Array(uniqueFolders)
        NSLog("📁 DEBUG: Loaded \(folders.count) folders")
        
        collectionView.reloadData()
        NSLog("🔄 DEBUG: Collection view data reloaded")
        
        // Update window height after loading folders
        updateWindowHeight()
    }
    
    private func getSystemStandardFolders() -> [FolderItem] {
        var folders: [FolderItem] = []
        
        let standardDirectories: [(FileManager.SearchPathDirectory, String, FileManager.SearchPathDomainMask)] = [
            (.desktopDirectory, "Desktop", .userDomainMask),
            (.documentDirectory, "Documents", .userDomainMask),
            (.picturesDirectory, "Pictures", .userDomainMask),
            (.moviesDirectory, "Movies", .userDomainMask),
            (.musicDirectory, "Music", .userDomainMask),
            (.downloadsDirectory, "Downloads", .userDomainMask)
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
        
        return folders
    }
    
    private func getCustomRecentPlaces() -> [FolderItem] {
        var folders: [FolderItem] = []
        
        let recentPlaces = UserDefaults.standard.stringArray(forKey: "DonLoadRecentPlaces") ?? []
        
        for place in recentPlaces.prefix(3) {
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
        
        return folders
    }
}

// MARK: - Collection View Data Source

extension FolderWindowViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        NSLog("🔍 DEBUG: numberOfItemsInSection called, returning \(folders.count)")
        return folders.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        NSLog("🔧 DEBUG: Creating item for index \(indexPath.item)")
        let item = collectionView.makeItem(withIdentifier: FolderDestinationCollectionViewItem.identifier, for: indexPath) as! FolderDestinationCollectionViewItem
        let folder = folders[indexPath.item]
        item.configure(with: folder, draggedFile: draggedFile, delegate: nil)
        NSLog("✅ DEBUG: Item created for folder: \(folder.name)")
        return item
    }
}

// MARK: - Collection View Delegate

extension FolderWindowViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first, let draggedFile = draggedFile else { return }
        
        let selectedFolder = folders[indexPath.item]
        
        // Notify delegate about folder selection
        delegate?.folderSelected(selectedFolder, for: draggedFile)
    }
}
