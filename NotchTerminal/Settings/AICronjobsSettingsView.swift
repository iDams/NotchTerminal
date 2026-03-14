import SwiftUI
import AppKit

struct AICronjobsSettingsView: View {
    @AppStorage(AppPreferences.Keys.experimentalFloatingMsgEnabled) var experimentalFloatingMsgEnabled: Bool = AppPreferences.Defaults.experimentalFloatingMsgEnabled
    @AppStorage(AppPreferences.Keys.experimentalAIProvider) var experimentalAIProvider: String = AppPreferences.Defaults.experimentalAIProvider
    @AppStorage(AppPreferences.Keys.experimentalAICustomURL) var experimentalAICustomURL: String = AppPreferences.Defaults.experimentalAICustomURL
    @AppStorage(AppPreferences.Keys.experimentalAIApiKey) var experimentalAIApiKey: String = AppPreferences.Defaults.experimentalAIApiKey
    @AppStorage(AppPreferences.Keys.experimentalAIModel) var experimentalAIModel: String = AppPreferences.Defaults.experimentalAIModel
    @AppStorage(AppPreferences.Keys.experimentalAICronjobsData) var experimentalAICronjobsData: [AICronjob] = AppPreferences.Defaults.experimentalAICronjobsData

    @State private var availableModels: [String] = []
    @State private var isFetchingModels = false

    @State private var showingEditSheet = false
    @State private var editingCronjob: AICronjob?
    @State private var isCreatingNewCronjob = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                floatingMessageSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .reportSettingsContentHeight(for: .aiCronjobs)
        }
    }

    private var floatingMessageSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "NotchAgent (Experimental)",
                subtitle: "Automate background tasks and get silent notifications powered by AI.",
                icon: "cpu"
            )
            
            Text("⚠️ This feature is in beta and might change in future updates.")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.bottom, 4)
            
            NotchTerminalPreferenceToggleRow(
                title: "Enable NotchAgent",
                subtitle: "Master switch to run background AI tasks",
                icon: "timer",
                binding: $experimentalFloatingMsgEnabled
            )
            
            if experimentalFloatingMsgEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Global Provider Configuration")
                        .font(.headline)
                        .padding(.top, 8)
                        
                    HStack {
                        Text("AI Provider")
                            .font(.subheadline)
                        Spacer()
                        Picker("", selection: $experimentalAIProvider) {
                            Text("OpenAI").tag("openai")
                            Text("OpenRouter Free").tag("openrouter")
                            Text("Custom (OpenAI-Compatible)").tag("custom")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }

                    if experimentalAIProvider == "custom" {
                        HStack {
                            Text("Custom API URL")
                                .font(.subheadline)
                            Spacer()
                            TextField("https://...", text: $experimentalAICustomURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 250)
                        }
                    }

                    HStack {
                        Text("API Key")
                            .font(.subheadline)
                        Spacer()
                        SecureField("sk-proj-...", text: $experimentalAIApiKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 250)
                    }

                    if experimentalAIProvider == "openrouter" {
                        HStack {
                            Text("Model")
                                .font(.subheadline)
                            Spacer()
                            Link("Get API Key / View Free Models \u{2197}", destination: URL(string: "https://openrouter.ai/openrouter/free")!)
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Text("Model")
                                .font(.subheadline)
                            Spacer()
                            
                            if isFetchingModels {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            }
                            
                            Picker("", selection: $experimentalAIModel) {
                                if availableModels.isEmpty {
                                    Text(experimentalAIModel).tag(experimentalAIModel)
                                } else {
                                    ForEach(availableModels, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                            
                            Button(action: {
                                Task { await fetchOpenAIModels() }
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .disabled(experimentalAIApiKey.isEmpty || isFetchingModels)
                            .help("Refresh Models")
                        }
                    }
                }
                .padding(.leading, 32)
                .padding(.bottom, 16)
                .task(id: experimentalAIProvider) {
                    if experimentalAIProvider != "openrouter" && !experimentalAIApiKey.isEmpty {
                        await fetchOpenAIModels()
                    }
                }
                .task(id: experimentalAIApiKey) {
                    if experimentalAIProvider != "openrouter" && !experimentalAIApiKey.isEmpty {
                        await fetchOpenAIModels()
                    }
                }
                
                Divider().padding(.horizontal, 32)

                if experimentalAICronjobsData.isEmpty {
                    Text("No cronjobs created yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.leading, 32)
                } else {
                    List {
                        ForEach(experimentalAICronjobsData) { process in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(process.name).font(.headline)
                                    Text("\(Int(process.interval))s limit")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    AICronjobManager.shared.triggerTest(for: process)
                                } label: {
                                    Image(systemName: "play.fill")
                                        .foregroundColor(process.isEnabled ? .accentColor : .secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Test Cronjob Now")
                                
                                Toggle("", isOn: Binding(
                                    get: { process.isEnabled },
                                    set: { newValue in
                                        if let idx = experimentalAICronjobsData.firstIndex(where: { $0.id == process.id }) {
                                            var updated = experimentalAICronjobsData[idx]
                                            updated.isEnabled = newValue
                                            if newValue {
                                                updated.activationDate = Date().timeIntervalSince1970
                                            }
                                            experimentalAICronjobsData[idx] = updated
                                        }
                                    }
                                ))
                                .labelsHidden()
                                
                                Button(action: {
                                    editingCronjob = process
                                    isCreatingNewCronjob = false
                                    showingEditSheet = true
                                }) {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                                
                                Button(action: {
                                    if let idx = experimentalAICronjobsData.firstIndex(where: { $0.id == process.id }) {
                                        experimentalAICronjobsData.remove(at: idx)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 250)
                    .cornerRadius(8)
                }

                Button {
                    editingCronjob = AICronjob()
                    isCreatingNewCronjob = true
                    showingEditSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add New Cronjob")
                    }
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
                .padding(.leading, 32)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AICronjobEditView(
                cronjob: Binding(
                    get: { editingCronjob ?? AICronjob() },
                    set: { editingCronjob = $0 }
                ),
                isNew: isCreatingNewCronjob,
                onSave: {
                    if let safeJob = editingCronjob {
                        if isCreatingNewCronjob {
                            experimentalAICronjobsData.append(safeJob)
                        } else if let idx = experimentalAICronjobsData.firstIndex(where: { $0.id == safeJob.id }) {
                            experimentalAICronjobsData[idx] = safeJob
                        }
                    }
                }
            )
        }
    }

    private func fetchOpenAIModels() async {
        guard !experimentalAIApiKey.isEmpty else { return }
        
        await MainActor.run { isFetchingModels = true }
        
        let baseURL = experimentalAIProvider == "custom" ? experimentalAICustomURL : "https://api.openai.com/v1"
        let safeURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard let url = URL(string: "\(safeURL)/models") else {
            await MainActor.run { isFetchingModels = false }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(experimentalAIApiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                
                let rawModels = dataArray.compactMap { $0["id"] as? String }
                
                let filteredModels: [String]
                if experimentalAIProvider == "openai" {
                    filteredModels = rawModels.filter { $0.starts(with: "gpt") || $0.starts(with: "o1") || $0.starts(with: "o3") }.sorted()
                } else {
                    filteredModels = rawModels.sorted()
                }
                
                await MainActor.run {
                    self.availableModels = filteredModels
                    if !filteredModels.contains(experimentalAIModel) && !filteredModels.isEmpty {
                        experimentalAIModel = filteredModels.first!
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

#Preview("Settings - AI Cronjobs") {
    AICronjobsSettingsView()
        .frame(width: 620, height: 600)
}
