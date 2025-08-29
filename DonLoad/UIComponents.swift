//
//  UIComponents.swift
//  DonLoad - Consolidated UI Components
//

import SwiftUI
import Cocoa
import UniformTypeIdentifiers

// MARK: - Constants

struct AppConstants {
    static let folderItemWidth: CGFloat = 150
    static let fileItemSize: CGFloat = 80
    static let filesRowHeight: CGFloat = 120
    static let collapsedPanelHeight: CGFloat = 56
    static let expandedPanelHeight: CGFloat = 192
    static let panelAnimationDuration: Double = 0.25
    
    static var windowWidth: CGFloat {
        (NSScreen.main?.frame.width ?? 800) * 0.5
    }
}

// MARK: - Main Content View

struct MainContentView: View {
    @StateObject private var fileManager = DownloadFileManager.shared
    @StateObject private var folderManager = FolderManager.shared
    @State private var showPanel = false
    
    var body: some View {
        VStack(spacing: 12) {
            // First Row: Downloaded Files
            FilesRowComponent(onDragStateChanged: updatePanelOnDragOrHover)
            
            // Second Row: Quick Actions Panel
            QuickActionsPanel(
                showPanel: $showPanel,
                folders: folderManager.folders
            )
        }
        .frame(width: AppConstants.windowWidth, height: 340, alignment: .top)
        .onAppear {
            fileManager.scan()
            folderManager.loadFolders()
        }
    }
    
    private func updatePanelOnDragOrHover(isDraggingFile: Bool) {
        if isDraggingFile {
            if !showPanel { togglePanel() }
        } else {
            if showPanel { togglePanel() }
        }
    }
    
    private func togglePanel() {
        withAnimation(.easeInOut(duration: AppConstants.panelAnimationDuration)) {
            showPanel.toggle()
        }
    }
}

// MARK: - Reusable Row Components

struct FilesRowComponent: View {
    @StateObject private var manager = DownloadFileManager.shared
    let onDragStateChanged: (Bool) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 12) {
                ForEach(manager.files, id: \.self) { file in
                    DraggableFileItem(file: file) {
                        onDragStateChanged(true)
                    }
                    .frame(width: AppConstants.fileItemSize, height: AppConstants.fileItemSize)
                }
                
                if manager.files.isEmpty {
                    EmptyStateView(message: "No files")
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: AppConstants.filesRowHeight)
        .frame(maxWidth: .infinity)
        .if(manager.files.count == 1) { view in
            view.frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 8)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .zIndex(0)
    }
}

struct QuickActionsPanel: View {
    @Binding var showPanel: Bool
    let folders: [FolderItem]
    
    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                PanelHeader(
                    title: "Suggest location",
                    icon: "folder",
                    isExpanded: showPanel
                ) {
                    togglePanel()
                }
                
                if showPanel {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Folder Section
                            CategorySection(title: "Folders") {
                                AdaptiveGrid(items: folders) { folder in
                                    DroppableFolderItem(folder: folder)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                    .frame(maxHeight: AppConstants.expandedPanelHeight - AppConstants.collapsedPanelHeight)
                }
            }
            .background(VisualEffectBackground())
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(
                minHeight: AppConstants.collapsedPanelHeight,
                maxHeight: showPanel ? AppConstants.expandedPanelHeight : AppConstants.collapsedPanelHeight,
                alignment: .top
            )
        }
        .zIndex(1)
    }
    
    private func togglePanel() {
        withAnimation(.easeInOut(duration: AppConstants.panelAnimationDuration)) {
            showPanel.toggle()
        }
    }
}

// MARK: - Reusable UI Components

struct PanelHeader: View {
    let title: String
    let icon: String
    let isExpanded: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.accentColor)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct CategorySection<Content: View>: View {
    let title: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            content()
        }
    }
}

struct AdaptiveGrid<Item, ItemView: View>: View {
    let items: [Item]
    let itemView: (Item) -> ItemView
    
    var body: some View {
        GeometryReader { geometry in
            let itemWidth: CGFloat = AppConstants.folderItemWidth
            let spacing: CGFloat = 12
            let availableWidth = geometry.size.width
            let itemsPerRow = max(1, Int(availableWidth / (itemWidth + spacing)))
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: itemsPerRow),
                spacing: spacing
            ) {
                ForEach(items.indices, id: \.self) { index in
                    itemView(items[index])
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .foregroundColor(.secondary)
            .frame(height: AppConstants.fileItemSize)
    }
}

// MARK: - Item Views

struct DraggableFileItem: NSViewRepresentable {
    let file: URL
    let onDragStart: () -> Void
    
