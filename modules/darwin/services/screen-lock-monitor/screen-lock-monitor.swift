import Cocoa
import Foundation

let betterdisplaycli = "/usr/local/bin/betterdisplaycli"
let mainMonitorName = "Left"
let physicalMonitorName = "Odyssey G93SC"

func run(_ arguments: [String]) -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: betterdisplaycli)
    process.arguments = arguments
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func isLeftMain() -> Bool {
    let result = run(["get", "-name=\(mainMonitorName)", "-main"])
    return result == "1" || result.lowercased() == "on" || result.lowercased() == "true"
}

let dnc = DistributedNotificationCenter.default()

dnc.addObserver(
    forName: NSNotification.Name("com.apple.screenIsLocked"),
    object: nil,
    queue: .main
) { _ in
    // Only switch if Left is currently the main display (PiP dual-screen mode active)
    guard isLeftMain() else { return }
    _ = run(["set", "-name=\(physicalMonitorName)", "-main=on"])
}

dnc.addObserver(
    forName: NSNotification.Name("com.apple.screenIsUnlocked"),
    object: nil,
    queue: .main
) { _ in
    // Only restore if Odyssey is currently main (meaning we switched it on lock)
    let odysseyMain = run(["get", "-name=\(physicalMonitorName)", "-main"])
    guard odysseyMain == "1" || odysseyMain.lowercased() == "on" || odysseyMain.lowercased() == "true" else { return }
    _ = run(["set", "-name=\(mainMonitorName)", "-main=on"])
}

// Keep the process alive
RunLoop.main.run()
