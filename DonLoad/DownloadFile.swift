//
//  DownloadFile.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Foundation
import UniformTypeIdentifiers
import Combine

class DownloadFile: ObservableObject, Identifiable, Hashable {
    
    let id = UUID()
    
    // MARK: - Core Properties
    
    @Published var url: URL
    @Published var name: String
    @Published var size: Int64
    @Published var uti: UTType?
    @Published var addedAt: Date
    @Published var lastOpenedAt: Date?
    @Published var status: FileStatus
    
    // MARK: - Metadata Properties
    
    @Published var sourceURLs: [String] = [] // kMDItemWhereFroms
    @Published var isExcluded: Bool = false
    
    // MARK: - Computed Properties
    
    var age: String {
        let now = Date()
        let interval = now.timeIntervalSince(addedAt)
        
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            let days = Int(interval / 86400)
            if days == 1 {
                return "1d"
            } else if days < 7 {
                return "\(days)d"
            } else if days < 30 {
                let weeks = Int(days / 7)
                return "\(weeks)w"
            } else if days < 365 {
                let months = Int(days / 30)
                return "\(months)m"
            } else {
                let years = Int(days / 365)
                return "\(years)y"
            }
        }
    }
    
    var isRecent: Bool {
        let fiveMinutesAgo = Date().addingTimeInterval(-300) // 5 minutes
        return addedAt > fiveMinutesAgo
    }
    
    var effectiveLastUsedDate: Date {
        // Use kMDItemLastUsedDate if available, fallback to other dates
        return lastOpenedAt ?? addedAt
    }
    
    var shouldAutoDelete: Bool {
        guard !isExcluded else { return false }
        
        let retentionDays = UserDefaults.standard.retentionDays
        let retentionInterval = TimeInterval(retentionDays * 24 * 60 * 60)
        let cutoffDate = Date().addingTimeInterval(-retentionInterval)
        
        return effectiveLastUsedDate < cutoffDate
    }
    
    // MARK: - Initialization
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.addedAt = Date.distantPast // Temporary placeholder until metadata is loaded
        self.status = .normal
        self.size = 0
        
        // Load metadata
        loadMetadata()
    }
    
    // MARK: - Metadata Loading
    
    private func loadMetadata() {
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .contentTypeKey,
                .creationDateKey,
                .contentAccessDateKey,
                .contentModificationDateKey
            ])
            
            self.size = Int64(resourceValues.fileSize ?? 0)
            
            if let contentType = resourceValues.contentType {
                self.uti = UTType(contentType.identifier)
            }
            
            // Log all available dates for debugging
            NSLog("🔍 File '\(self.name)' - Available dates:")
            if let creationDate = resourceValues.creationDate {
                NSLog("  📅 Creation Date: \(creationDate)")
            }
            if let modificationDate = resourceValues.contentModificationDate {
                NSLog("  📅 Modification Date: \(modificationDate)")
            }
            if let accessDate = resourceValues.contentAccessDate {
                NSLog("  📅 Access Date: \(accessDate)")
            }
            
            // Determine the best date to represent when the file was downloaded
            // Priority: creation date > modification date > access date
            var selectedDate: Date?
            var dateSource = "none"
            
            if let creationDate = resourceValues.creationDate {
                // Creation date is the most reliable for when a file was downloaded
                selectedDate = creationDate
                dateSource = "creationDate"
                NSLog("✅ Using creation date: \(creationDate)")
            } else if let modificationDate = resourceValues.contentModificationDate {
                // Modification date can indicate when the file was last changed
                selectedDate = modificationDate
                dateSource = "contentModificationDate"
                NSLog("✅ Using modification date: \(modificationDate)")
            } else if let accessDate = resourceValues.contentAccessDate {
                // Access date is least reliable as it changes when files are accessed
                selectedDate = accessDate
                dateSource = "contentAccessDate"
                NSLog("⚠️ Using access date (least reliable): \(accessDate)")
            }
            
            if let selectedDate = selectedDate {
                self.addedAt = selectedDate
                NSLog("📅 File '\(self.name)' - Final date set to: \(selectedDate) (source: \(dateSource))")
            } else {
                // If no date found, use current time as fallback
                self.addedAt = Date()
                NSLog("❌ No date found, using current time: \(self.addedAt)")
            }
            
            // Use access date as lastOpenedAt if available
            self.lastOpenedAt = resourceValues.contentAccessDate
            
            // Load extended metadata
            loadExtendedMetadata()
            
        } catch {
            print("Error loading metadata for \(url.path): \(error)")
            // Fallback to current time if metadata loading fails
            self.addedAt = Date()
        }
    }
    
    private func loadExtendedMetadata() {
        guard let mdItem = MDItemCreate(kCFAllocatorDefault, url.path as CFString) else { 
            NSLog("❌ Failed to create MDItem for '\(self.name)'")
            return 
        }
        
        NSLog("🔍 Loading extended metadata for '\(self.name)'")
        
        var earliestDate = self.addedAt
        var dateSource = "initial"
        
        // Get date added (kMDItemDateAdded) - most reliable for when file was added to location
        if let dateAdded = MDItemCopyAttribute(mdItem, kMDItemDateAdded) as? Date {
            NSLog("📅 Spotlight Date Added: \(dateAdded)")
            if dateAdded < earliestDate {
                earliestDate = dateAdded
                dateSource = "Spotlight Date Added"
                NSLog("✅ Found earlier date: \(dateAdded) (was: \(self.addedAt))")
            }
        }
        
        // Get last used date (kMDItemLastUsedDate)
        if let lastUsedDate = MDItemCopyAttribute(mdItem, kMDItemLastUsedDate) as? Date {
            NSLog("📅 Spotlight Last Used: \(lastUsedDate)")
            self.lastOpenedAt = lastUsedDate
        }
        
        // Get source URLs (kMDItemWhereFroms)
        if let whereFroms = MDItemCopyAttribute(mdItem, kMDItemWhereFroms) as? [String] {
            NSLog("📥 Source URLs: \(whereFroms)")
            self.sourceURLs = whereFroms
        }
        
        // Get content creation date (kMDItemContentCreationDate)
        if let contentCreationDate = MDItemCopyAttribute(mdItem, kMDItemContentCreationDate) as? Date {
            NSLog("📅 Spotlight Content Creation: \(contentCreationDate)")
            if contentCreationDate < earliestDate {
                earliestDate = contentCreationDate
                dateSource = "Spotlight Content Creation"
                NSLog("✅ Found earlier date: \(contentCreationDate) (was: \(earliestDate))")
            }
        }
        
        // Update addedAt with the earliest date found
        if earliestDate != self.addedAt {
            NSLog("🔄 Updating addedAt from \(self.addedAt) to \(earliestDate) (source: \(dateSource))")
            self.addedAt = earliestDate
        }
        
        NSLog("📅 Final addedAt for '\(self.name)': \(self.addedAt)")
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DownloadFile, rhs: DownloadFile) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - File Operations
    
    func updateLastOpened() {
        lastOpenedAt = Date()
    }
    
    func markAsExcluded(_ excluded: Bool = true) {
        isExcluded = excluded
    }
}

// MARK: - File Status

enum FileStatus {
    case normal
    case selected
    case hovered
    case moved(to: URL)
    case deleted
    case excluded
}
