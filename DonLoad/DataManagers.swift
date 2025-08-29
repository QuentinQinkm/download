//
//  DataManagers.swift
//  DonLoad - Consolidated Data Management
//

import Foundation
import Cocoa
import Combine

// MARK: - Data Models

struct FolderItem {
    let name: String
    let url: URL
    let icon: NSImage
}


// MARK: - Download File Manager

class DownloadFileManager: ObservableObject {
    static let shared = DownloadFileManager()
    
    @Published var files: [URL] = []
    
    private let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    private var directoryMonitor: DispatchSourceFileSystemObject?
    private let maxFilesToShow = 30
    
    private init() {
        setupDirectoryMonitoring()
    }
    
    deinit {
        directoryMonitor?.cancel()
    }
    
    private func setupDirectoryMonitoring() {
        let fileDescriptor = open(downloadsURL.path, O_EVTONLY)
        if fileDescriptor >= 0 {
            directoryMonitor = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: .write,
                queue: DispatchQueue.global()
            )
            directoryMonitor?.setEventHandler { [weak self] in
                DispatchQueue.main.async { self?.scan() }
            }
            directoryMonitor?.setCancelHandler { close(fileDescriptor) }
            directoryMonitor?.resume()
        }
    }
    
    func scan() {
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            .filter { !$0.hasDirectoryPath }
            .sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            .prefix(maxFilesToShow)
            .map { $0 }
        } catch {
            files = []
        }
    }
}

// MARK: - Folder Manager

class FolderManager: ObservableObject {
    static let shared = FolderManager()
    
    @Published var folders: [FolderItem] = []
    
    private var folderIcon: NSImage {
        NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
    }
    
    private init() {}
    
    func loadFolders() {
        folders = [
            FolderItem(
                name: "Desktop",
                url: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!,
                icon: folderIcon
            ),
            FolderItem(
                name: "Documents",
                url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
                icon: folderIcon
            ),
            FolderItem(
                name: "Pictures",
                url: FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!,
                icon: folderIcon
            ),
            FolderItem(
                name: "Movies",
                url: FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!,
                icon: folderIcon
            ),
            FolderItem(
                name: "Music",
                url: FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!,
                icon: folderIcon
            ),
            FolderItem(
                name: "Applications",
                url: URL(fileURLWithPath: "/Applications"),
                icon: folderIcon
            )
        ]
    }
    
    func addCustomFolder(name: String, url: URL) {
        let newFolder = FolderItem(name: name, url: url, icon: folderIcon)
        folders.append(newFolder)
    }
    
    func removeFolder(at index: Int) {
        guard index >= 6 else { return } // Don't allow removing system folders
        folders.remove(at: index)
    }
}


// MARK: - Category Manager (Extensible for new categories)

class CategoryManager: ObservableObject {
    static let shared = CategoryManager()
    
    enum CategoryType: String, CaseIterable {
        case folders = "Folders"
        case recentApps = "Recent Apps"
        case bookmarks = "Bookmarks"
        case cloudServices = "Cloud Services"
        
        var icon: String {
            switch self {
            case .folders: return "folder"
            case .recentApps: return "clock.arrow.circlepath"
            case .bookmarks: return "bookmark"
            case .cloudServices: return "icloud"
            }
        }
    }
    
    @Published var availableCategories: [CategoryType] = [.folders]
    @Published var enabledCategories: Set<CategoryType> = [.folders]
    
    private init() {}
    
    func toggleCategory(_ category: CategoryType) {
        if enabledCategories.contains(category) {
            enabledCategories.remove(category)
        } else {
            enabledCategories.insert(category)
        }
    }
    
    func addCategory(_ category: CategoryType) {
        if !availableCategories.contains(category) {
            availableCategories.append(category)
        }
        enabledCategories.insert(category)
    }
}

// MARK: - App Preferences Manager

class AppPreferencesManager: ObservableObject {
    static let shared = AppPreferencesManager()
    
    @Published var autoLaunch: Bool {
        didSet {
            UserDefaults.standard.set(autoLaunch, forKey: "autoLaunch")
        }
    }
    
    @Published var maxFilesToShow: Int {
        didSet {
            UserDefaults.standard.set(maxFilesToShow, forKey: "maxFilesToShow")
        }
    }
    
    @Published var showHiddenFiles: Bool {
        didSet {
            UserDefaults.standard.set(showHiddenFiles, forKey: "showHiddenFiles")
        }
    }
    
    private init() {
        self.autoLaunch = UserDefaults.standard.bool(forKey: "autoLaunch")
        self.maxFilesToShow = UserDefaults.standard.integer(forKey: "maxFilesToShow") == 0 ? 30 : UserDefaults.standard.integer(forKey: "maxFilesToShow")
        self.showHiddenFiles = UserDefaults.standard.bool(forKey: "showHiddenFiles")
    }
}