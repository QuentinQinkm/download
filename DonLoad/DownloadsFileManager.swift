//
//  DownloadsFileManager.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Foundation
import Combine
import AppKit

class DownloadsFileManager: ObservableObject {
    
    static let shared = DownloadsFileManager()
    
    // MARK: - Properties
    
    let downloadsURL: URL
    private var eventStream: FSEventStreamRef?
    private var debounceTimer: Timer?
    
    @Published var downloadFiles: [DownloadFile] = []
    @Published var recentFiles: [DownloadFile] = []
    
    // MARK: - Constants
    
    private let debounceInterval: TimeInterval = 0.5
    private let recentWindowMinutes: TimeInterval = 5 * 60 // 5 minutes
    private let temporaryFileExtensions = [".download", ".crdownload", ".part", ".tmp"]
    private let systemHiddenFiles = [".DS_Store", ".localized", ".com.apple.Foundation.NSItemProvider"]
    
    // MARK: - Initialization
    
    private init() {
        // Get the user's actual Downloads directory
        if let userDownloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            downloadsURL = userDownloadsURL
        } else {
            // Fallback to manual path construction
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            downloadsURL = homeURL.appendingPathComponent("Downloads")
        }
        
        NSLog("🏗️ DownloadsFileManager initialized with path: \(downloadsURL.path)")
        
