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
            
            // Use creation date first, then modification date as fallback
            self.addedAt = resourceValues.creationDate 
                        ?? resourceValues.contentModificationDate 
                        ?? Date()
            
            self.lastOpenedAt = resourceValues.contentAccessDate
            
            // Try to get more accurate date from Spotlight
            loadExtendedMetadata()
            
        } catch {
            print("Error loading metadata for \(url.path): \(error)")
            self.addedAt = Date()
        }
    }
    
    private func loadExtendedMetadata() {
        guard let mdItem = MDItemCreate(kCFAllocatorDefault, url.path as CFString) else { return }
        
        // Try to get more accurate dates from Spotlight
        let dateAdded = MDItemCopyAttribute(mdItem, kMDItemDateAdded) as? Date
        let contentCreationDate = MDItemCopyAttribute(mdItem, kMDItemContentCreationDate) as? Date
        
        // Use the earliest available date
        let candidates = [dateAdded, contentCreationDate, self.addedAt].compactMap { $0 }
        if let earliestDate = candidates.min() {
            self.addedAt = earliestDate
        }
        
        // Get additional metadata
        if let lastUsedDate = MDItemCopyAttribute(mdItem, kMDItemLastUsedDate) as? Date {
            self.lastOpenedAt = lastUsedDate
        }
        
        if let whereFroms = MDItemCopyAttribute(mdItem, kMDItemWhereFroms) as? [String] {
            self.sourceURLs = whereFroms
        }
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
