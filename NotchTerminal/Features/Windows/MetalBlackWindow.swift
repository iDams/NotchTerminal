import SwiftUI
import AppKit
import MetalKit
import SwiftTerm
import Darwin

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
    let isAlwaysOnTop: Bool
}

@MainActor
final class MetalBlackWindowsManager: NSObject, NSWindowDelegate {
    enum CloseActionMode: String {
        case closeWindowOnly
        case terminateProcessAndClose
    }

    struct NotchTarget {
        let displayID: CGDirectDisplayID
        let frame: CGRect
    }

    var onTerminalItemsChanged: (([TerminalWindowItem]) -> Void)?

    private struct WindowInstance {
        let id: UUID
        var number: Int
        var displayID: CGDirectDisplayID
        var originalDisplayID: CGDirectDisplayID
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
        var currentDirectory: String = NSHomeDirectory()
        var preferMouseReporting: Bool = false
    }

    private let compactSize = CGSize(width: 220, height: 220)
    
    @AppStorage(AppPreferences.Keys.terminalDefaultWidth) private var terminalDefaultWidth: Double = AppPreferences.Defaults.terminalDefaultWidth
    @AppStorage(AppPreferences.Keys.terminalDefaultHeight) private var terminalDefaultHeight: Double = AppPreferences.Defaults.terminalDefaultHeight
    @AppStorage(AppPreferences.Keys.notchDockingSensitivity) private var notchDockingSensitivity: Double = AppPreferences.Defaults.notchDockingSensitivity

    private var expandedSize: CGSize {
        CGSize(width: terminalDefaultWidth, height: terminalDefaultHeight)
    }
    private var windows: [UUID: WindowInstance] = [:]
    private var pendingDockTargets: [UUID: NotchTarget] = [:]
    private var dockingPreviewOriginalFrames: [UUID: CGRect] = [:]
    private var closingWithoutTerminate = Set<UUID>()
    private var nextNumber: Int = 1

    private func defaultDisplayIcon() -> NSImage? {
        NSImage(named: "AppLogo")
    }

