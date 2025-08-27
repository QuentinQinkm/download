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
            let width = screen.frame.width * 0.5
            let height: CGFloat = 120
            let x = screen.frame.width * 0.25
            let y = screen.frame.maxY - height - 50
            
            window = NSWindow(
                contentRect: NSRect(x: x, y: y, width: width, height: height),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            let contentView = ContentView(windowController: WindowController(window: window!))
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
            window.makeKeyAndOrderFront(nil)
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

// MARK: - Window Controller for animations

class WindowController: ObservableObject {
    let window: NSWindow
    @Published var isExpanded = false
    
    init(window: NSWindow) {
        self.window = window
    }
    
    func expand(to height: CGFloat) {
        let currentFrame = window.frame
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.maxY - height,
            width: currentFrame.width,
            height: height
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
        isExpanded = true
    }
    
    func collapse() {
        let currentFrame = window.frame
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.maxY - 120,
            width: currentFrame.width,
            height: 120
        )
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
        isExpanded = false
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var manager = DownloadFileManager.shared
    @StateObject private var folderManager = FolderManager.shared
    @ObservedObject var windowController: WindowController
    @State private var isDragging = false
    
    private var windowWidth: CGFloat {
        (NSScreen.main?.frame.width ?? 800) * 0.5
    }
    
    private var gridHeight: CGFloat {
        let itemWidth: CGFloat = 150
        let itemHeight: CGFloat = 40
        let spacing: CGFloat = 8
        let padding: CGFloat = 32
        
        let itemsPerRow = max(1, Int((windowWidth - padding) / (itemWidth + spacing)))
        let rows = max(1, Int(ceil(Double(folderManager.folders.count) / Double(itemsPerRow))))
        return CGFloat(rows) * itemHeight + CGFloat(rows - 1) * spacing + padding
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Files row
            filesRow
            
            // Folders row (appears during drag)
            if isDragging {
                foldersRow
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: windowWidth)
        .background(VisualEffectBackground().clipShape(RoundedRectangle(cornerRadius: 12)))
        .onAppear { 
            manager.scan()
            folderManager.loadFolders()
        }
        .onChange(of: isDragging) { dragging in
            if dragging {
                windowController.expand(to: 120 + gridHeight)
            } else {
                windowController.collapse()
            }
        }
    }
    
    private var filesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(manager.files, id: \.self) { file in
                    FileView(file: file, isDragging: $isDragging)
                }
                
                if manager.files.isEmpty {
                    Text("No files")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .frame(height: 120)
    }
    
    private var foldersRow: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(folderManager.folders, id: \.url) { folder in
                FolderItemView(folder: folder)
            }
        }
        .padding()
        .frame(height: gridHeight)
    }
    
    private var gridColumns: [GridItem] {
        let itemWidth: CGFloat = 150
        let spacing: CGFloat = 8
        let availableWidth = windowWidth - 32 // padding
        let itemsPerRow = max(1, Int(availableWidth / (itemWidth + spacing)))
        
        return Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: itemsPerRow)
    }
}

// MARK: - File View

struct FileView: View {
    let file: URL
    @Binding var isDragging: Bool
    @State private var hovered = false
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        ZStack {
            VStack(spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                    .resizable()
                    .frame(width: hovered ? 64 : 48, height: hovered ? 64 : 48)
                    .animation(.easeInOut(duration: 0.2), value: hovered)
                
                Text(file.lastPathComponent)
                    .font(.caption)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            
            if hovered {
                VStack {
                    HStack {
                        Button(action: deleteFile) {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.red).frame(width: 20, height: 20))
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(action: moveFile) {
                            Image(systemName: "folder")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.blue).frame(width: 20, height: 20))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    
                    Spacer()
                }
                .frame(width: 80, height: 80)
            }
        }
        .frame(width: 80, height: 80)
        .onHover { hovered = $0 }
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    if !isDragging && (abs(value.translation.width) > 5 || abs(value.translation.height) > 5) {
                        isDragging = true
                    }
                }
                .onEnded { _ in
                    dragOffset = .zero
                    isDragging = false
                }
        )
    }
    
    private func deleteFile() {
        try? Foundation.FileManager.default.trashItem(at: file, resultingItemURL: nil)
        DownloadFileManager.shared.scan()
    }
    
    private func moveFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let destination = panel.url {
            let destFile = destination.appendingPathComponent(file.lastPathComponent)
            try? Foundation.FileManager.default.moveItem(at: file, to: destFile)
            DownloadFileManager.shared.scan()
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            // Handle file drop here
            return true
        }
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
    
    func loadFolders() {
        folders = [
            FolderItem(name: "Desktop", url: Foundation.FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(forFileType: "public.folder")),
            FolderItem(name: "Documents", url: Foundation.FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(forFileType: "public.folder")),
            FolderItem(name: "Pictures", url: Foundation.FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(forFileType: "public.folder")),
            FolderItem(name: "Movies", url: Foundation.FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(forFileType: "public.folder")),
            FolderItem(name: "Music", url: Foundation.FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(forFileType: "public.folder")),
            FolderItem(name: "Applications", url: URL(fileURLWithPath: "/Applications"), icon: NSWorkspace.shared.icon(forFileType: "public.folder"))
        ]
    }
}

class DownloadFileManager: ObservableObject {
    static let shared = DownloadFileManager()
    @Published var files: [URL] = []
    
    private let downloadsURL = Foundation.FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    
    func scan() {
        do {
            files = try Foundation.FileManager.default.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            .filter { !$0.hasDirectoryPath }
            .sorted { file1, file2 in
                let date1 = try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
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
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}