import AppKit
import SwiftUI

struct AIProvidersSettingsView: View {
    @AppStorage(AppPreferences.Keys.aiProvidersData) var aiProvidersList: AIProviderList = AppPreferences.Defaults.aiProvidersData
    @AppStorage(AppPreferences.Keys.activeAIProviderID) var activeAIProviderIDString: String = AppPreferences.Defaults.activeAIProviderID
    @AppStorage(AppPreferences.Keys.experimentalFloatingMsgEnabled) var experimentalFloatingMsgEnabled: Bool = AppPreferences.Defaults.experimentalFloatingMsgEnabled

    @State private var selectedProviderID: UUID?
    @State private var editingProvider: AIProvider?
    @State private var isCreatingNewProvider = false
    @State private var newProviderType: AIProviderType = .openai
    @State private var newProviderName = ""
    @State private var newProviderAPIKey = ""
    @State private var newProviderModel = ""
    @State private var newProviderBaseURL = ""
    @State private var availableModels: [String] = []
    @State private var isFetchingModels = false

    private var aiProvidersData: [AIProvider] {
        aiProvidersList.providers
    }

    private var activeAIProviderID: UUID? {
        get { UUID(uuidString: activeAIProviderIDString) }
        nonmutating set { activeAIProviderIDString = newValue?.uuidString ?? "" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                contentSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .reportSettingsContentHeight(for: .aiProviders)
        }
    }

