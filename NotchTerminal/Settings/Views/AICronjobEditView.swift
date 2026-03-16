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
    @State private var availableInstalledApps: [AICronjobInstalledApp] = []
    @State private var installedAppsSearch = ""
    @State private var showingInstalledAppsPicker = false
    @State private var appTimerPreset: AppTimerPreset = .hourly
    @State private var appTimerCustomValue: Double = 1
    @State private var appTimerCustomUnit: AppTimerUnit = .hours
    @State private var daemonPreset: DaemonPreset = .daily
    @State private var daemonPrimaryHour: Int = 9
    @State private var daemonPrimaryMinute: Int = 0
    @State private var daemonSecondaryHour: Int = 17
    @State private var daemonSecondaryMinute: Int = 0
    @State private var daemonWeeklyDay: Int = 1
    @State private var daemonSelectedWeekdays: Set<Int> = [1, 3, 5]
    @State private var daemonMonthDaysText: String = "1,15"
    @State private var selectedTab: JobEditorTab = .overview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabStrip

            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .overview:
                        overviewSection
                    case .compose:
                        composeSection
                    case .advanced:
                        advancedSection
                    }
                }
                .padding()
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
            renderedPrompt = PromptTokenRenderer.render(prompt: cronjob.prompt)
            syncScheduleControlsFromJob()
        }
        .onChange(of: cronjob.prompt) { _, newValue in
            renderedPrompt = PromptTokenRenderer.render(prompt: newValue)
        }
        .onChange(of: cronjob.mode) { _, _ in
            syncScheduleControlsFromJob()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cronjob.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (isNew ? "New Agent Job" : "Untitled Job") : cronjob.name)
                        .font(.title3.weight(.semibold))

                    Text(isNew ? "Configure a new automation" : scheduleSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if !cronjob.recipeAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Recipe by \(cronjob.recipeAuthor)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("Enabled", isOn: $cronjob.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()

                Text(cronjob.isEnabled ? "On" : "Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var tabStrip: some View {
        HStack(spacing: 8) {
            ForEach(JobEditorTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            selectedTab == tab
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
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

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Agent Job Name", text: $cronjob.name)
                                .font(.title3.weight(.semibold))
                                .textFieldStyle(.plain)

                            TextField("Short description", text: $cronjob.detail, axis: .vertical)
                                .lineLimit(2...3)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textFieldStyle(.plain)
                        }

                        Spacer(minLength: 12)

                        VStack(alignment: .trailing, spacing: 8) {
                            overviewPill(cronjob.mode == .app ? "App Timer" : "Daemon")
                            overviewPill(cronjob.isEnabled ? "Enabled" : "Paused", accent: cronjob.isEnabled ? .green : .secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        overviewStatCard(title: "Schedule", value: scheduleSummary)
                        overviewStatCard(title: "Mode", value: modeSummary)
                    }
                }
            }

            sectionCard("Execution") {
                HStack {
                    Text("Execution Mode")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Picker("", selection: $cronjob.mode) {
                        Text("App Timer").tag(AICronjobExecutionMode.app)
                        Text("Daemon").tag(AICronjobExecutionMode.machine)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                if cronjob.mode == .app {
                    appTimerScheduleEditor
                } else {
                    daemonScheduleEditor
                }
            }

            if !providers.isEmpty {
                sectionCard("Provider") {
                    HStack {
                        Label("Model Provider", systemImage: "sparkles")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Picker("", selection: providerSelectionBinding) {
                            Text("Use active provider").tag("")
                            ForEach(providers) { provider in
                                Text(provider.name).tag(provider.id.uuidString)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 240)
                    }
                }
            }
        }
    }

    private var composeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard("Connected Apps") {
                connectedAppsSection
            }

            sectionCard("Prompt") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("System Prompt")
                                .font(.headline)

                            Text("Write the task while keeping app tokens and capture helpers visible above.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        if let onImprovePrompt {
                            Button(action: onImprovePrompt) {
                                if isImprovingPrompt {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label("Improve Prompt", systemImage: "wand.and.stars")
                                        .font(.caption.weight(.medium))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
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
                    .frame(height: max(promptEditorHeight, 260))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                }
            }
        }
    }

    private var advancedSection: some View {
        sectionCard {
            Text("Safety & Debugging")
                .font(.headline)

            HStack(spacing: 12) {
                if let onConfigurePermissions {
                    Button(action: onConfigurePermissions) {
                        Label(permissionSummaryText, systemImage: "checklist")
                    }
                    .buttonStyle(.bordered)
                }

                if let onViewLogs {
                    Button(action: onViewLogs) {
                        Label("View Logs", systemImage: "text.alignleft")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Toggle("Enable debug logging", isOn: $cronjob.debugLoggingEnabled)
                .font(.subheadline)
            Text(debugLoggingFootnote)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Auto-Disable Limit (3 Days)", isOn: $cronjob.autoDisable)
                .font(.subheadline)

            if !cronjob.autoDisable {
                Text("Warning: disabling the 3-day limit is not recommended and consumes battery/API quotas.")
                    .font(.caption)
                    .foregroundStyle(.orange)
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

    private func overviewPill(_ text: String, accent: Color = .accentColor) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accent.opacity(0.12), in: Capsule())
    }

    private func overviewStatCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var appTimerScheduleEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("While the app is open")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $appTimerPreset) {
                    ForEach(AppTimerPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
                .onChange(of: appTimerPreset) { _, newValue in
                    applyAppTimerPreset(newValue)
                }
            }

            if appTimerPreset == .custom {
                HStack(spacing: 10) {
                    Text("Repeat every")
                        .font(.subheadline)

                    TextField("", value: $appTimerCustomValue, format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: appTimerCustomValue) { _, _ in
                            applyCustomAppTimer()
                        }

                    Picker("", selection: $appTimerCustomUnit) {
                        ForEach(AppTimerUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .onChange(of: appTimerCustomUnit) { _, _ in
                        applyCustomAppTimer()
                    }

                    Spacer()
                }
            }

            Text("Best for repeating checks while NotchTerminal is open, like every 30 minutes or every 2 hours.")
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
                Picker("", selection: $daemonPreset) {
                    ForEach(DaemonPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
                .onChange(of: daemonPreset) { _, newValue in
                    showCustomCron = newValue == .custom
                    if !showCustomCron {
                        applyDaemonPreset()
                    }
                }
            }

            if showCustomCron {
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
                daemonPresetBuilder
            }

            Toggle("Advanced Custom Cron", isOn: $showCustomCron)
                .font(.caption)
                .foregroundStyle(.secondary)
                .onChange(of: showCustomCron) { _, isEnabled in
                    if isEnabled {
                        daemonPreset = .custom
                    } else {
                        if daemonPreset == .custom {
                            daemonPreset = .daily
                        }
                        applyDaemonPreset()
                    }
                }

            Text("Best for daily, weekly, selected weekdays, or month-based schedules, even when the app is closed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var daemonPresetBuilder: some View {
        switch daemonPreset {
        case .hourly:
            HStack {
                Text("At minute")
                    .font(.subheadline)
                Spacer()
                minutePicker(selection: $daemonPrimaryMinute)
                    .onChange(of: daemonPrimaryMinute) { _, _ in applyDaemonPreset() }
            }
        case .twiceDaily:
            VStack(alignment: .leading, spacing: 10) {
                timeEditorRow(title: "First run", hour: $daemonPrimaryHour, minute: $daemonPrimaryMinute)
                timeEditorRow(title: "Second run", hour: $daemonSecondaryHour, minute: $daemonSecondaryMinute)
            }
        case .daily, .weekdays:
            timeEditorRow(title: "Run at", hour: $daemonPrimaryHour, minute: $daemonPrimaryMinute)
        case .weekly:
            HStack {
                Text("Every")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $daemonWeeklyDay) {
                    ForEach(weekdayChoices) { day in
                        Text(day.title).tag(day.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
                .onChange(of: daemonWeeklyDay) { _, _ in applyDaemonPreset() }

                hourMinutePickers(hour: $daemonPrimaryHour, minute: $daemonPrimaryMinute)
            }
        case .selectedWeekdays:
            VStack(alignment: .leading, spacing: 10) {
                weekdayChipRow
                timeEditorRow(title: "Run at", hour: $daemonPrimaryHour, minute: $daemonPrimaryMinute)
            }
        case .monthDays:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Days of month")
                        .font(.subheadline)
                    Spacer()
                    TextField("1,15,28", text: $daemonMonthDaysText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .onChange(of: daemonMonthDaysText) { _, _ in applyDaemonPreset() }
                }
                timeEditorRow(title: "Run at", hour: $daemonPrimaryHour, minute: $daemonPrimaryMinute)
                Text("Use values from 1 to 31, separated by commas.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .custom:
            EmptyView()
        }
    }

    private var connectedAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connected Apps")
                .font(.subheadline)

            Text("Attach internal app tools or installed Mac apps to this job and drag their token into the prompt.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
                ForEach(AICronjobConnectedApp.allCases) { app in
                    connectedAppChip(app)
                }

                Button {
                    showingInstalledAppsPicker = true
                } label: {
                    Label("Add Installed App", systemImage: "plus.app")
                }
                .buttonStyle(.bordered)

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
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
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
            .onChange(of: hour.wrappedValue) { _, _ in applyDaemonPreset() }

            Text(":")
                .foregroundStyle(.secondary)

            minutePicker(selection: minute)
                .onChange(of: minute.wrappedValue) { _, _ in applyDaemonPreset() }
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
        applyDaemonPreset()
    }

    private func syncScheduleControlsFromJob() {
        if cronjob.mode == .app {
            let seconds = max(10, cronjob.interval)
            switch seconds {
            case 900:
                appTimerPreset = .quarterHour
            case 1800:
                appTimerPreset = .halfHour
            case 3600:
                appTimerPreset = .hourly
            case 7200:
                appTimerPreset = .twoHours
            case 21600:
                appTimerPreset = .sixHours
            default:
                appTimerPreset = .custom
                if seconds >= 3600, seconds.truncatingRemainder(dividingBy: 3600) == 0 {
                    appTimerCustomUnit = .hours
                    appTimerCustomValue = max(1, seconds / 3600)
                } else {
                    appTimerCustomUnit = .minutes
                    appTimerCustomValue = max(1, seconds / 60)
                }
            }
            return
        }

        showCustomCron = false
        switch cronjob.cronExpression {
        case let value where value.hasPrefix("0 * * * *"):
            daemonPreset = .hourly
            daemonPrimaryMinute = 0
        case let value where value == "\(daemonPrimaryMinute) * * * *":
            daemonPreset = .hourly
        case let value where value == "0 9,17 * * *":
            daemonPreset = .twiceDaily
            daemonPrimaryHour = 9
            daemonSecondaryHour = 17
            daemonPrimaryMinute = 0
            daemonSecondaryMinute = 0
        default:
            parseDaemonCron(cronjob.cronExpression)
        }
    }

    private func parseDaemonCron(_ cron: String) {
        let parts = cron.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == 5 else {
            daemonPreset = .custom
            showCustomCron = true
            return
        }

        let minute = parts[0]
        let hour = parts[1]
        let day = parts[2]
        let month = parts[3]
        let weekday = parts[4]

        guard month == "*" else {
            daemonPreset = .custom
            showCustomCron = true
            return
        }

        if day == "*", weekday == "*" {
            if hour == "*", let minuteValue = Int(minute) {
                daemonPreset = .hourly
                daemonPrimaryMinute = minuteValue
            } else if hour.contains(","), minute == "0" {
                let values = hour.split(separator: ",").compactMap { Int($0) }
                if values.count == 2 {
                    daemonPreset = .twiceDaily
                    daemonPrimaryHour = values[0]
                    daemonSecondaryHour = values[1]
                    daemonPrimaryMinute = 0
                    daemonSecondaryMinute = 0
                } else {
                    daemonPreset = .custom
                    showCustomCron = true
                }
            } else if let minuteValue = Int(minute), let hourValue = Int(hour) {
                daemonPreset = .daily
                daemonPrimaryHour = hourValue
                daemonPrimaryMinute = minuteValue
            } else {
                daemonPreset = .custom
                showCustomCron = true
            }
            return
        }

        if day == "*", weekday == "1,2,3,4,5", let minuteValue = Int(minute), let hourValue = Int(hour) {
            daemonPreset = .weekdays
            daemonPrimaryHour = hourValue
            daemonPrimaryMinute = minuteValue
            return
        }

        if day == "*", !weekday.contains(","), let minuteValue = Int(minute), let hourValue = Int(hour), let weekdayValue = Int(weekday) {
            daemonPreset = .weekly
            daemonPrimaryHour = hourValue
            daemonPrimaryMinute = minuteValue
            daemonWeeklyDay = weekdayValue == 7 ? 0 : weekdayValue
            return
        }

        if day == "*", weekday.contains(","), let minuteValue = Int(minute), let hourValue = Int(hour) {
            let values = Set(weekday.split(separator: ",").compactMap { Int($0) }.map { $0 == 7 ? 0 : $0 })
            if !values.isEmpty {
                daemonPreset = .selectedWeekdays
                daemonSelectedWeekdays = values
                daemonPrimaryHour = hourValue
                daemonPrimaryMinute = minuteValue
                return
            }
        }

        if weekday == "*", day.contains(","), let minuteValue = Int(minute), let hourValue = Int(hour) {
            daemonPreset = .monthDays
            daemonMonthDaysText = day
            daemonPrimaryHour = hourValue
            daemonPrimaryMinute = minuteValue
            return
        }

        daemonPreset = .custom
        showCustomCron = true
    }

    private func applyAppTimerPreset(_ preset: AppTimerPreset) {
        switch preset {
        case .quarterHour:
            cronjob.interval = 900
        case .halfHour:
            cronjob.interval = 1800
        case .hourly:
            cronjob.interval = 3600
        case .twoHours:
            cronjob.interval = 7200
        case .sixHours:
            cronjob.interval = 21600
        case .custom:
            applyCustomAppTimer()
        }
    }

    private func applyCustomAppTimer() {
        let value = max(1, appTimerCustomValue)
        cronjob.interval = appTimerCustomUnit.secondsMultiplier * value
    }

    private func applyDaemonPreset() {
        guard !showCustomCron else { return }

        switch daemonPreset {
        case .hourly:
            cronjob.cronExpression = "\(daemonPrimaryMinute) * * * *"
        case .twiceDaily:
            cronjob.cronExpression = "\(daemonPrimaryMinute) \(daemonPrimaryHour),\(daemonSecondaryHour) * * *"
        case .daily:
            cronjob.cronExpression = "\(daemonPrimaryMinute) \(daemonPrimaryHour) * * *"
        case .weekdays:
            cronjob.cronExpression = "\(daemonPrimaryMinute) \(daemonPrimaryHour) * * 1,2,3,4,5"
        case .weekly:
            cronjob.cronExpression = "\(daemonPrimaryMinute) \(daemonPrimaryHour) * * \(daemonWeeklyDay)"
        case .selectedWeekdays:
            let weekdays = daemonSelectedWeekdays.sorted().map(String.init).joined(separator: ",")
            cronjob.cronExpression = "\(daemonPrimaryMinute) \(daemonPrimaryHour) * * \(weekdays)"
        case .monthDays:
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
}

private enum AppTimerPreset: String, CaseIterable, Identifiable {
    case quarterHour
    case halfHour
    case hourly
    case twoHours
    case sixHours
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quarterHour: return "Every 15 minutes"
        case .halfHour: return "Every 30 minutes"
        case .hourly: return "Every hour"
        case .twoHours: return "Every 2 hours"
        case .sixHours: return "Every 6 hours"
        case .custom: return "Custom"
        }
    }
}

private enum AppTimerUnit: String, CaseIterable, Identifiable {
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

private enum DaemonPreset: String, CaseIterable, Identifiable {
    case hourly
    case twiceDaily
    case daily
    case weekdays
    case weekly
    case selectedWeekdays
    case monthDays
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hourly: return "Every hour"
        case .twiceDaily: return "2 times a day"
        case .daily: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekly: return "Once a week"
        case .selectedWeekdays: return "Some days each week"
        case .monthDays: return "Specific days of month"
        case .custom: return "Custom cron"
        }
    }
}

private struct WeekdayChoice: Identifiable {
    let id: Int
    let title: String
    let shortTitle: String
}

private enum JobEditorTab: String, CaseIterable, Identifiable {
    case overview
    case compose
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .compose: return "Compose"
        case .advanced: return "Advanced"
        }
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
