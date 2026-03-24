//
//  SkillsCLIService.swift
//  skills-ui
//
//  Service for running skills CLI commands
//

import Foundation

/// Service for executing skills CLI commands
actor SkillsCLIService {
    static let shared = SkillsCLIService()

    private let cliCommand = "npx"
    private let cliPackage = "skills"
    private let defaultTimeout: TimeInterval = 120

    private init() {}

    // MARK: - Availability Check

    func checkAvailability() async -> Bool {
        do {
            let result = try await runCommand(["--version"], timeout: 10)
            return result.succeeded
        } catch {
            return false
        }
    }

    // MARK: - List Skills

    func listSkills(scope: InstallScope? = nil, agents: [String] = []) async throws -> CLIResult {
        var args = ["list"]

        if scope == .global {
            args.append("-g")
        }

        for agent in agents {
            args.append(contentsOf: ["-a", agent])
        }

        return try await runCommand(args)
    }

    // MARK: - Find Skills

    func findSkills(query: String? = nil) async throws -> CLIResult {
        var args = ["find"]

        if let query = query, !query.isEmpty {
            args.append(query)
        }

        return try await runCommand(args)
    }

    // MARK: - List Available Skills

    func listAvailableSkills(source: SkillSource) async throws -> CLIResult {
        let args = ["add", source.cliString, "--list"]
        return try await runCommand(args)
    }

    // MARK: - Install Skills

    func installSkills(options: InstallOptions) async throws -> CLIResult {
        let args = options.toCLIArguments()
        return try await runWriteCommand(args)
    }

    // MARK: - Remove Skills

    func removeSkills(options: RemoveOptions) async throws -> CLIResult {
        let args = options.toCLIArguments()
        return try await runWriteCommand(args)
    }

    // MARK: - Check Updates

    func checkUpdates() async throws -> CLIResult {
        return try await runCommand(["check"])
    }

    // MARK: - Update Skills

    func updateSkills() async throws -> CLIResult {
        return try await runWriteCommand(["update"])
    }

    // MARK: - Init Skill

    func initSkill(name: String? = nil) async throws -> CLIResult {
        var args = ["init"]
        if let name = name {
            args.append(name)
        }
        return try await runCommand(args)
    }

    // MARK: - Detect Agents

    func detectAgents() async throws -> [Agent] {
        // Use filesystem detection
        return detectAgentsFromFilesystem()
    }

    private func detectAgentsFromFilesystem() -> [Agent] {
        let fileManager = FileManager.default
        let homePath = fileManager.homeDirectoryForCurrentUser.path

        return Agent.allAgents.map { agent in
            var mutableAgent = agent
            let globalPath = (agent.globalPath as NSString)
                .replacingOccurrences(of: "~", with: homePath)

            // Check if the agent's global directory or parent exists
            if fileManager.fileExists(atPath: globalPath) {
                mutableAgent.isDetected = true
                mutableAgent.isInstalled = true
            } else {
                let parentPath = (globalPath as NSString).deletingLastPathComponent
                if fileManager.fileExists(atPath: parentPath) {
                    mutableAgent.isDetected = true
                }
            }

            return mutableAgent
        }
    }

    // MARK: - Private Methods

    private func runCommand(_ args: [String], timeout: TimeInterval? = nil) async throws -> CLIResult {
        try await executeCommand(args, timeout: timeout ?? defaultTimeout)
    }

    private func runWriteCommand(_ args: [String], workingDirectory: URL? = nil) async throws -> CLIResult {
        try await executeCommand(args, workingDirectory: workingDirectory)
    }

    private func executeCommand(_ args: [String], workingDirectory: URL? = nil, timeout: TimeInterval? = nil) async throws -> CLIResult {
        let fullArgs = [cliPackage] + args
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [cliCommand] + fullArgs
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        let startTime = Date()

        do {
            try process.run()
        } catch {
            throw CLIError(
                exitCode: -1,
                message: "Failed to run npx skills. Make sure Node.js is installed: \(error.localizedDescription)",
                command: cliCommand,
                arguments: fullArgs
            )
        }

        // Read output asynchronously
        async let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        async let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        // Wait for process with timeout
        let timeoutValue = timeout ?? defaultTimeout
        let deadline = startTime.addingTimeInterval(timeoutValue)

        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                throw CLIError(
                    exitCode: -1,
                    message: "Command timed out after \(timeoutValue) seconds",
                    command: cliCommand,
                    arguments: fullArgs
                )
            }
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }

        let stdout = String(data: try await stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: try await stderrData, encoding: .utf8) ?? ""
        let duration = Date().timeIntervalSince(startTime)

        return CLIResult(
            command: cliCommand,
            arguments: fullArgs,
            exitCode: process.terminationStatus,
            standardOutput: stdout,
            standardError: stderr,
            duration: duration,
            workingDirectory: workingDirectory
        )
    }
}

