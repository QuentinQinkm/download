//
//  Extensions.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    static let newDownloadDetected = Notification.Name("newDownloadDetected")
}

// MARK: - UserDefaults Keys

extension UserDefaults {
    var retentionDays: Int {
        get {
            let value = integer(forKey: "retentionDays")
            return value > 0 ? value : 7 // Default to 7 days
        }
        set {
            set(newValue, forKey: "retentionDays")
        }
    }
    
    var autoOpenOnDownload: Bool {
        get {
            return bool(forKey: "autoOpenOnDownload")
        }
        set {
            set(newValue, forKey: "autoOpenOnDownload")
        }
    }
}
