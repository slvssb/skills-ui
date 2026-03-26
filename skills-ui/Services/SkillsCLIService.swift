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
        var args = ["list", "--json"]

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
        return try await runCommand(["check", "--json"])
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
    private static let ansiEscapePattern = #"\u{001B}\[[0-9;]*m"#
    private static let orphanedAnsiCodePattern = #"^\[[0-9;]*m|\[[0-9;]*m$"#

    private struct InstalledSkillRecord: Decodable {
        let name: String
        let path: String
        let scope: String
        let agents: [String]
    }

    private struct UpdateRecord: Decodable {
        let name: String
        let source: String
    }

    /// Parse the output of `skills list` command
    static func parseListOutput(_ output: String) -> [Skill] {
        if let jsonSkills = parseListJSONOutput(output) {
            return jsonSkills
        }

        return parseLegacyListTextOutput(output)
    }

    private static func parseListJSONOutput(_ output: String) -> [Skill]? {
        guard let data = output.data(using: .utf8) else {
            return nil
        }

        guard let records = try? JSONDecoder().decode([InstalledSkillRecord].self, from: data) else {
            return nil
        }

        return records.map { record in
            let installStatus = Dictionary(uniqueKeysWithValues: record.agents.map { agentName in
                let agentId = Agent.byName(agentName)?.id
                    ?? agentName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return (agentId, SkillInstallStatus.installed(version: nil))
            })
            let markdownContent = loadInstalledSkillMarkdownContent(from: record.path)

            return Skill(
                name: record.name,
                description: "",
                source: .registry(url: "installed"),
                installedPath: record.path,
                installStatus: installStatus,
                markdownContent: markdownContent
            )
        }
    }

    private static func parseLegacyListTextOutput(_ output: String) -> [Skill] {
        var skills: [Skill] = []
        let lines = output.components(separatedBy: .newlines)

        var currentSkillName: String?
        var currentAgents: [String: SkillInstallStatus] = [:]

        for line in lines {
            let cleanedLine = sanitizedLine(line)
            let trimmed = cleanedLine.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and headers
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("Skills") || trimmed.hasPrefix("=") || trimmed.hasPrefix("-") { continue }
            if trimmed.hasPrefix("No skills") || trimmed.hasPrefix("Run `") { continue }
            if trimmed.hasPrefix("No project skills") || trimmed.hasPrefix("No global skills") { continue }
            if trimmed.contains("Try listing ") { continue }

            // Check if this is a skill name line (not indented)
            if !cleanedLine.hasPrefix(" ") && !cleanedLine.hasPrefix("\t") && !trimmed.isEmpty {
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
            if (cleanedLine.hasPrefix("  ") || cleanedLine.hasPrefix("\t")) && trimmed.contains(":") {
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
            let trimmed = sanitizedLine(line).trimmingCharacters(in: .whitespaces)

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
            let trimmed = sanitizedLine(line).trimmingCharacters(in: .whitespaces)

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

    /// Parse the output of `skills check` command
    static func parseUpdateCheckOutput(_ output: String) -> UpdateCheckResult {
        if let jsonResult = parseUpdateCheckJSONOutput(output) {
            return jsonResult
        }

        return parseLegacyUpdateCheckTextOutput(output)
    }

    private static func parseUpdateCheckJSONOutput(_ output: String) -> UpdateCheckResult? {
        guard let data = output.data(using: .utf8),
              let records = try? JSONDecoder().decode([UpdateRecord].self, from: data) else {
            return nil
        }

        return UpdateCheckResult(
            updates: records.map { SkillUpdate(name: $0.name, source: $0.source) },
            skipped: [],
            errors: [],
            isUpToDate: records.isEmpty
        )
    }

    private static func parseLegacyUpdateCheckTextOutput(_ output: String) -> UpdateCheckResult {
        var updates: [SkillUpdate] = []
        var skipped: [SkillUpdateSkipped] = []
        var errors: [SkillUpdateError] = []
        var currentUpdateName: String?
        var currentErrorName: String?
        var currentSkippedName: String?
        var currentSkippedReason: String?
        var isUpToDate = false

        for line in output.components(separatedBy: .newlines) {
            let trimmed = sanitizedLine(line).trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("Checking") || trimmed.hasPrefix("=") {
                continue
            }

            if trimmed == "✓ All skills are up to date" {
                isUpToDate = true
                continue
            }

            if trimmed.hasSuffix("update(s) available:") || trimmed.hasPrefix("Run npx skills update") {
                continue
            }

            if trimmed.hasSuffix("skill(s) cannot be checked automatically:") {
                continue
            }

            if trimmed.hasPrefix("Could not check ") {
                continue
            }

            if trimmed.hasPrefix("↑ ") {
                currentUpdateName = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if let updateName = currentUpdateName, trimmed.hasPrefix("source: ") {
                let source = String(trimmed.dropFirst("source: ".count)).trimmingCharacters(in: .whitespaces)
                updates.append(SkillUpdate(name: updateName, source: source))
                currentUpdateName = nil
                continue
            }

            if trimmed.hasPrefix("✗ ") {
                currentErrorName = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                continue
            }

            if let errorName = currentErrorName, trimmed.hasPrefix("source: ") {
                let source = String(trimmed.dropFirst("source: ".count)).trimmingCharacters(in: .whitespaces)
                errors.append(SkillUpdateError(name: errorName, source: source))
                currentErrorName = nil
                continue
            }

            if trimmed.hasPrefix("• ") {
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let openParenIndex = content.lastIndex(of: "("), content.hasSuffix(")") {
                    let name = String(content[..<openParenIndex]).trimmingCharacters(in: .whitespaces)
                    let reasonStart = content.index(after: openParenIndex)
                    let reasonEnd = content.index(before: content.endIndex)
                    let reason = String(content[reasonStart..<reasonEnd]).trimmingCharacters(in: .whitespaces)
                    currentSkippedName = name
                    currentSkippedReason = reason
                }
                continue
            }

            if let skippedName = currentSkippedName, let skippedReason = currentSkippedReason, trimmed.hasPrefix("To update: ") {
                let command = String(trimmed.dropFirst("To update: ".count)).trimmingCharacters(in: .whitespaces)
                skipped.append(
                    SkillUpdateSkipped(
                        name: skippedName,
                        reason: skippedReason,
                        updateCommand: command
                    )
                )
                currentSkippedName = nil
                currentSkippedReason = nil
            }
        }

        return UpdateCheckResult(
            updates: updates,
            skipped: skipped,
            errors: errors,
            isUpToDate: isUpToDate
        )
    }

    private static func sanitizedLine(_ line: String) -> String {
        let withoutAnsi = line.replacingOccurrences(of: ansiEscapePattern, with: "", options: .regularExpression)
        return withoutAnsi.replacingOccurrences(of: orphanedAnsiCodePattern, with: "", options: .regularExpression)
    }

    private static func loadInstalledSkillMarkdownContent(from path: String) -> String? {
        let fileManager = FileManager.default
        var filePath = path

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            filePath = (path as NSString).appendingPathComponent("SKILL.md")
        }

        guard fileManager.fileExists(atPath: filePath) else {
            return nil
        }

        return try? String(contentsOfFile: filePath, encoding: .utf8)
    }
}