// MARK: - CLI Parser

enum SkillsCLIParser: Sendable {

    /// Parse the output of `skills list` command
    static func parseListOutput(_ output: String) -> [Skill] {
        var skills: [Skill] = []
        let lines = output.components(separatedBy: .newlines)

        var currentSkillName: String?
        var currentAgents: [String: SkillInstallStatus] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and headers
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("Skills") || trimmed.hasPrefix("=") || trimmed.hasPrefix("-") { continue }
            if trimmed.hasPrefix("No skills") || trimmed.hasPrefix("Run `") { continue }

            // Check if this is a skill name line (not indented)
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") && !trimmed.isEmpty {
                // Save previous skill if exists
                if let name = currentSkillName, !name.isEmpty {
                    skills.append(Skill(
                        name: name,
                        description: "",
                        source: .registry(url: "installed"),
                        installStatus: currentAgents
                    ))
                }

                currentSkillName = trimmed
                currentAgents = [:]
                continue
            }

            // Check for indented agent line
            if (line.hasPrefix("  ") || line.hasPrefix("\t")) && trimmed.contains(":") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count >= 1 {
                    let agentId = String(parts[0])
                        .trimmingCharacters(in: .whitespaces)
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "-")

                    var version: String? = nil
                    if parts.count == 2 {
                        let versionStr = String(parts[1]).trimmingCharacters(in: .whitespaces)
                        if !versionStr.isEmpty && versionStr != "installed" {
                            version = versionStr
                        }
                    }

                    currentAgents[agentId] = .installed(version: version)
                }
            }
        }

        // Don't forget the last skill
        if let name = currentSkillName, !name.isEmpty {
            skills.append(Skill(
                name: name,
                description: "",
                source: .registry(url: "installed"),
                installStatus: currentAgents
            ))
        }

        return skills
    }

    /// Parse the output of `skills find` command
    static func parseFindOutput(_ output: String) -> [Skill] {
        var skills: [Skill] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("Found") || trimmed.hasPrefix("=") || trimmed.hasPrefix("-") {
                continue
            }

            if let separatorRange = trimmed.range(of: " - ") {
                let name = String(trimmed[..<separatorRange.lowerBound])
                let description = String(trimmed[separatorRange.upperBound...])

                if !name.isEmpty {
                    skills.append(Skill(name: name, description: description, source: .registry(url: "skills.sh")))
                }
            } else if !trimmed.isEmpty {
                skills.append(Skill(name: trimmed, description: "", source: .registry(url: "skills.sh")))
            }
        }

        return skills
    }

    /// Parse available skills output
    static func parseAvailableSkillsOutput(_ output: String, source: SkillSource) -> [Skill] {
        var skills: [Skill] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("Skills") || trimmed.hasPrefix("=") || trimmed.hasPrefix("-") || trimmed.hasPrefix("Found") {
                continue
            }
            if trimmed.hasPrefix("No skills") || trimmed.hasPrefix("Run `") || trimmed.hasPrefix("Use `") {
                continue
            }

            if let separatorRange = trimmed.range(of: " - ") {
                let name = String(trimmed[..<separatorRange.lowerBound])
                let description = String(trimmed[separatorRange.upperBound...])

                if !name.isEmpty {
                    skills.append(Skill(name: name, description: description, source: source))
                }
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("[") && !trimmed.hasSuffix("]") {
                skills.append(Skill(name: trimmed, description: "", source: source))
            }
        }

        return skills
    }

    /// Parse update check output
    static func parseUpdateCheckOutput(_ output: String) -> [Skill] {
        var skills: [Skill] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("Checking") || trimmed.hasPrefix("=") {
                continue
            }

            if trimmed.contains("update available") || trimmed.contains("→") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let firstPart = parts.first {
                    skills.append(Skill(name: firstPart, description: "Update available", source: .registry(url: "update")))
                }
            }
        }

        return skills
    }
}
