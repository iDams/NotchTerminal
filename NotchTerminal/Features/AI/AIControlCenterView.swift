import AppKit
import SwiftUI

private enum AIWorkspaceSection: String, CaseIterable, Identifiable {
    case jobs
    case providers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jobs:
            return "Agent Jobs"
        case .providers:
            return "Providers"
        }
    }

    var subtitle: String {
        switch self {
        case .jobs:
            return "Automations and prompts"
        case .providers:
            return "Connections and models"
        }
    }

    var systemImage: String {
        switch self {
        case .jobs:
            return "cpu"
        case .providers:
            return "server.rack"
        }
    }
}

struct AIControlCenterView: View {
    @AppStorage(AppPreferences.Keys.experimentalAIAgentWhitelist) private var experimentalAIAgentWhitelist: String = AppPreferences.Defaults.experimentalAIAgentWhitelist
    @AppStorage(AppPreferences.Keys.experimentalAICronjobsData) private var experimentalAICronjobsData: [AICronjob] = AppPreferences.Defaults.experimentalAICronjobsData
    @AppStorage(AppPreferences.Keys.aiProvidersData) private var aiProvidersList: AIProviderList = AppPreferences.Defaults.aiProvidersData
    @AppStorage(AppPreferences.Keys.activeAIProviderID) private var activeAIProviderIDString: String = AppPreferences.Defaults.activeAIProviderID
    @AppStorage(AppPreferences.Keys.aiCronjobLogsData) private var aiCronjobLogsData: AICronjobLogStore = AppPreferences.Defaults.aiCronjobLogsData

    @State private var selectedSection: AIWorkspaceSection = .jobs
    @State private var editingCronjob: AICronjob?
    @State private var isCreatingNewCronjob = false
    @State private var editingProvider: AIProvider?
    @State private var isCreatingNewProvider = false
    @State private var newProviderType: AIProviderType = .openai
    @State private var newProviderName = ""
    @State private var newProviderAPIKey = ""
    @State private var newProviderModel = ""
    @State private var newProviderBaseURL = ""
    @State private var newProviderZAIMode: ZAIMode = .standard
    @State private var newProviderInstructions = ""
    @State private var availableModels: [String] = []
    @State private var isFetchingModels = false
    @State private var showingPermissionsEditor = false
    @State private var viewingLogsForJob: AICronjob?
    @State private var pendingJobDeletion: AICronjob?
    @State private var isImprovingPrompt = false
    @State private var promptImprovementErrorMessage = ""
    @State private var isTestingProvider = false
    @State private var providerTestMessage = ""
    @State private var providerTestSucceeded = false

    private let providerInstructionPresets: [AIProviderType: String] = [
        .minimax: "You are running inside NotchTerminal, a macOS automation agent with strict command safety rules. Never reveal hidden reasoning or thinking tags. Use one simple command at a time. Do not use pipes, redirects, shell chaining, or GUI-launch commands unless explicitly allowed. If a command fails because a service is offline, permissions block it, or the whitelist forbids it, stop and give a short final diagnosis with the best next step.",
        .custom: "This provider is expected to behave like an OpenAI-compatible chat completions endpoint. Keep answers concise, avoid hidden reasoning output, and stop quickly when tools fail or are blocked."
    ]

