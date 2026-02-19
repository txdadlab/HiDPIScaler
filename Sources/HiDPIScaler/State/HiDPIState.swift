import Foundation
import CoreGraphics
import AppKit
import CGVirtualDisplayBridge
import Combine

/// Resolution preset for quick selection
struct ResolutionPreset: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let width: UInt32
    let height: UInt32
}

/// Central state manager for the HiDPI Scaler app
final class HiDPIState: ObservableObject {

    // MARK: - Display list
    @Published var displays: [DisplayInfo] = []
    @Published var selectedDisplayID: CGDirectDisplayID? = nil

    // MARK: - Resolution input
    @Published var targetWidth: String = "1920"
    @Published var targetHeight: String = "1080"

    // MARK: - Active state
    @Published var isActive: Bool = false
    @Published var virtualDisplayID: CGDirectDisplayID? = nil
    @Published var activeTargetDisplayID: CGDirectDisplayID? = nil
    @Published var statusMessage: String = "Ready"
    @Published var isError: Bool = false

    // MARK: - Presets (computed from selected display's aspect ratio)

    var selectedDisplay: DisplayInfo? {
        displays.first { $0.displayID == selectedDisplayID }
    }

    /// The native aspect ratio of the selected display as a simplified fraction
    var nativeAspectRatio: (w: Int, h: Int) {
        guard let display = selectedDisplay else { return (16, 9) }
        let w = display.pixelWidth
        let h = display.pixelHeight
        let g = gcd(w, h)
        return (w / g, h / g)
    }

    /// Human-readable aspect ratio string (e.g. "32:9", "16:9", "21:9")
    var aspectRatioLabel: String {
        let r = nativeAspectRatio
        // Map common near-ratios to their marketing names
        let approx = Double(r.w) / Double(r.h)
        if abs(approx - 32.0/9.0) < 0.1 { return "32:9" }
        if abs(approx - 21.0/9.0) < 0.1 { return "21:9" }
        if abs(approx - 16.0/10.0) < 0.05 { return "16:10" }
        if abs(approx - 16.0/9.0) < 0.05 { return "16:9" }
        if abs(approx - 3.0/2.0) < 0.05 { return "3:2" }
        if abs(approx - 4.0/3.0) < 0.05 { return "4:3" }
        if abs(approx - 5.0/4.0) < 0.05 { return "5:4" }
        return "\(r.w):\(r.h)"
    }

    /// Generate resolution presets that match the selected display's aspect ratio.
    /// Widths are chosen as common logical widths, heights computed to maintain ratio.
    var presets: [ResolutionPreset] {
        guard let display = selectedDisplay else { return [] }

        let nativeW = display.pixelWidth
        let nativeH = display.pixelHeight
        let g = gcd(nativeW, nativeH)
        let ratioW = nativeW / g
        let ratioH = nativeH / g

        // Generate a range of widths, compute matching height, filter reasonable ones.
        // We want the logical resolution (which will be rendered at 2x),
        // so the backing pixels = width*2 x height*2.
        // The logical width should be <= native pixel width (no upscaling).
        let candidateWidths: [Int] = [
            960, 1024, 1280, 1440, 1600, 1680, 1920, 2048,
            2240, 2304, 2560, 2880, 3072, 3200, 3440, 3840,
            4096, 4480, 4608, 5120, 5760, 6016, 6400, 7680
        ]

        var results: [ResolutionPreset] = []
        var seen = Set<String>()

        for w in candidateWidths {
            // Height must be an integer for this aspect ratio
            let h = w * ratioH / ratioW
            guard h * ratioW == w * ratioH else { continue } // exact integer check

            // Backing would be 2x, so 2*w must fit in something reasonable
            // and logical resolution should be smaller than native
            guard w >= 640 && h >= 480 else { continue }
            guard w <= nativeW else { continue }
            // Skip if this is exactly the native resolution (no point in HiDPI at native)
            guard !(w == nativeW && h == nativeH) else { continue }

            let key = "\(w)x\(h)"
            guard seen.insert(key).inserted else { continue }

            results.append(ResolutionPreset(
                label: "\(w) x \(h)",
                width: UInt32(w),
                height: UInt32(h)
            ))
        }

        // Sort by width descending (higher resolutions first)
        results.sort { $0.width > $1.width }

        return results
    }

    /// Greatest common divisor
    private func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }

    // MARK: - Init

    init() {
        refreshDisplays()

        // Register for app termination to clean up
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.deactivate()
        }
    }

    deinit {
        deactivate()
    }

    // MARK: - Display Refresh

    func refreshDisplays() {
        displays = DisplayManager.getActiveDisplays()

        // Auto-select main display if nothing selected
        if selectedDisplayID == nil || !displays.contains(where: { $0.displayID == selectedDisplayID }) {
            selectedDisplayID = displays.first(where: { $0.isMain })?.displayID
                ?? displays.first?.displayID
        }
    }

    // MARK: - Apply Preset

    func applyPreset(_ preset: ResolutionPreset) {
        targetWidth = "\(preset.width)"
        targetHeight = "\(preset.height)"
    }

    // MARK: - Activate HiDPI

    func activate() {
        guard !isActive else {
            setStatus("Already active", error: true)
            return
        }

        guard let targetID = selectedDisplayID else {
            setStatus("No display selected", error: true)
            return
        }

        guard let width = UInt32(targetWidth), let height = UInt32(targetHeight) else {
            setStatus("Invalid resolution values", error: true)
            return
        }

        guard width >= VirtualDisplayController.minWidth,
              width <= VirtualDisplayController.maxWidth,
              height >= VirtualDisplayController.minHeight,
              height <= VirtualDisplayController.maxHeight else {
            setStatus("Resolution out of range (\(VirtualDisplayController.minWidth)-\(VirtualDisplayController.maxWidth))", error: true)
            return
        }

        setStatus("Creating virtual display...")

        // Run on background to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let vdID = try VirtualDisplayController.createDisplay(
                    logicalWidth: width,
                    logicalHeight: height,
                    refreshRate: 60.0,
                    name: "HiDPI Scaler Virtual Display"
                )

                // Let macOS register the display
                Thread.sleep(forTimeInterval: 1.0)

                try MirroringManager.enableMirroring(
                    sourceDisplay: targetID,
                    targetDisplay: vdID
                )

                DispatchQueue.main.async {
                    self.virtualDisplayID = vdID
                    self.activeTargetDisplayID = targetID
                    self.isActive = true
                    self.setStatus("HiDPI active: \(width)x\(height)")
                }
            } catch {
                // Clean up on failure
                if let vdID = self.virtualDisplayID {
                    try? VirtualDisplayController.destroyDisplay(vdID)
                }
                DispatchQueue.main.async {
                    self.setStatus("Failed: \(error.localizedDescription)", error: true)
                }
            }
        }
    }

    // MARK: - Deactivate

    func deactivate() {
        guard isActive, let vdID = virtualDisplayID else { return }

        if let targetID = activeTargetDisplayID {
            try? MirroringManager.disableMirroring(sourceDisplay: targetID)
        }

        try? VirtualDisplayController.destroyDisplay(vdID)

        virtualDisplayID = nil
        activeTargetDisplayID = nil
        isActive = false
        setStatus("Ready")

        // Refresh display list after deactivation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshDisplays()
        }
    }

    // MARK: - Status

    private func setStatus(_ message: String, error: Bool = false) {
        DispatchQueue.main.async {
            self.statusMessage = message
            self.isError = error
        }
    }
}
