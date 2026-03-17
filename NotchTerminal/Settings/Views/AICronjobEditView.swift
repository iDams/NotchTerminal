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
    var onToggleEnabled: ((Bool) -> Void)? = nil
    var onSave: () -> Void
    var onCancel: (() -> Void)? = nil

    @State private var selectedTab: Int = 0
    @State private var promptEditorHeight: CGFloat = 140
    @State private var renderedPrompt = NSAttributedString(string: "")
    @State private var availableInstalledApps: [AICronjobInstalledApp] = []
    @State private var installedAppsSearch = ""
    @State private var showingInstalledAppsPicker = false
    @State private var appTimerValue: Double = 1
    @State private var appTimerUnit: ScheduleIntervalUnit = .hours
    @State private var daemonPattern: DaemonSchedulePattern = .interval
    @State private var daemonIntervalValue: Int = 1
    @State private var daemonIntervalUnit: ScheduleIntervalUnit = .hours
    @State private var daemonIntervalMinuteOffset: Int = 0
    @State private var daemonPrimaryHour: Int = 9
    @State private var daemonPrimaryMinute: Int = 0
    @State private var daemonSecondaryHour: Int = 17
    @State private var daemonSecondaryMinute: Int = 0
    @State private var daemonSelectedWeekdays: Set<Int> = [1, 3, 5]
    @State private var daemonMonthDaysText: String = "1,15"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader

            Picker("", selection: $selectedTab) {
                Text("Prompt").tag(0)
                Text("Schedule").tag(1)
                Text("Safety & Debug").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case 0:
                        promptTab
                    case 1:
                        scheduleTab
                    case 2:
                        safetyTab
                    default:
                        EmptyView()
                    }
                }
                .padding(20)
            }
            .background(Color(nsColor: .windowBackgroundColor))

            HStack {
                Button("Cancel") {
                    onCancel?()
                }

                Spacer()

                Button(action: {
                    onSave()
                }) {
                    Text("Save Changes")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(cronjob.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || cronjob.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 500, minHeight: minimumHeight)
        .onAppear {
            availableInstalledApps = InstalledAppsCatalog.load()
            refreshEditorState()
        }
        .onChange(of: cronjob.id) { _, _ in
            refreshEditorState()
        }
        .onChange(of: cronjob.prompt) { _, newValue in
            renderedPrompt = PromptTokenRenderer.render(prompt: newValue)
        }
        .onChange(of: cronjob.mode) { _, _ in
            syncScheduleControlsFromJob()
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Job Name", text: $cronjob.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .textFieldStyle(.plain)

                    TextField("Describe what this automation does.", text: $cronjob.detail, axis: .vertical)
                        .lineLimit(2)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .textFieldStyle(.plain)

                    HStack(spacing: 10) {
                        statusBadge(cronjob.isEnabled ? "Running" : "Paused", color: cronjob.isEnabled ? .green : .secondary)
                        statusBadge(cronjob.mode == .app ? "App Timer" : "Daemon", color: .blue)
                        statusBadge(providerSummary, color: .orange)
                    }
                }

                Spacer()

                Toggle("", isOn: $cronjob.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(1.2)
                    .onChange(of: cronjob.isEnabled) { _, isEnabled in
                        onToggleEnabled?(isEnabled)
                    }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold).smallCaps())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
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

    private var scheduleSummary: String {
        cronjob.mode == .app ? AIScheduleFormatter.appTimer(cronjob.interval) : AIScheduleFormatter.cron(cronjob.cronExpression)
    }

    private var modeSummary: String {
        cronjob.mode == .app ? "Runs while the app is open" : "Runs in the background with launchd"
    }

    private var promptTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionCard("Connected Apps") {
                connectedAppsSection
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Prompt")
                            .font(.headline)
                        Text("Instructions for the AI agent.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if let onImprovePrompt {
                        Button(action: onImprovePrompt) {
                            Label(isImprovingPrompt ? "Improving..." : "Improve Prompt", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isImprovingPrompt || cronjob.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                CronjobPromptEditor(
                    text: $cronjob.prompt,
                    attributedText: $renderedPrompt,
                    placeholder: "Describe the task...",
                    dynamicHeight: $promptEditorHeight,
                    onInsertToken: insertConnectedAppToken
                )
                .frame(height: max(promptEditorHeight, 320))
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            }
        }
    }

    private var scheduleTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !providers.isEmpty {
                sectionCard("Provider Settings") {
                    HStack {
                        Label("Override Provider", systemImage: "sparkles")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Picker("", selection: providerSelectionBinding) {
                            Text("Default Active").tag("")
                            ForEach(providers) { provider in
                                Text(provider.name).tag(provider.id.uuidString)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                }
            }

            sectionCard("Execution Schedule") {
                HStack {
                    Text("Execution Mode")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Picker("", selection: $cronjob.mode) {
                        Text("App Timer").tag(AICronjobExecutionMode.app)
                        Text("Daemon").tag(AICronjobExecutionMode.machine)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                Divider().padding(.vertical, 8)

                if cronjob.mode == .app {
                    appTimerScheduleEditor
                } else {
                    daemonScheduleEditor
                }
            }
        }
    }

    private var safetyTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionCard("Security Whitelist") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Allowed Commands")
                        .font(.subheadline.weight(.medium))
                    
                    Text("Limit which terminal commands this job can execute silently.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let onConfigurePermissions {
                        Button(action: onConfigurePermissions) {
                            Label(permissionSummaryText, systemImage: "checklist")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            sectionCard("Diagnostics") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle("Enable Debug Logging", isOn: $cronjob.debugLoggingEnabled)
                            .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        if let onViewLogs {
                            Button(action: onViewLogs) {
                                Label("Open Log Viewer", systemImage: "text.alignleft")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Text(debugLoggingFootnote)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider().padding(.vertical, 4)

                    Toggle("Auto-Disable after 3 days", isOn: $cronjob.autoDisable)
                        .font(.subheadline.weight(.medium))

                    if !cronjob.autoDisable {
                        Label("Warning: Continuous background execution consumes significant resources.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var appTimerScheduleEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("While the app is open")
                    .font(.subheadline)
                Spacer()
                Text("Flexible interval")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Text("Repeat every")
                    .font(.subheadline)

                TextField("", value: $appTimerValue, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: appTimerValue) { _, _ in
                        applyAppTimerInterval()
                    }

                Picker("", selection: $appTimerUnit) {
                    ForEach(ScheduleIntervalUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: appTimerUnit) { _, _ in
                    applyAppTimerInterval()
                }

                Spacer()
            }

            quickScheduleChips(
                options: [.minutes(1), .minutes(15), .minutes(30), .hours(1), .hours(2), .hours(6)],
                onSelect: { unit, value in
                    appTimerUnit = unit
                    appTimerValue = Double(value)
                    applyAppTimerInterval()
                }
            )

            Text("Use any interval you want, like every minute, every 20 minutes, or every 3 hours while the app is open.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var daemonScheduleEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Schedule")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $daemonPattern) {
                    ForEach(DaemonSchedulePattern.allCases) { pattern in
                        Text(pattern.title).tag(pattern)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
                .onChange(of: daemonPattern) { _, _ in
                    applyDaemonSchedulePattern()
                }
            }

            if daemonPattern == .custom {
                HStack {
                    Text("Cron")
                        .font(.subheadline)
                    Spacer()
                    TextField("Cron Expression", text: $cronjob.cronExpression)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
                Text("Format: M H D m W. Example: '0 9 * * 1,4' for Mondays and Thursdays at 09:00.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                daemonPatternBuilder
            }

            quickScheduleChips(
                options: [.minutes(1), .minutes(15), .hours(1), .daily, .weekdays],
                onSelect: { unit, value in
                    switch (unit, value) {
                    case (.minutes, 1):
                        daemonPattern = .interval
                        daemonIntervalUnit = .minutes
                        daemonIntervalValue = 1
                    case (.minutes, 15):
                        daemonPattern = .interval
                        daemonIntervalUnit = .minutes
                        daemonIntervalValue = 15
                    case (.hours, 1):
                        daemonPattern = .interval
                        daemonIntervalUnit = .hours
                        daemonIntervalValue = 1
                    default:
                        daemonPattern = value == -1 ? .daily : .weekly
                        if value == -2 {
                            daemonSelectedWeekdays = [1, 2, 3, 4, 5]
                        }
                    }
                    applyDaemonSchedulePattern()
                }
            )

            Text("Choose intervals, daily times, selected weekdays, month days, or use a raw cron expression when you need something special.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var daemonPatternBuilder: some View {
        switch daemonPattern {
        case .interval:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Repeat every")
                        .font(.subheadline)

                    TextField("", value: $daemonIntervalValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: daemonIntervalValue) { _, _ in applyDaemonSchedulePattern() }

                    Picker("", selection: $daemonIntervalUnit) {
                        ForEach(ScheduleIntervalUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .onChange(of: daemonIntervalUnit) { _, _ in applyDaemonSchedulePattern() }

                    Spacer()
                }

                if daemonIntervalUnit == .hours {
                    HStack {
                        Text("Run at minute")
                            .font(.subheadline)
                        Spacer()
                        minutePicker(selection: $daemonIntervalMinuteOffset)
                            .onChange(of: daemonIntervalMinuteOffset) { _, _ in applyDaemonSchedulePattern() }
                    }
                }
            }
        case .daily:
            timeEditorRow(title: "Run at", hour: $daemonPrimaryHour, minute: $daemonPrimaryMinute)
        case .weekly:
            VStack(alignment: .leading, spacing: 10) {
                weekdayChipRow
                timeEditorRow(title: "Run at", hour: $daemonPrimaryHour, minute: $daemonPrimaryMinute)
            }
        case .monthly:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Days of month")
                        .font(.subheadline)
                    Spacer()
                    TextField("1,15,28", text: $daemonMonthDaysText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .onChange(of: daemonMonthDaysText) { _, _ in applyDaemonSchedulePattern() }
                }
                timeEditorRow(title: "Run at", hour: $daemonPrimaryHour, minute: $daemonPrimaryMinute)
                Text("Use values from 1 to 31, separated by commas.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .twiceDaily:
            VStack(alignment: .leading, spacing: 10) {
                timeEditorRow(title: "First run", hour: $daemonPrimaryHour, minute: $daemonPrimaryMinute)
                timeEditorRow(title: "Second run", hour: $daemonSecondaryHour, minute: $daemonSecondaryMinute)
            }
        case .custom:
            EmptyView()
        }
    }

    private var connectedAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text("Connected Apps")
                    .font(.subheadline)

                Spacer(minLength: 0)

                Button {
                    showingInstalledAppsPicker = true
                } label: {
                    Label("Add Installed App", systemImage: "plus.app")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Attach internal app tools or installed Mac apps to this job and drag their token into the prompt.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
                ForEach(AICronjobConnectedApp.allCases) { app in
                    connectedAppChip(app)
                }

                Spacer(minLength: 0)
            }

            if !cronjob.installedApps.isEmpty {
                installedAppsList
                installedAppsToolHints
            } else if !cronjob.connectedApps.isEmpty {
                connectedAppsToolHints
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingInstalledAppsPicker) {
            installedAppsPickerSheet
        }
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
        .frame(maxWidth: 320, alignment: .leading)
        .background(appChipBackground(isHighlighted: isAttached, tint: .accentColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(appChipBorder(isHighlighted: isAttached, tint: .accentColor))
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

    private var installedAppsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(cronjob.installedApps, id: \.bundleIdentifier) { app in
                installedAppChip(app)
            }
        }
    }

    private var installedAppsToolHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt Helpers")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Use these phrases in the prompt so the job knows when to inspect an app window.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(cronjob.installedApps, id: \.bundleIdentifier) { app in
                installedAppHintRow(app)
            }
        }
        .padding(.top, 2)
    }
    
    private var connectedAppsToolHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt Helpers")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Use these phrases in the prompt so the job knows when to inspect Notch Terminal.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(cronjob.connectedApps) { app in
                connectedAppHintRow(app)
            }
        }
        .padding(.top, 2)
    }

    private func installedAppChip(_ app: AICronjobInstalledApp) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "app.badge")
                .font(.system(size: 12, weight: .semibold))

            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName)
                    .font(.caption.weight(.semibold))
                Text(app.promptToken)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Insert") {
                insertInstalledAppToken(app)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                removeInstalledApp(app)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 320, alignment: .leading)
        .background(appChipBackground(isHighlighted: true, tint: .indigo), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(appChipBorder(isHighlighted: true, tint: .indigo))
        .help(app.appPath)
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

    private func installedAppHintRow(_ app: AICronjobInstalledApp) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.caption.weight(.semibold))
                Text(app.captureInstruction)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Insert Capture") {
                insertPromptLine(app.captureInstruction)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func connectedAppHintRow(_ app: AICronjobConnectedApp) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.caption.weight(.semibold))
                Text(app.captureInstruction)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Insert Capture") {
                insertPromptLine(app.captureInstruction)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var installedAppsPickerSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Installed App")
                .font(.headline)

            TextField("Search apps", text: $installedAppsSearch)

            List(filteredInstalledApps, id: \.bundleIdentifier) { app in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.displayName)
                        Text(app.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Add") {
                        attachInstalledApp(app)
                        insertInstalledAppToken(app)
                        showingInstalledAppsPicker = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(cronjob.installedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }))
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    showingInstalledAppsPicker = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
    }

    private var filteredInstalledApps: [AICronjobInstalledApp] {
        let query = installedAppsSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return availableInstalledApps }

        return availableInstalledApps.filter {
            $0.displayName.localizedStandardContains(query) ||
            $0.bundleIdentifier.localizedStandardContains(query)
        }
    }

    private func attachInstalledApp(_ app: AICronjobInstalledApp) {
        guard !cronjob.installedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
        cronjob.installedApps.append(app)
        cronjob.installedApps = cronjob.normalizedInstalledApps
    }

    private func removeInstalledApp(_ app: AICronjobInstalledApp) {
        cronjob.installedApps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
    }

    private func insertInstalledAppToken(_ app: AICronjobInstalledApp) {
        attachInstalledApp(app)

        insertPromptLine(app.promptToken)
    }

    private func insertPromptLine(_ line: String) {
        let trimmedPrompt = cronjob.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.contains(line) else { return }

        if trimmedPrompt.isEmpty {
            cronjob.prompt = line
        } else if cronjob.prompt.hasSuffix("\n") {
            cronjob.prompt += "\(line)"
        } else {
            cronjob.prompt += "\n\(line)"
        }
    }

    private func appChipBackground(isHighlighted: Bool, tint: Color) -> Color {
        isHighlighted ? tint.opacity(0.12) : Color(nsColor: .controlBackgroundColor)
    }

    private func appChipBorder(isHighlighted: Bool, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(isHighlighted ? tint.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
    }

    private var providerSelectionBinding: Binding<String> {
        Binding(
            get: { cronjob.providerID?.uuidString ?? "" },
            set: { cronjob.providerID = UUID(uuidString: $0) }
        )
    }

    private func timeEditorRow(title: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            hourMinutePickers(hour: hour, minute: minute)
        }
    }

    private func hourMinutePickers(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Picker("", selection: hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 72)
            .onChange(of: hour.wrappedValue) { _, _ in applyDaemonSchedulePattern() }

            Text(":")
                .foregroundStyle(.secondary)

            minutePicker(selection: minute)
                .onChange(of: minute.wrappedValue) { _, _ in applyDaemonSchedulePattern() }
        }
    }

    private func minutePicker(selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(0..<60, id: \.self) { value in
                Text(String(format: "%02d", value)).tag(value)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 72)
    }

    private var weekdayChipRow: some View {
        HStack(spacing: 8) {
            ForEach(weekdayChoices) { day in
                Button(day.shortTitle) {
                    toggleWeekday(day.id)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    daemonSelectedWeekdays.contains(day.id)
                        ? Color.accentColor.opacity(0.16)
                        : Color(nsColor: .controlBackgroundColor),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(
                            daemonSelectedWeekdays.contains(day.id)
                                ? Color.accentColor.opacity(0.35)
                                : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
            }
            Spacer()
        }
    }

    private var weekdayChoices: [WeekdayChoice] {
        [
            .init(id: 1, title: "Monday", shortTitle: "Mon"),
            .init(id: 2, title: "Tuesday", shortTitle: "Tue"),
            .init(id: 3, title: "Wednesday", shortTitle: "Wed"),
            .init(id: 4, title: "Thursday", shortTitle: "Thu"),
            .init(id: 5, title: "Friday", shortTitle: "Fri"),
            .init(id: 6, title: "Saturday", shortTitle: "Sat"),
            .init(id: 0, title: "Sunday", shortTitle: "Sun"),
        ]
    }

    private func toggleWeekday(_ weekday: Int) {
        if daemonSelectedWeekdays.contains(weekday) {
            daemonSelectedWeekdays.remove(weekday)
        } else {
            daemonSelectedWeekdays.insert(weekday)
        }
        if daemonSelectedWeekdays.isEmpty {
            daemonSelectedWeekdays.insert(weekday)
        }
        applyDaemonSchedulePattern()
    }

    private func syncScheduleControlsFromJob() {
        if cronjob.mode == .app {
            let seconds = max(10, cronjob.interval)
            if seconds >= 3600, seconds.truncatingRemainder(dividingBy: 3600) == 0 {
                appTimerUnit = .hours
                appTimerValue = max(1, seconds / 3600)
            } else {
                appTimerUnit = .minutes
                appTimerValue = max(1, seconds / 60)
            }
            return
        }

        parseDaemonCron(cronjob.cronExpression)
    }

    private func parseDaemonCron(_ cron: String) {
        let parts = cron.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == 5 else {
            daemonPattern = .custom
            return
        }

        let minute = parts[0]
        let hour = parts[1]
        let day = parts[2]
        let month = parts[3]
        let weekday = parts[4]

        guard month == "*" else {
            daemonPattern = .custom
            return
        }

        if day == "*", weekday == "*" {
            if minute == "*", hour == "*" {
                daemonPattern = .interval
                daemonIntervalUnit = .minutes
                daemonIntervalValue = 1
                daemonIntervalMinuteOffset = 0
                return
            }

            if minute.hasPrefix("*/"), hour == "*", let everyMinute = Int(minute.dropFirst(2)) {
                daemonPattern = .interval
                daemonIntervalUnit = .minutes
                daemonIntervalValue = max(1, everyMinute)
                daemonIntervalMinuteOffset = 0
                return
            }

            if let minuteValue = Int(minute), hour == "*" {
                daemonPattern = .interval
                daemonIntervalUnit = .hours
                daemonIntervalValue = 1
                daemonIntervalMinuteOffset = minuteValue
                return
            }

            if let minuteValue = Int(minute), hour.hasPrefix("*/"), let everyHour = Int(hour.dropFirst(2)) {
                daemonPattern = .interval
                daemonIntervalUnit = .hours
                daemonIntervalValue = max(1, everyHour)
                daemonIntervalMinuteOffset = minuteValue
                return
            }

            if hour.contains(","), minute == "0" {
                let values = hour.split(separator: ",").compactMap { Int($0) }
                if values.count == 2 {
                    daemonPattern = .twiceDaily
                    daemonPrimaryHour = values[0]
                    daemonSecondaryHour = values[1]
                    daemonPrimaryMinute = 0
                    daemonSecondaryMinute = 0
                } else {
                    daemonPattern = .custom
                }
                return
            }

            if let minuteValue = Int(minute), let hourValue = Int(hour) {
                daemonPattern = .daily
                daemonPrimaryHour = hourValue
                daemonPrimaryMinute = minuteValue
                return
            }
        }

        if day == "*", weekday != "*", let minuteValue = Int(minute), let hourValue = Int(hour) {
            let values = Set(weekday.split(separator: ",").compactMap { Int($0) }.map { $0 == 7 ? 0 : $0 })
            if !values.isEmpty {
                daemonPattern = .weekly
                daemonSelectedWeekdays = values
                daemonPrimaryHour = hourValue
                daemonPrimaryMinute = minuteValue
                return
            }
        }

        if weekday == "*", day.contains(","), let minuteValue = Int(minute), let hourValue = Int(hour) {
            daemonPattern = .monthly
            daemonMonthDaysText = day
            daemonPrimaryHour = hourValue
            daemonPrimaryMinute = minuteValue
            return
        }

        daemonPattern = .custom
    }

    private func refreshEditorState() {
        renderedPrompt = PromptTokenRenderer.render(prompt: cronjob.prompt)
        syncScheduleControlsFromJob()
    }

    private func applyAppTimerInterval() {
        let value = max(1, appTimerValue)
        cronjob.interval = appTimerUnit.secondsMultiplier * value
    }

    private func applyDaemonSchedulePattern() {
        switch daemonPattern {
        case .interval:
            let value = max(1, daemonIntervalValue)
            if daemonIntervalUnit == .minutes {
                cronjob.cronExpression = value == 1 ? "* * * * *" : "*/\(value) * * * *"
            } else {
                cronjob.cronExpression = value == 1
                    ? "\(daemonIntervalMinuteOffset) * * * *"
                    : "\(daemonIntervalMinuteOffset) */\(value) * * *"
            }
        case .twiceDaily:
            cronjob.cronExpression = "\(daemonPrimaryMinute) \(daemonPrimaryHour),\(daemonSecondaryHour) * * *"
        case .daily:
            cronjob.cronExpression = "\(daemonPrimaryMinute) \(daemonPrimaryHour) * * *"
        case .weekly:
            let weekdays = daemonSelectedWeekdays.sorted().map(String.init).joined(separator: ",")
            cronjob.cronExpression = "\(daemonPrimaryMinute) \(daemonPrimaryHour) * * \(weekdays)"
        case .monthly:
            let values = daemonMonthDaysText
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                .filter { (1...31).contains($0) }
            let dayList = values.isEmpty ? "1" : values.sorted().map(String.init).joined(separator: ",")
            cronjob.cronExpression = "\(daemonPrimaryMinute) \(daemonPrimaryHour) \(dayList) * *"
        case .custom:
            break
        }
    }

    private var providerSummary: String {
        if let providerID = cronjob.providerID,
           let provider = providers.first(where: { $0.id == providerID }) {
            return provider.name
        }
        return "Use active provider"
    }

    private func quickScheduleChips(options: [QuickScheduleOption], onSelect: @escaping (ScheduleIntervalUnit, Int) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                Button(option.title) {
                    onSelect(option.unit, option.value)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            Spacer()
        }
    }
}

private enum ScheduleIntervalUnit: String, CaseIterable, Identifiable {
    case minutes
    case hours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        }
    }

    var secondsMultiplier: Double {
        switch self {
        case .minutes: return 60
        case .hours: return 3600
        }
    }
}