    private var providers: [AIProvider] {
        aiProvidersList.providers.sorted { lhs, rhs in
            if activeAIProviderID == lhs.id { return true }
            if activeAIProviderID == rhs.id { return false }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var activeAIProviderID: UUID? {
        get { UUID(uuidString: activeAIProviderIDString) }
        nonmutating set { activeAIProviderIDString = newValue?.uuidString ?? "" }
    }

    private var activeProvider: AIProvider? {
        guard let activeAIProviderID else { return nil }
        return providers.first(where: { $0.id == activeAIProviderID })
    }

    private var activeProviderHasAPIKey: Bool {
        guard let activeProvider else { return false }
        return !activeProvider.type.requiresAPIKey || KeychainService.getAPIKey(for: activeProvider.id) != nil
    }

    private var enabledJobsCount: Int {
        experimentalAICronjobsData.filter(\.isEnabled).count
    }

    private var enabledProvidersCount: Int {
        providers.filter(\.isEnabled).count
    }

    private var whitelistCommands: [String] {
        sanitizeCommands(
            experimentalAIAgentWhitelist
                .components(separatedBy: ",")
        )
    }

    private var jobsProviderWarning: String? {
        if providers.isEmpty {
            return "Add a provider before enabling Agent Jobs."
        }
        if activeAIProviderID == nil {
            return "Choose one active provider for Agent Jobs."
        }
        if let activeProvider,
           activeProvider.type.requiresAPIKey,
           KeychainService.getAPIKey(for: activeProvider.id) == nil {
            return "The active provider '\(activeProvider.name)' still needs an API key in Keychain."
        }
        return nil
    }

    private var selectedSectionBinding: Binding<AIWorkspaceSection?> {
        Binding(
            get: { selectedSection },
            set: { if let newValue = $0 { selectedSection = newValue } }
        )
    }

    private var editingCronjobBinding: Binding<AICronjob>? {
        guard editingCronjob != nil else { return nil }
        return Binding(
            get: { editingCronjob ?? AICronjob() },
            set: { editingCronjob = $0 }
        )
    }

    private var selectedJob: AICronjob? {
        guard let editingCronjob else { return nil }
        return experimentalAICronjobsData.first(where: { $0.id == editingCronjob.id }) ?? editingCronjob
    }

    private var selectedJobLogEntries: [AICronjobLogEntry] {
        guard let selectedJob else { return [] }
        return aiCronjobLogsData.entries(for: selectedJob.id)
    }

    private var jobsFooterItems: [AIWorkspaceSummaryItem] {
        guard let selectedJob else {
            return [
                .init(title: "Jobs", value: "\(experimentalAICronjobsData.count) configured"),
                .init(title: "Enabled", value: "\(enabledJobsCount) active")
            ]
        }

        let commands = effectiveAllowedCommands(for: selectedJob)
        let latestLog = selectedJobLogEntries.first.map { relativeTimestamp(for: $0.timestamp) } ?? "No logs"
        return [
            .init(title: "Schedule", value: scheduleDescription(for: selectedJob)),
            .init(title: "Permissions", value: "\(commands.count) command\(commands.count == 1 ? "" : "s")"),
            .init(title: "Latest Log", value: latestLog)
        ]
    }

    private var providersFooterItems: [AIWorkspaceSummaryItem] {
        [
            .init(title: "Configured", value: "\(providers.count) providers"),
            .init(title: "Enabled", value: "\(enabledProvidersCount) available")
        ]
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingPermissionsEditor) {
            if let jobBinding = editingCronjobBinding {
                AIJobPermissionsSheet(
                    job: jobBinding,
                    defaultCommands: whitelistCommands,
                    onDone: { showingPermissionsEditor = false }
                )
            }
        }
        .sheet(item: $viewingLogsForJob) { job in
            AIJobLogsSheet(
                job: job,
                jobName: job.name,
                entries: aiCronjobLogsData.entries(for: job.id),
                onClear: {
                    var updatedStore = aiCronjobLogsData
                    updatedStore.clear(jobID: job.id)
                    aiCronjobLogsData = updatedStore
                    AICronjobManager.shared.clearLogs(for: job.id)
                    if viewingLogsForJob?.id == job.id {
                        viewingLogsForJob = job
                    }
                },
                onRun: {
                    runJobForDevelopment(job)
                }
            )
        }
        .alert("Prompt Improvement Failed", isPresented: promptImprovementErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(promptImprovementErrorMessage)
        }
        .alert(providerTestSucceeded ? "Connection Succeeded" : "Connection Failed", isPresented: providerTestAlertBinding) {
            Button("OK", role: .cancel) {
                providerTestMessage = ""
            }
        } message: {
            Text(providerTestMessage)
        }
        .confirmationDialog(
            pendingJobDeletion.map { "Delete job \($0.name)?" } ?? "Delete job?",
            isPresented: pendingJobDeletionBinding,
            titleVisibility: .visible
        ) {
            Button("Delete Job", role: .destructive) {
                if let job = pendingJobDeletion {
                    deleteJob(job)
                }
                pendingJobDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingJobDeletion = nil
            }
        } message: {
            Text("This removes the job configuration and its saved logs.")
        }
        .onAppear(perform: syncSelectionState)
    }

    private var sidebar: some View {
        List([AIWorkspaceSection.jobs], selection: selectedSectionBinding) { section in
            AIWorkspaceSidebarRow(
                title: section.title,
                subtitle: section.subtitle,
                systemImage: section.systemImage,
                badge: badgeText(for: section)
            )
            .tag(section)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                selectedSection = .providers
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Manage Providers")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    AIWorkspaceMiniStatusRow(
                        title: "Active Provider",
                        value: activeProvider?.name ?? "None selected",
                        systemImage: "bolt.horizontal.circle"
                    )

                    AIWorkspaceMiniStatusRow(
                        title: "Model",
                        value: activeProvider?.effectiveModel ?? "None selected",
                        systemImage: "cpu"
                    )

                    AIWorkspaceMiniStatusRow(
                        title: "API Key",
                        value: activeProvider == nil ? "No provider" : (activeProviderHasAPIKey ? "Connected" : "Missing key"),
                        systemImage: activeProviderHasAPIKey ? "key.fill" : "exclamationmark.triangle"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(selectedSection == .providers ? AnyShapeStyle(Color.accentColor.opacity(0.10)) : AnyShapeStyle(.regularMaterial))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .jobs:
            jobsWorkspace
        case .providers:
            providersWorkspace
        }
    }

    private var jobsWorkspace: some View {
        VStack(alignment: .leading, spacing: 0) {
            jobsHeader

            Divider()

            HSplitView {
                AIWorkspacePane(title: "Jobs") {
                    if experimentalAICronjobsData.isEmpty {
                        AIWorkspaceEmptyState(
                            title: "No Agent Jobs yet",
                            subtitle: "Create one recurring task, then tune the schedule and prompt from the detail pane.",
                            systemImage: "sparkles.rectangle.stack"
                        )
                    } else {
                        List {
                            ForEach(experimentalAICronjobsData) { job in
                                AIJobRow(
                                    job: job,
                                    isSelected: editingCronjob?.id == job.id && !isCreatingNewCronjob,
                                    onSelect: {
                                        isCreatingNewCronjob = false
                                        editingCronjob = job
                                    },
                                    onRun: {
                                        runJobForDevelopment(job)
                                    },
                                    onViewLogs: {
                                        viewingLogsForJob = job
                                    },
                                    onDelete: {
                                        pendingJobDeletion = job
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)

                AIWorkspacePane(title: selectedJob == nil ? "Details" : (isCreatingNewCronjob ? "New Job" : "Job Details")) {
                    if let jobBinding = editingCronjobBinding {
                        AICronjobEditView(
                            cronjob: jobBinding,
                            providers: providers,
                            isNew: isCreatingNewCronjob,
                            minimumHeight: 0,
                            isImprovingPrompt: isImprovingPrompt,
                            onImprovePrompt: improveSelectedJobPrompt,
                            onConfigurePermissions: preparePermissionsEditor,
                            onViewLogs: {
                                if let selectedJob {
                                    viewingLogsForJob = selectedJob
                                }
                            },
                            onSave: saveEditingJob,
                            onCancel: {
                                editingCronjob = nil
                                isCreatingNewCronjob = false
                                syncSelectionState()
                            }
                        )
                    } else {
                        AIWorkspaceEmptyState(
                            title: "Select a job",
                            subtitle: "Click any job on the left to inspect it, edit it, or review its logs.",
                            systemImage: "square.and.pencil"
                        )
                    }
                }
                .frame(minWidth: 560)
            }
            .layoutPriority(1)

            Divider()

            statusFooter(
                summaryItems: jobsFooterItems,
                warning: jobsProviderWarning,
                actionTitle: "New Job",
                actionSystemImage: "plus",
                action: beginCreatingCronjob
            )
        }
    }

    private var providersWorkspace: some View {
        VStack(alignment: .leading, spacing: 0) {
            HSplitView {
                AIWorkspacePane(title: "Providers") {
                    if providers.isEmpty {
                        AIWorkspaceEmptyState(
                            title: "No providers configured",
                            subtitle: "Add OpenAI, DeepSeek, Ollama, or a custom endpoint to start wiring Agent Jobs.",
                            systemImage: "server.rack"
                        )
                    } else {
                        List {
                            ForEach(providers) { provider in
                                AIProviderRow(
                                    provider: provider,
                                    isSelected: editingProvider?.id == provider.id && !isCreatingNewProvider,
                                    isActive: activeAIProviderID == provider.id,
                                    hasAPIKey: provider.type.requiresAPIKey ? (KeychainService.getAPIKey(for: provider.id) != nil) : true,
                                    onSelect: { loadProviderEditor(provider, isCreating: false) },
                                    onSetActive: { activeAIProviderID = provider.id },
                                    onToggle: { isEnabled in
                                        updateProvider(provider) { item in
                                            item.isEnabled = isEnabled
                                        }
                                    },
                                    onDelete: { deleteProvider(provider) }
                                )
                                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)

                AIWorkspacePane(title: editingProvider == nil ? "Details" : (isCreatingNewProvider ? "New Provider" : "Provider Details")) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let editingProvider {
                                AIProviderDetailHeader(
                                    provider: editingProvider,
                                    isDefault: activeAIProviderID == editingProvider.id,
                                    hasAPIKey: editingProvider.type.requiresAPIKey ? (KeychainService.getAPIKey(for: editingProvider.id) != nil) : true
                                )

                                AIProviderEditorView(
                                    provider: editingProvider,
                                    isCreatingNewProvider: isCreatingNewProvider,
                                    providerType: $newProviderType,
                                    displayName: $newProviderName,
                                    apiKey: $newProviderAPIKey,
                                    model: $newProviderModel,
                                    baseURL: $newProviderBaseURL,
                                    zAIMode: $newProviderZAIMode,
                                    instructions: $newProviderInstructions,
                                    availableModels: availableModels,
                                    isFetchingModels: isFetchingModels,
                                    isTestingConnection: isTestingProvider,
                                    onFetchModels: {
                                        Task { await fetchModels() }
                                    },
                                    onTestConnection: {
                                        Task { await testProviderConnection() }
                                    },
                                    onCancel: {
                                        self.editingProvider = nil
                                        self.isCreatingNewProvider = false
                                        syncSelectionState()
                                    },
                                    onSave: saveProvider
                                )
                            } else {
                                AIWorkspaceEmptyState(
                                    title: "Select a provider",
                                    subtitle: "Pick one from the list to change model, endpoint, or activation state.",
                                    systemImage: "network"
                                )
                                .frame(minHeight: 280)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(minWidth: 560)
            }
            .layoutPriority(1)

            Divider()

            statusFooter(
                summaryItems: providersFooterItems,
                warning: nil,
                actionTitle: "Add Provider",
                actionSystemImage: "plus",
                action: beginCreatingProvider
            )
        }
    }

    private var jobsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let selectedJob {
                    Text(selectedJob.name)
                        .font(.title3.weight(.semibold))
                    Text(scheduleDescription(for: selectedJob))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Agent Jobs")
                        .font(.title3.weight(.semibold))
                    Text("Select a job to edit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func preparePermissionsEditor() {
        guard var job = editingCronjob else { return }

        if job.usesDefaultAllowedCommands || job.allowedCommands.isEmpty {
            job.allowedCommands = sanitizeCommands(whitelistCommands)
            job.usesDefaultAllowedCommands = false
            editingCronjob = job
        }

        showingPermissionsEditor = true
    }

    private func badgeText(for section: AIWorkspaceSection) -> String {
        switch section {
        case .jobs:
            return experimentalAICronjobsData.isEmpty ? "New" : "\(enabledJobsCount)/\(experimentalAICronjobsData.count)"
        case .providers:
            return providers.isEmpty ? "Add" : "\(providers.count)"
        }
    }

    @ViewBuilder
    private func statusFooter(
        summaryItems: [AIWorkspaceSummaryItem],
        warning: String?,
        actionTitle: String,
        actionSystemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                ForEach(summaryItems) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: action) {
                Label(actionTitle, systemImage: actionSystemImage)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var promptImprovementErrorBinding: Binding<Bool> {
        Binding(
            get: { !promptImprovementErrorMessage.isEmpty },
            set: { if !$0 { promptImprovementErrorMessage = "" } }
        )
    }

    private var providerTestAlertBinding: Binding<Bool> {
        Binding(
            get: { !providerTestMessage.isEmpty },
            set: { if !$0 { providerTestMessage = "" } }
        )
    }

    private var pendingJobDeletionBinding: Binding<Bool> {
        Binding(
            get: { pendingJobDeletion != nil },
            set: { if !$0 { pendingJobDeletion = nil } }
        )
    }

    private func syncSelectionState() {
        if experimentalAICronjobsData.isEmpty {
            if !isCreatingNewCronjob {
                editingCronjob = nil
            }
        } else if editingCronjob == nil || (!isCreatingNewCronjob && !experimentalAICronjobsData.contains(where: { $0.id == editingCronjob?.id })) {
            editingCronjob = experimentalAICronjobsData.first
        }

        if providers.isEmpty {
            if !isCreatingNewProvider {
                editingProvider = nil
            }
        } else if editingProvider == nil || (!isCreatingNewProvider && !providers.contains(where: { $0.id == editingProvider?.id })) {
            if let activeProvider {
                loadProviderEditor(activeProvider, isCreating: false)
            } else if let firstProvider = providers.first {
                loadProviderEditor(firstProvider, isCreating: false)
            }
        }
    }

    private func beginCreatingCronjob() {
        isCreatingNewCronjob = true
        editingCronjob = AICronjob()
    }

    private func beginCreatingProvider() {
        loadProviderEditor(AIProvider(type: .openai), isCreating: true)
    }

    private func loadProviderEditor(_ provider: AIProvider, isCreating: Bool) {
        editingProvider = provider
        isCreatingNewProvider = isCreating
        newProviderType = provider.type
        newProviderName = provider.name
        newProviderModel = provider.effectiveModel
        newProviderBaseURL = provider.effectiveBaseURL
        newProviderZAIMode = provider.zAIModelMode
        newProviderInstructions = provider.instructions.isEmpty ? (providerInstructionPresets[provider.type] ?? "") : provider.instructions
        newProviderAPIKey = isCreating ? "" : (KeychainService.getAPIKey(for: provider.id) ?? "")
        availableModels = []
    }

    private func updateJob(_ job: AICronjob, mutate: (inout AICronjob) -> Void) {
        guard let index = experimentalAICronjobsData.firstIndex(where: { $0.id == job.id }) else { return }
        var updated = experimentalAICronjobsData[index]
        mutate(&updated)
        updated.allowedCommands = sanitizeCommands(updated.allowedCommands)
        experimentalAICronjobsData[index] = updated

        if editingCronjob?.id == updated.id, !isCreatingNewCronjob {
            editingCronjob = updated
        }
    }

    private func deleteJob(_ job: AICronjob) {
        experimentalAICronjobsData.removeAll { $0.id == job.id }
        aiCronjobLogsData.clear(jobID: job.id)
        if editingCronjob?.id == job.id {
            editingCronjob = experimentalAICronjobsData.first
        }
        isCreatingNewCronjob = false
    }

    private func saveEditingJob() {
        guard var safeJob = editingCronjob else { return }
        safeJob.allowedCommands = sanitizeCommands(safeJob.allowedCommands)
        if safeJob.usesDefaultAllowedCommands {
            safeJob.allowedCommands = []
        }

        if isCreatingNewCronjob {
            experimentalAICronjobsData.append(safeJob)
        } else if let idx = experimentalAICronjobsData.firstIndex(where: { $0.id == safeJob.id }) {
            experimentalAICronjobsData[idx] = safeJob
        }

        editingCronjob = safeJob
        isCreatingNewCronjob = false
    }

    private func runJobForDevelopment(_ job: AICronjob) {
        var updatedStore = aiCronjobLogsData
        updatedStore.clear(jobID: job.id)
        aiCronjobLogsData = updatedStore
        AICronjobManager.shared.clearLogs(for: job.id)
        viewingLogsForJob = job
        AICronjobManager.shared.triggerTest(for: job)
    }

    private func updateProvider(_ provider: AIProvider, mutate: (inout AIProvider) -> Void) {
        var list = aiProvidersList
        guard let index = list.providers.firstIndex(where: { $0.id == provider.id }) else { return }
        var updated = list.providers[index]
        mutate(&updated)
        updated.updatedAt = Date().timeIntervalSince1970
        list.providers[index] = updated
        aiProvidersList = list

        if editingProvider?.id == updated.id, !isCreatingNewProvider {
            loadProviderEditor(updated, isCreating: false)
        }
    }

    private func deleteProvider(_ provider: AIProvider) {
        KeychainService.deleteAPIKeySilently(for: provider.id)

        var list = aiProvidersList
        list.providers.removeAll { $0.id == provider.id }
        aiProvidersList = list

        if activeAIProviderID == provider.id {
            activeAIProviderID = list.providers.first?.id
        }

        if editingProvider?.id == provider.id {
            editingProvider = nil
        }

        isCreatingNewProvider = false
        syncSelectionState()
    }

    private func saveProvider() {
        guard var provider = editingProvider else { return }

        provider.type = newProviderType
        provider.name = newProviderName.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.baseURL = newProviderBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.model = newProviderModel.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.zAIModelMode = newProviderZAIMode
        provider.instructions = newProviderInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.updatedAt = Date().timeIntervalSince1970

        if newProviderType.requiresAPIKey {
            let trimmedKey = newProviderAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                KeychainService.saveAPIKeyIfNotEmpty(for: provider.id, apiKey: trimmedKey)
            }
        } else {
            KeychainService.deleteAPIKeySilently(for: provider.id)
        }

        var list = aiProvidersList
        if isCreatingNewProvider {
            list.providers.append(provider)
            if activeAIProviderID == nil {
                activeAIProviderID = provider.id
            }
        } else if let index = list.providers.firstIndex(where: { $0.id == provider.id }) {
            list.providers[index] = provider
        }

        aiProvidersList = list
        KeychainService.migrateAPIKeysForBackgroundAccess(providerIDs: list.providers.map(\.id))
        isCreatingNewProvider = false
        loadProviderEditor(provider, isCreating: false)
    }

    private func fetchModels() async {
        guard !(newProviderType.requiresAPIKey && newProviderAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else {
            return
        }

        await MainActor.run { isFetchingModels = true }

        let safeURL = newProviderBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: "\(safeURL)/models") else {
            await MainActor.run { isFetchingModels = false }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let trimmedKey = newProviderAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                let rawModels = dataArray.compactMap { $0["id"] as? String }
                let filteredModels: [String]
                if newProviderType == .openai {
                    filteredModels = rawModels.filter {
                        $0.starts(with: "gpt") || $0.starts(with: "o1") || $0.starts(with: "o3")
                    }.sorted()
                } else {
                    filteredModels = rawModels.sorted()
                }

                await MainActor.run {
                    availableModels = filteredModels
                    if !filteredModels.isEmpty, !filteredModels.contains(newProviderModel) {
                        newProviderModel = filteredModels[0]
                    }
                    isFetchingModels = false
                }
            } else {
                await MainActor.run { isFetchingModels = false }
            }
        } catch {
            await MainActor.run { isFetchingModels = false }
        }
    }

    private func testProviderConnection() async {
        await MainActor.run {
            isTestingProvider = true
            providerTestMessage = ""
        }

        do {
            let result = try await AICronjobManager.testProviderConnection(
                providerType: newProviderType,
                apiKey: newProviderAPIKey,
                baseURL: newProviderBaseURL,
                model: newProviderModel
            )

            await MainActor.run {
                providerTestSucceeded = true
                providerTestMessage = result
                isTestingProvider = false
            }
        } catch {
            await MainActor.run {
                providerTestSucceeded = false
                providerTestMessage = error.localizedDescription
                isTestingProvider = false
            }
        }
    }

    private func effectiveAllowedCommands(for job: AICronjob) -> [String] {
        if job.usesDefaultAllowedCommands {
            return whitelistCommands
        }
        return sanitizeCommands(job.allowedCommands)
    }

    private func sanitizeCommands(_ commands: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for command in commands {
            let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            ordered.append(trimmed)
        }

        return ordered
    }

    private func scheduleDescription(for job: AICronjob) -> String {
        if job.mode == .app {
            return "Every \(Int(job.interval))s"
        }
        return "Cron \(job.cronExpression)"
    }

    private func relativeTimestamp(for timestamp: Double) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: Date(timeIntervalSince1970: timestamp), relativeTo: Date())
    }

    private func improveSelectedJobPrompt() {
        guard var job = editingCronjob else { return }
        let prompt = job.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            promptImprovementErrorMessage = "Add a prompt first so the provider has something to improve."
            return
        }

        isImprovingPrompt = true
        Task {
            do {
                let improved = try await AICronjobManager.shared.improvePrompt(prompt, jobName: job.name)
                await MainActor.run {
                    job.prompt = improved
                    editingCronjob = job
                    isImprovingPrompt = false
                }
            } catch {
                await MainActor.run {
                    promptImprovementErrorMessage = error.localizedDescription
                    isImprovingPrompt = false
                }
            }
        }
    }
}

private struct AIWorkspaceSummaryItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct AIWorkspacePane<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.top, 12)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.clear)
    }
}

private struct AIWorkspaceMiniStatusRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct AIWorkspaceSidebarRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let badge: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Spacer(minLength: 6)
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AIWorkspaceEmptyState: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AIJobRow: View {
    let job: AICronjob
    let isSelected: Bool
    let onSelect: () -> Void
    let onRun: () -> Void
    let onViewLogs: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(job.name)
                        .font(.body.weight(.semibold))

                    Text(job.mode == .app ? "App" : "Daemon")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                        .foregroundStyle(.secondary)

                    Text(job.isEnabled ? "Active" : "Paused")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background((job.isEnabled ? Color.green : Color.secondary).opacity(0.14), in: Capsule())
                        .foregroundStyle(job.isEnabled ? Color.green : Color.secondary)
                }

                if !job.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(job.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(job.mode == .app ? "Every \(Int(job.interval)) seconds" : "Cron \(job.cronExpression)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(action: onRun) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .help("Run Job Now")

                Button(action: onViewLogs) {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("View Logs")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.08) : .clear)
        .clipShape(.rect(cornerRadius: 10))
        .contentShape(.rect)
        .onTapGesture(perform: onSelect)
    }
}

private struct AIProviderRow: View {
    let provider: AIProvider
    let isSelected: Bool
    let isActive: Bool
    let hasAPIKey: Bool
    let onSelect: () -> Void
    let onSetActive: () -> Void
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            providerIcon(provider.type)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(provider.name)
                        .font(.body.weight(.semibold))

                    if isActive {
                        Text("Default")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text("\(provider.type.displayName) - \(provider.effectiveModel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(hasAPIKey ? "Keychain ready" : "API key missing")
                    .font(.caption)
                    .foregroundStyle(hasAPIKey ? Color.secondary : Color.orange)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(isActive ? "Default" : "Set Default", action: onSetActive)
                    .controlSize(.small)
                    .disabled(isActive)

                Toggle("", isOn: Binding(get: { provider.isEnabled }, set: onToggle))
                    .labelsHidden()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.08) : .clear)
        .clipShape(.rect(cornerRadius: 10))
        .contentShape(.rect)
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private func providerIcon(_ type: AIProviderType) -> some View {
        let iconName = type.iconAssetName
        if let image = NSImage(named: iconName) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "server.rack")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
    }
}

private struct AIWorkspaceActiveProviderCard: View {
    let provider: AIProvider
    let hasAPIKey: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Provider")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(provider.name)
                .font(.headline)