    private var contentSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "AI Providers",
                subtitle: "Manage your AI provider configurations. API keys are securely stored in Keychain.",
                icon: "server.rack"
            )

            NotchTerminalPreferenceToggleRow(
                title: "Enable NotchAgent",
                subtitle: "Master switch to run background AI tasks",
                icon: "timer",
                binding: $experimentalFloatingMsgEnabled
            )

            if experimentalFloatingMsgEnabled {
                providersListSection

                if let editingProvider {
                    Divider()
                        .padding(.top, 8)

                    providerEditorSection(editingProvider)
                }
            }
        }
    }

    private var providersListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configured Providers")
                        .font(.headline)

                    Text("Select which provider to use for NotchAgent jobs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isCreatingNewProvider = true
                    newProviderType = .openai
                    newProviderName = AIProviderType.openai.displayName
                    newProviderAPIKey = ""
                    newProviderModel = AIProviderType.openai.defaultModel
                    newProviderBaseURL = AIProviderType.openai.defaultBaseURL
                    editingProvider = AIProvider(type: .openai)
                } label: {
                    Label("Add Provider", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if aiProvidersData.isEmpty {
                ContentUnavailableView(
                    "No Providers Configured",
                    systemImage: "server.rack",
                    description: Text("Add your first AI provider to enable NotchAgent jobs.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(aiProvidersData) { provider in
                        providerRow(provider)
                    }
                }
            }
        }
        .padding(.leading, 32)
    }

    private func providerRow(_ provider: AIProvider) -> some View {
        HStack(alignment: .top, spacing: 14) {
            providerIcon(provider.type)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(provider.name)
                        .font(.headline)

                    if let activeAIProviderID, activeAIProviderID == provider.id {
                        Text("Active")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }

                    if !provider.isEnabled {
                        Text("Disabled")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                Text(provider.type.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Model: \(provider.effectiveModel)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    setActiveProvider(provider.id)
                } label: {
                    Image(systemName: (activeAIProviderID == provider.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle((activeAIProviderID == provider.id) ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help((activeAIProviderID == provider.id) ? "Active Provider" : "Set as Active")

                Toggle("", isOn: Binding(
                    get: { provider.isEnabled },
                    set: { newValue in
                        updateProvider(provider) { $0.isEnabled = newValue }
                    }
                ))
                .labelsHidden()

                Button {
                    isCreatingNewProvider = false
                    editingProvider = provider
                    newProviderAPIKey = KeychainService.getAPIKey(for: provider.id) ?? ""
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)

                Button {
                    deleteProvider(provider)
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
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
    }

    private func providerEditorSection(_ provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isCreatingNewProvider ? "New Provider" : "Edit Provider")
                        .font(.headline)

                    Text("Configure the provider connection and model settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()

            Form {
                Section {
                    Picker("Provider Type", selection: $newProviderType) {
                        ForEach(AIProviderType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: newProviderType) { _, newType in
                        if isCreatingNewProvider {
                            newProviderName = newType.displayName
                            newProviderBaseURL = newType.defaultBaseURL
                            newProviderModel = newType.defaultModel
                        }
                    }

                    TextField("Display Name", text: $newProviderName)

                    if newProviderType == .custom {
                        TextField("Base URL", text: $newProviderBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section {
                    if newProviderType.requiresAPIKey {
                        HStack {
                            Text("API Key")
                                .font(.subheadline)
                            Spacer()
                            SecureField("sk-...", text: $newProviderAPIKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 320)
                        }
                    }

                    HStack {
                        Text("Model")
                            .font(.subheadline)
                        Spacer()

                        if isFetchingModels {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        }

                        HStack(spacing: 6) {
                            TextField("Model ID", text: $newProviderModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)

                            if !availableModels.isEmpty {
                                Menu {
                                    ForEach(availableModels, id: \.self) { model in
                                        Button(model) {
                                            newProviderModel = model
                                        }
                                    }
                                } label: {
                                    Image(systemName: "chevron.down.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .menuStyle(.borderlessButton)
                                .menuIndicator(.hidden)
                                .fixedSize()
                                .help("Select from fetched models")
                            }
                        }

                        Button {
                            Task { await fetchModels() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(newProviderAPIKey.isEmpty || isFetchingModels)
                        .help("Refresh Models")
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    editingProvider = nil
                    isCreatingNewProvider = false
                }

                Spacer()

                Button("Save") {
                    saveProvider()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newProviderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            if isCreatingNewProvider {
                newProviderType = provider.type
                newProviderName = provider.name
                newProviderModel = provider.model
                newProviderBaseURL = provider.baseURL
                newProviderAPIKey = ""
            } else {
                newProviderType = provider.type
                newProviderName = provider.name
                newProviderModel = provider.model
                newProviderBaseURL = provider.baseURL
                newProviderAPIKey = KeychainService.getAPIKey(for: provider.id) ?? ""
            }
        }
    }

    private func setActiveProvider(_ id: UUID) {
        activeAIProviderID = id
    }

    private func updateProvider(_ provider: AIProvider, mutate: (inout AIProvider) -> Void) {
        var list = aiProvidersList
        guard let index = list.providers.firstIndex(where: { $0.id == provider.id }) else { return }
        var updated = list.providers[index]
        mutate(&updated)
        updated.updatedAt = Date().timeIntervalSince1970
        list.providers[index] = updated
        aiProvidersList = list
    }

    private func deleteProvider(_ provider: AIProvider) {
        KeychainService.deleteAPIKeySilently(for: provider.id)
        var list = aiProvidersList
        list.providers.removeAll { $0.id == provider.id }
        aiProvidersList = list
        if editingProvider?.id == provider.id {
            editingProvider = nil
        }
        if activeAIProviderID == provider.id {
            activeAIProviderID = list.providers.first?.id
        }
    }

    private func saveProvider() {
        guard var provider = editingProvider else { return }

        provider.name = newProviderName.trimmingCharacters(in: .whitespacesAndNewlines)
        provider.type = newProviderType
        provider.baseURL = newProviderBaseURL
        provider.model = newProviderModel
        provider.updatedAt = Date().timeIntervalSince1970

        if newProviderType.requiresAPIKey {
            KeychainService.saveAPIKeyIfNotEmpty(for: provider.id, apiKey: newProviderAPIKey)
        }

        var list = aiProvidersList
        if isCreatingNewProvider {
            list.providers.append(provider)
            if activeAIProviderID == nil {
                activeAIProviderID = provider.id
            }
        } else if let idx = list.providers.firstIndex(where: { $0.id == provider.id }) {
            list.providers[idx] = provider
        }
        aiProvidersList = list

        editingProvider = nil
        isCreatingNewProvider = false
    }

    private func fetchModels() async {
        let apiKey = newProviderAPIKey
        guard !apiKey.isEmpty else { return }

        await MainActor.run { isFetchingModels = true }

        let baseURL = newProviderType == .custom ? newProviderBaseURL : newProviderType.defaultBaseURL
        let safeURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: "\(safeURL)/models") else {
            await MainActor.run { isFetchingModels = false }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                let rawModels = dataArray.compactMap { $0["id"] as? String }

                let filteredModels: [String]
                if newProviderType == .openai {
                    filteredModels = rawModels.filter { $0.starts(with: "gpt") || $0.starts(with: "o1") || $0.starts(with: "o3") }.sorted()
                } else {
                    filteredModels = rawModels.sorted()
                }

                await MainActor.run {
                    availableModels = filteredModels
                    if !filteredModels.contains(newProviderModel) && !filteredModels.isEmpty {
                        newProviderModel = filteredModels.first ?? newProviderModel
                    }
                    isFetchingModels = false
                }
            } else {
                await MainActor.run { isFetchingModels = false }
            }
        } catch {
            print("Error fetching models: \(error)")
            await MainActor.run { isFetchingModels = false }
        }
    }
}