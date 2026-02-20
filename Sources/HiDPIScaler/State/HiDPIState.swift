import Foundation
import CoreGraphics
import AppKit
import CGVirtualDisplayBridge
import Combine
import ServiceManagement

/// Resolution preset for quick selection
struct ResolutionPreset: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let width: UInt32
    let height: UInt32
}

/// Central state manager for the HiDPI Scaler app
final class HiDPIState: ObservableObject {

    // MARK: - Persistence Keys

    private enum DefaultsKey {
        static let selectedDisplayID = "selectedDisplayID"
        static let targetWidth = "targetWidth"
        static let targetHeight = "targetHeight"
        static let launchAtLogin = "launchAtLogin"
        static let autoActivate = "autoActivate"
    }

    // MARK: - Display list
    @Published var displays: [DisplayInfo] = []
    @Published var selectedDisplayID: CGDirectDisplayID? = nil

    // MARK: - Resolution input
    @Published var targetWidth: String = "1920"
    @Published var targetHeight: String = "1080"

    // MARK: - Settings
    @Published var launchAtLogin: Bool = false
    @Published var autoActivate: Bool = false

    // MARK: - Active state
    @Published var isActive: Bool = false
    @Published var virtualDisplayID: CGDirectDisplayID? = nil
    @Published var activeTargetDisplayID: CGDirectDisplayID? = nil
    @Published var statusMessage: String = "Ready"
    @Published var isError: Bool = false

    // MARK: - Update check
    @Published var updateAvailable: (version: String, url: URL)? = nil

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Presets (computed from selected display's aspect ratio)

    var selectedDisplay: DisplayInfo? {
        displays.first { $0.displayID == selectedDisplayID }
    }

    /// The native aspect ratio of the selected display as a simplified fraction
    var nativeAspectRatio: (w: Int, h: Int) {
        guard let display = selectedDisplay else { return (16, 9) }
        let w = display.logicalWidth
        let h = display.logicalHeight
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

        let nativeW = display.logicalWidth
        let nativeH = display.logicalHeight
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
        // Load saved settings before refreshing displays
        let defaults = UserDefaults.standard
        let savedWidth = defaults.string(forKey: DefaultsKey.targetWidth)
        let savedHeight = defaults.string(forKey: DefaultsKey.targetHeight)
        if let savedWidth, let savedHeight {
            targetWidth = savedWidth
            targetHeight = savedHeight
        }

        autoActivate = defaults.bool(forKey: DefaultsKey.autoActivate)

        // Sync launch-at-login with system state (system is source of truth)
        launchAtLogin = SMAppService.mainApp.status == .enabled

        refreshDisplays()

        // Restore saved display selection (if still connected)
        let savedDisplayID = defaults.integer(forKey: DefaultsKey.selectedDisplayID)
        if savedDisplayID != 0,
           displays.contains(where: { $0.displayID == savedDisplayID }) {
            selectedDisplayID = CGDirectDisplayID(savedDisplayID)
        }

        // Auto-save settings on change
        $selectedDisplayID.dropFirst().sink { id in
            guard let id else { return }
            defaults.set(Int(id), forKey: DefaultsKey.selectedDisplayID)
        }.store(in: &cancellables)

        $targetWidth.dropFirst().sink { value in
            defaults.set(value, forKey: DefaultsKey.targetWidth)
        }.store(in: &cancellables)

        $targetHeight.dropFirst().sink { value in
            defaults.set(value, forKey: DefaultsKey.targetHeight)
        }.store(in: &cancellables)

        $launchAtLogin.dropFirst().sink { [weak self] value in
            self?.updateLaunchAtLogin(value)
        }.store(in: &cancellables)

        $autoActivate.dropFirst().sink { value in
            defaults.set(value, forKey: DefaultsKey.autoActivate)
        }.store(in: &cancellables)

        // Register for app termination to clean up
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.deactivate()
        }

        checkForUpdates()

        // Auto-activate on launch if enabled
        if autoActivate, selectedDisplayID != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, !self.isActive else { return }
                // Re-verify display is still connected
                self.refreshDisplays()
                guard let displayID = self.selectedDisplayID,
                      self.displays.contains(where: { $0.displayID == displayID }) else {
                    self.setStatus("Auto-connect skipped: saved display not found", error: true)
                    return
                }
                self.activate()
            }
        }
    }

    deinit {
        deactivate()
    }

    // MARK: - Launch at Login

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: DefaultsKey.launchAtLogin)
        } catch {
            Logger.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            // Revert the toggle on failure
            DispatchQueue.main.async { [weak self] in
                self?.launchAtLogin = !enabled
            }
            setStatus("Launch at login failed: \(error.localizedDescription)", error: true)
        }
    }

    // MARK: - Display Refresh

    func refreshDisplays() {
        var allDisplays = DisplayManager.getActiveDisplays()

        // Filter out any virtual display we created
        if let vdID = virtualDisplayID {
            allDisplays.removeAll { $0.displayID == vdID }
        }

        displays = allDisplays

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

        let physicalDisplayID = activeTargetDisplayID

        if let targetID = activeTargetDisplayID {
            try? MirroringManager.disableMirroring(sourceDisplay: targetID)
        }

        try? VirtualDisplayController.destroyDisplay(vdID)

        virtualDisplayID = nil
        activeTargetDisplayID = nil
        isActive = false
        setStatus("Ready")

        // Give macOS time to fully deregister the virtual display, then refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.refreshDisplays()
            // Re-select the physical display we were targeting
            if let physicalDisplayID,
               self.displays.contains(where: { $0.displayID == physicalDisplayID }) {
                self.selectedDisplayID = physicalDisplayID
            }
        }
    }

    // MARK: - Status

    private func setStatus(_ message: String, error: Bool = false) {
        DispatchQueue.main.async {
            self.statusMessage = message
            self.isError = error
        }
    }

    // MARK: - Update Check

    private func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/txdadlab/HiDPIScaler/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard error == nil,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String,
                  let releaseURL = URL(string: htmlURL) else { return }

            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }

            if Self.isVersion(remoteVersion, newerThan: currentVersion) {
                DispatchQueue.main.async {
                    self?.updateAvailable = (version: remoteVersion, url: releaseURL)
                }
            }
        }.resume()
    }

    /// Compare two semantic version strings (major.minor.patch).
    /// Returns `true` when `a` is strictly newer than `b`.
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }
        return false
    }
}
