//
//  MinimalApp.swift  
//  DonLoad - MINIMAL VERSION
//

import Cocoa
import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Constants

private let folderItemWidth: CGFloat = 150


class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var window: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "DonLoad")
        statusItem?.button?.action = #selector(toggleWindow)
        statusItem?.button?.target = self
        
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let width = visible.width * 0.5
            let height: CGFloat = 340 // match your SwiftUI ContentView frame!
            let x = visible.origin.x + (visible.width - width) / 2
            let verticalInset: CGFloat = 48
            let y = visible.origin.y + visible.height - height - verticalInset
            
            window = NSWindow(
                contentRect: NSRect(x: x, y: y, width: width, height: height),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            let contentView = ContentView()
            window?.contentViewController = NSHostingController(rootView: contentView)
            window?.backgroundColor = NSColor.clear
            window?.isOpaque = false
            window?.level = .popUpMenu
            window?.hasShadow = true
        }
    }
    
    @objc func toggleWindow() {
        guard let window = window else { return }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
        }
    }
}

@main
struct MinimalDonLoadApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}





// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var manager = DownloadFileManager.shared
    @StateObject private var folderManager = FolderManager.shared
    @State private var showPanel = false
    
    private let collapsedSuggestRowHeight: CGFloat = 56
    private let expandedSuggestRowHeight: CGFloat = 192
    
    private func updatePanelOnDragOrHover(isDraggingFile: Bool) {
        if isDraggingFile {
            if !showPanel { togglePanel() }
        } else {
            if showPanel { togglePanel() }
        }
    }

    private var windowWidth: CGFloat {
        (NSScreen.main?.frame.width ?? 800) * 0.5
    }
    
    var body: some View {
        VStack(spacing: 12) {
            filesRow
                .frame(maxWidth: .infinity)
                .if(manager.files.count == 1) { view in
                    view.frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.vertical, 8)
                .background(VisualEffectBackground())
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .zIndex(0)
            
            GeometryReader { sectionProxy in
                VStack(spacing: 0) {
                    Button(action: togglePanel) {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                            Text("Suggest location")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.accentColor)
                                .rotationEffect(.degrees(showPanel ? 180 : 0))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)

                    if showPanel {
                        foldersRow
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                    }
                }
                .background(VisualEffectBackground())
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(minHeight: collapsedSuggestRowHeight, maxHeight: showPanel ? expandedSuggestRowHeight : collapsedSuggestRowHeight, alignment: .top)
            }
            .zIndex(1)
        }
        .frame(width: windowWidth, height: 340, alignment: .top)
        .onAppear {
            manager.scan()
            folderManager.loadFolders()
        }
    }
    
    private func togglePanel() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showPanel.toggle()
        }
    }
    
    private var filesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 12) {
                ForEach(manager.files, id: \.self) { file in
                    AppKitFileItemView(file: file) {
                        updatePanelOnDragOrHover(isDraggingFile: true)
                    }
                    .frame(width: 80, height: 80)
                }
                
                if manager.files.isEmpty {
                    Text("No files")
                        .foregroundColor(.secondary)
                        .frame(height: 80)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 120)
    }
    
    private var foldersRow: some View {
        GeometryReader { geometry in
            let itemWidth: CGFloat = folderItemWidth
            let spacing: CGFloat = 12
            let availableWidth = geometry.size.width - 40 // Account for horizontal padding
            let itemsPerRow = max(1, Int(availableWidth / (itemWidth + spacing)))
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: itemsPerRow), spacing: spacing) {
                ForEach(folderManager.folders, id: \.url) { folder in
                    FolderItemView(folder: folder)
                }
            }
        }
    }
}

// MARK: - AppKit File Item View with Proper Drag Support

struct AppKitFileItemView: NSViewRepresentable {
    let file: URL
    let onDragStart: () -> Void
    
    func makeNSView(context: Context) -> FileItemNSView {
        let view = FileItemNSView(file: file, onDragStart: onDragStart)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 80).isActive = true
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        return view
    }
    
    func updateNSView(_ nsView: FileItemNSView, context: Context) {
        nsView.file = file
    }
}

class FileItemNSView: NSView, NSDraggingSource, NSFilePromiseProviderDelegate {
    var file: URL
    private let onDragStart: () -> Void
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet {
            needsDisplay = true
        }
    }
    
    init(file: URL, onDragStart: @escaping () -> Void) {
        self.file = file
        self.onDragStart = onDragStart
        super.init(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        
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
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background
        if isHovered {
            NSColor.gray.withAlphaComponent(0.2).setFill()
            let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
            path.fill()
        }
        
        // File icon
        let icon = NSWorkspace.shared.icon(forFile: file.path)
        icon.size = NSSize(width: 48, height: 48)
        let iconRect = NSRect(
            x: (bounds.width - 48) / 2,
            y: bounds.height - 48 - 8,
            width: 48,
            height: 48
        )
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
        
        // Use a simple approach that works for both internal and external drops
        let draggingItem = NSDraggingItem(pasteboardWriter: file as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: file.path)
        draggingItem.setDraggingFrame(bounds, contents: icon)
        
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    
    // MARK: - NSDraggingSource
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move // Force move operation
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Refresh the file list after any drag operation
        DispatchQueue.main.async {
            DownloadFileManager.shared.scan()
        }
    }
    
    // MARK: - NSFilePromiseProviderDelegate
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        return file.lastPathComponent
    }
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        do {
            // Copy the file to the promised location
            try FileManager.default.copyItem(at: file, to: url)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
    
    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        return OperationQueue.main
    }
}

