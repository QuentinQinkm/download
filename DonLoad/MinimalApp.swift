//
//  MinimalApp.swift  
//  DonLoad - MINIMAL VERSION
//

import Cocoa
import SwiftUI
import Combine
import UniformTypeIdentifiers


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
            if !showPanel { showPanel = true }
        } else {
            if showPanel { showPanel = false }
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
                                .animation(.easeInOut(duration: 0.2), value: showPanel)
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
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .background(VisualEffectBackground())
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(minHeight: collapsedSuggestRowHeight, maxHeight: showPanel ? expandedSuggestRowHeight : collapsedSuggestRowHeight)
                .animation(.easeInOut(duration: 0.27), value: showPanel)
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
        withAnimation(.easeInOut(duration: 0.27)) {
            showPanel.toggle()
        }
    }
    
    private var filesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 12) {
                ForEach(manager.files, id: \.self) { file in
                    VStack(spacing: 4) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                            .resizable()
                            .frame(width: 48, height: 48)
                        
                        Text(file.lastPathComponent)
                            .font(.caption)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .frame(maxWidth: 80)
                    }
                    .frame(width: 80, height: 80)
                    .onDrag {
                        updatePanelOnDragOrHover(isDraggingFile: true)
                        return NSItemProvider(object: file as NSURL)
                    }
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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(folderManager.folders, id: \.url) { folder in
                FolderItemView(folder: folder)
            }
        }
    }
}


// MARK: - Folder Item View

struct FolderItemView: View {
    let folder: FolderItem
    @State private var hovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: folder.icon)
                .resizable()
                .frame(width: 20, height: 20)
            
            Text(folder.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(width: 150, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hovered ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
        .onHover { hovered = $0 }
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

