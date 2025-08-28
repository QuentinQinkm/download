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

// MARK: - Window Controller

class WindowController: ObservableObject {
    let window: NSWindow
    @Published var isExpanded = false
    @Published var isAnimating = false
    
    init(window: NSWindow) {
        self.window = window
    }
    
    func expand() {
        guard !isAnimating else { return }
        isAnimating = true
        let currentFrame = window.frame
        let targetHeight: CGFloat = 240
        let heightDelta = targetHeight - currentFrame.height
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y - heightDelta,
            width: currentFrame.width,
            height: targetHeight
        )
        print("🔧 Expanding: Top stays at \(currentFrame.origin.y + currentFrame.height), height goes to \(targetHeight)")
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }, completionHandler: {
            DispatchQueue.main.async {
                self.isExpanded = true
                self.isAnimating = false
            }
        })
    }
    
    func collapse() {
        guard !isAnimating else { return }
        isExpanded = false
        isAnimating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let currentFrame = self.window.frame
            let targetHeight: CGFloat = 120
            let heightDelta = currentFrame.height - targetHeight
            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y + heightDelta,
                width: currentFrame.width,
                height: targetHeight
            )
            print("🔧 Collapsing: Top stays at \(currentFrame.origin.y + currentFrame.height), height goes to \(targetHeight)")
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.window.animator().setFrame(newFrame, display: true)
            }, completionHandler: {
                DispatchQueue.main.async {
                    self.isAnimating = false
                }
            })
        }
    }
}

// MARK: - Folders Panel Controller

class FoldersPanelController {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    private weak var parentWindow: NSWindow?
    
    init(parentWindow: NSWindow?) {
        self.parentWindow = parentWindow
    }
    
    func showPanel(relativeTo rect: NSRect, in view: NSView, withContent content: AnyView) {
        if panel == nil {
            let style: NSWindow.StyleMask = [.borderless]
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 140),
                                styleMask: style,
                                backing: .buffered,
                                defer: false)
            panel.isFloatingPanel = true
            panel.level = .popUpMenu
            panel.hasShadow = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            
            hostingController = NSHostingController(rootView: content)
            hostingController?.view.frame = panel.contentView!.bounds
            hostingController?.view.autoresizingMask = [.width, .height]
            hostingController?.view.wantsLayer = true
            hostingController?.view.layer?.cornerRadius = 12
            hostingController?.view.layer?.masksToBounds = true
            
            panel.contentView?.addSubview(hostingController!.view)
            self.panel = panel
        } else {
            hostingController?.rootView = content
        }
        
        guard let panel = panel else { return }
        
        // Position the panel directly below the given rect in the given view's coordinate
        let screenRect = view.convert(rect, to: nil)
        let windowRect = view.window?.convertToScreen(screenRect) ?? screenRect
        
        let panelOriginX = windowRect.origin.x + (windowRect.width - panel.frame.width) / 2
        let panelOriginY = windowRect.origin.y - panel.frame.height
        
        let targetFrame = NSRect(x: panelOriginX, y: panelOriginY, width: panel.frame.width, height: panel.frame.height)
        
        if panel.isVisible {
            // Animate moving to new position if needed
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            })
        } else {
            panel.setFrame(targetFrame, display: false)
            parentWindow?.addChildWindow(panel, ordered: .above)
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 1
            })
        }
    }
    
    func hidePanel() {
        guard let panel = panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            self.parentWindow?.removeChildWindow(panel)
        })
    }
}

// MARK: - AnchorView for NSViewRepresentable

struct AnchorView: NSViewRepresentable {
    @Binding var nsView: NSView?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.nsView = view
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var manager = DownloadFileManager.shared
    @StateObject private var folderManager = FolderManager.shared
    @State private var showPanel = false
    @State private var isDraggingFile = false
    @State private var isHoveringFolder = false
    
    private let collapsedSuggestRowHeight: CGFloat = 56
    private let expandedSuggestRowHeight: CGFloat = 192
    
