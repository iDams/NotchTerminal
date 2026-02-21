import SwiftUI
import AppKit
import Combine

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
    private var hostsByDisplay: [CGDirectDisplayID: NSHostingView<AnyView>] = [:]
    private var modelsByDisplay: [CGDirectDisplayID: NotchViewModel] = [:]
    private let blackWindowController = MetalBlackWindowsManager()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lastCursorLocation: CGPoint?
    private var cancellables = Set<AnyCancellable>()

    private var lastKeyTime: Date?
    private var lastInteractionTime: Date?
    private var eventMonitor: Any?
    private var closeWorkItem: DispatchWorkItem?
    private var pendingShrinkWorkItems: [CGDirectDisplayID: DispatchWorkItem] = [:]

    func start() {
        blackWindowController.onTerminalItemsChanged = { [weak self] items in
            self?.applyTerminalItems(items)
        }
        rebuildPanels()
        startMouseTracking()
        startEventMonitoring()
        registerObservers()
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        closeWorkItem?.cancel()
        closeWorkItem = nil
        pendingShrinkWorkItems.values.forEach { $0.cancel() }
        pendingShrinkWorkItems.removeAll()

        blackWindowController.closeAllWindows()
    }

    private func startEventMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.lastKeyTime = Date()
        }
    }

    private func startMouseTracking() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.updateExpansionAndLayout()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func registerObservers() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didChangeScreenParametersNotification,
            NSWindow.didChangeScreenNotification
        ]

        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.rebuildPanels()
                    self?.blackWindowController.reconcileDisplays()
                }
            }
            observers.append(token)
        }
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
            let model = modelsByDisplay[displayID] ?? NotchViewModel()
            model.hasPhysicalNotch = hasNotch
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
                hostsByDisplay[displayID] = panel.contentView as? NSHostingView<AnyView>

                model.$contentWidth
                    .removeDuplicates()
                    .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
                    .sink { [weak self] _ in
                        self?.layoutPanels(animated: true, displays: [displayID])
                    }
                    .store(in: &cancellables)
            } else {
                hostsByDisplay[displayID]?.rootView = AnyView(
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
                        openSettings: { [weak self] in
                            self?.openSettings(for: displayID)
                        }
                    )
                        .environmentObject(model)
                )
            }
        }

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
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(
            rootView: AnyView(
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
                    openSettings: { [weak self] in
                        self?.openSettings(for: displayID)
                    }
                )
                    .environmentObject(model)
            )
        )
        panel.orderFrontRegardless()
        return panel
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

            let visualTargetWidth = min(max(model.contentWidth + (model.contentPadding * 2), 680), 1100)
            let currentWidth = model.isExpanded ? visualTargetWidth : collapsedNoNotchSize.width
            let currentHeight = model.isExpanded ? 160.0 : collapsedNoNotchSize.height
            let topInset = model.hasPhysicalNotch ? notchTopInset : noNotchTopInset
            let activationPadding: CGFloat = model.isExpanded ? 10 : 20
            
            let accurateActivationRect = CGRect(
                x: screen.frame.midX - (currentWidth / 2) - activationPadding,
                y: screen.frame.maxY - currentHeight - topInset - activationPadding,
                width: currentWidth + (activationPadding * 2),
                height: currentHeight + topInset + (activationPadding * 2)
            )

            let isHovering = accurateActivationRect.contains(cursor)
            var shouldExpand = model.isExpanded

            if isHovering {
                if model.autoOpenOnHover || model.isExpanded {
                    shouldExpand = true
                }
            } else {
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
            }
        }

        if !changedDisplays.isEmpty {
            layoutPanels(animated: true, displays: changedDisplays)
        }
    }

    // MARK: - Layout

    private func layoutPanels(animated: Bool, displays: Set<CGDirectDisplayID>? = nil, isCollapsing: Bool = false) {
        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen),
                  let panel = panelsByDisplay[displayID],
                  let model = modelsByDisplay[displayID] else { continue }

            if let displays, !displays.contains(displayID) { continue }
            let frame = frameForPanel(on: screen, model: model)
            panel.ignoresMouseEvents = !model.isExpanded

            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = model.isExpanded ? 0.25 : 0.20
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(frame, display: true)
                }
            } else {
                panel.setFrame(frame, display: true)
            }
        }
    }

    private func frameForPanel(on screen: NSScreen, model: NotchViewModel) -> CGRect {
        let hasNotch = model.hasPhysicalNotch
        let isExpanded = model.isExpanded
        let contentWidth = model.contentWidth

        let closedSize: NSSize = {
            guard hasNotch else { return collapsedNoNotchSize }
            let raw = screen.notchSizeOrFallback(fallback: collapsedNoNotchSize)
            return NSSize(
                width: max(92, raw.width * notchClosedWidthScale + model.notchWidthOffset),
                height: max(22, raw.height * notchClosedHeightScale + model.notchHeightOffset)
            )
        }()

        let visualSize: NSSize
        if isExpanded {
            let minWidth: CGFloat = 680
            let maxWidth: CGFloat = 1100
            let targetWidth = min(max(contentWidth + (model.contentPadding * 2), minWidth), maxWidth)
            visualSize = NSSize(width: targetWidth, height: 160)
        } else {
            visualSize = closedSize
        }
        
        let shoulderExtra: CGFloat = hasNotch ? (isExpanded ? 14 : 6) * 2 : 0

        // Extend 2px up into the bezel when expanded to hide transparency gaps
        let topOvershoot: CGFloat = (isExpanded && hasNotch) ? 2.0 : 0.0

        let panelSize = NSSize(width: visualSize.width + shoulderExtra + (shadowPadding * 2), height: visualSize.height + topOvershoot + (shadowPadding * 2))
        let topInset = hasNotch ? notchTopInset : noNotchTopInset

        let visualOrigin = CGPoint(
            x: screen.frame.midX - (visualSize.width + shoulderExtra) / 2.0,
            y: screen.frame.maxY - visualSize.height - topInset
        )

        return CGRect(
            x: visualOrigin.x - shadowPadding,
            y: visualOrigin.y - shadowPadding,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    // MARK: - Activation Geometry

    private func notchActivationRect(for screen: NSScreen, model: NotchViewModel) -> CGRect {
        let hasNotch = model.hasPhysicalNotch

        if model.isExpanded {
            // While expanded, keep a larger interaction zone so moving to previews
            // does not immediately collapse the notch.
            let expandedFrame = frameForPanel(on: screen, model: model)
            return expandedFrame.insetBy(dx: -54, dy: -76)
        }

        let notchRect = hardwareNotchRect(for: screen)
        if hasNotch && notchRect != .zero {
            // Tight hover region to avoid accidental expansions when the cursor
            // passes near the top edge (browser tabs/menu bar area).
            return notchRect.insetBy(dx: -22, dy: -14)
        }

        let virtual = CGRect(
            x: screen.frame.midX - collapsedNoNotchSize.width / 2,
            y: screen.frame.maxY - collapsedNoNotchSize.height - noNotchTopInset,
            width: collapsedNoNotchSize.width,
            height: collapsedNoNotchSize.height
        )
        // Keep fake-notch activation compact for non-notch displays.
        return virtual.insetBy(dx: -18, dy: -12)
    }

    private func hardwareNotchRect(for screen: NSScreen) -> CGRect {
        let size = screen.notchSize
        guard size != .zero else { return .zero }
        return CGRect(
            x: screen.frame.midX - size.width / 2.0,
            y: screen.frame.maxY - size.height - notchTopInset,
            width: size.width,
            height: size.height
        )
    }

    // MARK: - Black Window Integration

    private func openBlackWindow(for displayID: CGDirectDisplayID) {
        blackWindowController.createWindow(
            displayID: displayID,
            anchorScreen: screen(forDisplayID: displayID),
            notchTargetsProvider: { [weak self] in
                guard let self else { return [] }
                return self.panelsByDisplay.map { key, panel in
                    MetalBlackWindowsManager.NotchTarget(displayID: key, frame: panel.frame)
                }
            }
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
        for (_, model) in modelsByDisplay {
            model.terminalItems = items.sorted { $0.number < $1.number }
        }
    }

    // MARK: - Utilities

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
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
