import Foundation

let role = CommandLine.arguments[1]
let key = CommandLine.arguments[2]
let barrier = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
let defaults = UserDefaults.standard
if role == "writer" {
    defaults.set("synthetic-sentinel", forKey: key)
    defaults.synchronize()
    try Data().write(to: barrier.appendingPathComponent("ready"))
    let deadline = Date().addingTimeInterval(10)
    while !FileManager.default.fileExists(atPath: barrier.appendingPathComponent("done").path), Date() < deadline {
        Thread.sleep(forTimeInterval: 0.01)
    }
    defaults.synchronize()
    print("writerAfter=\(defaults.string(forKey: key) ?? "nil")")
    defaults.removeObject(forKey: key)
    defaults.synchronize()
} else {
    print("siblingBefore=\(defaults.string(forKey: key) ?? "nil")")
    defaults.removeObject(forKey: key)
    defaults.synchronize()
    try Data().write(to: barrier.appendingPathComponent("done"))
}