    func makeNSView(context: Context) -> FileItemNSView {
        let view = FileItemNSView(file: file, onDragStart: onDragStart)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: AppConstants.fileItemSize).isActive = true
        view.heightAnchor.constraint(equalToConstant: AppConstants.fileItemSize).isActive = true
        return view
    }
    
    func updateNSView(_ nsView: FileItemNSView, context: Context) {
        nsView.file = file
    }
}

struct DroppableFolderItem: View {
    let folder: FolderItem
    @State private var dropHovered = false
    
    var body: some View {
        FolderDropView(folder: folder, isDropHovered: $dropHovered)
    }
}


// MARK: - AppKit Integration

struct FolderDropView: NSViewRepresentable {
    let folder: FolderItem
    @Binding var isDropHovered: Bool
    
    func makeNSView(context: Context) -> FolderDropNSView {
        let view = FolderDropNSView(folder: folder)
        view.onDropHoverChanged = { hovering in
            DispatchQueue.main.async {
                self.isDropHovered = hovering
            }
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: AppConstants.folderItemWidth).isActive = true
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }
    
    func updateNSView(_ nsView: FolderDropNSView, context: Context) {
        nsView.folder = folder
    }
}

class FileItemNSView: NSView, NSDraggingSource {
    var file: URL
    private let onDragStart: () -> Void
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    
    init(file: URL, onDragStart: @escaping () -> Void) {
        self.file = file
        self.onDragStart = onDragStart
        super.init(frame: NSRect(x: 0, y: 0, width: Int(AppConstants.fileItemSize), height: Int(AppConstants.fileItemSize)))
        
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect]
        let ta = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingArea = ta
    }
    
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background
        if isHovered {
            NSColor.gray.withAlphaComponent(0.2).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        }
        
        // File icon
        let icon = NSWorkspace.shared.icon(forFile: file.path)
        icon.size = NSSize(width: 48, height: 48)
        let iconRect = NSRect(x: (bounds.width - 48) / 2, y: bounds.height - 48 - 8, width: 48, height: 48)
        icon.draw(in: iconRect)
        
        // File name
        let filename = file.lastPathComponent
        let font = NSFont.systemFont(ofSize: 11)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingMiddle
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let textRect = NSRect(x: 4, y: 4, width: bounds.width - 8, height: 20)
        filename.draw(in: textRect, withAttributes: attributes)
    }
    
    override func mouseDragged(with event: NSEvent) {
        onDragStart()
        let draggingItem = NSDraggingItem(pasteboardWriter: file as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: file.path)
        draggingItem.setDraggingFrame(bounds, contents: icon)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        DispatchQueue.main.async {
            DownloadFileManager.shared.scan()
        }
    }
}

class FolderDropNSView: NSView {
    var folder: FolderItem
    var onDropHoverChanged: ((Bool) -> Void)?
    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    private var trackingArea: NSTrackingArea?
    
    init(folder: FolderItem) {
        self.folder = folder
        super.init(frame: NSRect(x: 0, y: 0, width: Int(AppConstants.folderItemWidth), height: 50))
        
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        
        registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, NSPasteboard.PasteboardType.URL])
        setupTrackingArea()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect]
        let ta = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingArea = ta
    }
    
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let bgColor = isHovered ? NSColor.controlAccentColor.withAlphaComponent(0.2) : NSColor.controlBackgroundColor.withAlphaComponent(0.05)
        bgColor.setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        path.fill()
        
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        
        // Folder icon and name
        let icon = folder.icon
        icon.size = NSSize(width: 20, height: 20)
        let iconRect = NSRect(x: 8, y: (bounds.height - 20) / 2, width: 20, height: 20)
        icon.draw(in: iconRect)
        
        let font = NSFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        let textRect = NSRect(x: 36, y: (bounds.height - 16) / 2, width: bounds.width - 44, height: 16)
        folder.name.draw(in: textRect, withAttributes: attributes)
    }
    
    // MARK: - Drag & Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDropHoverChanged?(true)
        return .move
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDropHoverChanged?(false)
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let sourceURL = urls.first {
            return performMove(from: sourceURL)
        }
        return false
    }
    
    private func performMove(from sourceURL: URL) -> Bool {
        let destFile = folder.url.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destFile)
            DispatchQueue.main.async {
                DownloadFileManager.shared.scan()
            }
            return true
        } catch {
            return false
        }
    }
    
    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onDropHoverChanged?(false)
    }
}

// MARK: - Visual Effects

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .vibrantDark)
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - SwiftUI Extensions

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}