import SwiftUI
import AppKit
import Combine
import SwiftData

/// A hosting view that passes mouse events specifically if the SwiftUI layer determines it shouldn't catch them.
class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    var model: NotchViewModel?

    private var experimentalStartupOrbEnabled: Bool {
        AppPreferences.experimentalFeatureConfiguration().startupOrbEnabled
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func interactionRects() -> (notchRect: CGRect, orbRect: CGRect?)? {
        guard let model = model else { return nil }
        let hostRect = StartupOrbGeometry.hostRectInPanel(
            panelBounds: bounds,
            model: model,
            shadowPadding: 42
        )
        return (hostRect.insetBy(dx: -20, dy: -20), nil)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let rects = interactionRects() else { return super.hitTest(point) }

        if rects.notchRect.contains(point) || rects.orbRect?.contains(point) == true {
            return super.hitTest(point)
        }
        return nil
    }
}

@MainActor
final class NotchOverlayController {
    private let collapsedNoNotchSize = NSSize(width: 126, height: 26)
    private let expandedSize = NSSize(width: 336, height: 78)
    private let notchClosedWidthScale: CGFloat = 0.92
    private let notchClosedHeightScale: CGFloat = 0.90
    private let shadowPadding: CGFloat = 42
    private let noNotchTopInset: CGFloat = 6
    private let notchTopInset: CGFloat = 0

    private var panelsByDisplay: [CGDirectDisplayID: NSPanel] = [:]
    private var hostsByDisplay: [CGDirectDisplayID: PassthroughHostingView<AnyView>] = [:]
    private var modelsByDisplay: [CGDirectDisplayID: NotchViewModel] = [:]
    private let blackWindowController = MetalBlackWindowsManager()
    private var timer: Timer?
    private var trackingFPS: Int = 60
    private var trackingTickCount: Int = 0
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var scrollEventTap: CFMachPort?
    private var scrollEventTapRunLoopSource: CFRunLoopSource?
    private var lastCursorLocation: CGPoint?
    private var cancellables = Set<AnyCancellable>()
    private var modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    private var lastKeyTime: Date?
    private var lastInteractionTime: Date?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var globalSwipeMonitor: Any?
    private var localSwipeMonitor: Any?
    private var pendingSpaceSwitchResetWorkItem: DispatchWorkItem?
    private var closeWorkItem: DispatchWorkItem?
    private var pendingExpandWorkItems: [CGDirectDisplayID: DispatchWorkItem] = [:]
    private var pendingShrinkWorkItems: [CGDirectDisplayID: DispatchWorkItem] = [:]
    private var pinnedExpandedDisplays: Set<CGDirectDisplayID> = []
    private var dockHoverDisplays: Set<CGDirectDisplayID> = []
    private var commandOrbQueues: [CGDirectDisplayID: [TerminalCommandOrbEvent]] = [:]
    private var commandOrbDismissWorkItems: [CGDirectDisplayID: DispatchWorkItem] = [:]
    private var pendingSessionSaveWorkItem: DispatchWorkItem?

