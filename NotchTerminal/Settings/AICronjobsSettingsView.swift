import AppKit
import SwiftUI

struct AICronjobsSettingsView: View {
    @AppStorage(AppPreferences.Keys.experimentalFloatingMsgEnabled) var experimentalFloatingMsgEnabled: Bool = AppPreferences.Defaults.experimentalFloatingMsgEnabled
    @AppStorage(AppPreferences.Keys.experimentalAIAgentWhitelist) var experimentalAIAgentWhitelist: String = AppPreferences.Defaults.experimentalAIAgentWhitelist
    @AppStorage(AppPreferences.Keys.experimentalAICronjobsData) var experimentalAICronjobsData: [AICronjob] = AppPreferences.Defaults.experimentalAICronjobsData
    @AppStorage(AppPreferences.Keys.aiProvidersData) var aiProvidersList: AIProviderList = AppPreferences.Defaults.aiProvidersData
    @AppStorage(AppPreferences.Keys.activeAIProviderID) var activeAIProviderIDString: String = AppPreferences.Defaults.activeAIProviderID

    @State private var editingCronjob: AICronjob?
    @State private var isCreatingNewCronjob = false
    @State private var commandDraft = ""

    private var aiProvidersData: [AIProvider] {
        aiProvidersList.providers
    }

    private var activeAIProviderID: UUID? {
        UUID(uuidString: activeAIProviderIDString)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                contentSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .reportSettingsContentHeight(for: .aiCronjobs)
        }
    }

    private var contentSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "Agent Jobs",
                subtitle: "Automate background tasks and get silent notifications powered by AI.",
                icon: "cpu"
            )

            Text("⚠️ This feature is in beta and might change in future updates.")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.bottom, 4)

            NotchTerminalPreferenceToggleRow(
                title: "Enable NotchAgent",
                subtitle: "Master switch to run background AI tasks",
                icon: "timer",
                binding: $experimentalFloatingMsgEnabled
            )

            if experimentalFloatingMsgEnabled {
                if let providerWarning = providerWarningMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(providerWarning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 8))
                    .padding(.leading, 32)
                }

                whitelistSection

                Divider().padding(.horizontal, 32)

                jobsSection
            }
        }
    }

    private var providerWarningMessage: String? {
        if aiProvidersData.isEmpty {
            return "No AI provider configured. Add one in the AI Providers tab."
        }
        if activeAIProviderID == nil {
            return "No active provider selected. Select one in the AI Providers tab."
        }
        if let activeID = activeAIProviderID,
           let provider = aiProvidersData.first(where: { $0.id == activeID }),
           provider.type.requiresAPIKey,
           KeychainService.getAPIKey(for: provider.id) == nil {
            return "The active provider '\(provider.name)' has no API key. Configure it in the AI Providers tab."
        }
        return nil
    }

    private var whitelistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Allowed Commands")
                .font(.headline)

            Text("Choose the read-only commands NotchAgent can run silently for system inspection.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(whitelistCommands.chunked(into: 6), id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { command in
                            HStack(spacing: 8) {
                                Text(command)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                                Button {
                                    removeWhitelistCommand(command)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                TextField("Add command", text: $commandDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit(addWhitelistCommand)

                Button("Add Command") {
                    addWhitelistCommand()
                }
                .buttonStyle(.bordered)
                .disabled(commandDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.leading, 32)
        .padding(.bottom, 16)
    }

    private var jobsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Agent Jobs")
                        .font(.headline)

                    Text("Each job can carry its own description, schedule, and prompt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isCreatingNewCronjob = true
                    editingCronjob = AICronjob()
                } label: {
                    Label("New Job", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if experimentalAICronjobsData.isEmpty {
                ContentUnavailableView(
                    "No Agent Jobs Yet",
                    systemImage: "sparkles.rectangle.stack",
                    description: Text("Create your first Agent Job to automate a recurring AI workflow.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(experimentalAICronjobsData) { job in
                        agentJobRow(job)
                    }
                }
            }

            if let editingCronjob {
                Divider()
                    .padding(.top, 8)

                AICronjobEditView(
                    cronjob: Binding(
                        get: { editingCronjob },
                        set: { self.editingCronjob = $0 }
                    ),
                    isNew: isCreatingNewCronjob,
                    onSave: saveEditingJob,
                    onCancel: {
                        self.editingCronjob = nil
                        self.isCreatingNewCronjob = false
                    }
                )
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(.leading, 32)
    }

    private func agentJobRow(_ job: AICronjob) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(job.name)
                        .font(.headline)

                    Text(job.mode == .app ? "App Timer" : "Machine Daemon")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                        .foregroundStyle(.secondary)
                }

                if !job.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(job.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(job.mode == .app ? "Every \(Int(job.interval)) seconds" : "Cron: \(job.cronExpression)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    AICronjobManager.shared.triggerTest(for: job)
                } label: {
                    Image(systemName: "play.fill")
                        .foregroundStyle(job.isEnabled ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Run Job Now")

                Toggle("", isOn: Binding(
                    get: { job.isEnabled },
                    set: { newValue in
                        updateJob(job) { item in
                            item.isEnabled = newValue
                            if newValue {
                                item.activationDate = Date().timeIntervalSince1970
                            }
                        }
                    }
                ))
                .labelsHidden()

                Button {
                    isCreatingNewCronjob = false
                    editingCronjob = job
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)

                Button {
                    deleteJob(job)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var whitelistCommands: [String] {
        experimentalAIAgentWhitelist
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func addWhitelistCommand() {
        let trimmed = commandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !whitelistCommands.contains(trimmed) else {
            commandDraft = ""
            return
        }

        var commands = whitelistCommands
        commands.append(trimmed)
        experimentalAIAgentWhitelist = commands.joined(separator: ", ")
        commandDraft = ""
    }

    private func removeWhitelistCommand(_ command: String) {
        experimentalAIAgentWhitelist = whitelistCommands
            .filter { $0 != command }
            .joined(separator: ", ")
    }

    private func updateJob(_ job: AICronjob, mutate: (inout AICronjob) -> Void) {
        guard let index = experimentalAICronjobsData.firstIndex(where: { $0.id == job.id }) else { return }
        var updated = experimentalAICronjobsData[index]
        mutate(&updated)
        experimentalAICronjobsData[index] = updated
    }

    private func deleteJob(_ job: AICronjob) {
        experimentalAICronjobsData.removeAll { $0.id == job.id }
        if editingCronjob?.id == job.id {
            editingCronjob = nil
        }
    }

    private func saveEditingJob() {
        guard let safeJob = editingCronjob else { return }
        if isCreatingNewCronjob {
            experimentalAICronjobsData.append(safeJob)
        } else if let idx = experimentalAICronjobsData.firstIndex(where: { $0.id == safeJob.id }) {
            experimentalAICronjobsData[idx] = safeJob
        }
        editingCronjob = nil
        isCreatingNewCronjob = false
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview("Settings - AI Cronjobs") {
    AICronjobsSettingsView()
        .frame(width: 760, height: 620)
}