import Foundation

struct ShellError: Error {
    var status: Int32
    var description: String
}

@discardableResult
func shell(
    _ cmd: String
) throws -> String {
    let process = Process()
    process.launchPath = "/bin/bash"
    process.arguments = ["-c", cmd]

    let standardOut = Pipe() 
    let standardError = Pipe()
    process.standardOutput = standardOut
    process.standardError = standardError

    try process.run()
    process.waitUntilExit()

    let outData = standardOut.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outData, encoding: .utf8) ?? ""
    switch process.terminationStatus {
    case 0:
        return output
    default:
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        var description = String(data: errorData, encoding: .utf8) ?? ""
        if description.isEmpty {
            description = output
        }
        throw ShellError(status: process.terminationStatus, description: description)
    }
}

@discardableResult
func shell(
    _ cmd: String,
    at location: String
) throws -> String {
    try shell("cd \(location) && \(cmd)")
}