private enum DaemonSchedulePattern: String, CaseIterable, Identifiable {
    case interval
    case twiceDaily
    case daily
    case weekly
    case monthly
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interval: return "Every X minutes or hours"
        case .twiceDaily: return "2 times a day"
        case .daily: return "Every day"
        case .weekly: return "Selected weekdays"
        case .monthly: return "Specific days of month"
        case .custom: return "Custom cron"
        }
    }
}

private struct QuickScheduleOption: Identifiable {
    let id = UUID()
    let title: String
    let unit: ScheduleIntervalUnit
    let value: Int

    static func minutes(_ value: Int) -> QuickScheduleOption {
        .init(title: value == 1 ? "Every minute" : "Every \(value)m", unit: .minutes, value: value)
    }

    static func hours(_ value: Int) -> QuickScheduleOption {
        .init(title: value == 1 ? "Every hour" : "Every \(value)h", unit: .hours, value: value)
    }

    static let daily = QuickScheduleOption(title: "Daily", unit: .hours, value: -1)
    static let weekdays = QuickScheduleOption(title: "Weekdays", unit: .hours, value: -2)
}

private struct WeekdayChoice: Identifiable {
    let id: Int
    let title: String
    let shortTitle: String
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
            textView.setRenderedPrompt(attributedText)
            let insertionLocation = text.count
            textView.setSelectedRange(NSRange(location: insertionLocation, length: 0))
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
            applyAttributes(
                connectedChipAttributes(),
                for: app.promptToken,
                in: nsString,
                result: result
            )
        }

        let installedAppPattern = #"@app:[A-Za-z0-9.\-_]+"#
        if let regex = try? NSRegularExpression(pattern: installedAppPattern) {
            let fullRange = NSRange(location: 0, length: nsString.length)
            regex.enumerateMatches(in: prompt, options: [], range: fullRange) { match, _, _ in
                guard let matchRange = match?.range else { return }
                result.addAttributes(installedChipAttributes(), range: matchRange)
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

    private static func applyAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        for token: String,
        in nsString: NSString,
        result: NSMutableAttributedString
    ) {
        var searchRange = NSRange(location: 0, length: nsString.length)
        while true {
            let foundRange = nsString.range(of: token, options: [], range: searchRange)
            if foundRange.location == NSNotFound { break }

            result.addAttributes(attributes, range: foundRange)

            let nextLocation = foundRange.location + foundRange.length
            guard nextLocation < nsString.length else { break }
            searchRange = NSRange(location: nextLocation, length: nsString.length - nextLocation)
        }
    }

    private static func connectedChipAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.controlAccentColor,
            .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.14)
        ]
    }

    private static func installedChipAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
            .foregroundColor: NSColor.systemIndigo,
            .backgroundColor: NSColor.systemIndigo.withAlphaComponent(0.12)
        ]
    }
}
