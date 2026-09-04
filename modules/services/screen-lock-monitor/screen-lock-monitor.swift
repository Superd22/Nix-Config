import Cocoa
import Foundation

// Replaced with the store path of the `betterdisplaycli` package at build time
// by default.nix; the placeholder is not a path and this will not compile into
// anything runnable without that substitution (#21). It used to be a literal
// /usr/local/bin path written by another module's activation script, with
// nothing anywhere saying so.
let betterdisplaycli = "@betterdisplaycli@"
let mainMonitorName = "Left"
let physicalMonitorName = "Odyssey G93SC"

func run(_ arguments: [String]) -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: betterdisplaycli)
    process.arguments = arguments
    process.standardOutput = pipe
    do {
        try process.run()
    } catch {
        // This was `try?`, which meant a missing or broken betterdisplaycli
        // left the agent running and quietly doing nothing at every lock and
        // unlock. Say so in the log instead.
        FileHandle.standardError.write(
            "screen-lock-monitor: could not run \(betterdisplaycli): \(error)\n"
                .data(using: .utf8)!)
        return ""
    }
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
