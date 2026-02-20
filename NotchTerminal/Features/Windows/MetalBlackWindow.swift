import SwiftUI
import AppKit
import MetalKit
import SwiftTerm

final class InteractiveTerminalPanel: NSPanel {
    var onCommandPlus: (() -> Void)?
    var onCommandMinus: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        switch event.charactersIgnoringModifiers {
        case "+", "=":
            onCommandPlus?()
            return true
        case "-":
            onCommandMinus?()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}

struct TerminalWindowItem: Identifiable {
    let id: UUID
    let number: Int
    let displayID: CGDirectDisplayID
    let title: String
    let icon: NSImage?
    let preview: NSImage?
    let isMinimized: Bool
}

@MainActor
final class MetalBlackWindowsManager: NSObject, NSWindowDelegate {
    struct NotchTarget {
        let displayID: CGDirectDisplayID
        let frame: CGRect
    }

    var onTerminalItemsChanged: (([TerminalWindowItem]) -> Void)?

    private struct WindowInstance {
        let id: UUID
        var number: Int
        var displayID: CGDirectDisplayID
        let panel: NSPanel
        let notchTargetsProvider: () -> [NotchTarget]
        var displayTitle: String
        var displayIcon: NSImage?
        var isCompact: Bool
        var isMinimized: Bool
        var isAlwaysOnTop: Bool
        var isMaximized: Bool
        var preMaximizeFrame: CGRect?
        var expandedFrame: CGRect
        var terminalFontSize: CGFloat
        var previewSnapshot: NSImage?
        var isAnimatingMinimize: Bool = false
    }

    private let expandedSize = CGSize(width: 820, height: 520)
    private let compactSize = CGSize(width: 220, height: 220)
    private var windows: [UUID: WindowInstance] = [:]
    private var pendingDockTargets: [UUID: NotchTarget] = [:]
    private var nextNumber: Int = 1

    func createWindow(
        displayID: CGDirectDisplayID,
        anchorScreen: NSScreen?,
        notchTargetsProvider: @escaping () -> [NotchTarget]
    ) {
        let screen = anchorScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let id = UUID()
        let number = nextNumber
        nextNumber += 1

        let panel = makePanel()
        let frame = frameForInitialShow(on: screen, size: expandedSize)
        panel.setFrame(frame, display: true)

        windows[id] = WindowInstance(
            id: id,
            number: number,
            displayID: displayID,
            panel: panel,
            notchTargetsProvider: notchTargetsProvider,
            displayTitle: "NotchTerminal",
            displayIcon: nil,
            isCompact: false,
            isMinimized: false,
            isAlwaysOnTop: false,
            isMaximized: false,
            preMaximizeFrame: nil,
            expandedFrame: frame,
            terminalFontSize: defaultTerminalFontSize(),
            previewSnapshot: nil,
            isAnimatingMinimize: false
        )

        updateContent(for: id)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
        publishTerminalItems()
    }

    func restoreWindow(id: UUID) {
        guard var instance = windows[id] else { return }
        guard instance.isMinimized else {
            instance.panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            windows[id] = instance
            return
        }

        let targetFrame = instance.expandedFrame
        let startFrame: CGRect = {
            let preferredTarget = closestDockTarget(for: targetFrame, in: instance)
            guard let notchFrame = preferredTarget?.frame ?? notchFrame(for: instance.displayID, in: instance) else {
                let size = CGSize(width: 54, height: 54)
                let origin = CGPoint(x: targetFrame.midX - 27, y: targetFrame.maxY - size.height)
                return CGRect(origin: origin, size: size)
            }
            let size = CGSize(width: 54, height: 54)
            let origin = CGPoint(
                x: notchFrame.midX - size.width / 2,
                y: notchFrame.maxY - size.height
            )
            return CGRect(origin: origin, size: size)
        }()
        instance.panel.setFrame(startFrame, display: true)

        instance.isAnimatingMinimize = true
        windows[id] = instance
        updateContent(for: id)
        
        instance.panel.alphaValue = 0.0
        instance.panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            instance.panel.animator().setFrame(targetFrame, display: true)
            instance.panel.animator().alphaValue = 1.0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var updated = self.windows[id]
                updated?.isAnimatingMinimize = false
                updated?.isMinimized = false
                if let safeUpdated = updated {
                    self.windows[id] = safeUpdated
                }
                if let panel = self.windows[id]?.panel, let contentView = panel.contentView {
                    self.refreshTerminalView(in: contentView)
                }
                self.updateContent(for: id)
                self.publishTerminalItems()
            }
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func reorganizeVisibleWindows(on displayID: CGDirectDisplayID, screen: NSScreen?) {
        guard let screen else { return }

        let visibleIDs = windows.values
            .filter { $0.displayID == displayID && !$0.isMinimized }
            .sorted { $0.number < $1.number }
            .map(\.id)

        guard !visibleIDs.isEmpty else { return }

        let usable = screen.visibleFrame
        let marginX: CGFloat = 20
        let marginTop: CGFloat = 20
        let marginBottom: CGFloat = 20
        let vSpacing: CGFloat = 14
        let hSpacing: CGFloat = 16
        let columnWidth = visibleIDs
            .compactMap { windows[$0]?.panel.frame.width }
            .max() ?? expandedSize.width

        var currentX = usable.maxX - marginX - columnWidth
        var currentTop = usable.maxY - marginTop
        let minY = usable.minY + marginBottom
        let minX = usable.minX + marginX

        for id in visibleIDs {
            guard var instance = windows[id] else { continue }
            let size = instance.panel.frame.size

            if currentTop - size.height < minY {
                currentX -= (columnWidth + hSpacing)
                currentTop = usable.maxY - marginTop
            }

            if currentX < minX {
                // If windows exceed available columns, keep them in the leftmost column
                // instead of pushing off-screen.
                currentX = minX
                currentTop = max(minY + size.height, currentTop)
            }

            let origin = CGPoint(x: currentX, y: max(minY, currentTop - size.height))
            let targetFrame = CGRect(origin: origin, size: size)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                instance.panel.animator().setFrame(targetFrame, display: true)
            }

            instance.expandedFrame = targetFrame
            windows[id] = instance
            currentTop = targetFrame.minY - vSpacing
        }
    }

