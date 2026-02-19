import SwiftUI
import CGVirtualDisplayBridge

@main
struct HiDPIScalerApp: App {
    @StateObject private var state = HiDPIState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: state)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: state.isActive
                      ? "sparkles.rectangle.stack.fill"
                      : "sparkles.rectangle.stack")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
