import Foundation
import CoreGraphics
import CGVirtualDisplayBridge

struct DisplayInfo: Identifiable, Hashable {
    let displayID: CGDirectDisplayID
    let logicalWidth: Int
    let logicalHeight: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
    let physicalWidthMM: Double
    let physicalHeightMM: Double
    let isBuiltIn: Bool
    let isMain: Bool
    let scaleFactor: Double
    var isHiDPI: Bool { scaleFactor > 1.0 }

    var id: CGDirectDisplayID { displayID }

    var displayName: String {
        let main = isMain ? " (Main)" : ""
        let builtin = isBuiltIn ? " Built-in" : ""
        return "Display \(displayID)\(main)\(builtin) — \(logicalWidth)x\(logicalHeight)"
    }

    var physicalDiagonalInches: Double {
        guard physicalWidthMM > 0, physicalHeightMM > 0 else { return 0 }
        return sqrt(physicalWidthMM * physicalWidthMM +
                    physicalHeightMM * physicalHeightMM) / 25.4
    }

    func hash(into hasher: inout Hasher) { hasher.combine(displayID) }
    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        lhs.displayID == rhs.displayID
    }
}

struct DisplayModeInfo {
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
    let isHiDPI: Bool
}

enum DisplayManager {

    static func getActiveDisplays() -> [DisplayInfo] {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 32)
        var displayCount: UInt32 = 0

        let err = HiDPIGetActiveDisplays(&displayIDs, 32, &displayCount)
        guard err == CGError.success else { return [] }

        let mainID = HiDPIGetMainDisplayID()
        var results: [DisplayInfo] = []
        for i in 0..<Int(displayCount) {
            if let info = getDisplayInfo(id: displayIDs[i], mainID: mainID) {
                results.append(info)
            }
        }
        return results
    }

    static func getDisplayInfo(id: CGDirectDisplayID, mainID: CGDirectDisplayID? = nil) -> DisplayInfo? {
        var width: Int = 0, height: Int = 0
        var pixelWidth: Int = 0, pixelHeight: Int = 0
        var refreshRate: Double = 0

        let err = HiDPIGetCurrentDisplayMode(id, &width, &height, &pixelWidth, &pixelHeight, &refreshRate)
        guard err == CGError.success else { return nil }

        var physW: Double = 0, physH: Double = 0
        HiDPIGetDisplayPhysicalSize(id, &physW, &physH)

        let main = mainID ?? HiDPIGetMainDisplayID()
        let scale = width > 0 ? Double(pixelWidth) / Double(width) : 1.0

        return DisplayInfo(
            displayID: id, logicalWidth: width, logicalHeight: height,
            pixelWidth: pixelWidth, pixelHeight: pixelHeight,
            refreshRate: refreshRate,
            physicalWidthMM: physW, physicalHeightMM: physH,
            isBuiltIn: HiDPIIsBuiltInDisplay(id),
            isMain: id == main, scaleFactor: scale
        )
    }

    static func getDisplayModes(for displayID: CGDirectDisplayID) -> [DisplayModeInfo] {
        let maxModes: UInt32 = 512
        var modes = [HiDPIDisplayModeInfo](repeating: HiDPIDisplayModeInfo(), count: Int(maxModes))
        var count: UInt32 = 0

        let err = HiDPIGetDisplayModes(displayID, &modes, maxModes, &count)
        guard err == CGError.success else { return [] }

        return (0..<Int(count)).map { i in
            let m = modes[i]
            return DisplayModeInfo(
                width: Int(m.width), height: Int(m.height),
                pixelWidth: Int(m.pixelWidth), pixelHeight: Int(m.pixelHeight),
                refreshRate: m.refreshRate, isHiDPI: m.isHiDPI
            )
        }
    }
}
