import Foundation

enum Logger {
    static var verbose: Bool = false

    static func info(_ message: String)    { print("[INFO] \(message)") }
    static func debug(_ message: String)   { guard verbose else { return }; print("[DEBUG] \(message)") }
    static func warn(_ message: String)    { FileHandle.standardError.write(Data("[WARN] \(message)\n".utf8)) }
    static func error(_ message: String)   { FileHandle.standardError.write(Data("[ERROR] \(message)\n".utf8)) }
    static func success(_ message: String) { print("[OK] \(message)") }
}
