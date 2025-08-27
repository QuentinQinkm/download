//
//  Extensions.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Foundation
import Cocoa

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

// MARK: - NSView Extensions

extension NSView {
    
    func createStyledContainer(cornerRadius: CGFloat) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }
    
    func addShadow(color: NSColor = NSColor.black.withAlphaComponent(0.08),
                   offset: NSSize = NSSize(width: 0, height: 2),
                   radius: CGFloat = 6,
                   opacity: Float = 0.4) {
        self.layer?.shadowColor = color.cgColor
        self.layer?.shadowOffset = offset
        self.layer?.shadowRadius = radius
        self.layer?.shadowOpacity = opacity
    }
}

// MARK: - Custom Window for Immediate Focus

class FocusableWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.acceptsMouseMovedEvents = true
    }
}
