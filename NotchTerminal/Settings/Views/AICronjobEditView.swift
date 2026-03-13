import SwiftUI

struct AICronjobEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cronjob: AICronjob
    var isNew: Bool
    var onSave: () -> Void

    @State private var showCustomCron: Bool = false
    private let presetCrons = ["* * * * *", "*/5 * * * *", "*/15 * * * *", "*/30 * * * *", "0 * * * *", "0 */6 * * *", "0 */12 * * *", "0 0 * * *"]

    var body: some View {
        VStack(spacing: 0) {
            Text(isNew ? "New AI Cronjob" : "Edit AI Cronjob")
                .font(.headline)
                .padding()
            
            Form {
                Section {
                    TextField("Cronjob Name", text: $cronjob.name)
                    
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
                        Slider(
                            value: Binding(
                                get: { cronjob.interval },
                                set: { cronjob.interval = $0 }
                            ),
                            in: 10 ... 600,
                            step: 5
                        ) {
                            Text("Execution Interval")
                        } minimumValueLabel: {
                            Text("10s")
                        } maximumValueLabel: {
                            Text("600s")
                        }
                        Text("Current: \(Int(cronjob.interval))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading) {
                            if showCustomCron {
                                TextField("Cron Expression", text: $cronjob.cronExpression)
                                    .textFieldStyle(.roundedBorder)
                                Text("Format: M H D m W (e.g., '0 * * * *' for every hour).\nMachine daemon executes directly on macOS launchd/crontab even if NotchTerminal is closed.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
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
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
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
                    TextField("System Prompt", text: $cronjob.prompt)
                    
                    Toggle(isOn: $cronjob.autoDisable) {
                        Text("Auto-Disable Limit (3 Days)")
                    }
                    
                    if !cronjob.autoDisable {
                        Text("Warning: Disabling the 3-day limit is not recommended. Continuous background AI requests consume system resources, API quotas, and battery life over long periods.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Save") {
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(cronjob.name.isEmpty || cronjob.prompt.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 450)
    }
}
