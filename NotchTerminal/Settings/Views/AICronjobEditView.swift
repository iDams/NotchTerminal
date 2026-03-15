import Foundation
import AppKit
import SwiftUI

private let notchTerminalConnectedAppTokenUTType = NSPasteboard.PasteboardType("com.notchterminal.connected-app-token")

struct AICronjobEditView: View {
    @Binding var cronjob: AICronjob
    var providers: [AIProvider] = []
    var isNew: Bool
    var minimumHeight: CGFloat = 560
    var isImprovingPrompt: Bool = false
    var onImprovePrompt: (() -> Void)? = nil
    var onConfigurePermissions: (() -> Void)? = nil
    var onViewLogs: (() -> Void)? = nil
    var onSave: () -> Void
    var onCancel: (() -> Void)? = nil

    @State private var showCustomCron = false
    @State private var promptEditorHeight: CGFloat = 140
    @State private var renderedPrompt = NSAttributedString(string: "")
    private let presetCrons = ["* * * * *", "*/5 * * * *", "*/15 * * * *", "*/30 * * * *", "0 * * * *", "0 */6 * * *", "0 */12 * * *", "0 0 * * *"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Form {
                Section {
                    TextField("Agent Job Name", text: $cronjob.name)

                    TextField("Short description", text: $cronjob.detail, axis: .vertical)
                        .lineLimit(2...3)

                    Picker("Execution Mode", selection: $cronjob.mode) {
                        Text("App Timer (Seconds)").tag(AICronjobExecutionMode.app)
                        Text("Machine Daemon").tag(AICronjobExecutionMode.machine)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)

                    if cronjob.mode == .app {
                        HStack {
                            Text("Interval (Seconds)")
                            Spacer()
                            TextField("", value: $cronjob.interval, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)

                            Stepper("", value: $cronjob.interval, in: 10...3600, step: 5)
                                .labelsHidden()
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            if showCustomCron {
                                TextField("Cron Expression", text: $cronjob.cronExpression)
                                    .textFieldStyle(.roundedBorder)
                                Text("Format: M H D m W (e.g. '0 * * * *' for every hour)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Picker("Interval", selection: $cronjob.cronExpression) {
                                    Text("Every 1 Minute").tag("* * * * *")
                                    Text("Every 5 Minutes").tag("*/5 * * * *")
                                    Text("Every 15 Minutes").tag("*/15 * * * *")
                                    Text("Every 30 Minutes").tag("*/30 * * * *")
                                    Text("Every 1 Hour").tag("0 * * * *")
                                    Text("Every 6 Hours").tag("0 */6 * * *")
                                    Text("Every 12 Hours").tag("0 */12 * * *")
                                    Text("Every Day (Midnight)").tag("0 0 * * *")
                                }
                                .pickerStyle(.menu)
                            }

                            Toggle("Advanced Custom Cron", isOn: $showCustomCron)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .onAppear {
                            if !presetCrons.contains(cronjob.cronExpression) {
                                showCustomCron = true
                            }
                        }
                    }
                }

                Section(header: Text("Prompt & Safety")) {
                    if !providers.isEmpty {
                        Picker("Provider", selection: providerSelectionBinding) {
                            Text("Use active provider").tag("")
                            ForEach(providers) { provider in
                                Text(provider.name).tag(provider.id.uuidString)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    connectedAppsSection

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 10) {
                            Text("System Prompt")
                                .font(.subheadline)

                            Spacer(minLength: 0)

                            if let onImprovePrompt {
                                Button(action: onImprovePrompt) {
                                    if isImprovingPrompt {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Label("Improve Prompt", systemImage: "wand.and.stars")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isImprovingPrompt || cronjob.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        CronjobPromptEditor(
                            text: $cronjob.prompt,
                            attributedText: $renderedPrompt,
                            placeholder: "Describe what this job should do",
                            dynamicHeight: $promptEditorHeight,
                            onInsertToken: insertConnectedAppToken
                        )
                        .frame(height: promptEditorHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 10) {
                        if let onConfigurePermissions {
                            Button(action: onConfigurePermissions) {
                                Label(permissionSummaryText, systemImage: "checklist")
                            }
                            .buttonStyle(.bordered)
                        }

                        if let onViewLogs {
                            Button(action: onViewLogs) {
                                Label("View Logs", systemImage: "doc.text.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Toggle("Enable debug logging", isOn: $cronjob.debugLoggingEnabled)

                    Text(debugLoggingFootnote)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(isOn: $cronjob.autoDisable) {
                        Text("Auto-Disable Limit (3 Days)")
                    }

                    if !cronjob.autoDisable {
                        Text("Warning: disabling the 3-day limit is not recommended. Continuous background AI requests consume system resources, API quotas, and battery life over long periods.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    onCancel?()
                }

                Spacer()

                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(cronjob.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cronjob.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: minimumHeight)
        .onAppear {
            renderedPrompt = PromptTokenRenderer.render(prompt: cronjob.prompt)
        }
        .onChange(of: cronjob.prompt) { _, newValue in
            renderedPrompt = PromptTokenRenderer.render(prompt: newValue)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isNew ? "New Agent Job" : "Edit Agent Job")
                        .font(.headline)

                    Text("Configure the task, schedule, and prompt for this job.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            if !cronjob.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(cronjob.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Enable Job", isOn: $cronjob.isEnabled)
                .toggleStyle(.switch)
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 6)
    }

    private var permissionSummaryText: String {
        if cronjob.usesDefaultAllowedCommands {
            return "Using default permissions"
        }

        let count = cronjob.allowedCommands.count
        return count == 0 ? "Custom permissions" : "\(count) custom command\(count == 1 ? "" : "s")"
    }

    private var debugLoggingFootnote: String {
        cronjob.debugLoggingEnabled
            ? "Debug logging keeps recent provider and command events for this job so you can inspect failures."
            : "Turn on debug logging only while setting up a job or investigating failures."
    }

    private var connectedAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connected Apps")
                .font(.subheadline)

            Text("Attach internal app tools to this job and drag their token into the prompt.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
                ForEach(AICronjobConnectedApp.allCases) { app in
                    connectedAppChip(app)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 4)
    }

    private func connectedAppChip(_ app: AICronjobConnectedApp) -> some View {
        let isAttached = cronjob.connectedApps.contains(app)

        return HStack(spacing: 8) {
            Image(systemName: app.systemImage)
                .font(.system(size: 12, weight: .semibold))

            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName)
                    .font(.caption.weight(.semibold))
                Text(app.promptToken)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(isAttached ? "Insert" : "Attach") {
                attachConnectedApp(app)
                insertConnectedAppToken(app)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 280, alignment: .leading)
        .background(isAttached ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isAttached ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .help(app.shortDescription)
        .onDrag {
            let itemProvider = NSItemProvider()
            itemProvider.registerDataRepresentation(forTypeIdentifier: notchTerminalConnectedAppTokenUTType.rawValue, visibility: .all) { completion in
                completion(app.promptToken.data(using: .utf8), nil)
                return nil
            }
            itemProvider.registerObject(app.promptToken as NSString, visibility: .all)
            return itemProvider
        }
    }

    private func attachConnectedApp(_ app: AICronjobConnectedApp) {
        guard !cronjob.connectedApps.contains(app) else { return }
        cronjob.connectedApps.append(app)
    }

    private func insertConnectedAppToken(_ app: AICronjobConnectedApp) {
        attachConnectedApp(app)

        let trimmedPrompt = cronjob.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.contains(app.promptToken) else { return }

        if trimmedPrompt.isEmpty {
            cronjob.prompt = app.promptToken
        } else if cronjob.prompt.hasSuffix("\n") {
            cronjob.prompt += "\(app.promptToken) "
        } else {
            cronjob.prompt += "\n\(app.promptToken) "
        }
    }

    private var providerSelectionBinding: Binding<String> {
        Binding(
            get: { cronjob.providerID?.uuidString ?? "" },
            set: { cronjob.providerID = UUID(uuidString: $0) }
        )
    }
}

private struct CronjobPromptEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var attributedText: NSAttributedString
    let placeholder: String
    @Binding var dynamicHeight: CGFloat
    let onInsertToken: (AICronjobConnectedApp) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = PromptTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.placeholder = placeholder
        textView.baseTypingAttributes = PromptTokenRenderer.baseTypingAttributes()
        textView.setRenderedPrompt(attributedText)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 0
        textView.connectedAppDropHandler = { app in
            context.coordinator.parent.onInsertToken(app)
        }

        scrollView.documentView = textView
        context.coordinator.recalculateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PromptTextView else { return }

        context.coordinator.parent = self
        textView.placeholder = placeholder
        textView.baseTypingAttributes = PromptTokenRenderer.baseTypingAttributes()
        textView.connectedAppDropHandler = { app in
            context.coordinator.parent.onInsertToken(app)
        }

        if textView.string != text || textView.textStorage?.isEqual(to: attributedText) == false {
            let selectedRange = textView.selectedRange()
            textView.setRenderedPrompt(attributedText)
            textView.setSelectedRange(NSRange(location: min(selectedRange.location, textView.string.count), length: 0))
        }

        context.coordinator.recalculateHeight(for: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CronjobPromptEditor

        init(parent: CronjobPromptEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? PromptTextView else { return }
            let newValue = textView.string
            if parent.text != newValue {
                parent.text = newValue
            }
            let rendered = PromptTokenRenderer.render(prompt: newValue)
            if parent.attributedText != rendered {
                parent.attributedText = rendered
            }
            recalculateHeight(for: textView)
        }

        func recalculateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let nextHeight = min(max(usedRect.height + (textView.textContainerInset.height * 2), 140), 260)

            if abs(parent.dynamicHeight - nextHeight) > 1 {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = nextHeight
                }
            }
        }
    }
}

private final class PromptTextView: NSTextView {
    var connectedAppDropHandler: ((AICronjobConnectedApp) -> Void)?
    var baseTypingAttributes: [NSAttributedString.Key: Any] = PromptTokenRenderer.baseTypingAttributes() {
        didSet {
            typingAttributes = baseTypingAttributes
        }
    }
    var placeholder: String = "" {
        didSet { needsDisplay = true }
    }

    override var string: String {
        didSet { needsDisplay = true }
    }

    override func didChangeText() {
        super.didChangeText()
        typingAttributes = baseTypingAttributes
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        let placeholderRect = NSRect(
            x: textContainerInset.width,
            y: textContainerInset.height,
            width: bounds.width - (textContainerInset.width * 2),
            height: bounds.height - (textContainerInset.height * 2)
        )

        placeholder.draw(in: placeholderRect, withAttributes: attributes)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 {
            insertText("    ", replacementRange: selectedRange())
            return
        }

        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        readableConnectedApp(from: sender) == nil ? [] : .copy
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        readableConnectedApp(from: sender) != nil
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let app = readableConnectedApp(from: sender) else { return false }
        connectedAppDropHandler?(app)
        return true
    }

    private func readableConnectedApp(from draggingInfo: any NSDraggingInfo) -> AICronjobConnectedApp? {
        let pasteboard = draggingInfo.draggingPasteboard

        if let data = pasteboard.data(forType: notchTerminalConnectedAppTokenUTType),
           let token = String(data: data, encoding: .utf8) {
            return AICronjobConnectedApp.allCases.first(where: { $0.promptToken == token })
        }

        guard let items = pasteboard.readObjects(forClasses: [NSString.self]),
              let token = items.first as? String else {
            return nil
        }

        return AICronjobConnectedApp.allCases.first(where: { $0.promptToken == token })
    }

    func setRenderedPrompt(_ attributedText: NSAttributedString) {
        textStorage?.setAttributedString(attributedText)
        typingAttributes = baseTypingAttributes
        needsDisplay = true
    }
}

private enum PromptTokenRenderer {
    static func render(prompt: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: prompt, attributes: baseTypingAttributes())
        let nsString = prompt as NSString

        for app in AICronjobConnectedApp.allCases {
            var searchRange = NSRange(location: 0, length: nsString.length)
            while true {
                let foundRange = nsString.range(of: app.promptToken, options: [], range: searchRange)
                if foundRange.location == NSNotFound { break }

                result.addAttributes(chipAttributes(), range: foundRange)

                let nextLocation = foundRange.location + foundRange.length
                guard nextLocation < nsString.length else { break }
                searchRange = NSRange(location: nextLocation, length: nsString.length - nextLocation)
            }
        }

        return result
    }

    static func baseTypingAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
    }

    private static func chipAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.controlAccentColor,
            .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.14)
        ]
    }
}
