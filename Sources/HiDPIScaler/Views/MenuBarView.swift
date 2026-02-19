import SwiftUI
import CGVirtualDisplayBridge

struct MenuBarView: View {
    @ObservedObject var state: HiDPIState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()

            if state.isActive {
                activeSection
            } else {
                configSection
            }

            Divider()

            // Status bar
            statusSection

            Divider()

            // Settings
            settingsSection

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 320)
        .onAppear {
            state.refreshDisplays()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title2)
                .foregroundColor(.accentColor)

            Text("HiDPI Scaler")
                .font(.headline)

            Spacer()

            if state.isActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Active State

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HiDPI Scaling Active")
                .font(.subheadline.weight(.medium))

            if let display = state.selectedDisplay {
                Label {
                    Text(display.displayName)
                        .font(.caption)
                } icon: {
                    Image(systemName: "display")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            HStack {
                Label {
                    Text("\(state.targetWidth) x \(state.targetHeight) HiDPI")
                        .font(.caption.monospaced())
                } icon: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Button(action: state.deactivate) {
                Label("Disable HiDPI", systemImage: "stop.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding(16)
    }

    // MARK: - Configuration

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Display picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Display")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $state.selectedDisplayID) {
                    ForEach(state.displays) { display in
                        Text(display.displayName)
                            .tag(Optional(display.displayID))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            // Selected display info
            if let display = state.selectedDisplay {
                HStack(spacing: 12) {
                    InfoBadge(label: "Native",
                              value: "\(display.pixelWidth)x\(display.pixelHeight)")
                    InfoBadge(label: "Ratio",
                              value: state.aspectRatioLabel)
                    InfoBadge(label: "Scale",
                              value: "\(String(format: "%.0f", display.scaleFactor))x")
                    if display.physicalDiagonalInches > 0 {
                        InfoBadge(label: "Size",
                                  value: "\(String(format: "%.0f", display.physicalDiagonalInches))\"")
                    }
                }
            }

            Divider()

            // Resolution input
            VStack(alignment: .leading, spacing: 4) {
                Text("HiDPI Resolution")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("Width", text: $state.targetWidth)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.center)

                    Text("x")
                        .foregroundColor(.secondary)

                    TextField("Height", text: $state.targetHeight)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.center)

                    Spacer()

                    Text("@ 2x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            // Presets
            VStack(alignment: .leading, spacing: 4) {
                Text("Presets")
                    .font(.caption)
                    .foregroundColor(.secondary)

                FlowLayout(spacing: 4) {
                    ForEach(state.presets) { preset in
                        Button(preset.label) {
                            state.applyPreset(preset)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(isPresetSelected(preset) ? .accentColor : .secondary)
                    }
                }
            }

            // Activate button
            Button(action: state.activate) {
                Label("Enable HiDPI", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(state.displays.isEmpty)
        }
        .padding(16)
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack {
            Image(systemName: state.isError ? "exclamationmark.triangle" : "info.circle")
                .font(.caption)
                .foregroundColor(state.isError ? .red : .secondary)

            Text(state.statusMessage)
                .font(.caption)
                .foregroundColor(state.isError ? .red : .secondary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Launch at Login")
                Spacer()
                Toggle("", isOn: $state.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }

            HStack {
                Text("Auto-connect on Launch")
                Spacer()
                Toggle("", isOn: $state.autoActivate)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button("Refresh") {
                state.refreshDisplays()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            Spacer()

            Button("Quit") {
                state.deactivate()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func isPresetSelected(_ preset: ResolutionPreset) -> Bool {
        state.targetWidth == "\(preset.width)" && state.targetHeight == "\(preset.height)"
    }
}

// MARK: - Supporting Views

struct InfoBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.monospaced().weight(.medium))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(6)
    }
}

/// Simple flow layout for preset buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
