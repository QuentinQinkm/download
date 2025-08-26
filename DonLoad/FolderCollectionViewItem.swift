//
//  FolderCollectionViewItem.swift
//  DonLoad
//
//  Created by Kuangming Qin on 8/26/25.
//

import Cocoa

class FolderCollectionViewItem: NSCollectionViewItem {
    
    static let identifier = NSUserInterfaceItemIdentifier("FolderCollectionViewItem")
    
    // MARK: - UI Elements
    
    private var containerView: NSView!
    private var iconImageView: NSImageView!
    private var titleLabel: NSTextField!
    
    // MARK: - Lifecycle
    
    override func loadView() {
        view = NSView()
        setupUI()
        setupConstraints()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Container view with rounded corners
        containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        containerView.layer?.borderWidth = 2
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon image view
        iconImageView = NSImageView()
        iconImageView.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Downloads Folder")
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title label
        titleLabel = NSTextField(labelWithString: "Open Downloads")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        view.addSubview(containerView)
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(openDownloadsFolder))
        view.addGestureRecognizer(clickGesture)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
            
            // Icon image view
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Configuration
    
    func configure() {
        // Already configured in setupUI
    }
    
    // MARK: - Actions
    
    @objc private func openDownloadsFolder() {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        NSWorkspace.shared.open(downloadsURL)
    }
}