    private func normalizedWorkingDirectory(_ raw: String?) -> String {
        let fallback = NSHomeDirectory()
        let candidate = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.hasPrefix("/"), candidate != "/" else { return fallback }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return fallback
        }
        return candidate
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            self.displayID(for: screen) == displayID
        }
    }

    private func dockThumbnailFrame(from sourceFrame: CGRect, notchFrame: CGRect?) -> CGRect {
        let size = CGSize(width: 54, height: 54)
        let origin: CGPoint
        if let notchFrame {
            origin = CGPoint(
                x: notchFrame.midX - size.width / 2,
                y: notchFrame.maxY - size.height
            )
        } else {
            origin = CGPoint(
                x: sourceFrame.midX - size.width / 2,
                y: sourceFrame.maxY - size.height
            )
        }
        return CGRect(origin: origin, size: size)
    }

    func createWindow(
        displayID: CGDirectDisplayID,
        anchorScreen: NSScreen?,
        session: TerminalSession? = nil,
        notchTargetsProvider: @escaping () -> [NotchTarget]
    ) {
        let screen = anchorScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let id = session?.id ?? UUID()
        let number = nextNumber
        nextNumber += 1

        let panel = makePanel()
        let initialSize = session.map { CGSize(width: $0.windowWidth, height: $0.windowHeight) } ?? expandedSize
        let frame = frameForInitialShow(on: screen, size: initialSize)
        panel.setFrame(frame, display: true)

        windows[id] = WindowInstance(
            id: id,
            number: number,
            displayID: displayID,
            originalDisplayID: displayID,
            panel: panel,
            notchTargetsProvider: notchTargetsProvider,
            displayTitle: "NotchTerminal",
            displayIcon: defaultDisplayIcon(),
            isCompact: false,
            isMinimized: false,
            isAlwaysOnTop: false,
            isMaximized: false,
            preMaximizeFrame: nil,
            expandedFrame: frame,
            terminalFontSize: defaultTerminalFontSize(),
            previewSnapshot: nil,
            isAnimatingMinimize: false,
            currentDirectory: normalizedWorkingDirectory(session?.workingDirectory),
            preferMouseReporting: false
        )

        updateContent(for: id)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
        publishTerminalItems()
    }

    func restoreWindow(id: UUID) {
        guard var instance = windows[id] else { return }
        applyBaseLevel(for: instance)
        guard instance.isMinimized else {
            instance.panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            windows[id] = instance
            return
        }
        guard !instance.isAnimatingMinimize else { return }

        var targetFrame = instance.expandedFrame
        if let closedNotchFrame = notchFrame(for: instance.displayID, in: instance) {
            // Keep restored windows a bit below the notch so they don't feel glued to it.
            let restoreGapFromNotch: CGFloat = 22
            let maxAllowedY = closedNotchFrame.minY - restoreGapFromNotch - targetFrame.height
            targetFrame.origin.y = min(targetFrame.origin.y, maxAllowedY)
        }
        // Use the displayID saved at minimize time to find the correct notch position
        let startFrame = dockThumbnailFrame(
            from: targetFrame,
            notchFrame: notchFrame(for: instance.displayID, in: instance)
        )
        instance.panel.setFrame(startFrame, display: false)

        instance.isAnimatingMinimize = true
        windows[id] = instance
        updateContent(for: id)
        
        instance.panel.alphaValue = 0.0
        instance.panel.makeKeyAndOrderFront(nil)

        // Let WindowServer register the start frame first; otherwise restore can jump/freeze.
        DispatchQueue.main.async {
            self.animatePanel(
                instance.panel,
                to: targetFrame,
                duration: 0.24,
                alpha: 1.0
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    var updated = self.windows[id]
                    updated?.isAnimatingMinimize = false
                    updated?.isMinimized = false
                    updated?.previewSnapshot = nil
                    if let safeUpdated = updated {
                        self.windows[id] = safeUpdated
                    }
                    self.updateContent(for: id)
                    self.publishTerminalItems()
                    NSApp.activate(ignoringOtherApps: true)

                    // Refresh terminal grid on next turn, after SwiftUI tree is restored.
                    DispatchQueue.main.async { [weak self] in
                        guard let self,
                              let panel = self.windows[id]?.panel,
                              let contentView = panel.contentView else { return }
                        self.refreshTerminalView(in: contentView)
                    }
                }
            }
        }
    }

    func minimizeWindow(id: UUID) {
        guard let instance = windows[id], !instance.isAnimatingMinimize else { return }
        minimizeWindowInternal(id: id)
    }

    func closeWindow(id: UUID, mode: CloseActionMode? = nil) {
        closeWindowInternal(id: id, mode: mode ?? preferredCloseActionMode())
    }

    func toggleAlwaysOnTopWindow(id: UUID) {
        toggleAlwaysOnTop(id: id)
    }

    func restoreAllWindows() {
        for id in orderedWindowIDs() {
            restoreWindow(id: id)
        }
    }

    func minimizeAllWindows() {
        for id in orderedWindowIDs(where: { !$0.isMinimized }) {
            minimizeWindowInternal(id: id)
        }
    }

    func closeAllWindows(mode: CloseActionMode? = nil) {
        let actionMode = mode ?? preferredCloseActionMode()
        for id in orderedWindowIDs() {
            closeWindowInternal(id: id, mode: actionMode)
        }
    }

    func closeAllWindows(on displayID: CGDirectDisplayID, mode: CloseActionMode? = nil) {
        let actionMode = mode ?? preferredCloseActionMode()
        for id in orderedWindowIDs(where: { $0.displayID == displayID }) {
            closeWindowInternal(id: id, mode: actionMode)
        }
    }

    func bringWindow(id: UUID, to displayID: CGDirectDisplayID) {
        guard var instance = windows[id] else { return }
        
        guard let targetScreen = screen(for: displayID) else { return }
        
        instance.displayID = displayID
        instance.originalDisplayID = displayID
        
        let usable = targetScreen.visibleFrame
        let currentSize = instance.panel.frame.size
        let origin = CGPoint(
            x: usable.midX - currentSize.width / 2,
            y: usable.midY - currentSize.height / 2
        )
        let newFrame = CGRect(origin: origin, size: currentSize)
        
        instance.expandedFrame = newFrame
        windows[id] = instance
        
        instance.isMinimized = false
        instance.panel.setFrame(newFrame, display: true, animate: false)
        instance.panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        updateContent(for: id)
        publishTerminalItems()
    }

    func reconcileDisplays() {
        let screens = NSScreen.screens
        let activeDisplayIDs = Set(screens.compactMap(displayID(for:)))
        
        guard let mainScreen = NSScreen.main ?? screens.first,
              let mainDisplayID = displayID(for: mainScreen) else {
            return
        }

        for (id, instance) in windows {
            if activeDisplayIDs.contains(instance.originalDisplayID) {
                // Return to the original monitor if we are currently orphaned
                if instance.displayID != instance.originalDisplayID {
                    bringWindow(id: id, to: instance.originalDisplayID)
                }
            } else {
                // Relocate to the main laptop screen if our current monitor is completely gone
                if !activeDisplayIDs.contains(instance.displayID) {
                    bringWindow(id: id, to: mainDisplayID)
                }
            }
        }
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

        let minX = usable.minX + marginX
        let maxX = usable.maxX - marginX
        let minY = usable.minY + marginBottom
        let maxY = usable.maxY - marginTop

        var placements: [UUID: CGRect] = [:]
        var overflowIDs: [UUID] = []

        // Row-flow layout from top-right to left, then wraps to next row.
        // This avoids overlap for normal counts.
        var rowRightX = maxX
        var rowTopY = maxY
        var rowHeight: CGFloat = 0

        for id in visibleIDs {
            guard let instance = windows[id] else { continue }
            let size = instance.panel.frame.size

            // Wrap to next row if current window doesn't fit this row.
            if rowRightX - size.width < minX {
                rowTopY -= (rowHeight + vSpacing)
                rowRightX = maxX
                rowHeight = 0
            }

            let nextY = rowTopY - size.height
            if nextY < minY {
                overflowIDs.append(id)
                continue
            }

            let x = max(minX, rowRightX - size.width)
            let frame = CGRect(x: x, y: nextY, width: size.width, height: size.height)
            placements[id] = frame

            rowRightX = x - hSpacing
            rowHeight = max(rowHeight, size.height)
        }

        // If there are more windows than the screen can tile, place the rest
        // in a controlled diagonal stack near bottom-left.
        if !overflowIDs.isEmpty {
            let stackStepX: CGFloat = 24
            let stackStepY: CGFloat = 20
            let stackColumns = 4

            for (index, id) in overflowIDs.enumerated() {
                guard let instance = windows[id] else { continue }
                let size = instance.panel.frame.size
                let col = CGFloat(index % stackColumns)
                let row = CGFloat(index / stackColumns)

                let x = min(maxX - size.width, minX + (col * stackStepX))
                let y = min(maxY - size.height, minY + (row * stackStepY))
                placements[id] = CGRect(
                    x: max(minX, x),
                    y: max(minY, y),
                    width: size.width,
                    height: size.height
                )
            }
        }

        for id in visibleIDs {
            guard var instance = windows[id], let targetFrame = placements[id] else { continue }

            animatePanel(instance.panel, to: targetFrame, duration: 0.24)

            instance.expandedFrame = targetFrame
            windows[id] = instance
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

        animatePanel(instance.panel, to: targetFrame, duration: 0.22)

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

        animatePanel(instance.panel, to: targetFrame, duration: 0.22)

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
            animatePanel(instance.panel, to: restoreFrame, duration: 0.22)
            instance.isMaximized = false
            instance.preMaximizeFrame = nil
            instance.expandedFrame = restoreFrame
        } else {
            // Maximize
            guard let screen = instance.panel.screen ?? NSScreen.main else { return }
            instance.preMaximizeFrame = instance.panel.frame
            let targetFrame = screen.visibleFrame
            animatePanel(instance.panel, to: targetFrame, duration: 0.22)
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

    private func animatePanel(
        _ panel: NSPanel,
        to frame: CGRect,
        duration: Double,
        alpha: CGFloat? = nil,
        completion: (() -> Void)? = nil
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
            if let alpha {
                panel.animator().alphaValue = alpha
            }
        } completionHandler: {
            completion?()
        }
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

    private func minimizeWindowInternal(id: UUID) {
        guard var instance = windows[id] else { return }
        guard !instance.isMinimized else { return }

        let frameBeforeDockPreview = dockingPreviewOriginalFrames[id]
        instance.expandedFrame = frameBeforeDockPreview ?? instance.panel.frame
        instance.previewSnapshot = capturePreview(from: instance.panel)
        let preferredTarget = closestDockTarget(for: instance.panel.frame, in: instance)
        if let preferredTarget {
            instance.displayID = preferredTarget.displayID
        }
        let targetFrame = dockThumbnailFrame(
            from: instance.panel.frame,
            notchFrame: preferredTarget?.frame ?? notchFrame(for: instance.displayID, in: instance)
        )
        
        instance.isAnimatingMinimize = true
        windows[id] = instance
        updateContent(for: id)
        dockingPreviewOriginalFrames.removeValue(forKey: id)

        animatePanel(
            instance.panel,
            to: targetFrame,
            duration: 0.20,
            alpha: 0.0
        ) { [weak self] in
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

    private func closeWindowInternal(id: UUID, mode: CloseActionMode) {
        guard let instance = windows[id] else { return }
        if mode == .terminateProcessAndClose, let contentView = instance.panel.contentView {
            terminateTerminalViews(in: contentView)
        } else {
            closingWithoutTerminate.insert(id)
        }
        instance.panel.orderOut(nil)
        instance.panel.close()
        windows.removeValue(forKey: id)
        closingWithoutTerminate.remove(id)
        renumberWindows()
        publishTerminalItems()
    }

    private func orderedWindowIDs(where predicate: ((WindowInstance) -> Bool)? = nil) -> [UUID] {
        windows.values
            .filter { predicate?($0) ?? true }
            .sorted { $0.number < $1.number }
            .map(\.id)
    }

    /// Re-assigns sequential numbers (1, 2, 3…) to all remaining windows
    /// sorted by their current number, so there are never gaps.
    private func renumberWindows() {
        let sortedIDs = orderedWindowIDs()

        for (index, id) in sortedIDs.enumerated() {
            windows[id]?.number = index + 1
            updateContent(for: id)
        }
        nextNumber = sortedIDs.count + 1
    }

    private func publishTerminalItems() {
        let items = windows.values
            .map(makeTerminalItem(from:))
            .sorted { $0.number < $1.number }
        onTerminalItemsChanged?(items)
    }

    private func makeTerminalItem(from instance: WindowInstance) -> TerminalWindowItem {
        let currentPreview = instance.isMinimized ? instance.previewSnapshot : capturePreview(from: instance.panel)
        return TerminalWindowItem(
            id: instance.id,
            number: instance.number,
            displayID: instance.displayID,
            title: instance.displayTitle,
            icon: instance.displayIcon,
            preview: currentPreview,
            isMinimized: instance.isMinimized,
            isAlwaysOnTop: instance.isAlwaysOnTop
        )
    }

    private func makePanel() -> NSPanel {
        let panel = InteractiveTerminalPanel(
            contentRect: CGRect(origin: .zero, size: expandedSize),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
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
        // Do not mark terminal panels as transient; transient windows disappear in Mission Control.
        panel.collectionBehavior = [.managed, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
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
            previewSnapshot: instance.previewSnapshot,
            currentDirectory: instance.currentDirectory,
            preferMouseReporting: instance.preferMouseReporting
        )

        if let hostingView = instance.panel.contentView as? NSHostingView<MetalBlackWindowContent> {
            hostingView.rootView = root
        } else {
            let hostingView = NSHostingView(rootView: root)
            instance.panel.contentView = hostingView
        }
        // Ensure the hosting view is fully transparent so the SwiftUI clipShape
        // defines the visible edges — no opaque rectangle behind the rounded corners.
        if let cv = instance.panel.contentView {
            cv.wantsLayer = true
            cv.layer?.backgroundColor = .clear
            cv.layer?.cornerRadius = 0
            cv.layer?.masksToBounds = false
        }
        instance.panel.invalidateShadow()

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
            y: screen.frame.maxY - size.height - 220
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

        updateDockPreviewState(for: id, panelFrame: panel.frame, instance: instance)
        installDragEndMonitorIfNeeded()
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow,
              let id = windowID(for: panel) else { return }

        let skipTerminate = closingWithoutTerminate.contains(id)
        closingWithoutTerminate.remove(id)
        if !skipTerminate, let contentView = panel.contentView {
            terminateTerminalViews(in: contentView)
        }

        windows.removeValue(forKey: id)
        renumberWindows()
        publishTerminalItems()
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
            if matchesPendingDockTarget(target, for: instance) {
                pendingDockTargets.removeValue(forKey: id)
                minimizeWindow(id: id)
                return
            }
        }
        for id in Array(dockingPreviewOriginalFrames.keys) {
            restoreDockPreviewIfNeeded(id: id)
        }
        pendingDockTargets.removeAll()
    }

    private func updateDockPreviewState(for id: UUID, panelFrame: CGRect, instance: WindowInstance) {
        let isDraggingWithMouse = (NSEvent.pressedMouseButtons & 0x1) != 0
        let nearTarget = closestDockTarget(for: panelFrame, in: instance)

        if let nearTarget, isDraggingWithMouse {
            pendingDockTargets[id] = nearTarget
            applyDockPreviewIfNeeded(id: id)
            return
        }

        pendingDockTargets.removeValue(forKey: id)
        restoreDockPreviewIfNeeded(id: id)
    }

    private func installDragEndMonitorIfNeeded() {
        guard dragMonitor == nil else { return }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.handleDragEnd()
            }
        }
    }

    private func matchesPendingDockTarget(_ target: NotchTarget, for instance: WindowInstance) -> Bool {
        guard let currentTarget = closestDockTarget(for: instance.panel.frame, in: instance) else { return false }
        return currentTarget.displayID == target.displayID
    }

    private func applyDockPreviewIfNeeded(id: UUID) {
        guard let instance = windows[id], !instance.isAnimatingMinimize else { return }
        guard dockingPreviewOriginalFrames[id] == nil else { return }

        let original = instance.panel.frame
        dockingPreviewOriginalFrames[id] = original

        // Keep dragged terminal above notch overlay while it is in dock preview range.
        instance.panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        instance.panel.orderFrontRegardless()

        // Temporary visual shrink while the dragged window is in notch dock range.
        // This is only a preview and is restored if the drop is canceled.
        let width = max(300, original.width * 0.74)
        let height = max(190, original.height * 0.74)
        let previewSize = CGSize(width: width, height: height)
        let previewOrigin = CGPoint(
            x: original.midX - (previewSize.width / 2),
            y: original.maxY - previewSize.height
        )
        let previewFrame = CGRect(origin: previewOrigin, size: previewSize)

        animatePanel(instance.panel, to: previewFrame, duration: 0.12)
    }

    private func restoreDockPreviewIfNeeded(id: UUID) {
        guard let originalFrame = dockingPreviewOriginalFrames.removeValue(forKey: id),
              let instance = windows[id],
              !instance.isAnimatingMinimize,
              !instance.isMinimized else { return }

        animatePanel(instance.panel, to: originalFrame, duration: 0.12)
        publishTerminalItems()
        applyBaseLevel(for: instance)
    }

    func currentSessions() -> [TerminalSession] {
        windows.values.map { instance in
            TerminalSession(
                id: instance.id,
                workingDirectory: normalizedWorkingDirectory(instance.currentDirectory),
                windowWidth: instance.expandedFrame.width,
                windowHeight: instance.expandedFrame.height,
                isDockedToNotch: instance.isMinimized,
                lastKnownDisplayID: String(instance.displayID),
                creationTimestamp: Date()
            )
        }
    }

    private func applyBaseLevel(for instance: WindowInstance) {
        if instance.isAlwaysOnTop {
            instance.panel.level = .floating
        } else {
            instance.panel.level = .normal
        }
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

    private func terminateTerminalViews(in view: NSView) {
        if let terminalView = view as? DetectingLocalProcessTerminalView {
            terminalView.terminateProcessTree()
            return
        }
        if let terminalView = view as? LocalProcessTerminalView {
            terminalView.terminate()
            return
        }
        for subview in view.subviews {
            terminateTerminalViews(in: subview)
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
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let branding = CLICommandBrandingResolver.branding(for: command)

        if let newTitle = branding.title {
            guard instance.displayTitle != newTitle || instance.displayIcon !== branding.icon else { return }
            instance.displayTitle = newTitle
            instance.displayIcon = branding.icon
            instance.preferMouseReporting = (newTitle == "opencode")
        } else {
            // Keep branding for in-CLI slash commands, but reset when leaving the CLI.
            if trimmed == "exit" || trimmed == "quit" {
                instance.displayTitle = "NotchTerminal"
                instance.displayIcon = defaultDisplayIcon()
                instance.preferMouseReporting = false
            } else if trimmed.hasPrefix("/") {
                return
            } else if instance.displayIcon != nil {
                // If a regular shell command appears after branding was active,
                // assume we returned to the shell and clear branding.
                instance.displayTitle = "NotchTerminal"
                instance.displayIcon = defaultDisplayIcon()
                instance.preferMouseReporting = false
            } else {
                return
            }
        }

        windows[id] = instance
        updateContent(for: id)
        publishTerminalItems()
    }

    private func handleDirectoryChanged(id: UUID, directory: String) {
        guard var instance = windows[id] else { return }

        instance.currentDirectory = normalizedWorkingDirectory(parseDirectoryPath(directory))

        windows[id] = instance
    }

    private func parseDirectoryPath(_ rawDirectory: String) -> String {
        var cleanPath = rawDirectory
        if cleanPath.hasPrefix("file://") {
            if let url = URL(string: cleanPath) {
                cleanPath = url.path
            } else {
                cleanPath = String(cleanPath.dropFirst(7))
                if let hostEnd = cleanPath.firstIndex(of: "/") {
                    cleanPath = String(cleanPath[hostEnd...])
                }
            }
        }
        return cleanPath.removingPercentEncoding ?? cleanPath
    }

    private func preferredCloseActionMode() -> CloseActionMode {
        let raw = UserDefaults.standard.string(forKey: AppPreferences.Keys.closeActionMode) ?? AppPreferences.Defaults.closeActionMode
        return CloseActionMode(rawValue: raw) ?? .terminateProcessAndClose
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
                let sensitivity = CGFloat(notchDockingSensitivity)
                
                // CRITICAL FIX: `target.frame` is the NSPanel frame, which expands dynamically
                // when the UI grid opens, becoming huge. 
                // We MUST dock into the closed notch frame exclusively.
                let baseFrame = self.notchFrame(for: target.displayID, in: instance) ?? target.frame
                let expanded = baseFrame.insetBy(dx: -sensitivity, dy: -(sensitivity * 0.75))
                
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
    let currentDirectory: String
    let preferMouseReporting: Bool
    
    @AppStorage(AppPreferences.Keys.enableCRTFilter) private var enableCRTFilter: Bool = AppPreferences.Defaults.enableCRTFilter
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var showOpenPortsPopover = false
    @State private var openPorts: [OpenPortEntry] = []
    @State private var isLoadingOpenPorts = false
    @State private var portsMessage: String?

    private var cornerRadius: CGFloat { isCompact ? 18 : 22 }
    private var terminalCornerRadius: CGFloat { isCompact ? 12 : 16 }
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black)

            BlackWindowMetalEffectView(isActive: ((controlActiveState == .key) || !openPorts.isEmpty) && !isAnimatingMinimize)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .opacity(isCompact ? 0.22 : 0.35)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)

            VStack(spacing: 0) {
                if isCompact {
                    compactHeader
                } else {
                    regularHeader
                }

                terminalBody
                Spacer()
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background(Color.black.opacity(0.001))
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isCompact)
    }

    private var compactHeader: some View {
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
    }

    private var regularHeader: some View {
        HStack(spacing: 8) {
            headerButton(systemName: "xmark", action: closeWindow)
            headerButton(systemName: "minus", action: minimize)
            headerButton(
                systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                action: maximize
            )

            Spacer()

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
            .allowsHitTesting(false)

            Spacer()

            networkButton

            Button(action: toggleAlwaysOnTop) {
                Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin.slash")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isAlwaysOnTop ? .yellow : .white)
                    .frame(width: 20, height: 20)
                    .background((isAlwaysOnTop ? Color.yellow.opacity(0.2) : .white.opacity(0.14)), in: Circle())
            }
            .buttonStyle(.plain)

            headerButton(systemName: "pip", action: toggleCompact)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
        .background {
            WindowDragRegionView()
                .background(Color.white.opacity(0.001))
                .onTapGesture(count: 2) {
                    maximize()
                }
        }
    }

    private var networkButton: some View {
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
    }

    private var terminalBody: some View {
        Group {
            if isRunningInPreview {
                RoundedRectangle(cornerRadius: terminalCornerRadius, style: .continuous)
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
                        currentDirectory: currentDirectory,
                        preferMouseReporting: preferMouseReporting,
                        commandSubmitted: commandSubmitted,
                        directoryChanged: directoryChanged
                    )
                    .modifier(CRTFilterModifier(enabled: enableCRTFilter))
                    .opacity(isAnimatingMinimize ? 0 : 1)

                    if isAnimatingMinimize, let previewSnapshot {
                        GeometryReader { geo in
                            Image(nsImage: previewSnapshot)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                    }
                }
            }
        }
        .clipped()
        .padding(.top, isCompact ? 8 : 14)
        .padding(.horizontal, isCompact ? 6 : 10)
        .padding(.bottom, isCompact ? 6 : 8)
        .clipShape(.rect(cornerRadius: terminalCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: terminalCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func headerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
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
                    portsMessage = ports.isEmpty ? "openPorts.message.noListening".localized : nil
                }
            } catch {
                await MainActor.run {
                    isLoadingOpenPorts = false
                    portsMessage = "openPorts.message.loadFailed".localized
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
                    portsMessage = openPorts.isEmpty ? "openPorts.message.noListening".localized : nil
                } else {
                    portsMessage = String(format: "openPorts.message.terminateFailed".localized, String(port.pid))
                }
            }
        }
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
        previewSnapshot: nil,
        currentDirectory: "/Users/marco/project",
        preferMouseReporting: false
    )
    .frame(width: 860, height: 560)
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}

struct BlackWindowMetalEffectView: NSViewRepresentable {
    var isActive: Bool = true
    
    func makeCoordinator() -> Renderer {
        Renderer()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isPaused = !isActive
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

    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.isPaused = !isActive
    }

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
