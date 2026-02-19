import Foundation
import CoreGraphics
import CGVirtualDisplayBridge

enum MirroringError: LocalizedError {
    case configurationFailed(CGError)
    var errorDescription: String? {
        switch self {
        case .configurationFailed(let err):
            return "Display mirroring failed (CGError: \(err.rawValue))"
        }
    }
}

enum MirroringManager {
    static func enableMirroring(sourceDisplay: CGDirectDisplayID,
                                targetDisplay: CGDirectDisplayID) throws {
        let err = HiDPIConfigureMirroring(sourceDisplay, targetDisplay)
        guard err == CGError.success else {
            throw MirroringError.configurationFailed(err)
        }
    }

    static func disableMirroring(sourceDisplay: CGDirectDisplayID) throws {
        let err = HiDPIConfigureMirroring(sourceDisplay, kCGNullDirectDisplay)
        guard err == CGError.success else {
            throw MirroringError.configurationFailed(err)
        }
    }
}
