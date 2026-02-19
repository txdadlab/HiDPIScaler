import Foundation
import CoreGraphics
import CGVirtualDisplayBridge

enum VirtualDisplayError: LocalizedError {
    case creationFailed
    case invalidDimensions(String)
    case destroyFailed(CGDirectDisplayID)

    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "Failed to create virtual display."
        case .invalidDimensions(let msg):
            return "Invalid dimensions: \(msg)"
        case .destroyFailed(let id):
            return "Failed to destroy virtual display \(id)"
        }
    }
}

enum VirtualDisplayController {
    static let minWidth: UInt32  = 640
    static let maxWidth: UInt32  = 7680
    static let minHeight: UInt32 = 480
    static let maxHeight: UInt32 = 4320

    static func createDisplay(
        logicalWidth: UInt32, logicalHeight: UInt32,
        refreshRate: Double = 60.0,
        name: String = "HiDPI Virtual Display"
    ) throws -> CGDirectDisplayID {
        guard logicalWidth >= minWidth, logicalWidth <= maxWidth else {
            throw VirtualDisplayError.invalidDimensions("Width out of range")
        }
        guard logicalHeight >= minHeight, logicalHeight <= maxHeight else {
            throw VirtualDisplayError.invalidDimensions("Height out of range")
        }

        let displayID = HiDPICreateVirtualDisplay(
            logicalWidth, logicalHeight, refreshRate, name)
        guard displayID != 0 else { throw VirtualDisplayError.creationFailed }
        return displayID
    }

    static func destroyDisplay(_ displayID: CGDirectDisplayID) throws {
        guard HiDPIDestroyVirtualDisplay(displayID) else {
            throw VirtualDisplayError.destroyFailed(displayID)
        }
    }

    static func destroyAll() { HiDPIDestroyAllVirtualDisplays() }
}