            Text("\(provider.type.displayName) - \(provider.effectiveModel)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(hasAPIKey ? "Credentials are stored in Keychain." : "Add an API key to finish this provider.")
                .font(.footnote)
                .foregroundStyle(hasAPIKey ? Color.secondary : Color.orange)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: .rect(cornerRadius: 12))
    }
}

private struct AIProviderEditorView: View {
    let provider: AIProvider
    let isCreatingNewProvider: Bool
    @Binding var providerType: AIProviderType
    @Binding var displayName: String
    @Binding var apiKey: String
    @Binding var model: String
    @Binding var baseURL: String
    @Binding var zAIMode: ZAIMode
    @Binding var instructions: String
    let availableModels: [String]
    let isFetchingModels: Bool
    let isTestingConnection: Bool
    let onFetchModels: () -> Void
    let onTestConnection: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Provider Type")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Provider Type", selection: $providerType) {
                            ForEach(AIProviderType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display Name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("OpenAI", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Endpoint")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("https://api.example.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                }

                if providerType == .zai {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Z.ai Mode")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Z.ai Mode", selection: $zAIMode) {
                            ForEach(ZAIMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(zAIMode == .coding ? "Uses the dedicated coding endpoint for GLM coding-plan models." : "Uses the general endpoint for standard Z.ai models.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Model")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        if isFetchingModels {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Model ID", text: $model)
                            .textFieldStyle(.roundedBorder)

                        let suggestedModels = providerType == .zai ? zAIMode.suggestedModels : []

                        if !suggestedModels.isEmpty {
                            Menu {
                                ForEach(suggestedModels, id: \.self) { suggestedModel in
                                    Button(suggestedModel) {
                                        model = suggestedModel
                                        if providerType == .zai {
                                            baseURL = zAIMode.defaultBaseURL
                                        }
                                    }
                                }
                            } label: {
                                Label("Presets", systemImage: "slider.horizontal.3")
                            }
                            .menuStyle(.borderlessButton)
                        }

                        if !availableModels.isEmpty {
                            Menu {
                                ForEach(availableModels, id: \.self) { availableModel in
                                    Button(availableModel) {
                                        model = availableModel
                                    }
                                }
                            } label: {
                                Label("Models", systemImage: "list.bullet")
                            }
                            .menuStyle(.borderlessButton)
                        }

                        Button(action: onFetchModels) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Fetch available models")

                        Button(action: onTestConnection) {
                            if isTestingConnection {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Test", systemImage: "bolt.horizontal.circle")
                            }
                        }
                        .buttonStyle(.borderless)
                        .help("Test provider connection")
                        .disabled(isTestingConnection)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(providerType == .custom ? "Custom Instructions" : "Provider Instructions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField(
                        providerType == .custom
                            ? "Optional system guidance for this custom provider"
                            : "Optional provider-specific guidance",
                        text: $instructions,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    Text("Applied before the job prompt. Useful for provider quirks, response style, or custom compatibility notes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if providerType.requiresAPIKey {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        SecureField(isCreatingNewProvider ? "sk-..." : "Leave blank to keep existing key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                        Text("Saved securely in Keychain. Existing keys stay untouched if this field stays blank while editing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("This provider does not require an API key.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button("Cancel", action: onCancel)
                Spacer(minLength: 0)
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .onChange(of: providerType) { _, newType in
            if isCreatingNewProvider {
                displayName = newType.displayName
                baseURL = newType.defaultBaseURL
                model = newType.defaultModel
                if newType == .zai {
                    baseURL = zAIMode.defaultBaseURL
                    model = zAIMode.defaultModel
                }
            }
            if instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                instructions = providerInstructionPreset(for: newType)
            }
        }
        .onChange(of: zAIMode) { _, newMode in
            guard providerType == .zai else { return }
            baseURL = newMode.defaultBaseURL
            if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !newMode.suggestedModels.contains(model) {
                model = newMode.defaultModel
            }
        }
        .onAppear {
            if isCreatingNewProvider {
                baseURL = providerType.defaultBaseURL
                model = providerType.defaultModel
                if providerType == .zai {
                    baseURL = zAIMode.defaultBaseURL
                    model = zAIMode.defaultModel
                }
                if instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    instructions = providerInstructionPreset(for: providerType)
                }
            }
        }
    }

    private func providerInstructionPreset(for type: AIProviderType) -> String {
        switch type {
        case .zai:
            return "Z.ai compatibility: if using Coding Plan, prefer coding-oriented models like GLM-4.7 and keep tool usage structured. Do not expose hidden reasoning. If a command is blocked or a service is offline, stop and provide a direct final diagnosis."
        case .minimax:
            return "You are running inside NotchTerminal, a macOS automation agent with strict command safety rules. Never reveal hidden reasoning or thinking tags. Use one simple command at a time. Do not use pipes, redirects, shell chaining, or GUI-launch commands unless explicitly allowed. If a command fails because a service is offline, permissions block it, or the whitelist forbids it, stop and give a short final diagnosis with the best next step."
        case .custom:
            return "This provider is expected to behave like an OpenAI-compatible chat completions endpoint. Keep answers concise, avoid hidden reasoning output, and stop quickly when tools fail or are blocked."
        default:
            return ""
        }
    }
}

private struct AIProviderDetailHeader: View {
    let provider: AIProvider
    let isDefault: Bool
    let hasAPIKey: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            providerIcon(provider.type)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(provider.name)
                        .font(.headline)

                    if isDefault {
                        Text("Default")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text(provider.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(hasAPIKey ? "Keychain ready" : "API key missing")
                    .font(.caption)
                    .foregroundStyle(hasAPIKey ? Color.secondary : Color.orange)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func providerIcon(_ type: AIProviderType) -> some View {
        let iconName = type.iconAssetName
        if let image = NSImage(named: iconName) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "server.rack")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
    }
}

private struct AIJobPermissionsSheet: View {
    @Binding var job: AICronjob
    let defaultCommands: [String]
    let onDone: () -> Void

    @State private var draftCommands: [String] = []
    @State private var editingCommandIndex: Int?

    private var commands: [String] {
        sanitize(draftCommands)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Job Permissions")
                        .font(.headline)
                    Text("These commands are copied from the default list once, and then become editable only for this job.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
            }

            Text("\(commands.count) command\(commands.count == 1 ? "" : "s") for this job")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if commands.isEmpty {
                Text("No commands yet. Add one below.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    EditableCommandGrid(commands: commands, onSelect: { index in
                        editingCommandIndex = index
                    }, onRemove: { index in
                        removeCommand(at: index)
                    }, editingIndex: editingCommandIndex, bindingForIndex: { index in
                        Binding(
                            get: { draftCommands[safe: index] ?? "" },
                            set: { updateDraft(at: index, with: $0) }
                        )
                    }, onSubmit: { index in
                        finishEditing(index: index)
                    })
                }
                .frame(maxHeight: 260)
            }

            addCommandChip

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
        .onAppear {
            if job.allowedCommands.isEmpty {
                job.allowedCommands = sanitize(defaultCommands)
            }
            job.usesDefaultAllowedCommands = false
            draftCommands = sanitize(job.allowedCommands)
        }
    }

    @ViewBuilder
    private func editableCommandChip(index: Int, command: String) -> some View {
        HStack(spacing: 6) {
            if editingCommandIndex == index {
                TextField("command", text: Binding(
                    get: { draftCommands[safe: index] ?? "" },
                    set: { updateDraft(at: index, with: $0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(minWidth: 72)
                .onSubmit {
                    finishEditing(index: index)
                }
            } else {
                Button {
                    editingCommandIndex = index
                } label: {
                    Text(command)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .buttonStyle(.plain)
            }

            Button {
                removeCommand(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        .onTapGesture {
            editingCommandIndex = index
        }
    }

    private var addCommandChip: some View {
        Button {
            draftCommands.append("")
            editingCommandIndex = draftCommands.count - 1
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("Add command")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func updateDraft(at index: Int, with value: String) {
        guard draftCommands.indices.contains(index) else { return }
        draftCommands[index] = value
        syncJobCommands()
    }

    private func finishEditing(index: Int) {
        guard draftCommands.indices.contains(index) else { return }
        let trimmed = draftCommands[index].trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            removeCommand(at: index)
        } else {
            draftCommands[index] = trimmed
            syncJobCommands()
            editingCommandIndex = nil
        }
    }

    private func removeCommand(at index: Int) {
        guard draftCommands.indices.contains(index) else { return }
        draftCommands.remove(at: index)
        if let editingCommandIndex {
            if editingCommandIndex == index {
                self.editingCommandIndex = nil
            } else if editingCommandIndex > index {
                self.editingCommandIndex = editingCommandIndex - 1
            }
        }
        syncJobCommands()
    }

    private func syncJobCommands() {
        let cleaned = sanitize(draftCommands)
        draftCommands = cleaned
        job.allowedCommands = cleaned
        job.usesDefaultAllowedCommands = false
    }

    private func sanitize(_ commands: [String]) -> [String] {
        var seen = Set<String>()
        return commands.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return nil }
            seen.insert(trimmed)
            return trimmed
        }
    }
}

private struct EditableCommandGrid: View {
    let commands: [String]
    let onSelect: (Int) -> Void
    let onRemove: (Int) -> Void
    let editingIndex: Int?
    let bindingForIndex: (Int) -> Binding<String>
    let onSubmit: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let rows = stride(from: 0, to: commands.count, by: 4).map { start in
                Array(start..<Swift.min(start + 4, commands.count))
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { row in
                HStack(spacing: 8) {
                    ForEach(row.element, id: \.self) { index in
                        HStack(spacing: 6) {
                            if editingIndex == index {
                                TextField("command", text: bindingForIndex(index))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .frame(minWidth: 72)
                                    .onSubmit {
                                        onSubmit(index)
                                    }
                            } else {
                                Button {
                                    onSelect(index)
                                } label: {
                                    Text(commands[index])
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                onRemove(index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                        .onTapGesture {
                            onSelect(index)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private struct AIJobLogsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let job: AICronjob
    let jobName: String
    let entries: [AICronjobLogEntry]
    let onClear: () -> Void
    let onRun: () -> Void

    @State private var selectedLevels = Set(AICronjobLogLevel.allCases)
    @State private var searchText = ""
    @State private var aiQuestion = ""
    @State private var reviewMessages: [AIReviewMessage] = []
    @State private var isReviewingWithAI = false
    @State private var aiErrorMessage = ""
    @State private var showingClearConfirmation = false
    @State private var autoFollowLogs = true
    @State private var logViewportHeight: CGFloat = 1
    @State private var suppressAutoFollowTracking = false
    @State private var revealThinking = false

    private let logBottomID = "job-logs-bottom"

    private var filteredEntries: [AICronjobLogEntry] {
        entries
            .sorted { $0.timestamp < $1.timestamp }
            .filter { entry in
            guard selectedLevels.contains(entry.level) else { return false }
            let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedQuery.isEmpty else { return true }
            return entry.message.localizedStandardContains(trimmedQuery)
                || entry.level.rawValue.localizedStandardContains(trimmedQuery)
                || timestampText(for: entry.timestamp).localizedStandardContains(trimmedQuery)
            }
    }

    private var levelCounts: [AICronjobLogLevel: Int] {
        Dictionary(grouping: entries, by: \.level).mapValues(\.count)
    }

    private var exportedText: String {
        let header = "NotchTerminal Job Logs\nJob: \(jobName)\nPrompt:\n\(job.prompt)\n\n"
        let body = filteredEntries.map { entry in
            "[\(entry.level.rawValue.uppercased())] \(timestampText(for: entry.timestamp))\n\(entry.message)"
        }.joined(separator: "\n\n")
        return header + body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HSplitView {
                VStack(alignment: .leading, spacing: 12) {
                    filtersBar

                    if entries.isEmpty {
                        AIWorkspaceEmptyState(
                            title: "No logs yet",
                            subtitle: "Run the job or enable debug logging to inspect provider requests, errors, and command activity.",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    } else if filteredEntries.isEmpty {
                        AIWorkspaceEmptyState(
                            title: "No matching logs",
                            subtitle: "Try changing the filters or search text.",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    } else {
                        GeometryReader { geometry in
                            ScrollViewReader { proxy in
                                ZStack(alignment: .bottomTrailing) {
                                    ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 0) {
                                            ForEach(filteredEntries) { entry in
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack(spacing: 8) {
                                                        Text(entry.level.rawValue.uppercased())
                                                            .font(.caption2.weight(.bold))
                                                            .foregroundStyle(color(for: entry.level))

                                                        Text(timestampText(for: entry.timestamp))
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }

                                                    Text(entry.message)
                                                        .font(.system(.body, design: .monospaced))
                                                        .textSelection(.enabled)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)

                                                Divider()
                                            }

                                            Color.clear
                                                .frame(height: 1)
                                                .id(logBottomID)
                                                .background(
                                                    GeometryReader { marker in
                                                        Color.clear.preference(
                                                            key: LogBottomOffsetPreferenceKey.self,
                                                            value: marker.frame(in: .named("AIJobLogsScroll")).maxY
                                                        )
                                                    }
                                                )
                                        }
                                    }
                                    .coordinateSpace(name: "AIJobLogsScroll")
                                    .clipShape(.rect(cornerRadius: 12))
                                    .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                    )
                                    .onAppear {
                                        logViewportHeight = geometry.size.height
                                        if autoFollowLogs {
                                            scrollToBottom(with: proxy, animated: false)
                                        }
                                    }
                                    .onChange(of: geometry.size.height) { _, newHeight in
                                        logViewportHeight = newHeight
                                    }
                                    .onChange(of: filteredEntries.map(\.id)) { _, _ in
                                        if autoFollowLogs {
                                            scrollToBottom(with: proxy, animated: true)
                                        }
                                    }
                                    .onPreferenceChange(LogBottomOffsetPreferenceKey.self) { bottomOffset in
                                        guard !suppressAutoFollowTracking else { return }
                                        autoFollowLogs = (bottomOffset - logViewportHeight) <= 28
                                    }

                                    if !autoFollowLogs {
                                        Button {
                                            autoFollowLogs = true
                                            scrollToBottom(with: proxy, animated: true)
                                        } label: {
                                            Label("Jump to Latest", systemImage: "arrow.down.circle.fill")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .padding(12)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 720, minHeight: 480)

                aiReviewPane
                    .frame(minWidth: 300, idealWidth: 340)
            }

            footerBar
        }
        .padding(20)
        .frame(minWidth: 1040, minHeight: 620)
        .alert("AI Review Failed", isPresented: aiErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(aiErrorMessage)
        }
        .confirmationDialog("Clear logs for \(jobName)?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Clear Logs", role: .destructive, action: clearLogs)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the persisted log history for this job.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Job Logs")
                    .font(.headline)
                Text(jobName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(filteredEntries.count) of \(entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button {
                    reviewWithAI()
                } label: {
                    Label("Review with AI", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(entries.isEmpty || isReviewingWithAI)

                Button(action: copyLogs) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(filteredEntries.isEmpty)

                Button(action: exportLogs) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(filteredEntries.isEmpty)

                Button(action: onRun) {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var filtersBar: some View {
        HStack(spacing: 10) {
            ForEach(AICronjobLogLevel.allCases, id: \.self) { level in
                Button {
                    toggle(level)
                } label: {
                    Text("\(level.rawValue.capitalized) \(levelCounts[level, default: 0])")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedLevels.contains(level) ? Color.primary : Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedLevels.contains(level) ? color(for: level).opacity(0.14) : Color(nsColor: .controlBackgroundColor), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            TextField("Filter logs", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Button("All") {
                selectedLevels = Set(AICronjobLogLevel.allCases)
            }
            .buttonStyle(.borderless)
        }
    }

    private var aiReviewPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Review")
                .font(.headline)

            Text("Ask what failed, why it happened, or how to fix this job.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show thinking", isOn: $revealThinking)
                .toggleStyle(.switch)

            ScrollView {
                if reviewMessages.isEmpty {
                    Text("The AI review will use the original prompt, job configuration, permissions, and the current filtered logs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(reviewMessages) { message in
                            AIReviewBubble(message: message, revealThinking: revealThinking)
                        }
                    }
                }
            }

            Divider()

            TextField("What is the main problem here?", text: $aiQuestion, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .onSubmit {
                    reviewWithAI()
                }

            HStack(spacing: 8) {
                Button {
                    reviewWithAI()
                } label: {
                    if isReviewingWithAI {
                        Label("Reviewing...", systemImage: "hourglass")
                    } else {
                        Label("Send", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(entries.isEmpty || isReviewingWithAI)

                if !reviewMessages.isEmpty {
                    Button("Clear Chat") {
                        reviewMessages.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
    }

    private var footerBar: some View {
        HStack {
            Button("Clear Logs", role: .destructive) {
                showingClearConfirmation = true
            }
            .buttonStyle(.bordered)
            .disabled(entries.isEmpty)

            Spacer(minLength: 0)

            if autoFollowLogs {
                Label("Following live logs", systemImage: "arrow.down.to.line.compact")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Auto-follow paused", systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aiErrorBinding: Binding<Bool> {
        Binding(
            get: { !aiErrorMessage.isEmpty },
            set: { if !$0 { aiErrorMessage = "" } }
        )
    }

    private func toggle(_ level: AICronjobLogLevel) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }

    private func copyLogs() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(exportedText, forType: .string)
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = sanitizedFileName(jobName) + "-logs.txt"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try exportedText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            aiErrorMessage = error.localizedDescription
        }
    }

    private func reviewWithAI() {
        guard !filteredEntries.isEmpty else { return }
        let question = aiQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalQuestion = question.isEmpty ? "What is the problem in these logs and what are the best fixes?" : question

        reviewMessages.append(AIReviewMessage(role: .user, text: finalQuestion))
        aiQuestion = ""
        isReviewingWithAI = true

        Task {
            do {
                let history = reviewMessages.map { message in
                    "\(message.role == .user ? "User" : "Assistant"): \(message.text)"
                }
                let result = try await AICronjobManager.shared.analyzeLogs(
                    for: job,
                    entries: filteredEntries,
                    question: finalQuestion,
                    conversationHistory: history
                )
                await MainActor.run {
                    reviewMessages.append(AIReviewMessage(role: .assistant, text: result))
                    isReviewingWithAI = false
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = error.localizedDescription
                    isReviewingWithAI = false
                }
            }
        }
    }

    private func clearLogs() {
        onClear()
        autoFollowLogs = true
    }

    private func scrollToBottom(with proxy: ScrollViewProxy, animated: Bool) {
        suppressAutoFollowTracking = true

        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(logBottomID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(logBottomID, anchor: .bottom)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                suppressAutoFollowTracking = false
            }
        }
    }

    private func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet.alphanumerics.union(.init(charactersIn: "-_" )).inverted
        let cleaned = name.components(separatedBy: invalid).filter { !$0.isEmpty }.joined(separator: "-")
        return cleaned.isEmpty ? "job" : cleaned.lowercased()
    }

    private func color(for level: AICronjobLogLevel) -> Color {
        switch level {
        case .info:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .debug:
            return .blue
        }
    }

    private func timestampText(for timestamp: Double) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

private struct AIReviewMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

private struct AIReviewBubble: View {
    let message: AIReviewMessage
    let revealThinking: Bool

    var body: some View {
        let displayedText = revealThinking ? message.text : sanitizedText

        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .user ? "You" : "NotchTerminal AI")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(displayedText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(backgroundColor, in: .rect(cornerRadius: 12))
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor.opacity(0.10)
        case .assistant:
            return Color(nsColor: .controlBackgroundColor)
        }
    }

    private var sanitizedText: String {
        let text = message.text.replacingOccurrences(
            of: "(?is)<think>.*?</think>",
            with: "",
            options: .regularExpression
        )
        return text
            .replacingOccurrences(of: "<think>", with: "")
            .replacingOccurrences(of: "</think>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct LogBottomOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct FlexibleTagLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let rows = stride(from: 0, to: items.count, by: 4).map {
                Array(items[$0..<Swift.min($0 + 4, items.count)])
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { element in
                HStack(spacing: 8) {
                    ForEach(element.element, id: \.self) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

#Preview {
    AIControlCenterView()
        .frame(width: 1_220, height: 780)
}
