//
//  CLIResult.swift
//  skills-ui
//
//  Result wrapper for CLI operations
//

import Foundation

/// Represents the result of a CLI command execution
struct CLIResult: Sendable {
    let command: String
    let arguments: [String]
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
    let duration: TimeInterval
    let workingDirectory: URL?

    var succeeded: Bool {
        exitCode == 0
    }

    var failed: Bool {
        exitCode != 0
    }

    var output: String {
        if succeeded {
            return standardOutput
        }
        return standardError.isEmpty ? standardOutput : standardError
    }

    var error: CLIError? {
        guard failed else { return nil }
        return CLIError(
            exitCode: exitCode,
            message: standardError.isEmpty ? standardOutput : standardError,
            command: command,
            arguments: arguments
        )
    }

    static func success(command: String, arguments: [String], output: String, workingDirectory: URL? = nil) -> CLIResult {
        CLIResult(
            command: command,
            arguments: arguments,
            exitCode: 0,
            standardOutput: output,
            standardError: "",
            duration: 0,
            workingDirectory: workingDirectory
        )
    }

    static func failure(command: String, arguments: [String], exitCode: Int32, error: String, workingDirectory: URL? = nil) -> CLIResult {
        CLIResult(
            command: command,
            arguments: arguments,
            exitCode: exitCode,
            standardOutput: "",
            standardError: error,
            duration: 0,
            workingDirectory: workingDirectory
        )
    }
}

/// Represents an error from CLI execution
struct CLIError: Error, LocalizedError, Sendable {
    let exitCode: Int32
    let message: String
    let command: String
    let arguments: [String]

    var errorDescription: String? {
        message
    }

    var recoverySuggestion: String? {
        if message.contains("ENOENT") || message.contains("not found") {
            return "Make sure Node.js is installed and npx is available in your PATH."
        }
        if message.contains("permission") || message.contains("EACCES") {
            return "Check file permissions for the target directory."
        }
        if message.contains("network") || message.contains("ETIMEDOUT") {
            return "Check your network connection and try again."
        }
        return nil
    }
}