    private func toggleCompact(id: UUID) {
        guard var instance = windows[id] else { return }
        instance.isCompact.toggle()

        let targetSize = instance.isCompact ? compactSize : expandedSize
        let currentFrame = instance.panel.frame
        let targetOrigin = CGPoint(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.maxY - targetSize.height
        )
        let targetFrame = CGRect(origin: targetOrigin, size: targetSize)

        updateContent(for: id, isCompactOverride: instance.isCompact)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            instance.panel.animator().setFrame(targetFrame, display: true)
        }

        instance.expandedFrame = targetFrame
        windows[id] = instance
    }

    private func resetWindowSize(id: UUID) {
        guard var instance = windows[id] else { return }
        instance.isCompact = false

        let current = instance.panel.frame
        let targetFrame = CGRect(
            x: current.minX,
            y: current.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )

        updateContent(for: id, isCompactOverride: false)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            instance.panel.animator().setFrame(targetFrame, display: true)
        }

        instance.expandedFrame = targetFrame
        windows[id] = instance
    }

    private func maximizeWindow(id: UUID) {
        guard var instance = windows[id] else { return }

        if instance.isMaximized {
            // Restore to previous size
            let restoreFrame = instance.preMaximizeFrame ?? CGRect(
                origin: CGPoint(
                    x: instance.panel.frame.midX - expandedSize.width / 2,
                    y: instance.panel.frame.midY - expandedSize.height / 2
                ),
                size: expandedSize
            )
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                instance.panel.animator().setFrame(restoreFrame, display: true)
            }
            instance.isMaximized = false
            instance.preMaximizeFrame = nil
            instance.expandedFrame = restoreFrame
        } else {
            // Maximize
            guard let screen = instance.panel.screen ?? NSScreen.main else { return }
            instance.preMaximizeFrame = instance.panel.frame
            let targetFrame = screen.visibleFrame
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                instance.panel.animator().setFrame(targetFrame, display: true)
            }
            instance.isMaximized = true
            instance.expandedFrame = targetFrame
        }

        instance.isCompact = false
        windows[id] = instance
        updateContent(for: id, isCompactOverride: false)
    }

    private func toggleAlwaysOnTop(id: UUID) {
        guard var instance = windows[id] else { return }
        instance.isAlwaysOnTop.toggle()
        if instance.isAlwaysOnTop {
            instance.panel.level = .floating
            instance.panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        } else {
            instance.panel.level = .normal
            instance.panel.collectionBehavior = [.managed, .fullScreenAuxiliary]
        }
        windows[id] = instance
        updateContent(for: id)
    }

    private func adjustTerminalFontSize(id: UUID, delta: CGFloat) {
        guard var instance = windows[id] else { return }
        let minSize: CGFloat = 10
        let maxSize: CGFloat = 28
        let newSize = min(max(instance.terminalFontSize + delta, minSize), maxSize)
        guard newSize != instance.terminalFontSize else { return }
        instance.terminalFontSize = newSize
        windows[id] = instance
        updateContent(for: id)
    }

    private func minimizeWindow(id: UUID) {
        guard var instance = windows[id] else { return }
        guard !instance.isMinimized else { return }

        instance.expandedFrame = instance.panel.frame
        instance.previewSnapshot = capturePreview(from: instance.panel)
        let preferredTarget = closestDockTarget(for: instance.panel.frame, in: instance)
        if let preferredTarget {
            instance.displayID = preferredTarget.displayID
        }
        let targetFrame: CGRect = {
            guard let notchFrame = preferredTarget?.frame ?? notchFrame(for: instance.displayID, in: instance) else {
                let size = CGSize(width: 54, height: 54)
                let origin = CGPoint(x: instance.panel.frame.midX - 27, y: instance.panel.frame.maxY - size.height)
                return CGRect(origin: origin, size: size)
            }
            let size = CGSize(width: 54, height: 54)
            let origin = CGPoint(
                x: notchFrame.midX - size.width / 2,
                y: notchFrame.maxY - size.height
            )
            return CGRect(origin: origin, size: size)
        }()
        
        instance.isAnimatingMinimize = true
        windows[id] = instance
        updateContent(for: id)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            instance.panel.animator().setFrame(targetFrame, display: true)
            instance.panel.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var updated = self.windows[id]
                updated?.isAnimatingMinimize = false
                if let safeUpdated = updated {
                    self.windows[id] = safeUpdated
                    safeUpdated.panel.alphaValue = 1.0
                    safeUpdated.panel.orderOut(nil)
                }
                self.updateContent(for: id)
            }
        }

        instance.isMinimized = true
        windows[id] = instance
        publishTerminalItems()
    }

    private func closeWindow(id: UUID) {
        guard let instance = windows[id] else { return }
        instance.panel.orderOut(nil)
        instance.panel.close()
        windows.removeValue(forKey: id)
        renumberWindows()
        publishTerminalItems()
    }

    /// Re-assigns sequential numbers (1, 2, 3…) to all remaining windows
    /// sorted by their current number, so there are never gaps.
    private func renumberWindows() {
        let sortedIDs = windows.values
            .sorted { $0.number < $1.number }
            .map(\.id)

        for (index, id) in sortedIDs.enumerated() {
            windows[id]?.number = index + 1
            updateContent(for: id)
        }
        nextNumber = sortedIDs.count + 1
    }

    private func publishTerminalItems() {
        let items = windows.values
            .map { instance in
                // If it's not minimized, take a fresh snapshot right now
                // so the notch preview is always up to date.
                let currentPreview = instance.isMinimized ? instance.previewSnapshot : capturePreview(from: instance.panel)
                
                return TerminalWindowItem(
                    id: instance.id,
                    number: instance.number,
                    displayID: instance.displayID,
                    title: instance.displayTitle,
                    icon: instance.displayIcon,
                    preview: currentPreview,
                    isMinimized: instance.isMinimized
                )
            }
            .sorted { $0.number < $1.number }
        onTerminalItemsChanged?(items)
    }

    private func makePanel() -> NSPanel {
        let panel = InteractiveTerminalPanel(
            contentRect: CGRect(origin: .zero, size: expandedSize),
            styleMask: [.borderless, .resizable, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.showsResizeIndicator = true
        panel.level = .normal
        panel.minSize = CGSize(width: 360, height: 240)
        panel.collectionBehavior = [.managed, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.delegate = self

        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        return panel
    }

    private func updateContent(for id: UUID, isCompactOverride: Bool? = nil) {
        guard let instance = windows[id] else { return }
        let isCompact = isCompactOverride ?? instance.isCompact

        let root = MetalBlackWindowContent(
            displayTitle: instance.displayTitle,
            displayIcon: instance.displayIcon,
            windowNumber: instance.number,
            isCompact: isCompact,
            isAlwaysOnTop: instance.isAlwaysOnTop,
            isMaximized: instance.isMaximized,
            terminalFontSize: instance.terminalFontSize,
            toggleCompact: { [weak self] in
                self?.toggleCompact(id: id)
            },
            increaseFontSize: { [weak self] in
                self?.adjustTerminalFontSize(id: id, delta: 1)
            },
            decreaseFontSize: { [weak self] in
                self?.adjustTerminalFontSize(id: id, delta: -1)
            },
            commandSubmitted: { [weak self] command in
                self?.handleCommandSubmitted(id: id, command: command)
            },
            directoryChanged: { [weak self] directory in
                self?.handleDirectoryChanged(id: id, directory: directory)
            },
            closeWindow: { [weak self] in
                self?.closeWindow(id: id)
            },
            minimize: { [weak self] in
                self?.minimizeWindow(id: id)
            },
            maximize: { [weak self] in
                self?.maximizeWindow(id: id)
            },
            toggleAlwaysOnTop: { [weak self] in
                self?.toggleAlwaysOnTop(id: id)
            },
            isAnimatingMinimize: instance.isAnimatingMinimize,
            expandedFrameSize: instance.expandedFrame.size,
            previewSnapshot: instance.previewSnapshot
        )

        if let hostingView = instance.panel.contentView as? NSHostingView<MetalBlackWindowContent> {
            hostingView.rootView = root
        } else {
            instance.panel.contentView = NSHostingView(rootView: root)
        }

        if let panel = instance.panel as? InteractiveTerminalPanel {
            panel.onCommandPlus = { [weak self] in
                self?.adjustTerminalFontSize(id: id, delta: 1)
            }
            panel.onCommandMinus = { [weak self] in
                self?.adjustTerminalFontSize(id: id, delta: -1)
            }
        }
    }

    private func frameForInitialShow(on screen: NSScreen, size: CGSize) -> CGRect {
        let origin = CGPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height - 120
        )
        return CGRect(origin: origin, size: size)
    }

    private func defaultTerminalFontSize() -> CGFloat {
        if let raw = ProcessInfo.processInfo.environment["NOTCH_TERMINAL_FONT_SIZE"],
           let value = Double(raw), value >= 10, value <= 28 {
            return CGFloat(value)
        }
        return 13
    }

    private func windowID(for panel: NSWindow) -> UUID? {
        windows.first(where: { $0.value.panel === panel })?.key
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow,
              let id = windowID(for: panel),
              var instance = windows[id],
              !instance.isMinimized else { return }

        if !instance.isCompact {
            instance.expandedFrame = panel.frame
            windows[id] = instance
        }
        
        // Force the terminal to snap its grid to the integer cell size
        // continuously during the live resize drag to avoid ghosting.
        if let rootView = panel.contentView {
            refreshTerminalView(in: rootView)
        }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow,
              let rootView = panel.contentView else { return }
        refreshTerminalView(in: rootView)
    }

    private var dragMonitor: Any?

    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow,
              let id = windowID(for: panel),
              let instance = windows[id],
              !instance.isMinimized else { return }

        let nearTarget = closestDockTarget(for: panel.frame, in: instance)

        if let nearTarget {
            pendingDockTargets[id] = nearTarget
        } else {
            pendingDockTargets.removeValue(forKey: id)
        }

        // Install a one-shot mouse-up monitor to detect end of drag.
        // Use global monitor because the window server manages the drag loop
        // and local monitors may not fire during window drags.
        if dragMonitor == nil {
            dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.handleDragEnd()
                }
            }
        }
    }

    private func handleDragEnd() {
        // Remove the monitor immediately
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
            dragMonitor = nil
        }

        // Check all pending dock targets
        for (id, target) in pendingDockTargets {
            guard let instance = windows[id], !instance.isMinimized else { continue }
            let currentTarget = closestDockTarget(for: instance.panel.frame, in: instance)
            if let currentTarget, currentTarget.displayID == target.displayID {
                pendingDockTargets.removeValue(forKey: id)
                minimizeWindow(id: id)
                return
            }
        }
        pendingDockTargets.removeAll()
    }

    private func refreshTerminalView(in view: NSView) {
        if let terminalView = view as? DetectingLocalProcessTerminalView {
            terminalView.refreshAfterResize()
            return
        }
        for subview in view.subviews {
            refreshTerminalView(in: subview)
        }
    }

    private func capturePreview(from panel: NSPanel) -> NSImage? {
        guard let contentView = panel.contentView else { return nil }
        let bounds = contentView.bounds.integral
        guard bounds.width > 8, bounds.height > 8 else { return nil }

        let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds)
        guard let rep else { return nil }
        contentView.cacheDisplay(in: bounds, to: rep)

        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    private func handleCommandSubmitted(id: UUID, command: String) {
        guard var instance = windows[id] else { return }
        let branding = CLICommandBrandingResolver.branding(for: command)

        // Only update title for whitelisted AI CLI tools
        guard let newTitle = branding.title else { return }
        guard instance.displayTitle != newTitle || instance.displayIcon !== branding.icon else { return }
        instance.displayTitle = newTitle
        instance.displayIcon = branding.icon
        windows[id] = instance
        updateContent(for: id)
        publishTerminalItems()
    }

    private func handleDirectoryChanged(id: UUID, directory: String) {
        guard var instance = windows[id] else { return }

        // Clean up the directory path
        // OSC 7 often sends "file://hostname/path/to/dir"
        var cleanPath = directory
        if cleanPath.hasPrefix("file://") {
             if let url = URL(string: cleanPath) {
                 cleanPath = url.path
             } else {
                 // Fallback manual cleanup if URL parsing fails
                 cleanPath = String(cleanPath.dropFirst(7))
                 if let hostEnd = cleanPath.firstIndex(of: "/") {
                     cleanPath = String(cleanPath[hostEnd...])
                 }
             }
        }

        // URL decode in case of spaces etc.
        cleanPath = cleanPath.removingPercentEncoding ?? cleanPath

        let newTitle = "NotchTerminal"
        guard instance.displayTitle != newTitle else { return }
        // Restore default title format, clearing any AI CLI branding
        instance.displayTitle = newTitle
        instance.displayIcon = nil
        windows[id] = instance
        updateContent(for: id)
        publishTerminalItems()
    }

    private func notchFrame(for displayID: CGDirectDisplayID, in instance: WindowInstance) -> CGRect? {
        instance.notchTargetsProvider().first(where: { $0.displayID == displayID })?.frame
    }

    private func closestDockTarget(for windowFrame: CGRect, in instance: WindowInstance) -> NotchTarget? {
        // Use top-center of window (where the title bar is) for proximity detection
        let topCenter = CGPoint(x: windowFrame.midX, y: windowFrame.maxY)
        let targets = instance.notchTargetsProvider()

        let candidate = targets
            .map { target -> (NotchTarget, CGFloat, CGRect) in
                let expanded = target.frame.insetBy(dx: -200, dy: -150)
                let dx = topCenter.x - expanded.midX
                let dy = topCenter.y - expanded.midY
                let dist2 = (dx * dx) + (dy * dy)
                return (target, dist2, expanded)
            }
            .filter { $0.2.contains(topCenter) }
            .min { $0.1 < $1.1 }

        return candidate?.0
    }
}