    // Expand/collapse 2nd row automatically on drag or hover
    private func updatePanelOnDragOrHover() {
        if isDraggingFile || isHoveringFolder {
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
                // Center the HStack when only one file exists
                .if(manager.files.count == 1) { view in
                    view.frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.vertical, 8)
                .background(VisualEffectBackground())
                .clipShape(RoundedRectangle(cornerRadius: 16))
            .zIndex(0)
            
            GeometryReader { sectionProxy in
                ZStack {
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
                }
                .background(VisualEffectBackground())
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(minHeight: collapsedSuggestRowHeight, maxHeight: showPanel ? expandedSuggestRowHeight : collapsedSuggestRowHeight)
                .animation(.easeInOut(duration: 0.27), value: showPanel)
                .onAppear {
                    let g = sectionProxy.frame(in: .global)
                    let l = sectionProxy.frame(in: .local)
                    print("[DEBUG] suggestRow global: \(g), local: \(l)")
                }
                .onChange(of: sectionProxy.size) { _ in
                    let g = sectionProxy.frame(in: .global)
                    let l = sectionProxy.frame(in: .local)
                    print("[DEBUG] suggestRow (changed) global: \(g), local: \(l)")
                }
            }
            .zIndex(1)
        }
        .frame(width: windowWidth, height: 340, alignment: .top)
        // Removed outer background and clipShape as instructed
        .onAppear {
            manager.scan()
            folderManager.loadFolders()
        }
        .onChange(of: isDraggingFile) { _ in
            updatePanelOnDragOrHover()
        }
        .onChange(of: isHoveringFolder) { _ in
            updatePanelOnDragOrHover()
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
                    FileView(file: file, isDragging: Binding(get: { isDraggingFile }, set: { isDraggingFile = $0 }))
                }
                
                if manager.files.isEmpty {
                    Text("No files")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 0)
            .padding(.horizontal, 8)
            .frame(minHeight: 120)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
    }
    
    private var foldersRow: some View {
        GeometryReader { geometry in
            let padding: CGFloat = 0
            let itemWidth: CGFloat = 150
            let spacing: CGFloat = 12
            let availableWidth = geometry.size.width - padding * 2
            let itemsPerRow = max(1, Int(availableWidth / (itemWidth + spacing)))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: itemsPerRow), spacing: spacing) {
                ForEach(folderManager.folders, id: \.url) { folder in
                    FolderItemView(folder: folder,
                                   isDragging: Binding(get: { isDraggingFile }, set: { isDraggingFile = $0 }),
                                   isHovering: Binding(get: { isHoveringFolder }, set: { isHoveringFolder = $0 }))
                }
            }
            .frame(width: geometry.size.width, alignment: .center)
        }
        // Removed frame(height: showPanel ? 160 : 0) and clipped()
    }
}

// MARK: - File View

struct FileView: View {
    let file: URL
    @Binding var isDragging: Bool
    @State private var hovered = false
    @State private var localIsDragging = false
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .center, spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                
                Text(file.lastPathComponent)
                    .font(.caption)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80, height: 80, alignment: .center)
            
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
            .opacity(hovered && !localIsDragging ? 1 : 0)
            .allowsHitTesting(hovered && !localIsDragging)
        }
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(hovered ? Color.gray.opacity(0.35) : Color.clear)
        )
        .padding(4)
        .onHover { hovered = $0 }
        .onDrag {
            isDragging = true
            localIsDragging = true
            
            // Reset dragging state after a delay to handle drag completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isDragging = false
                localIsDragging = false
            }
            
            return NSItemProvider(object: file as NSURL)
        }
        .simultaneousGesture(
            DragGesture()
                .onEnded { _ in
                    // Reset dragging state when drag gesture ends
                    isDragging = false
                    localIsDragging = false
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
    @Binding var isDragging: Bool
    @Binding var isHovering: Bool
    @State private var hovered = false
    @State private var localDropHover = false
    
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
                .fill((hovered || localDropHover) ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
        .onHover { hovered = $0 }
        .onDrop(of: [.fileURL], isTargeted: $localDropHover) { providers in
            isHovering = true
            
            if let itemProvider = providers.first {
                itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    guard error == nil else { return }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            let destFile = folder.url.appendingPathComponent(url.lastPathComponent)
                            do {
                                try Foundation.FileManager.default.moveItem(at: url, to: destFile)
                                DownloadFileManager.shared.scan()
                            } catch {
                                // Handle error if needed
                            }
                        }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async {
                            let destFile = folder.url.appendingPathComponent(url.lastPathComponent)
                            do {
                                try Foundation.FileManager.default.moveItem(at: url, to: destFile)
                                DownloadFileManager.shared.scan()
                            } catch {
                                // Handle error if needed
                            }
                        }
                    }
                }
            }
            
            return true
        }
        .onChange(of: localDropHover) { _ in
            if !localDropHover {
                isHovering = false
            } else {
                isHovering = true
            }
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
        let folderContentType = UTType.folder
        folders = [
            FolderItem(name: "Desktop", url: Foundation.FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(for: folderContentType)),
            FolderItem(name: "Documents", url: Foundation.FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(for: folderContentType)),
            FolderItem(name: "Pictures", url: Foundation.FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(for: folderContentType)),
            FolderItem(name: "Movies", url: Foundation.FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(for: folderContentType)),
            FolderItem(name: "Music", url: Foundation.FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!, icon: NSWorkspace.shared.icon(for: folderContentType)),
            FolderItem(name: "Applications", url: URL(fileURLWithPath: "/Applications"), icon: NSWorkspace.shared.icon(for: folderContentType))
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
