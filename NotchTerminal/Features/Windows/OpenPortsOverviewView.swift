import AppKit
import SwiftUI

struct OpenPortsOverviewView: View {
    @Bindable var service: OpenPortsOverviewService

    var body: some View {
        content
            .navigationTitle("openPorts.title".localized)
            .frame(minWidth: 820, minHeight: 560)
            .task {
                service.refreshIfNeeded()
            }
            .searchable(
                text: $service.searchText,
                placement: .toolbar,
                prompt: Text("openPorts.search.placeholder".localized)
            )
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Picker("openPorts.scope.picker".localized, selection: $service.scope) {
                        ForEach(OpenPortsOverviewService.Scope.allCases) { scope in
                            Text(scope.localizedTitle).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)

                    Button {
                        service.refresh()
                    } label: {
                        Label("openPorts.action.refresh".localized, systemImage: "arrow.clockwise")
                    }
                    .disabled(service.isLoading)
                }
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryHeader

            Divider()

            if service.isLoading && service.ports.isEmpty {
                loadingState
            } else if let message = service.message, service.visiblePorts.isEmpty {
                emptyState(message: message)
            } else {
                portList
            }
        }
        .background(.regularMaterial)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("openPorts.title".localized)
                .font(.title2.weight(.semibold))

            Text("openPorts.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(
                    String(format: "openPorts.summary.count".localized, service.devPortCount),
                    systemImage: "hammer"
                )
                Label(
                    String(format: "openPorts.summary.other".localized, service.otherPortCount),
                    systemImage: "circle.grid.2x2"
                )

                if service.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var portList: some View {
        List {
            ForEach(service.visiblePorts) { port in
                portRow(port)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
        }
        .listStyle(.inset)
    }

    private func portRow(_ port: OpenPortEntry) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(port.isLikelyDev ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(":\(port.port)")
                        .font(.headline.monospacedDigit())

                    Text(port.command)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(String(format: "openPorts.row.pidAndEndpoint".localized, String(port.pid), port.endpoint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(role: .destructive) {
                service.terminate(port)
            } label: {
                Label("openPorts.kill".localized, systemImage: "xmark.circle")
            }
            .buttonStyle(.borderless)
        }
    }

    private var loadingState: some View {
        ContentUnavailableView {
            Label("openPorts.scanning".localized, systemImage: "network")
        } description: {
            Text("openPorts.subtitle".localized)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(message: String) -> some View {
        ContentUnavailableView {
            Label("openPorts.title".localized, systemImage: "network")
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