struct MetalBlackWindowContent: View {
    let displayTitle: String
    let displayIcon: NSImage?
    let windowNumber: Int
    let isCompact: Bool
    let isAlwaysOnTop: Bool
    let isMaximized: Bool
    let terminalFontSize: CGFloat
    let toggleCompact: () -> Void
    let increaseFontSize: () -> Void
    let decreaseFontSize: () -> Void
    let commandSubmitted: (String) -> Void
    let directoryChanged: (String) -> Void
    let closeWindow: () -> Void
    let minimize: () -> Void
    let maximize: () -> Void
    let toggleAlwaysOnTop: () -> Void
    let isAnimatingMinimize: Bool
    let expandedFrameSize: CGSize
    let previewSnapshot: NSImage?
    
    @AppStorage("enableCRTFilter") private var enableCRTFilter: Bool = false
    @State private var showOpenPortsPopover = false
    @State private var openPorts: [OpenPortEntry] = []
    @State private var isLoadingOpenPorts = false
    @State private var portsMessage: String?

    private var cornerRadius: CGFloat { isCompact ? 18 : 22 }
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black)

            BlackWindowMetalEffectView()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .opacity(isCompact ? 0.22 : 0.35)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)

            VStack(spacing: 0) {
                if isCompact {
                    // Compact mode: centered badge with minimal controls
                    HStack(spacing: 6) {
                        Button(action: closeWindow) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 16, height: 16)
                                .background(.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Center badge: icon or name
                        HStack(spacing: 5) {
                            if let displayIcon {
                                Image(nsImage: displayIcon)
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            }
                            Text(displayIcon != nil ? displayTitle : "NT")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.1), in: Capsule())

                        Spacer()

                        Button(action: toggleCompact) {
                            Image(systemName: "pip.exit")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 16, height: 16)
                                .background(.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 4)
                } else {
                    // Normal mode: full controls
                    HStack(spacing: 8) {
                        // Left: window controls
                        Button(action: closeWindow) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(.white.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: minimize) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(.white.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: maximize) {
                            Image(systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(.white.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Center: title
                        HStack(spacing: 6) {
                            if let displayIcon {
                                Image(nsImage: displayIcon)
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                            }
                            Text(displayTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        Spacer()

                        // Right: ports + pin + compact
                        Button {
                            showOpenPortsPopover.toggle()
                            if showOpenPortsPopover {
                                refreshOpenPorts()
                            }
                        } label: {
                            Image(systemName: "network")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(.white.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showOpenPortsPopover, arrowEdge: .bottom) {
                            OpenPortsPopoverView(
                                ports: openPorts,
                                isLoading: isLoadingOpenPorts,
                                message: portsMessage,
                                onRefresh: { refreshOpenPorts() },
                                onKill: { port in killPortProcess(port) }
                            )
                        }

                        Button(action: toggleAlwaysOnTop) {
                            Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin.slash")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isAlwaysOnTop ? .yellow : .white)
                                .frame(width: 20, height: 20)
                                .background((isAlwaysOnTop ? Color.yellow.opacity(0.2) : .white.opacity(0.14)), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: toggleCompact) {
                            Image(systemName: "pip")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(.white.opacity(0.14), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 6)
                    .background {
                        Color.white.opacity(0.001)
                            .onTapGesture(count: 2) {
                                maximize()
                            }
                    }
                }

                Group {
                    if isRunningInPreview {
                        RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                            .fill(Color.black.opacity(0.94))
                            .overlay(alignment: .topLeading) {
                                Text("Preview Terminal")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(12)
                            }
                    } else {
                        ZStack {
                            SwiftTermContainerView(
                                windowNumber: windowNumber,
                                fontSize: terminalFontSize,
                                commandSubmitted: commandSubmitted,
                                directoryChanged: directoryChanged
                            )
                            .frame(
                                width: isAnimatingMinimize ? expandedFrameSize.width : nil,
                                height: isAnimatingMinimize ? expandedFrameSize.height : nil,
                                alignment: .top
                            )
                            .modifier(CRTFilterModifier(enabled: enableCRTFilter))
                            .opacity(isAnimatingMinimize ? 0 : 1)
                            
                            if isAnimatingMinimize, let previewSnapshot {
                                Image(nsImage: previewSnapshot)
                                    .resizable()
                            }
                        }
                    }
                }
                    .clipped()
                    .padding(.top, isCompact ? 8 : 14)
                    .padding(.horizontal, isCompact ? 6 : 10)
                    .padding(.bottom, isCompact ? 6 : 8)
                    .clipShape(.rect(cornerRadius: isCompact ? 12 : 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: isCompact ? 12 : 16, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    }
                Spacer()
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .padding(8) // Provide a generous invisible grip area (approx 8pt)
        .background(Color.black.opacity(0.001)) // The secret sauce: invisible layer to catch mouse resize events
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isCompact)
    }

    private func refreshOpenPorts() {
        isLoadingOpenPorts = true
        portsMessage = nil

        Task {
            do {
                let ports = try await PortProcessService.fetchListeningPorts()
                await MainActor.run {
                    openPorts = ports
                    isLoadingOpenPorts = false
                    portsMessage = ports.isEmpty ? "No listening TCP ports found." : nil
                }
            } catch {
                await MainActor.run {
                    isLoadingOpenPorts = false
                    portsMessage = "Could not load open ports."
                }
            }
        }
    }

    private func killPortProcess(_ port: OpenPortEntry) {
        Task {
            let terminated = await PortProcessService.terminate(pid: port.pid)
            await MainActor.run {
                if terminated {
                    openPorts.removeAll { $0.id == port.id }
                    portsMessage = openPorts.isEmpty ? "No listening TCP ports found." : nil
                } else {
                    portsMessage = "Could not terminate PID \(port.pid)."
                }
            }
        }
    }
}

private struct OpenPortsPopoverView: View {
    private enum PortScope: String, CaseIterable, Identifiable {
        case dev = "Dev"
        case all = "All"
        var id: String { rawValue }
    }
    
    private enum ThemeMode: String, CaseIterable, Identifiable {
        case system = "System"
        case dark = "Dark"
        case light = "Light"
        var id: String { rawValue }
    }

    let ports: [OpenPortEntry]
    let isLoading: Bool
    let message: String?
    let onRefresh: () -> Void
    let onKill: (OpenPortEntry) -> Void
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var scope: PortScope = .dev
    @State private var themeMode: ThemeMode = .dark
    @State private var searchText = ""
    
    private var overrideColorScheme: ColorScheme? {
        switch themeMode {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    private var resolvedColorScheme: ColorScheme {
        overrideColorScheme ?? systemColorScheme
    }

    private var isDarkMode: Bool { resolvedColorScheme == .dark }
    private var primaryText: SwiftUI.Color { isDarkMode ? .white : .black }
    private var secondaryText: SwiftUI.Color { isDarkMode ? .white.opacity(0.65) : .black.opacity(0.62) }
    private var subtleText: SwiftUI.Color { isDarkMode ? .white.opacity(0.55) : .black.opacity(0.50) }
    private var cardStroke: SwiftUI.Color { isDarkMode ? .white.opacity(0.14) : .black.opacity(0.10) }
    private var glassTint: SwiftUI.Color { isDarkMode ? .black.opacity(0.36) : .white.opacity(0.42) }

    private var searchedPorts: [OpenPortEntry] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ports
        }
        let query = searchText.lowercased()
        return ports.filter {
            String($0.port).contains(query) ||
            String($0.pid).contains(query) ||
            $0.command.lowercased().contains(query) ||
            $0.endpoint.lowercased().contains(query)
        }
    }

    private var visiblePorts: [OpenPortEntry] {
        scope == .all ? searchedPorts : searchedPorts.filter(\.isLikelyDev)
    }

    private var devPorts: [OpenPortEntry] {
        visiblePorts.filter(\.isLikelyDev)
    }

    private var otherPorts: [OpenPortEntry] {
        visiblePorts.filter { !$0.isLikelyDev }
    }

    var body: some View {
        Group {
            popoverBody
        }
        .ifLet(overrideColorScheme) { view, scheme in
            view.environment(\.colorScheme, scheme)
        }
    }

    private var popoverBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(glassTint)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [primaryText.opacity(0.22), .clear, primaryText.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(primaryText.opacity(0.9))
                        .frame(width: 24, height: 24)
                        .background(primaryText.opacity(0.1), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Open Ports")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(primaryText)
                        Text("Inspect and terminate occupied ports quickly")
                            .font(.caption)
                            .foregroundStyle(subtleText)
                    }
                    Spacer()
                    Menu {
                        Picker("Theme", selection: $themeMode) {
                            ForEach(ThemeMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(primaryText.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .background(primaryText.opacity(0.12), in: Circle())
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)

                    Text("\(visiblePorts.count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryText.opacity(0.1), in: Capsule())
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(primaryText.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .background(primaryText.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    scopeButton(.dev)
                    scopeButton(.all)
                    Spacer()
                    metricPill(label: "Dev", value: devPorts.count)
                    metricPill(label: "Other", value: otherPorts.count)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(subtleText)
                    TextField("Filter by port, process or PID", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(primaryText)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(subtleText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cardStroke, lineWidth: 1)
                )

                if isLoading {
                    ProgressView("Scanning ports...")
                        .controlSize(.small)
                        .tint(primaryText)
                } else if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            if !devPorts.isEmpty {
                                sectionLabel("Dev")
                                ForEach(devPorts) { port in
                                    portRow(port)
                                }
                            }

                            if scope == .all, !otherPorts.isEmpty {
                                sectionLabel("Other")
                                ForEach(otherPorts) { port in
                                    portRow(port)
                                }
                            }

                            if visiblePorts.isEmpty {
                                Text(scope == .all ? "No open ports match this filter." : "No dev ports match this filter.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 10)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 420, height: 320)
    }

    @ViewBuilder
    private func scopeButton(_ value: PortScope) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                scope = value
            }
        } label: {
            Text(value.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(scope == value ? (isDarkMode ? .black : .white) : primaryText.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if scope == value {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.regularMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(primaryText.opacity(isDarkMode ? 0.22 : 0.32))
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(cardStroke, lineWidth: 1)
                                )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metricPill(label: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(subtleText)
            Text("\(value)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(primaryText.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(cardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    @ViewBuilder
    private func portRow(_ port: OpenPortEntry) -> some View {
        HStack(spacing: 10) {
            Text(":\(port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(primaryText.opacity(0.95))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((port.isLikelyDev ? Color.blue.opacity(0.22) : Color.gray.opacity(0.22)), in: Capsule())

            VStack(alignment: .leading, spacing: 1) {
                Text(port.command)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(primaryText)
                Text("PID \(String(port.pid)) • \(port.endpoint)")
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Button {
                onKill(port)
            } label: {
                Label("Kill", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.red.opacity(0.88), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
    }
}

private extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ optional: T?, transform: (Self, T) -> Content) -> some View {
        if let optional {
            transform(self, optional)
        } else {
            self
        }
    }
}

private struct OpenPortEntry: Identifiable, Hashable {
    let pid: Int
    let port: Int
    let command: String
    let endpoint: String

    var id: String { "\(pid)-\(port)-\(endpoint)" }

    var isLikelyDev: Bool {
        if OpenPortEntry.devPorts.contains(port) { return true }
        let normalized = command.lowercased()
        return OpenPortEntry.devProcessHints.contains { normalized.contains($0) }
    }

    private static let devPorts: Set<Int> = [
        3000, 3001, 4000, 4200, 5000, 5173, 5432, 6379, 8000, 8080, 8081, 9000, 9229
    ]

    private static let devProcessHints: [String] = [
        "node", "bun", "deno", "python", "ruby", "java", "go", "docker", "postgres", "redis", "nginx", "vite", "next"
    ]
}

private enum PortProcessService {
    static func fetchListeningPorts() async throws -> [OpenPortEntry] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let raw = try runCommand("/usr/sbin/lsof", arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"])
                    let parsed = parseLsofMachineOutput(raw.output)
                    continuation.resume(returning: parsed.sorted { lhs, rhs in
                        lhs.port == rhs.port ? lhs.pid < rhs.pid : lhs.port < rhs.port
                    })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func terminate(pid: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if (try? runCommand("/bin/kill", arguments: ["-TERM", String(pid)]).status) == 0 {
                    continuation.resume(returning: true)
                    return
                }
                if (try? runCommand("/bin/kill", arguments: ["-KILL", String(pid)]).status) == 0 {
                    continuation.resume(returning: true)
                    return
                }
                continuation.resume(returning: false)
            }
        }
    }

    private static func parseLsofMachineOutput(_ output: String) -> [OpenPortEntry] {
        var entries: [OpenPortEntry] = []
        var seen = Set<String>()
        var currentPID: Int?
        var currentCommand = "unknown"

        for line in output.split(separator: "\n").map(String.init) {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())

            switch field {
            case "p":
                currentPID = Int(value)
            case "c":
                currentCommand = value
            case "n":
                guard let pid = currentPID, let port = parsePort(from: value) else { continue }
                let key = "\(pid)-\(port)-\(value)"
                guard seen.insert(key).inserted else { continue }
                entries.append(OpenPortEntry(pid: pid, port: port, command: currentCommand, endpoint: value))
            default:
                continue
            }
        }

        return entries
    }

    private static func parsePort(from endpoint: String) -> Int? {
        let normalized = endpoint.replacingOccurrences(of: "->", with: " ")
        guard let first = normalized.split(separator: " ").first,
              let colon = first.lastIndex(of: ":") else { return nil }
        return Int(first[first.index(after: colon)...])
    }

    private static func runCommand(_ executable: String, arguments: [String]) throws -> (output: String, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errors = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (output + errors, process.terminationStatus)
    }
}

#Preview("Terminal Window") {
    MetalBlackWindowContent(
        displayTitle: "NotchTerminal · ~/project",
        displayIcon: nil,
        windowNumber: 1,
        isCompact: false,
        isAlwaysOnTop: false,
        isMaximized: false,
        terminalFontSize: 13,
        toggleCompact: {},
        increaseFontSize: {},
        decreaseFontSize: {},
        commandSubmitted: { _ in },
        directoryChanged: { _ in },
        closeWindow: {},
        minimize: {},
        maximize: {},
        toggleAlwaysOnTop: {},
        isAnimatingMinimize: false,
        expandedFrameSize: CGSize(width: 820, height: 520),
        previewSnapshot: nil
    )
    .frame(width: 860, height: 560)
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}

struct CRTFilterModifier: ViewModifier {
    let enabled: Bool
    
    func body(content: Content) -> some View {
        if enabled {
            content.overlay {
                if #available(macOS 14.0, *) {
                    GeometryReader { geo in
                        let size = geo.size
                        TimelineView(.animation) { ctx in
                            Rectangle()
                                .fill(.white)
                                .colorEffect(
                                    ShaderLibrary.crtFilter(
                                        .float2(size),
                                        .float(ctx.date.timeIntervalSinceReferenceDate)
                                    )
                                )
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        } else {
            content
        }
    }
}

final class DetectingLocalProcessTerminalView: LocalProcessTerminalView {
    var commandSubmitted: ((String) -> Void)?
    private var currentInputLine = ""
    private var isInLiveResize = false

    override func send(source: TerminalView, data: ArraySlice<UInt8>) {
        super.send(source: source, data: data)

        for byte in data {
            switch byte {
            case 10, 13: // \n or \r
                let command = currentInputLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if !command.isEmpty {
                    commandSubmitted?(command)
                }
                currentInputLine = ""
            case 8, 127: // backspace/delete
                if !currentInputLine.isEmpty {
                    currentInputLine.removeLast()
                }
            default:
                if byte >= 32 && byte <= 126 {
                    currentInputLine.append(Character(UnicodeScalar(byte)))
                }
            }
        }
    }

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        isInLiveResize = true
    }

    override func viewDidEndLiveResize() {
        isInLiveResize = false
        super.viewDidEndLiveResize()
        // After live resize ends, force a fresh terminal resize + full redraw.
        // Call setFrameSize with the current size to trigger processSizeChange
        // internally, then do a full screen update to clear artifacts.
        super.setFrameSize(frame.size)
        let terminal = getTerminal()
        terminal.updateFullScreen()
        needsDisplay = true
        layer?.setNeedsDisplay()
    }

    func refreshAfterResize() {
        super.setFrameSize(frame.size)
        let terminal = getTerminal()
        terminal.updateFullScreen()
        needsDisplay = true
        layer?.setNeedsDisplay()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        hasDroppableFileURLs(sender) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let droppedURLs = fileURLs(from: sender), !droppedURLs.isEmpty else { return false }

        let insertion = droppedURLs
            .map { shellQuotedPath($0.path(percentEncoded: false)) }
            .joined(separator: " ") + " "

        let bytes = Array(insertion.utf8)
        send(source: self, data: bytes[...])
        window?.makeFirstResponder(self)
        return true
    }

    private func hasDroppableFileURLs(_ sender: NSDraggingInfo) -> Bool {
        fileURLs(from: sender)?.isEmpty == false
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL]? {
        let pasteboard = sender.draggingPasteboard
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        return pasteboard.readObjects(forClasses: classes, options: options) as? [URL]
    }

    private func shellQuotedPath(_ path: String) -> String {
        // Single-quote shell escaping compatible with zsh/bash.
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

struct SwiftTermContainerView: NSViewRepresentable {
    let windowNumber: Int
    let fontSize: CGFloat
    let commandSubmitted: (String) -> Void
    let directoryChanged: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = DetectingLocalProcessTerminalView(frame: .zero)
        terminal.commandSubmitted = commandSubmitted
        terminal.registerForDraggedTypes([.fileURL])
        terminal.processDelegate = context.coordinator
        context.coordinator.onDirectoryChanged = directoryChanged
        terminal.font = preferredTerminalFont(size: fontSize)
        terminal.nativeBackgroundColor = .black
        terminal.nativeForegroundColor = .white
        terminal.wantsLayer = true
        terminal.layer?.backgroundColor = NSColor.black.cgColor
        context.coordinator.windowNumber = windowNumber
        context.coordinator.tryStartProcessIfNeeded(on: terminal)
        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        nsView.font = preferredTerminalFont(size: fontSize)
        context.coordinator.windowNumber = windowNumber
        context.coordinator.tryStartProcessIfNeeded(on: nsView)
        if nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    static func dismantleNSView(_ nsView: LocalProcessTerminalView, coordinator: Coordinator) {
        nsView.terminate()
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var processStarted = false
        var startRetryScheduled = false
        var windowNumber: Int = 0
        var onDirectoryChanged: ((String) -> Void)?

        func tryStartProcessIfNeeded(on terminal: LocalProcessTerminalView) {
            guard !processStarted else { return }

            if terminal.window != nil, terminal.bounds.width > 120, terminal.bounds.height > 90 {
                let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
                terminal.startProcess(
                    executable: shell,
                    args: ["-l"],
                    currentDirectory: NSHomeDirectory()
                )
                processStarted = true
                return
            }

            guard !startRetryScheduled else { return }
            startRetryScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self, weak terminal] in
                guard let self else { return }
                self.startRetryScheduled = false
                guard let terminal else { return }
                self.tryStartProcessIfNeeded(on: terminal)
            }
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            if let directory {
                onDirectoryChanged?(directory)
            }
        }
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }

    private func preferredTerminalFont(size: CGFloat) -> NSFont {
        let env = ProcessInfo.processInfo.environment
        if let explicit = env["NOTCH_TERMINAL_FONT"], let font = NSFont(name: explicit, size: size) {
            return font
        }

        let candidates = [
            "MesloLGS NF",
            "MesloLGM Nerd Font",
            "JetBrainsMono Nerd Font",
            "Hack Nerd Font",
            "FiraCode Nerd Font",
            "SauceCodePro Nerd Font",
            "Symbols Nerd Font Mono"
        ]
        for name in candidates {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }

}

struct BlackWindowMetalEffectView: NSViewRepresentable {
    func makeCoordinator() -> Renderer {
        Renderer()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isPaused = false
        view.enableSetNeedsDisplay = true
        view.preferredFramesPerSecond = 30
        view.sampleCount = 1
        view.framebufferOnly = true
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat = .bgra8Unorm
        context.coordinator.configure(with: view)
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    final class Renderer: NSObject, MTKViewDelegate {
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        private var start = CACurrentMediaTime()

        func configure(with view: MTKView) {
            guard let device = view.device else { return }
            commandQueue = device.makeCommandQueue()

            guard let library = device.makeDefaultLibrary(),
                  let vertex = library.makeFunction(name: "notchVertex"),
                  let fragment = library.makeFunction(name: "blackWindowFragment") else {
                return
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            if #available(macOS 13.0, *) {
                descriptor.rasterSampleCount = view.sampleCount
            } else {
                descriptor.sampleCount = view.sampleCount
            }
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let commandQueue,
                  let pipelineState,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }

            let time = Float(CACurrentMediaTime() - start)
            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentBytes([time], length: MemoryLayout<Float>.size, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
