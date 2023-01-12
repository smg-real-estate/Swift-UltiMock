import XFoundation

@discardableResult
func shell(_ command: String) throws -> String {
    print(command)
    let process = Process()
    let pipe = Pipe()

    process.standardOutput = pipe
    process.standardError = pipe
    process.arguments = ["-c", command]
    process.launchPath = ProcessInfo.processInfo.environment["SHELL"]
    try process.run()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    process.waitUntilExit()

    if process.terminationStatus != 0 {
        throw SimpleError(output)
    }

    print(output)
    return output
}
