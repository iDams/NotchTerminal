import SwiftUI

struct AICronjobEditView: View {
    @Binding var cronjob: AICronjob
    var isNew: Bool
    var onSave: () -> Void
    var onCancel: (() -> Void)? = nil

    @State private var showCustomCron = false
    @State private var promptEditorHeight: CGFloat = 140
    private let presetCrons = ["* * * * *", "*/5 * * * *", "*/15 * * * *", "*/30 * * * *", "0 * * * *", "0 */6 * * *", "0 */12 * * *", "0 0 * * *"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isNew ? "New Agent Job" : "Edit Agent Job")
                        .font(.headline)

                    Text("Configure the task, schedule, and prompt for this job.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()

            Form {
                Section {
                    TextField("Agent Job Name", text: $cronjob.name)

                    TextField("Short description", text: $cronjob.detail, axis: .vertical)
                        .lineLimit(2...3)

                    Toggle(isOn: $cronjob.isEnabled) {
                        Text("Enabled")
                    }

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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Prompt")
                            .font(.subheadline)

                        CronjobPromptEditor(
                            text: $cronjob.prompt,
                            placeholder: "Describe what this job should do",
                            dynamicHeight: $promptEditorHeight
                        )
                        .frame(height: promptEditorHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)

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
        .frame(minWidth: 500, minHeight: 560)
    }
}

private struct CronjobPromptEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @Binding var dynamicHeight: CGFloat

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
        textView.string = text
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 0

        scrollView.documentView = textView
        context.coordinator.recalculateHeight(for: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PromptTextView else { return }

        context.coordinator.parent = self
        textView.placeholder = placeholder

        if textView.string != text {
            textView.string = text
        }

        context.coordinator.recalculateHeight(for: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CronjobPromptEditor

        init(parent: CronjobPromptEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newValue = textView.string
            if parent.text != newValue {
                parent.text = newValue
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
    var placeholder: String = "" {
        didSet { needsDisplay = true }
    }

    override var string: String {
        didSet { needsDisplay = true }
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
}
