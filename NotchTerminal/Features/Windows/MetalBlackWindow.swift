import SwiftUI
import AppKit
import MetalKit
import SwiftTerm
import Darwin

extension Notification.Name {
    static let notchDockHoverChanged = Notification.Name("NotchTerminal.notchDockHoverChanged")
}

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

@MainActor
final class MetalBlackWindowsManager: NSObject, NSWindowDelegate {
    typealias NotchTarget = TerminalWindowDockTarget

    enum CloseActionMode: String {
        case closeWindowOnly
        case terminateProcessAndClose
    }

    var onTerminalItemsChanged: (([TerminalWindowItem]) -> Void)?
    var onCommandOrbEvent: ((TerminalCommandOrbEvent) -> Void)?

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
        var projectRootPath: String?
        var projectName: String?
        var lastSubmittedCommand: String?
        var preferMouseReporting: Bool = false
    }

    private let compactSize = CGSize(width: 220, height: 220)
    
    @AppStorage(AppPreferences.Keys.terminalDefaultWidth) private var terminalDefaultWidth: Double = AppPreferences.Defaults.terminalDefaultWidth
    @AppStorage(AppPreferences.Keys.terminalDefaultHeight) private var terminalDefaultHeight: Double = AppPreferences.Defaults.terminalDefaultHeight

    private var expandedSize: CGSize {
        CGSize(width: terminalDefaultWidth, height: terminalDefaultHeight)
    }

    private var experimentalPreferences: AppPreferences.ExperimentalFeatureConfiguration {
        AppPreferences.experimentalFeatureConfiguration()
    }
    private var windows: [UUID: WindowInstance] = [:]
    private var activeWindowID: UUID?
    private var pendingDockTargets: [UUID: NotchTarget] = [:]
    private var dockingPreviewOriginalFrames: [UUID: CGRect] = [:]
    private var dockSuppressionUntil: [UUID: Date] = [:]
    private var closingWithoutTerminate = Set<UUID>()
    private var nextNumber: Int = 1
    private var pendingOrbCommands: [UUID: PendingOrbCommandState] = [:]

    private func defaultDisplayIcon() -> NSImage? {
        NSImage(named: "AppLogo")
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
        let restoredBranding = TerminalWindowContextResolver.restoredBranding(for: session)
        let restoredTitle: String = {
            let candidate = session?.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return candidate.isEmpty ? "NotchTerminal" : candidate
        }()
        let workingDirectory = TerminalWindowContextResolver.normalizedWorkingDirectory(session?.workingDirectory)
        let projectContext = TerminalWindowContextResolver.resolvedProjectContext(for: workingDirectory, session: session)
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
            displayTitle: restoredTitle,
            displayIcon: restoredBranding.icon ?? defaultDisplayIcon(),
            isCompact: session?.isCompact ?? false,
            isMinimized: false,
            isAlwaysOnTop: session?.isAlwaysOnTop ?? false,
            isMaximized: session?.isMaximized ?? false,
            preMaximizeFrame: session?.preMaximizeFrame,
            expandedFrame: frame,
            terminalFontSize: defaultTerminalFontSize(),
            previewSnapshot: nil,
            isAnimatingMinimize: false,
            currentDirectory: workingDirectory,
            projectRootPath: projectContext?.rootPath,
            projectName: projectContext?.displayName,
            lastSubmittedCommand: session?.lastSubmittedCommand,
            preferMouseReporting: false
        )

        if let instance = windows[id] {
            applyBaseLevel(for: instance)
        }
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
        let startFrame = TerminalWindowDockingLogic.dockThumbnailFrame(
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
        for id in WindowSessionLogic.orderedWindowIDs(on: displayID, from: sessionSnapshots()) {
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
        let targetFrame = TerminalWindowGeometryLogic.compactToggleFrame(
            currentFrame: instance.panel.frame,
            targetSize: targetSize
        )

        updateContent(for: id, isCompactOverride: instance.isCompact)

        animatePanel(instance.panel, to: targetFrame, duration: 0.22)

        instance.expandedFrame = targetFrame
        windows[id] = instance
    }

    private func resetWindowSize(id: UUID) {
        guard var instance = windows[id] else { return }
        instance.isCompact = false

        let targetFrame = TerminalWindowGeometryLogic.resetFrame(
            currentFrame: instance.panel.frame,
            expandedSize: expandedSize
        )

        updateContent(for: id, isCompactOverride: false)

        animatePanel(instance.panel, to: targetFrame, duration: 0.22)

        instance.expandedFrame = targetFrame
        windows[id] = instance
    }

    private func maximizeWindow(id: UUID) {
        guard var instance = windows[id] else { return }

        if instance.isMaximized {
            let restoreFrame = TerminalWindowGeometryLogic.restoredFrameFromMaximize(
                currentFrame: instance.panel.frame,
                expandedSize: expandedSize,
                preMaximizeFrame: instance.preMaximizeFrame
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
        let targetFrame = TerminalWindowDockingLogic.dockThumbnailFrame(
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
        WindowSessionLogic.orderedWindowIDs(
            from: sessionSnapshots(),
            where: predicate.map { predicate in
                { snapshot in
                    guard let instance = self.windows[snapshot.id] else { return false }
                    return predicate(instance)
                }
            }
        )
    }

    /// Re-assigns sequential numbers (1, 2, 3…) to all remaining windows
    /// sorted by their current number, so there are never gaps.
    private func renumberWindows() {
        let renumbered = WindowSessionLogic.renumberedNumbersByID(from: sessionSnapshots())

        for (id, number) in renumbered {
            windows[id]?.number = number
            updateContent(for: id)
        }
        nextNumber = WindowSessionLogic.nextWindowNumber(from: sessionSnapshots())
    }

    private func publishTerminalItems() {
        onTerminalItemsChanged?(TerminalWindowPresentationLogic.items(from: terminalPresentationSnapshots()))
    }

    private func terminalPresentationSnapshots() -> [TerminalWindowPresentationSnapshot] {
        windows.values.map(makePresentationSnapshot(from:))
    }

    private func makePresentationSnapshot(from instance: WindowInstance) -> TerminalWindowPresentationSnapshot {
        let currentPreview = instance.isMinimized ? instance.previewSnapshot : capturePreview(from: instance.panel)
        return TerminalWindowPresentationSnapshot(
            id: instance.id,
            number: instance.number,
            displayID: instance.displayID,
            title: instance.displayTitle,
            projectName: instance.projectName,
            workingDirectory: instance.currentDirectory,
            lastCommand: instance.lastSubmittedCommand,
            icon: instance.displayIcon,
            preview: currentPreview,
            isMinimized: instance.isMinimized,
            isAlwaysOnTop: instance.isAlwaysOnTop,
            isActive: instance.id == activeWindowID
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
            outputReceived: { [weak self] text in
                self?.handleCommandOutput(id: id, text: text)
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
        TerminalWindowGeometryLogic.initialFrame(screenFrame: screen.frame, windowSize: size)
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

        guard experimentalPreferences.dragToNotchEnabled else {
            clearDockPreviewState(for: id)
            return
        }

        updateDockPreviewState(for: id, panelFrame: panel.frame, instance: instance)
        installDragEndMonitorIfNeeded()
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow,
              let id = windowID(for: panel) else { return }

        if activeWindowID == id {
            activeWindowID = nil
        }
        let skipTerminate = closingWithoutTerminate.contains(id)
        closingWithoutTerminate.remove(id)
        if !skipTerminate, let contentView = panel.contentView {
            terminateTerminalViews(in: contentView)
        }

        windows.removeValue(forKey: id)
        pendingOrbCommands.removeValue(forKey: id)
        renumberWindows()
        publishTerminalItems()
    }

    private func handleDragEnd() {
        // Remove the monitor immediately
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
            dragMonitor = nil
        }

        let matchedDisplayID: CGDirectDisplayID? = {
            guard experimentalPreferences.dragToNotchEnabled else { return nil }
            for (id, target) in pendingDockTargets {
                guard let instance = windows[id], !instance.isMinimized else { continue }
                if matchesPendingDockTarget(target, for: instance) {
                    return target.displayID
                }
            }
            return nil
        }()

        let resolution = TerminalWindowDockingLogic.dragEndResolution(
            dragToNotchEnabled: experimentalPreferences.dragToNotchEnabled,
            pendingTargets: Array(pendingDockTargets.values),
            matchedMinimizeDisplayID: matchedDisplayID
        )

        for displayID in resolution.hoverDisplayIDsToClear {
            postNotchDockHoverChanged(displayID: displayID, isHovering: false)
        }

        if let matchedDisplayID = resolution.targetToMinimize,
           let matchedEntry = pendingDockTargets.first(where: { $0.value.displayID == matchedDisplayID }) {
            pendingDockTargets.removeValue(forKey: matchedEntry.key)
            minimizeWindow(id: matchedEntry.key)
            return
        }

        if resolution.shouldRestoreAllPreviews {
            for id in Array(dockingPreviewOriginalFrames.keys) {
                restoreDockPreviewIfNeeded(id: id)
            }
        }
        if resolution.shouldClearPendingTargets {
            pendingDockTargets.removeAll()
        }
    }

    private func updateDockPreviewState(for id: UUID, panelFrame: CGRect, instance: WindowInstance) {
        let isDraggingWithMouse = (NSEvent.pressedMouseButtons & 0x1) != 0
        let now = Date()
        let previousTarget = pendingDockTargets[id]
        let nearTarget = closestDockTarget(for: panelFrame, in: instance)

        let previousTargetIsPill: Bool = {
            guard let previousTarget else { return false }
            let baseFrame = notchFrame(for: previousTarget.displayID, in: instance) ?? previousTarget.frame
            return TerminalWindowDockingLogic.isPillShape(frame: baseFrame)
        }()

        let update = TerminalWindowDockingLogic.previewUpdate(
            dragToNotchEnabled: experimentalPreferences.dragToNotchEnabled,
            isDraggingWithMouse: isDraggingWithMouse,
            now: now,
            suppressionUntil: dockSuppressionUntil[id],
            previousTarget: previousTarget,
            nearTarget: nearTarget,
            previousTargetIsPill: previousTargetIsPill
        )

        if let previousTarget, previousTarget.displayID != update.hoverDisplayID {
            postNotchDockHoverChanged(displayID: previousTarget.displayID, isHovering: false)
        }

        if let hoverDisplayID = update.hoverDisplayID,
           previousTarget?.displayID != hoverDisplayID,
           let nearTarget {
            pendingDockTargets[id] = nearTarget
            postNotchDockHoverChanged(displayID: hoverDisplayID, isHovering: true)
        }

        if update.shouldPreview {
            applyDockPreviewIfNeeded(id: id)
            dockSuppressionUntil[id] = update.suppressionUntil
            return
        }

        if update.shouldClearPendingTarget {
            pendingDockTargets.removeValue(forKey: id)
        }
        dockSuppressionUntil[id] = update.suppressionUntil

        if update.shouldRestorePreview {
            restoreDockPreviewIfNeeded(id: id)
        }
    }

    private func postNotchDockHoverChanged(displayID: CGDirectDisplayID, isHovering: Bool) {
        NotificationCenter.default.post(
            name: .notchDockHoverChanged,
            object: nil,
            userInfo: [
                "displayID": displayID,
                "isHovering": isHovering
            ]
        )
    }

    private func clearDockPreviewState(for id: UUID) {
        let resolution = TerminalWindowDockingLogic.clearPreviewResolution(
            pendingTargets: pendingDockTargets[id].map { [$0] } ?? [],
            scope: .singleTarget
        )

        for displayID in resolution.hoverDisplayIDsToClear {
            postNotchDockHoverChanged(displayID: displayID, isHovering: false)
        }
        if resolution.shouldClearPendingTargets {
            pendingDockTargets.removeValue(forKey: id)
        }
        if resolution.shouldClearSuppression {
            dockSuppressionUntil.removeValue(forKey: id)
        }
        if resolution.shouldRestorePreview {
            restoreDockPreviewIfNeeded(id: id)
        }
    }

    private func clearAllDockPreviewState() {
        let resolution = TerminalWindowDockingLogic.clearPreviewResolution(
            pendingTargets: Array(pendingDockTargets.values),
            scope: .allTargets
        )

        if resolution.shouldRemoveMonitor, let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
            dragMonitor = nil
        }

        for displayID in resolution.hoverDisplayIDsToClear {
            postNotchDockHoverChanged(displayID: displayID, isHovering: false)
        }

        if resolution.shouldRestoreAllPreviews {
            for id in Array(dockingPreviewOriginalFrames.keys) {
                restoreDockPreviewIfNeeded(id: id)
            }
        }

        if resolution.shouldClearPendingTargets {
            pendingDockTargets.removeAll()
        }
        if resolution.shouldClearSuppression {
            dockSuppressionUntil.removeAll()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow,
              let id = windowID(for: panel) else { return }
        if activeWindowID != id {
            activeWindowID = id
            publishTerminalItems()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow,
              let id = windowID(for: panel) else { return }
        if activeWindowID == id {
            activeWindowID = nil
            publishTerminalItems()
        }
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

        let previewFrame = TerminalWindowDockingLogic.previewFrame(for: original)

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
        WindowSessionLogic.serializedSessions(
            from: sessionSnapshots(),
            normalizeWorkingDirectory: { TerminalWindowContextResolver.normalizedWorkingDirectory($0) },
            creationTimestamp: Date()
        )
    }

    private func sessionSnapshots() -> [WindowSessionSnapshot] {
        windows.values.map { instance in
            WindowSessionLogic.snapshot(
                from: .init(
                    id: instance.id,
                    number: instance.number,
                    displayID: instance.displayID,
                    workingDirectory: instance.currentDirectory,
                    expandedFrame: instance.expandedFrame,
                    isDockedToNotch: instance.isMinimized,
                    isAlwaysOnTop: instance.isAlwaysOnTop,
                    isCompact: instance.isCompact,
                    isMaximized: instance.isMaximized,
                    displayTitle: instance.displayTitle,
                    projectRootPath: instance.projectRootPath,
                    projectName: instance.projectName,
                    lastSubmittedCommand: instance.lastSubmittedCommand,
                    preMaximizeFrame: instance.preMaximizeFrame
                )
            )
        }
    }

    private func applyBaseLevel(for instance: WindowInstance) {
        if instance.isAlwaysOnTop {
            instance.panel.level = .floating
            instance.panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        } else {
            instance.panel.level = .normal
            instance.panel.collectionBehavior = [.managed, .fullScreenAuxiliary]
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
        let update = TerminalCommandLifecycleLogic.submittedCommandUpdate(
            command: command,
            currentDisplayTitle: instance.displayTitle,
            currentDisplayIcon: instance.displayIcon,
            defaultDisplayIcon: defaultDisplayIcon(),
            displayID: instance.displayID,
            terminalNumber: instance.number
        )

        instance.lastSubmittedCommand = update.lastSubmittedCommand

        if let pending = update.pendingOrbCommand {
            pendingOrbCommands[id] = pending
        } else {
            pendingOrbCommands.removeValue(forKey: id)
        }

        if let orbEvent = update.emittedOrbEvent {
            onCommandOrbEvent?(orbEvent)
        }

        guard let brandingState = update.brandingState else {
            windows[id] = instance
            return
        }

        instance.displayTitle = brandingState.displayTitle
        instance.displayIcon = brandingState.displayIcon
        instance.preferMouseReporting = brandingState.preferMouseReporting

        windows[id] = instance
        updateContent(for: id)
        publishTerminalItems()
    }

    private func handleCommandOutput(id: UUID, text: String) {
        guard let pending = pendingOrbCommands[id],
              let (failed, event) = TerminalCommandLifecycleLogic.failedOrbState(for: text, pending: pending) else {
            return
        }
        pendingOrbCommands[id] = failed
        onCommandOrbEvent?(event)
    }

    private func handleDirectoryChanged(id: UUID, directory: String) {
        guard var instance = windows[id] else { return }

        instance.currentDirectory = TerminalWindowContextResolver.normalizedWorkingDirectory(Self.parseDirectoryPath(directory))
        let projectContext = ProjectContextResolver.resolve(from: instance.currentDirectory)
        instance.projectRootPath = projectContext?.rootPath
        instance.projectName = projectContext?.displayName
        if let pending = pendingOrbCommands[id] {
            pendingOrbCommands.removeValue(forKey: id)
            if !pending.hasFailed {
                onCommandOrbEvent?(TerminalCommandOrbClassifier.makeCompletionEvent(from: pending.event, status: .success))
            }
        }

        windows[id] = instance
    }

    private func preferredCloseActionMode() -> CloseActionMode {
        let raw = AppPreferences.terminalActionConfiguration().closeActionMode
        return CloseActionMode(rawValue: raw) ?? .terminateProcessAndClose
    }

    private func notchFrame(for displayID: CGDirectDisplayID, in instance: WindowInstance) -> CGRect? {
        instance.notchTargetsProvider().first(where: { $0.displayID == displayID })?.frame
    }

    private func closestDockTarget(for windowFrame: CGRect, in instance: WindowInstance) -> NotchTarget? {
        let preferences = experimentalPreferences
        guard preferences.dragToNotchEnabled else { return nil }

        let targets = instance.notchTargetsProvider()

        let candidates = targets.map { target in
            // CRITICAL FIX: `target.frame` is the NSPanel frame, which expands dynamically
            // when the UI grid opens, becoming huge.
            // We MUST dock into the closed notch frame exclusively.
            let baseFrame = self.notchFrame(for: target.displayID, in: instance) ?? target.frame
            return TerminalWindowDockingLogic.Candidate(target: target, effectiveFrame: baseFrame)
        }

        return TerminalWindowDockingLogic.closestTarget(
            to: windowFrame,
            sensitivity: CGFloat(preferences.notchDockingSensitivity),
            candidates: candidates
        )
    }
}

extension MetalBlackWindowsManager {
    static func parseDirectoryPath(_ rawDirectory: String) -> String {
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
}