    func start() {
        blackWindowController.onTerminalItemsChanged = { [weak self] items in
            self?.applyTerminalItems(items)
        }
        blackWindowController.onCommandOrbEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.enqueueCommandOrbEvent(event)
            }
        }
        rebuildPanels()
        updateFullScreenAndMenuStatus()
        startGestureMonitoring()
        startMouseTracking()
        startEventMonitoring()
        registerObservers()
        restoreSessions()
        startIPCServer()
    }

    func stop() {
        NotchSocketServer.shared.stop()
        saveSessions()
        timer?.invalidate()
        timer = nil

        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let globalSwipeMonitor {
            NSEvent.removeMonitor(globalSwipeMonitor)
            self.globalSwipeMonitor = nil
        }
        if let localSwipeMonitor {
            NSEvent.removeMonitor(localSwipeMonitor)
            self.localSwipeMonitor = nil
        }

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        if let scrollEventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), scrollEventTapRunLoopSource, .commonModes)
            self.scrollEventTapRunLoopSource = nil
        }
        if let scrollEventTap {
            CFMachPortInvalidate(scrollEventTap)
            self.scrollEventTap = nil
        }

        closeWorkItem?.cancel()
        closeWorkItem = nil
        pendingSessionSaveWorkItem?.cancel()
        pendingSessionSaveWorkItem = nil
        pendingSpaceSwitchResetWorkItem?.cancel()
        pendingSpaceSwitchResetWorkItem = nil
        pendingExpandWorkItems.values.forEach { $0.cancel() }
        pendingExpandWorkItems.removeAll()
        pendingShrinkWorkItems.values.forEach { $0.cancel() }
        pendingShrinkWorkItems.removeAll()
        commandOrbDismissWorkItems.values.forEach { $0.cancel() }
        commandOrbDismissWorkItems.removeAll()
        commandOrbQueues.removeAll()
        for (_, model) in modelsByDisplay {
            model.commandOrbEvent = nil
            model.activeCommandOrbEvent = nil
        }
        pinnedExpandedDisplays.removeAll()

        blackWindowController.closeAllWindows()
    }

    func openBlackWindowForCurrentInteractionScreen() {
        let targetDisplayID = displayIDForCurrentInteractionScreen() ?? CGMainDisplayID()
        openBlackWindow(for: targetDisplayID)
    }

    func openBlackWindow(on screen: NSScreen?) {
        if let screen,
           let displayID = displayID(for: screen) {
            openBlackWindow(for: displayID)
            return
        }

        openBlackWindowForCurrentInteractionScreen()
    }

    func restoreAllWindows() {
        blackWindowController.restoreAllWindows()
    }

    private func restoreSessions() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<TerminalSession>()
        if let sessions = try? modelContext.fetch(descriptor), !sessions.isEmpty {
            let plans = SessionPersistenceLogic.restorePlans(from: sessions)
            for plan in plans {
                blackWindowController.createWindow(
                    displayID: plan.displayID,
                    anchorScreen: screen(forDisplayID: plan.displayID),
                    session: plan.session,
                    notchTargetsProvider: { [weak self] in self?.notchTargets() ?? [] }
                )
                if plan.shouldStartMinimized {
                    blackWindowController.minimizeWindow(id: plan.session.id)
                }
            }
        }
    }

    private func saveSessions() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<TerminalSession>()
        let existingSessions = (try? modelContext.fetch(descriptor)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existingSessions.map { ($0.id, $0) })
        let latestSessions = blackWindowController.currentSessions()
        let latestIDs = Set(latestSessions.map(\.id))

        for existing in existingSessions where !latestIDs.contains(existing.id) {
            modelContext.delete(existing)
        }

        for session in latestSessions {
            if let existing = existingByID[session.id] {
                SessionPersistenceLogic.updatePersistedSession(existing, from: session)
            } else {
                modelContext.insert(session)
            }
        }
        try? modelContext.save()
    }

    private func startEventMonitoring() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.lastKeyTime = Date()
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            self.lastKeyTime = Date()
            if self.handleGlobalShortcut(event) {
                return nil
            }
            return event
        }
        globalSwipeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handlePotentialSpaceSwipe(event)
        }
        localSwipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handlePotentialSpaceSwipe(event)
            return event
        }
    }

    private func startGestureMonitoring() {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard type == .scrollWheel,
                  let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let controller = Unmanaged<NotchOverlayController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            controller.handlePotentialSpaceScrollEvent(event)
            return Unmanaged.passUnretained(event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        scrollEventTap = eventTap
        scrollEventTapRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func startMouseTracking() {
        trackingFPS = preferredTrackingFPS()
        let interval = 1.0 / Double(trackingFPS)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateExpansionAndLayout()
                
                self.trackingTickCount += 1
                // Check full-screen and menu state roughly every 1 second (e.g. at 60fps -> 60 ticks)
                if self.trackingTickCount >= self.trackingFPS {
                    self.trackingTickCount = 0
                    self.updateFullScreenAndMenuStatus()
                }
            }
        }
        // Let the system coalesce timer wakeups a bit for better efficiency.
        timer.tolerance = interval * 0.15
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func restartMouseTrackingIfNeeded() {
        let newFPS = preferredTrackingFPS()
        guard newFPS != trackingFPS else { return }
        timer?.invalidate()
        timer = nil
        startMouseTracking()
    }

    private func preferredTrackingFPS() -> Int {
        let screenRates = NSScreen.screens.map { screen -> Int in
            if #available(macOS 12.0, *) {
                return max(30, screen.maximumFramesPerSecond)
            }
            return 60
        }
        let maxRate = screenRates.max() ?? 60
        // Bound to a sane range for pointer-tracking work.
        return min(max(maxRate, 30), 120)
    }

    private func registerObservers() {
        let center = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSApplication.didChangeScreenParametersNotification,
            NSWindow.didChangeScreenNotification,
            UserDefaults.didChangeNotification
        ]

        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleScreenConfigurationChange()
                }
            }
            observers.append(token)
        }

        let dockHoverToken = center.addObserver(forName: .notchDockHoverChanged, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor [weak self] in
                self?.handleDockHoverNotification(note)
            }
        }
        observers.append(dockHoverToken)

        let activeSpaceToken = workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleActiveSpaceDidChange()
            }
        }
        workspaceObservers.append(activeSpaceToken)
    }

    // MARK: - Panel Management

    private func rebuildPanels() {
        let screens = NSScreen.screens
        let sortedDisplays = screens.compactMap(displayID(for:))
        let displayIDs = Set(sortedDisplays)

        for (displayID, panel) in panelsByDisplay where !displayIDs.contains(displayID) {
            panel.orderOut(nil)
            panelsByDisplay.removeValue(forKey: displayID)
            hostsByDisplay.removeValue(forKey: displayID)
            modelsByDisplay.removeValue(forKey: displayID)
        }

        for screen in screens {
            guard let displayID = displayID(for: screen) else { continue }
            let hasNotch = detectNotch(on: screen)
            let notchHeight = screen.safeAreaInsets.top
            let model = modelsByDisplay[displayID] ?? NotchViewModel()
            model.hasPhysicalNotch = hasNotch
            model.physicalNotchHeight = hasNotch ? max(notchHeight, 32) : 0
            model.ownDisplayID = displayID
            model.availableScreens = sortedDisplays
            
            if !sortedDisplays.indices.contains(model.activeScreenIndex) || (panelsByDisplay[displayID] == nil && model.activeScreenIndex == 0) {
                if let idx = sortedDisplays.firstIndex(of: displayID) {
                    model.activeScreenIndex = idx
                }
            }
            
            modelsByDisplay[displayID] = model

            if panelsByDisplay[displayID] == nil {
                let panel = makePanel(model: model, displayID: displayID)
                panelsByDisplay[displayID] = panel
                hostsByDisplay[displayID] = panel.contentView as? PassthroughHostingView<AnyView>
                hostsByDisplay[displayID]?.model = model

                model.$contentWidth
                    .removeDuplicates()
                    .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
                    .sink { [weak self] _ in
                        self?.layoutPanels(animated: true, displays: [displayID])
                    }
                    .store(in: &cancellables)
            } else {
                hostsByDisplay[displayID]?.rootView = AnyView(
                    makeNotchCapsuleView(for: displayID).environmentObject(model)
                )
            }

            applyNotchVisibility(for: displayID)
        }

        updateFullScreenAndMenuStatus()
        layoutPanels(animated: false)
    }

    private func makePanel(model: NotchViewModel, displayID: CGDirectDisplayID) -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        // For static large window to work, the window itself MUST accept mouse events,
        // but the PassthroughHostingView will reject them if they hit clear pixels!
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient]
        panel.contentView = PassthroughHostingView(
            rootView: AnyView(makeNotchCapsuleView(for: displayID).environmentObject(model))
        )
        (panel.contentView as? PassthroughHostingView<AnyView>)?.model = model
        panel.orderFrontRegardless()
        return panel
    }

    // MARK: - View Factory

    private func makeNotchCapsuleView(for displayID: CGDirectDisplayID) -> AnyView {
        AnyView(
            NotchCapsuleView(
                openBlackWindow: { [weak self] in
                    self?.openBlackWindow(for: displayID)
                },
                reorganizeBlackWindows: { [weak self] in
                    self?.reorganizeBlackWindows(for: displayID)
                },
                restoreBlackWindow: { [weak self] windowID in
                    self?.blackWindowController.restoreWindow(id: windowID)
                },
                bringBlackWindow: { [weak self] windowID in
                    self?.blackWindowController.bringWindow(id: windowID, to: displayID)
                },
                minimizeBlackWindow: { [weak self] windowID in
                    self?.blackWindowController.minimizeWindow(id: windowID)
                },
                closeBlackWindow: { [weak self] windowID in
                    self?.blackWindowController.closeWindow(id: windowID)
                },
                toggleAlwaysOnTop: { [weak self] windowID in
                    self?.blackWindowController.toggleAlwaysOnTopWindow(id: windowID)
                },
                restoreAllWindows: { [weak self] in
                    self?.blackWindowController.restoreAllWindows()
                },
                minimizeAllWindows: { [weak self] in
                    self?.blackWindowController.minimizeAllWindows()
                },
                closeAllWindows: { [weak self] in
                    self?.blackWindowController.closeAllWindows()
                },
                closeAllWindowsOnDisplay: { [weak self] in
                    self?.blackWindowController.closeAllWindows(on: displayID)
                },
                requestCloseAllConfirmation: { [weak self] sourceDisplayID in
                    self?.presentSystemCloseAllAlert(for: sourceDisplayID)
                },
                openSettings: { [weak self] in
                    self?.openSettings(for: displayID)
                }
            )
        )
    }

    // MARK: - Expansion Logic

    private func updateExpansionAndLayout() {
        let cursor = NSEvent.mouseLocation
        if let lastCursorLocation {
            let dx = cursor.x - lastCursorLocation.x
            let dy = cursor.y - lastCursorLocation.y
            if (dx * dx + dy * dy) < 0.25 { return }
        }
        lastCursorLocation = cursor
        var changedDisplays: Set<CGDirectDisplayID> = []

        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen),
                  let model = modelsByDisplay[displayID] else { continue }
            guard AppPreferences.isNotchEnabled(for: displayID) else {
                if model.isExpanded {
                    model.isExpanded = false
                    changedDisplays.insert(displayID)
                }
                pendingExpandWorkItems[displayID]?.cancel()
                pendingExpandWorkItems.removeValue(forKey: displayID)
                continue
            }
                  
            // Only hide the fake notch on full-screen apps.
            if !model.hasPhysicalNotch && model.isFullScreenAppActive {
                if model.isExpanded {
                    model.isExpanded = false
                    changedDisplays.insert(displayID)
                }
                pendingExpandWorkItems[displayID]?.cancel()
                pendingExpandWorkItems.removeValue(forKey: displayID)
                continue
            }

            if pinnedExpandedDisplays.contains(displayID) {
                pendingExpandWorkItems[displayID]?.cancel()
                pendingExpandWorkItems.removeValue(forKey: displayID)
                if !model.isExpanded {
                    model.isExpanded = true
                    changedDisplays.insert(displayID)
                }
                continue
            }

            if dockHoverDisplays.contains(displayID) {
                pendingExpandWorkItems[displayID]?.cancel()
                pendingExpandWorkItems.removeValue(forKey: displayID)
                closeWorkItem?.cancel()
                closeWorkItem = nil
                if !model.isExpanded {
                    model.isExpanded = true
                    changedDisplays.insert(displayID)
                }
                continue
            }

            let accurateActivationRect = notchActivationRect(for: screen, model: model)
            let orbRect = startupOrbScreenRect(for: screen, model: model)
            let isHovering = accurateActivationRect.contains(cursor) && !(orbRect?.contains(cursor) == true)
            var shouldExpand = model.isExpanded

            if isHovering {
                if model.autoOpenOnHover || model.isExpanded {
                    if model.hasPhysicalNotch && !model.isExpanded {
                        scheduleDelayedExpandIfNeeded(displayID: displayID, screen: screen, model: model)
                        shouldExpand = false
                    } else {
                        shouldExpand = true
                    }
                }
            } else {
                pendingExpandWorkItems[displayID]?.cancel()
                pendingExpandWorkItems.removeValue(forKey: displayID)
                if model.isExpanded {
                    let isTyping = model.lockWhileTyping &&
                                   (lastKeyTime?.timeIntervalSinceNow ?? -10) > -1.5

                    // If the mouse has physically strayed very far from the accurate bounding box (e.g. they moved down to codebase)
                    // we forcefully tear down the hover states to avoid SwiftUI .onHover getting stuck.
                    let isFarAway = !accurateActivationRect.insetBy(dx: -40, dy: -40).contains(cursor)
                    
                    if isFarAway && (model.isHoveringPreview || model.isHoveringItem) {
                        DispatchQueue.main.async {
                            model.isHoveringPreview = false
                            model.isHoveringItem = false
                        }
                    }

                    if !model.preventCloseOnMouseLeave && !isTyping && (!model.isHoveringPreview || isFarAway) {
                        shouldExpand = false
                    }
                }
            }

            if shouldExpand != model.isExpanded {
                if shouldExpand {
                    closeWorkItem?.cancel()
                    closeWorkItem = nil
                    model.isExpanded = true
                    changedDisplays.insert(displayID)
                    model.triggerHaptic()
                } else {
                    if closeWorkItem == nil {
                        let workItem = DispatchWorkItem { [weak self, weak model] in
                            guard let self, let model else { return }
                            if model.isExpanded {
                                model.isExpanded = false
                                model.hasPreviewedDuringSession = false
                                self.layoutPanels(animated: true, displays: [displayID], isCollapsing: true)
                            }
                            self.closeWorkItem = nil
                        }
                        closeWorkItem = workItem

                        let delay: Double = model.hasPreviewedDuringSession ? 1.1 : 0.55

                        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
                    }
                }
            } else if shouldExpand {
                closeWorkItem?.cancel()
                closeWorkItem = nil
                pendingExpandWorkItems[displayID]?.cancel()
                pendingExpandWorkItems.removeValue(forKey: displayID)
            }
        }

        if !changedDisplays.isEmpty {
            layoutPanels(animated: true, displays: changedDisplays)
        }
    }

    private func scheduleDelayedExpandIfNeeded(displayID: CGDirectDisplayID, screen: NSScreen, model: NotchViewModel) {
        guard pendingExpandWorkItems[displayID] == nil else { return }

        let workItem = DispatchWorkItem { [weak self, weak model] in
            guard let self, let model else { return }
            guard !model.isExpanded else { return }

            let cursor = NSEvent.mouseLocation
            let rect = self.notchActivationRect(for: screen, model: model)
            guard rect.contains(cursor) else { return }
            guard model.autoOpenOnHover else { return }

            model.isExpanded = true
            model.triggerHaptic()
            self.layoutPanels(animated: true, displays: [displayID])
            self.pendingExpandWorkItems.removeValue(forKey: displayID)
        }

        pendingExpandWorkItems[displayID] = workItem
        let delay = max(0.1, min(3.0, model.autoOpenOnHoverDelay))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    // MARK: - Layout

    private func layoutPanels(animated: Bool, displays: Set<CGDirectDisplayID>? = nil, isCollapsing: Bool = false) {
        let cursor = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen),
                  let panel = panelsByDisplay[displayID],
                  let model = modelsByDisplay[displayID] else { continue }

            if let displays, !displays.contains(displayID) { continue }
            if !AppPreferences.isNotchEnabled(for: displayID) {
                applyNotchVisibility(for: displayID)
                continue
            }
            let frame = frameForPanel(on: screen, model: model)
            panel.ignoresMouseEvents = !shouldAllowMouseEvents(for: model, on: screen, cursor: cursor)

            if animated {
                // We no longer animate AppKit frames at all for the Notch!
                // The frame is now a static interaction zone that covers the maximum
                // possible size of the Notch. The entire visual expansion animation
                // is executed by SwiftUI internally, so it bounces flawlessly!
                // We update it non-animated here, just in case screens changed.
                panel.setFrame(frame, display: true)
            } else {
                panel.setFrame(frame, display: true)
            }
            
            // Only hide the fake notch on full-screen apps.
            if !model.hasPhysicalNotch && model.isFullScreenAppActive {
                panel.alphaValue = 0.0
                panel.ignoresMouseEvents = true
            } else {
                panel.alphaValue = 1.0
            }
            panel.orderFrontRegardless()
        }
    }

    private func frameForPanel(on screen: NSScreen, model: NotchViewModel) -> CGRect {
        let displayID = displayID(for: screen)
        let configuration = notchDisplayConfiguration(for: displayID)
        let constants = overlayGeometryConstants()

        let closedSize = NotchOverlayGeometryLogic.closedSize(
            screenNotchSize: screen.notchSize,
            fallbackNotchSize: collapsedNoNotchSize,
            hasPhysicalNotch: model.hasPhysicalNotch,
            widthOffset: model.notchWidthOffset,
            heightOffset: model.notchHeightOffset,
            configuration: configuration,
            constants: constants
        )

        DispatchQueue.main.async {
            model.closedSize = closedSize
        }

        return NotchOverlayGeometryLogic.panelFrame(
            screenFrame: screen.frame,
            hasPhysicalNotch: model.hasPhysicalNotch,
            configuration: configuration,
            constants: constants
        )
    }

    // MARK: - Activation Geometry

    private func notchActivationRect(for screen: NSScreen, model: NotchViewModel) -> CGRect {
        return NotchOverlayGeometryLogic.activationRect(
            screenFrame: screen.frame,
            panelFrame: frameForPanel(on: screen, model: model),
            closedSize: model.closedSize,
            hasPhysicalNotch: model.hasPhysicalNotch,
            isExpanded: model.isExpanded,
            hardwareNotchRect: hardwareNotchRect(for: screen),
            configuration: notchDisplayConfiguration(for: displayID(for: screen)),
            constants: overlayGeometryConstants()
        )
    }

    private func startupOrbScreenRect(for screen: NSScreen, model: NotchViewModel) -> CGRect? {
        let isEnabled = AppPreferences.experimentalFeatureConfiguration().startupOrbEnabled
        guard isEnabled, !model.hasPhysicalNotch, !model.isExpanded else { return nil }
        let configuration = displayID(for: screen).map { AppPreferences.notchConfiguration(for: $0) }
        let hostRect = StartupOrbGeometry.hostRectOnScreen(
            screenFrame: screen.frame,
            hostWidth: max(26, collapsedNoNotchSize.width + (configuration.map { CGFloat($0.widthAdjustment) } ?? 0)),
            hostHeight: collapsedNoNotchSize.height,
            topInset: noNotchTopInset
        )
        let horizontalOffset = configuration.map { CGFloat($0.offsetX) } ?? 0
        let verticalOffset = configuration.map { CGFloat($0.offsetY) } ?? 0
        return StartupOrbGeometry.detachedFrame(
            alignedTo: hostRect.offsetBy(dx: horizontalOffset, dy: -verticalOffset),
            style: .pill
        )
    }

    private func shouldAllowMouseEvents(for model: NotchViewModel, on screen: NSScreen, cursor: CGPoint) -> Bool {
        NotchOverlayGeometryLogic.shouldAllowMouseEvents(
            hasPhysicalNotch: model.hasPhysicalNotch,
            isExpanded: model.isExpanded,
            screenFrame: screen.frame,
            cursor: cursor,
            startupOrbRect: startupOrbScreenRect(for: screen, model: model),
            configuration: notchDisplayConfiguration(for: displayID(for: screen)),
            constants: overlayGeometryConstants()
        )
    }

    private func topInset(for model: NotchViewModel) -> CGFloat {
        if model.hasPhysicalNotch {
            return notchTopInset
        }
        return noNotchTopInset
    }

    private func hardwareNotchRect(for screen: NSScreen) -> CGRect {
        NotchOverlayGeometryLogic.hardwareNotchRect(
            screenFrame: screen.frame,
            notchSize: screen.notchSize,
            notchTopInset: notchTopInset
        )
    }

    private func notchDisplayConfiguration(for displayID: CGDirectDisplayID?) -> NotchOverlayGeometryLogic.DisplayConfiguration {
        let configuration = displayID.map { AppPreferences.notchConfiguration(for: $0) }
        return .init(
            offsetX: CGFloat(configuration?.offsetX ?? 0),
            offsetY: CGFloat(configuration?.offsetY ?? 0),
            widthAdjustment: CGFloat(configuration?.widthAdjustment ?? 0)
        )
    }

    private func overlayGeometryConstants() -> NotchOverlayGeometryLogic.Constants {
        .init(
            collapsedNoNotchSize: collapsedNoNotchSize,
            notchClosedWidthScale: notchClosedWidthScale,
            notchClosedHeightScale: notchClosedHeightScale,
            shadowPadding: shadowPadding,
            noNotchTopInset: noNotchTopInset,
            notchTopInset: notchTopInset
        )
    }

    // MARK: - Black Window Integration

    private func openBlackWindow(for displayID: CGDirectDisplayID) {
        blackWindowController.createWindow(
            displayID: displayID,
            anchorScreen: screen(forDisplayID: displayID),
            notchTargetsProvider: { [weak self] in self?.notchTargets() ?? [] }
        )
    }

    private func reorganizeBlackWindows(for displayID: CGDirectDisplayID) {
        blackWindowController.reorganizeVisibleWindows(
            on: displayID,
            screen: screen(forDisplayID: displayID)
        )
    }

    private func openSettings(for displayID: CGDirectDisplayID) {
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyTerminalItems(_ items: [TerminalWindowItem]) {
        let sortedItems = items.sorted { $0.number < $1.number }
        for (_, model) in modelsByDisplay {
            model.terminalItems = sortedItems
        }
        scheduleSessionSave()
    }

    private func scheduleSessionSave() {
        pendingSessionSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveSessions()
            self?.pendingSessionSaveWorkItem = nil
        }
        pendingSessionSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    private func enqueueCommandOrbEvent(_ event: TerminalCommandOrbEvent) {
        guard let model = modelsByDisplay[event.displayID] else { return }

        let update = NotchCommandOrbLogic.enqueue(
            event: event,
            isStartupOrbEnabled: AppPreferences.experimentalFeatureConfiguration().startupOrbEnabled,
            isNotchEnabled: AppPreferences.isNotchEnabled(for: event.displayID),
            existingQueue: commandOrbQueues[event.displayID, default: []],
            activeEvent: model.activeCommandOrbEvent,
            displayedEvent: model.commandOrbEvent
        )

        guard !update.shouldIgnore else { return }
        model.activeCommandOrbEvent = update.activeEvent
        commandOrbQueues[event.displayID] = update.queuedEvents

        if event.isPersistent && event.status == .running {
            return
        }

        if let displayedEvent = update.displayedEvent, model.commandOrbEvent == nil {
            model.commandOrbEvent = displayedEvent
            scheduleCommandOrbDismiss(for: event.displayID, event: displayedEvent)
        }
    }

    private func showNextCommandOrbEvent(on displayID: CGDirectDisplayID) {
        guard var queue = commandOrbQueues[displayID], !queue.isEmpty,
              let model = modelsByDisplay[displayID] else { return }

        let nextEvent = queue.removeFirst()
        commandOrbQueues[displayID] = queue
        model.commandOrbEvent = nextEvent

        commandOrbDismissWorkItems[displayID]?.cancel()
        scheduleCommandOrbDismiss(for: displayID, event: nextEvent)
    }

    private func scheduleCommandOrbDismiss(for displayID: CGDirectDisplayID, event: TerminalCommandOrbEvent) {
        commandOrbDismissWorkItems[displayID]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let model = self.modelsByDisplay[displayID] else { return }
            let update = NotchCommandOrbLogic.dismiss(
                displayedEvent: model.commandOrbEvent,
                queue: self.commandOrbQueues[displayID, default: []]
            )
            model.commandOrbEvent = update.displayedEvent
            self.commandOrbQueues[displayID] = update.queuedEvents
            self.commandOrbDismissWorkItems[displayID] = nil
            if let nextEvent = update.displayedEvent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                    self?.scheduleCommandOrbDismiss(for: displayID, event: nextEvent)
                }
            }
        }
        commandOrbDismissWorkItems[displayID] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + event.duration, execute: workItem)
    }

    private func handleGlobalShortcut(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains([.command, .option]) else { return false }
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        switch key {
        case "k":
            blackWindowController.closeAllWindows()
            return true
        case "m":
            blackWindowController.minimizeAllWindows()
            return true
        case "r":
            blackWindowController.restoreAllWindows()
            return true
        default:
            return false
        }
    }

    private func presentSystemCloseAllAlert(for sourceDisplayID: CGDirectDisplayID) {
        let terminalCount = modelsByDisplay.values.first?.terminalItems.count ?? 0
        guard terminalCount > 0 else { return }
        pinDisplayExpanded(sourceDisplayID)

        let alert = NSAlert()
        alert.messageText = "Close all terminals?"
        alert.informativeText = "Close \(terminalCount) terminal\(terminalCount == 1 ? "" : "s")?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Close All")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if alert.suppressionButton?.state == .on {
            AppPreferences.setConfirmBeforeCloseAll(false)
        }
        if response == .alertFirstButtonReturn {
            blackWindowController.closeAllWindows()
        }

        unpinDisplayExpanded(sourceDisplayID)
    }

    private func pinDisplayExpanded(_ displayID: CGDirectDisplayID) {
        pinnedExpandedDisplays.insert(displayID)
        if let model = modelsByDisplay[displayID] {
            model.isExpanded = true
        }
        layoutPanels(animated: false, displays: [displayID])
    }

    private func unpinDisplayExpanded(_ displayID: CGDirectDisplayID) {
        pinnedExpandedDisplays.remove(displayID)
        layoutPanels(animated: false, displays: [displayID])
    }
    
    // MARK: - Full Screen Detection
    
    private func updateFullScreenAndMenuStatus() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        var candidateWindowBounds: [CGRect] = []
        
        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? Int32,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }
            
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            if layer < 0 { continue } // Ignore desktop backdrops naturally

            // For full screen checks, we only care about other apps
            if pid != myPID {
                candidateWindowBounds.append(bounds)
            }
        }
        
        var layoutNeeded = false
        
        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen),
                  let model = modelsByDisplay[displayID] else { continue }
            
            let displayBounds = CGDisplayBounds(displayID)
            var isCovered = false
            
            for rect in candidateWindowBounds {
                if windowBounds(rect, approximatelyMatchFullScreenDisplay: displayBounds) {
                    isCovered = true
                    break
                }
            }
            
            let shouldHideForFullScreen = !model.hasPhysicalNotch && isCovered

            if model.isFullScreenAppActive != shouldHideForFullScreen {
                model.isFullScreenAppActive = shouldHideForFullScreen
                layoutNeeded = true
                if shouldHideForFullScreen && model.isExpanded {
                    model.isExpanded = false
                }
            }
        }
        
        if layoutNeeded {
            layoutPanels(animated: true)
        }
    }

    private func windowBounds(_ windowBounds: CGRect, approximatelyMatchFullScreenDisplay displayBounds: CGRect) -> Bool {
        let tolerance: CGFloat = 6.0

        return abs(windowBounds.minX - displayBounds.minX) <= tolerance &&
               abs(windowBounds.maxX - displayBounds.maxX) <= tolerance &&
               abs(windowBounds.minY - displayBounds.minY) <= tolerance &&
               abs(windowBounds.maxY - displayBounds.maxY) <= tolerance
    }

    private func handleScreenConfigurationChange() {
        DispatchQueue.main.async { [weak self] in
            self?.rebuildPanels()
            self?.blackWindowController.reconcileDisplays()
            self?.restartMouseTrackingIfNeeded()
        }
    }

    private func applyNotchVisibility(for displayID: CGDirectDisplayID) {
        guard let panel = panelsByDisplay[displayID],
              let model = modelsByDisplay[displayID] else { return }

        if AppPreferences.isNotchEnabled(for: displayID) {
            panel.alphaValue = 1.0
            panel.ignoresMouseEvents = false
            panel.orderFrontRegardless()
        } else {
            model.isExpanded = false
            panel.alphaValue = 0.0
            panel.ignoresMouseEvents = true
            panel.orderOut(nil)
        }
    }

    private func handleDockHoverNotification(_ note: Notification) {
        guard let userInfo = note.userInfo,
              let displayID = userInfo["displayID"] as? CGDirectDisplayID,
              let isHovering = userInfo["isHovering"] as? Bool,
              let model = modelsByDisplay[displayID] else { return }

        if isHovering {
            dockHoverDisplays.insert(displayID)
            pendingExpandWorkItems[displayID]?.cancel()
            pendingExpandWorkItems.removeValue(forKey: displayID)
            closeWorkItem?.cancel()
            closeWorkItem = nil
            if !model.isExpanded {
                model.isExpanded = true
            }
        } else {
            dockHoverDisplays.remove(displayID)
        }

        layoutPanels(animated: true, displays: [displayID])
    }

    private func handleActiveSpaceDidChange() {
        let eligibleDisplays = physicalNotchDisplayIDs()
        guard !eligibleDisplays.isEmpty else { return }

        scheduleSpaceSwitchReset(after: 0.03, displayIDs: eligibleDisplays)
    }

    private func handlePotentialSpaceSwipe(_ event: NSEvent) {
        let phase = event.phase
        let momentumPhase = event.momentumPhase
        let isGesturePhase = phase.contains(.began) || phase.contains(.changed) || phase.contains(.mayBegin)
        let isMomentumPhase = momentumPhase.contains(.began) || momentumPhase.contains(.changed)
        guard isGesturePhase || isMomentumPhase else { return }

        let horizontalMagnitude = abs(event.deltaX)
        let verticalMagnitude = abs(event.deltaY)
        let preciseHorizontalMagnitude = abs(event.scrollingDeltaX)
        let preciseVerticalMagnitude = abs(event.scrollingDeltaY)
        let dominantHorizontal = max(horizontalMagnitude, preciseHorizontalMagnitude)
        let dominantVertical = max(verticalMagnitude, preciseVerticalMagnitude)
        let isEarlyGesturePhase = phase.contains(.began) || phase.contains(.mayBegin)
        let requiredHorizontalMagnitude: CGFloat = isEarlyGesturePhase ? 0.15 : 1.0
        guard dominantHorizontal > dominantVertical * 1.2, dominantHorizontal > requiredHorizontalMagnitude else { return }

        let eligibleDisplays = physicalNotchDisplayIDs()
        guard !eligibleDisplays.isEmpty else { return }

        setSpaceSwitching(true, displayIDs: eligibleDisplays)
        scheduleSpaceSwitchReset(after: 1.0, displayIDs: eligibleDisplays)
    }

    private func handlePotentialSpaceScrollEvent(_ event: CGEvent) {
        _ = event
    }

    private func physicalNotchDisplayIDs() -> [CGDirectDisplayID] {
        modelsByDisplay.compactMap { displayID, model in
            model.hasPhysicalNotch ? displayID : nil
        }
    }

    private func setSpaceSwitching(_ isSwitching: Bool, displayIDs: [CGDirectDisplayID]) {
        for displayID in displayIDs {
            modelsByDisplay[displayID]?.isSwitchingSpace = isSwitching
            guard let panel = panelsByDisplay[displayID] else { continue }
            panel.alphaValue = isSwitching ? 0 : 1
            if !isSwitching {
                panel.orderFrontRegardless()
            }
        }
    }

    private func scheduleSpaceSwitchReset(after delay: TimeInterval, displayIDs: [CGDirectDisplayID]) {
        pendingSpaceSwitchResetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.setSpaceSwitching(false, displayIDs: displayIDs)
            self.pendingSpaceSwitchResetWorkItem = nil
        }
        pendingSpaceSwitchResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func displayID(from raw: String) -> CGDirectDisplayID {
        SessionPersistenceLogic.resolvedDisplayID(from: raw)
    }

    private func notchTargets() -> [MetalBlackWindowsManager.NotchTarget] {
        panelsByDisplay.compactMap { key, _ in
            guard let screen = screen(forDisplayID: key),
                  let model = modelsByDisplay[key] else { return nil }

            let size = model.closedSize
            let topInset: CGFloat = model.hasPhysicalNotch ? notchTopInset : noNotchTopInset
            let configuration = AppPreferences.notchConfiguration(for: key)
            let horizontalOffset = CGFloat(configuration.offsetX)
            let verticalOffset = CGFloat(configuration.offsetY)
            let origin = CGPoint(
                x: screen.frame.midX - size.width / 2.0 + horizontalOffset,
                y: screen.frame.maxY - size.height - topInset - verticalOffset
            )
            return MetalBlackWindowsManager.NotchTarget(displayID: key, frame: CGRect(origin: origin, size: size))
        }
    }

    private func startIPCServer() {
        NotchSocketServer.shared.start { [weak self] ipcEvent in
            DispatchQueue.main.async {
                self?.handleIPCEvent(ipcEvent)
            }
        }
    }

    private func handleIPCEvent(_ ipcEvent: NotchIPCEvent) {
        let statusMap: [String: TerminalCommandOrbStatus] = [
            "running": .running,
            "success": .success,
            "error": .error
        ]
        
        var kind: TerminalCommandOrbKind = .generic
        if let tool = ipcEvent.tool?.lowercased() {
            if tool.contains("npm") || tool.contains("yarn") || tool.contains("pnpm") { kind = .package }
            else if tool.contains("git") { kind = .git }
            else if tool.contains("build") || tool.contains("xcodebuild") || tool.contains("cargo") { kind = .build }
            else if tool.contains("test") || tool.contains("jest") || tool.contains("pytest") { kind = .test }
            else if tool.contains("curl") || tool.contains("wget") { kind = .download }
        }
        
        let status = statusMap[ipcEvent.status?.lowercased() ?? ""] ?? .running
        let currentItems = self.modelsByDisplay.values.first?.terminalItems ?? []
        let activeItem = currentItems.first(where: { $0.isActive }) ?? currentItems.first
        
        let targetDisplayID: CGDirectDisplayID
        if let id = ipcEvent.displayID {
            targetDisplayID = CGDirectDisplayID(id)
        } else {
            targetDisplayID = activeItem?.displayID ?? CGMainDisplayID()
        }
        
        let terminalNumber = ipcEvent.terminalNumber ?? activeItem?.number ?? 0
        
        let event = TerminalCommandOrbEvent(
            displayID: targetDisplayID,
            terminalNumber: terminalNumber,
            kind: kind,
            status: status,
            command: ipcEvent.message ?? ipcEvent.tool ?? "IPC Task",
            duration: 3.0,
            isPersistent: status == .running
        )
        
        self.enqueueCommandOrbEvent(event)
    }

    // MARK: - Utilities

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func displayIDForCurrentInteractionScreen() -> CGDirectDisplayID? {
        let interactionPoint = NSEvent.mouseLocation

        if let hoveredScreen = NSScreen.screens.first(where: { $0.frame.contains(interactionPoint) }),
           let hoveredDisplayID = displayID(for: hoveredScreen) {
            return hoveredDisplayID
        }

        if let mainScreen = NSScreen.main,
           let mainDisplayID = displayID(for: mainScreen) {
            return mainDisplayID
        }

        return panelsByDisplay.keys.sorted().first
    }

    private func detectNotch(on screen: NSScreen) -> Bool {
        guard #available(macOS 12.0, *) else { return false }
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        let blockedWidth = screen.frame.width - left.width - right.width
        return blockedWidth > 20 && min(left.height, right.height) > 0
    }

    private func screen(forDisplayID targetDisplayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { displayID(for: $0) == targetDisplayID }
    }
}