        // Verify the directory exists and is accessible
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: downloadsURL.path, isDirectory: &isDirectory)
        NSLog("📁 Downloads directory exists: \(exists), isDirectory: \(isDirectory.boolValue)")
        
        // Request access to Downloads folder
        requestDownloadsAccess()
        
        // Initial scan
        performInitialScan()
        
        // Start periodic updates for recent files
        startPeriodicUpdates()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - File System Monitoring
    
    func startMonitoring() {
        guard eventStream == nil else { return }
        
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let info = clientCallBackInfo else { return }
            let manager = Unmanaged<DownloadsFileManager>.fromOpaque(info).takeUnretainedValue()
            manager.handleFileSystemEvents(numEvents: numEvents, eventPaths: eventPaths, eventFlags: eventFlags)
        }
        
        let pathsToWatch = [downloadsURL.path] as CFArray
        
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // latency
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )
        
        guard let stream = eventStream else {
            print("Failed to create FSEventStream")
            return
        }
        
        // Use modern DispatchQueue API instead of deprecated RunLoop methods (macOS 13.0+)
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .background))
        
        if !FSEventStreamStart(stream) {
            print("Failed to start FSEventStream")
            FSEventStreamRelease(stream)
            eventStream = nil
        } else {
            print("Started monitoring Downloads folder: \(downloadsURL.path)")
        }
    }
    
    func stopMonitoring() {
        guard let stream = eventStream else { return }
        
        FSEventStreamStop(stream)
        // No need to unschedule when using DispatchQueue - just stop and release
        FSEventStreamSetDispatchQueue(stream, nil) // Clear the dispatch queue
        FSEventStreamRelease(stream)
        eventStream = nil
        
        print("Stopped monitoring Downloads folder")
    }
    
    // MARK: - Event Handling
    
    private func handleFileSystemEvents(numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<FSEventStreamEventFlags>) {
        let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
        
        // Debounce multiple rapid events
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { _ in
            self.processFileSystemEvents(paths: paths, flags: eventFlags, count: numEvents)
        }
    }
    
    private func processFileSystemEvents(paths: [String], flags: UnsafePointer<FSEventStreamEventFlags>, count: Int) {
        var hasChanges = false
        
        for i in 0..<count {
            let path = paths[i]
            let flag = flags[i]
            let url = URL(fileURLWithPath: path)
            
            // Skip temporary files
            if isTemporaryFile(url) {
                continue
            }
            
            // Skip files outside Downloads folder
            guard url.path.hasPrefix(downloadsURL.path) else { continue }
            
            // Skip directories
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                continue
            }
            
            if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
                // File created
                addFile(at: url)
                hasChanges = true
            } else if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
                // File removed
                removeFile(at: url)
                hasChanges = true
            } else if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0 {
                // File modified
                updateFile(at: url)
                hasChanges = true
            }
        }
        
        if hasChanges {
            DispatchQueue.main.async {
                self.updateRecentFiles()
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - File Management
    
    private func addFile(at url: URL) {
        // Check if file already exists
        if downloadFiles.contains(where: { $0.url == url }) {
            return
        }
        
        let downloadFile = DownloadFile(url: url)
        downloadFiles.append(downloadFile)
        
        // Post notification for new download
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .newDownloadDetected, object: downloadFile)
        }
        
    }
    
    private func removeFile(at url: URL) {
        downloadFiles.removeAll { $0.url == url }
    }
    
    private func updateFile(at url: URL) {
        if let index = downloadFiles.firstIndex(where: { $0.url == url }) {
            // Update last opened time if the file was accessed
            downloadFiles[index].updateLastOpened()
        }
    }
    
    // MARK: - Public Methods
    
    func getRecentFiles() -> [DownloadFile] {
        return recentFiles
    }
    
    func getAllFiles() -> [DownloadFile] {
        let files = Array(downloadFiles.prefix(30)) // Max 30 items
        NSLog("📂 getAllFiles() returning \(files.count) files from \(downloadFiles.count) total")
        return files
    }
    
    // MARK: - Sorting Options
    
    func getFilesSortedByDownloadDate(limit: Int = 30) -> [DownloadFile] {
        let files = Array(downloadFiles.prefix(limit))
        NSLog("📂 getFilesSortedByDownloadDate() returning \(files.count) files sorted by download date")
        return files
    }
    
    func getFilesSortedByName(limit: Int = 30) -> [DownloadFile] {
        let files = Array(downloadFiles.prefix(limit))
        let sortedFiles = files.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        NSLog("📂 getFilesSortedByName() returning \(sortedFiles.count) files sorted alphabetically")
        return sortedFiles
    }
    
    func getFilesSortedBySize(limit: Int = 30, largestFirst: Bool = true) -> [DownloadFile] {
        let files = Array(downloadFiles.prefix(limit))
        let sortedFiles = files.sorted { largestFirst ? $0.size > $1.size : $0.size < $1.size }
        NSLog("📂 getFilesSortedBySize() returning \(sortedFiles.count) files sorted by size (\(largestFirst ? "largest" : "smallest") first)")
        return sortedFiles
    }
    
    func getFilesSortedByLastOpened(limit: Int = 30) -> [DownloadFile] {
        let files = Array(downloadFiles.prefix(limit))
        let sortedFiles = files.sorted { 
            ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt)
        }
        NSLog("📂 getFilesSortedByLastOpened() returning \(sortedFiles.count) files sorted by last opened date")
        return sortedFiles
    }
    
    func refreshFiles() {
        performInitialScan()
    }
    
    // MARK: - File Operations
    
    func deleteFile(_ downloadFile: DownloadFile) -> Bool {
        do {
            try FileManager.default.trashItem(at: downloadFile.url, resultingItemURL: nil)
            
            // Remove from our arrays
            downloadFiles.removeAll { $0.id == downloadFile.id }
            recentFiles.removeAll { $0.id == downloadFile.id }
            
            NSLog("🗑️ Successfully moved file to trash: \(downloadFile.name)")
            return true
        } catch {
            NSLog("❌ Failed to delete file \(downloadFile.name): \(error)")
            return false
        }
    }
    
    func revealInFinder(_ downloadFile: DownloadFile) {
        NSWorkspace.shared.selectFile(downloadFile.url.path, inFileViewerRootedAtPath: downloadsURL.path)
        NSLog("👁️ Revealed file in Finder: \(downloadFile.name)")
    }
    
    func openWithQuickLook(_ downloadFile: DownloadFile) {
        // Use NSWorkspace to open with Quick Look
        NSWorkspace.shared.open(downloadFile.url)
        NSLog("👀 Opened file with Quick Look: \(downloadFile.name)")
    }
    
    func moveFile(_ downloadFile: DownloadFile, to destinationFolder: URL) -> Bool {
        let destinationURL = destinationFolder.appendingPathComponent(downloadFile.url.lastPathComponent)
        
        do {
            // Check if destination already exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                // Try to create a unique name
                let uniqueURL = createUniqueURL(for: destinationURL)
                try FileManager.default.moveItem(at: downloadFile.url, to: uniqueURL)
                NSLog("📦 Successfully moved file to: \(uniqueURL.path) (renamed to avoid conflict)")
            } else {
                try FileManager.default.moveItem(at: downloadFile.url, to: destinationURL)
                NSLog("📦 Successfully moved file to: \(destinationURL.path)")
            }
            
            // Remove from our arrays
            downloadFiles.removeAll { $0.id == downloadFile.id }
            recentFiles.removeAll { $0.id == downloadFile.id }
            
            return true
        } catch {
            NSLog("❌ Failed to move file \(downloadFile.name): \(error)")
            return false
        }
    }
    
    func removeFileFromCache(_ downloadFile: DownloadFile) {
        NSLog("🗑️ Removing file from cache: \(downloadFile.name)")
        
        // Remove from both arrays to prevent conflicts when FSEvents eventually fires
        downloadFiles.removeAll { $0.id == downloadFile.id }
        recentFiles.removeAll { $0.id == downloadFile.id }
        
        // Immediately trigger UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        NSLog("✅ File removed from cache. Remaining files: \(downloadFiles.count)")
    }
    
    private func createUniqueURL(for url: URL) -> URL {
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        
        var counter = 1
        var uniqueURL = url
        
        while FileManager.default.fileExists(atPath: uniqueURL.path) {
            let newFilename = "\(filename) \(counter)"
            uniqueURL = directory.appendingPathComponent(newFilename).appendingPathExtension(fileExtension)
            counter += 1
        }
        
        return uniqueURL
    }
    
    // MARK: - Private Methods
    
    private func performInitialScan() {
        NSLog("🔍 Starting initial scan of Downloads folder: \(downloadsURL.path)")
        
        DispatchQueue.global(qos: .background).async {
            var files: [DownloadFile] = []
            
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: self.downloadsURL,
                    includingPropertiesForKeys: [.creationDateKey, .fileSizeKey, .contentAccessDateKey, .contentModificationDateKey],
                    options: [.skipsSubdirectoryDescendants]
                )
                
                NSLog("📁 Found \(fileURLs.count) items in Downloads folder")
                
                for url in fileURLs {
                    // Skip temporary files and directories
                    if self.isTemporaryFile(url) {
                        continue
                    }
                    
                    if self.isDirectory(url) {
                        continue
                    }
                    
                    let downloadFile = DownloadFile(url: url)
                    files.append(downloadFile)
                }
                
                // Sort by actual download date (newest downloads first) after metadata is loaded
                files.sort { file1, file2 in
                    // Use the actual file dates, not when the app loaded them
                    let date1 = file1.addedAt
                    let date2 = file2.addedAt
                    return date1 > date2
                }
                
                NSLog("📊 Total files processed: \(files.count), sorted by actual download date (newest first)")
                
            } catch {
                NSLog("❌ Error scanning Downloads folder: \(error)")
            }
            
            DispatchQueue.main.async {
                self.downloadFiles = files
                self.updateRecentFiles()
                NSLog("🔄 Updated downloadFiles array with \(files.count) files")
            }
        }
    }
    
    private func updateRecentFiles() {
        let cutoffDate = Date().addingTimeInterval(-recentWindowMinutes)
        recentFiles = downloadFiles.filter { $0.addedAt > cutoffDate }
    }
    
    private func startPeriodicUpdates() {
        // Update recent files every minute and cleanup stale files
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.cleanupStaleFiles()
            self.updateRecentFiles()
        }
    }
    
    private func cleanupStaleFiles() {
        // Remove any files from cache that no longer exist on disk
        let initialCount = downloadFiles.count
        downloadFiles.removeAll { file in
            let exists = FileManager.default.fileExists(atPath: file.url.path)
            if !exists {
                NSLog("🧹 Cleaned up stale file: \(file.name)")
            }
            return !exists
        }
        
        recentFiles.removeAll { file in
            !FileManager.default.fileExists(atPath: file.url.path)
        }
        
        if downloadFiles.count != initialCount {
            NSLog("🧹 Cleaned up \(initialCount - downloadFiles.count) stale files")
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    private func isTemporaryFile(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent.lowercased()
        
        // Check for temporary file extensions
        if temporaryFileExtensions.contains(where: { fileName.hasSuffix($0) }) {
            return true
        }
        
        // Check for system hidden files
        if systemHiddenFiles.contains(where: { fileName.hasPrefix($0.lowercased()) }) {
            return true
        }
        
        return false
    }
    
    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
    
    private func requestDownloadsAccess() {
        // Request access to Downloads folder
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = downloadsURL
        openPanel.prompt = "Grant Access"
        openPanel.message = "DonLoad needs access to your Downloads folder to monitor file changes."
        
        // For now, we'll assume access is granted
        // In a production app, you'd handle the user's response
        print("Downloads folder access requested")
    }
}
