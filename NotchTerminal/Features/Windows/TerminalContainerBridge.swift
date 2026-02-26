import SwiftUI
import AppKit
import SwiftTerm
import Darwin

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
    private var wheelMonitor: Any?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // Preserve shell autocomplete regardless of focus chain quirks.
        if event.keyCode == 48, modifiers.isEmpty {
            let tab: [UInt8] = [0x09]
            send(source: self, data: tab[...])
            return true
        }

        guard modifiers == [.command], let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "c":
            copy(self)
            return true
        case "v":
            paste(self)
            return true
        case "a":
            selectAll(self)
            return true
        case "k":
            clearBuffer(nil)
            return true
        case "f":
            searchAction(nil)
            return true
        case "w":
            closeTerminalSession(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func send(source: TerminalView, data: ArraySlice<UInt8>) {
        super.send(source: source, data: data)

        for byte in data {
            switch byte {
            case 10, 13:
                let command = currentInputLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if !command.isEmpty {
                    commandSubmitted?(command)
                }
                currentInputLine = ""
            case 8, 127:
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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installWheelForwardMonitorIfNeeded()
    }

    deinit {
        if let wheelMonitor {
            NSEvent.removeMonitor(wheelMonitor)
        }
    }

    override func viewDidEndLiveResize() {
        isInLiveResize = false
        super.viewDidEndLiveResize()
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
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func installWheelForwardMonitorIfNeeded() {
        guard wheelMonitor == nil else { return }

        wheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else {
                return event
            }

            guard self.allowMouseReporting else { return event }
            let terminal = self.getTerminal()
            guard terminal.mouseMode != .off else { return event }

            let point: CGPoint = {
                if event.window === self.window {
                    return self.convert(event.locationInWindow, from: nil)
                }
                if let window = self.window {
                    return self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                }
                return .init(x: -1, y: -1)
            }()
            guard self.bounds.contains(point) else { return event }

            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
            guard delta != 0 else { return event }

            let cols = max(1, terminal.cols)
            let rows = max(1, terminal.rows)
            let cellWidth = max(1.0, self.bounds.width / CGFloat(cols))
            let cellHeight = max(1.0, self.bounds.height / CGFloat(rows))
            let col = max(0, min(cols - 1, Int(point.x / cellWidth)))
            let rowFromTop = Int((self.bounds.height - point.y) / cellHeight)
            let row = max(0, min(rows - 1, rowFromTop))

            let flags = event.modifierFlags
            let button = delta > 0 ? 4 : 5
            let buttonFlags = terminal.encodeButton(
                button: button,
                release: false,
                shift: flags.contains(.shift),
                meta: flags.contains(.option),
                control: flags.contains(.control)
            )
            terminal.sendEvent(buttonFlags: buttonFlags, x: col, y: row, pixelX: Int(point.x), pixelY: Int(point.y))
            return event
        }
    }

    func ensureWheelForwardingMonitor() {
        installWheelForwardMonitorIfNeeded()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.allowsContextMenuPlugIns = false

        let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = self
        copyItem.isEnabled = true
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: "Paste", action: #selector(paste(_:)), keyEquivalent: "v")
        pasteItem.keyEquivalentModifierMask = [.command]
        pasteItem.target = self
        pasteItem.isEnabled = true
        menu.addItem(pasteItem)

        menu.addItem(.separator())
        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "a")
        selectAllItem.keyEquivalentModifierMask = [.command]
        selectAllItem.target = self
        selectAllItem.isEnabled = true
        menu.addItem(selectAllItem)

        menu.addItem(.separator())
        let clearItem = NSMenuItem(title: "Clear Buffer", action: #selector(clearBuffer(_:)), keyEquivalent: "k")
        clearItem.keyEquivalentModifierMask = [.command]
        clearItem.target = self
        clearItem.isEnabled = true
        menu.addItem(clearItem)

        let searchItem = NSMenuItem(title: "Search", action: #selector(searchAction(_:)), keyEquivalent: "f")
        searchItem.keyEquivalentModifierMask = [.command]
        searchItem.target = self
        searchItem.isEnabled = true
        menu.addItem(searchItem)

        menu.addItem(.separator())
        let closeItem = NSMenuItem(title: "Close", action: #selector(closeTerminalSession(_:)), keyEquivalent: "w")
        closeItem.keyEquivalentModifierMask = [.command]
        closeItem.target = self
        closeItem.isEnabled = true
        menu.addItem(closeItem)

        return menu
    }

    @objc func clearBuffer(_ sender: Any?) {
        let clearCommand = Array("clear\n".utf8)
        send(source: self, data: clearCommand[...])
        window?.makeFirstResponder(self)
    }

    @objc func closeTerminalSession(_ sender: Any?) {
        let exitCommand = Array("exit\n".utf8)
        send(source: self, data: exitCommand[...])
        window?.makeFirstResponder(self)
    }

    @objc func searchAction(_ sender: Any?) {
        let reverseSearch: [UInt8] = [0x12]
        send(source: self, data: reverseSearch[...])
        window?.makeFirstResponder(self)
    }

    func terminateProcessTree() {
        let pid = process.shellPid
        guard pid > 0 else {
            terminate()
            return
        }

        _ = kill(-pid, SIGHUP)
        _ = kill(-pid, SIGTERM)
        _ = kill(pid, SIGTERM)

        terminate()

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.35) {
            _ = kill(-pid, SIGKILL)
            _ = kill(pid, SIGKILL)
        }
    }
}

struct WindowDragRegionView: NSViewRepresentable {
    func makeNSView(context: Context) -> DragRegionNSView {
        DragRegionNSView(frame: .zero)
    }

    func updateNSView(_ nsView: DragRegionNSView, context: Context) {}
}

final class DragRegionNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        window.performDrag(with: event)
    }
}

struct SwiftTermContainerView: NSViewRepresentable {
    let windowNumber: Int
    let fontSize: CGFloat
    let currentDirectory: String
    let preferMouseReporting: Bool
    let commandSubmitted: (String) -> Void
    let directoryChanged: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = DetectingLocalProcessTerminalView(frame: .zero)
        terminal.ensureWheelForwardingMonitor()
        terminal.commandSubmitted = commandSubmitted
        terminal.registerForDraggedTypes([.fileURL])
        terminal.processDelegate = context.coordinator
        context.coordinator.onDirectoryChanged = directoryChanged
        terminal.font = preferredTerminalFont(size: fontSize)
        terminal.nativeBackgroundColor = .black
        terminal.nativeForegroundColor = .white
        terminal.allowMouseReporting = true
        terminal.wantsLayer = true
        terminal.layer?.backgroundColor = NSColor.black.cgColor
        context.coordinator.windowNumber = windowNumber
        context.coordinator.currentDirectory = Self.validatedWorkingDirectory(currentDirectory)
        context.coordinator.tryStartProcessIfNeeded(on: terminal)
        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }
        return terminal
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        nsView.font = preferredTerminalFont(size: fontSize)
        nsView.allowMouseReporting = true
        (nsView as? DetectingLocalProcessTerminalView)?.ensureWheelForwardingMonitor()
        context.coordinator.windowNumber = windowNumber
        context.coordinator.currentDirectory = Self.validatedWorkingDirectory(currentDirectory)
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
        var currentDirectory: String = NSHomeDirectory()
        var onDirectoryChanged: ((String) -> Void)?

        func tryStartProcessIfNeeded(on terminal: LocalProcessTerminalView) {
            guard !processStarted else { return }

            if terminal.window != nil, terminal.bounds.width > 120, terminal.bounds.height > 90 {
                let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
                terminal.startProcess(
                    executable: shell,
                    args: ["-l"],
                    currentDirectory: SwiftTermContainerView.validatedWorkingDirectory(currentDirectory)
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

    private static func validatedWorkingDirectory(_ raw: String) -> String {
        let fallback = NSHomeDirectory()
        let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.hasPrefix("/"), candidate != "/" else { return fallback }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return fallback
        }
        return candidate
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