// MARK: - Folder Item View

struct FolderItemView: View {
    let folder: FolderItem
    @State private var hovered = false
    @State private var dropHovered = false
    
    var body: some View {
        AppKitFolderDropView(folder: folder, isDropHovered: $dropHovered)
            .onHover { hovered = $0 }
    }
}

struct AppKitFolderDropView: NSViewRepresentable {
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
        view.widthAnchor.constraint(equalToConstant: folderItemWidth).isActive = true
        view.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return view
    }
    
    func updateNSView(_ nsView: FolderDropNSView, context: Context) {
        nsView.folder = folder
    }
}

class FolderDropNSView: NSView {
    var folder: FolderItem
    var onDropHoverChanged: ((Bool) -> Void)?
    private var isHovered = false {
        didSet {
            needsDisplay = true
        }
    }
    private var trackingArea: NSTrackingArea?
    
    init(folder: FolderItem) {
        self.folder = folder
        super.init(frame: NSRect(x: 0, y: 0, width: Int(folderItemWidth), height: 50))
        
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
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background
        let bgColor = isHovered ? NSColor.controlAccentColor.withAlphaComponent(0.2) : NSColor.controlBackgroundColor.withAlphaComponent(0.05)
        bgColor.setFill()
        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        path.fill()
        
        // Border
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        
        // Folder icon
        let icon = folder.icon
        icon.size = NSSize(width: 20, height: 20)
        let iconRect = NSRect(x: 8, y: (bounds.height - 20) / 2, width: 20, height: 20)
        icon.draw(in: iconRect)
        
        // Folder name
        let font = NSFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        
        let textRect = NSRect(x: 36, y: (bounds.height - 16) / 2, width: bounds.width - 44, height: 16)
        folder.name.draw(in: textRect, withAttributes: attributes)
    }
    
    // MARK: - NSDraggingDestination
    
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
        // Try different ways to get the file URL
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let sourceURL = urls.first {
            return performMove(from: sourceURL)
        }
        
        if let urlString = sender.draggingPasteboard.propertyList(forType: .fileURL) as? String,
           let sourceURL = URL(string: urlString) {
            return performMove(from: sourceURL)
        }
        
        if let urlString = sender.draggingPasteboard.string(forType: .fileURL),
           let sourceURL = URL(string: urlString) {
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

// MARK: - Data Models

struct FolderItem {
    let name: String
    let url: URL
    let icon: NSImage
}

class FolderManager: ObservableObject {
    static let shared = FolderManager()
    @Published var folders: [FolderItem] = []
    
    private var folderIcon: NSImage {
        NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericFolderIcon)))
    }
    
    func loadFolders() {
        folders = [
            FolderItem(name: "Desktop", url: Foundation.FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!, icon: folderIcon),
            FolderItem(name: "Documents", url: Foundation.FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!, icon: folderIcon),
            FolderItem(name: "Pictures", url: Foundation.FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!, icon: folderIcon),
            FolderItem(name: "Movies", url: Foundation.FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!, icon: folderIcon),
            FolderItem(name: "Music", url: Foundation.FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!, icon: folderIcon),
            FolderItem(name: "Applications", url: URL(fileURLWithPath: "/Applications"), icon: folderIcon)
        ]
    }
}

class DownloadFileManager: ObservableObject {
    static let shared = DownloadFileManager()
    @Published var files: [URL] = []
    
    private let downloadsURL = Foundation.FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    
    private var directoryMonitor: DispatchSourceFileSystemObject?
    
    init() {
        let fileDescriptor = open(downloadsURL.path, O_EVTONLY)
        if fileDescriptor >= 0 {
            directoryMonitor = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: DispatchQueue.global())
            directoryMonitor?.setEventHandler { [weak self] in
                DispatchQueue.main.async { self?.scan() }
            }
            directoryMonitor?.setCancelHandler { close(fileDescriptor) }
            directoryMonitor?.resume()
        }
    }
    
    deinit {
        directoryMonitor?.cancel()
    }
    
    func scan() {
        do {
            files = try Foundation.FileManager.default.contentsOfDirectory(
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
            .prefix(30)
            .map { $0 }
        } catch {
            files = []
        }
    }
}

// MARK: - Visual Effect Background

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

// MARK: - View Extension for Conditional Modifier

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

