//
//  Skill.swift
//  skills-ui
//
//  Skill model representing an agent skill
//

import Foundation

/// Installation status for a skill on a specific agent
enum SkillInstallStatus: Codable, Equatable, Hashable, Sendable {
    case notInstalled
    case installed(version: String?)
    case updateAvailable(currentVersion: String?, newVersion: String?)

    var isInstalled: Bool {
        switch self {
        case .notInstalled:
            return false
        case .installed, .updateAvailable:
            return true
        }
    }

    var needsUpdate: Bool {
        if case .updateAvailable = self {
            return true
        }
        return false
    }
}

/// Represents an agent skill from the skills registry or other sources
struct Skill: Codable, Identifiable, Hashable, Sendable {
    let id: String  // Usually the name, but unique per source
    let name: String
    let description: String
    let source: SkillSource
    var installStatus: [String: SkillInstallStatus]  // Agent ID -> Status
    let markdownContent: String?
    let metadata: SkillMetadata?

    init(
        id: String? = nil,
        name: String,
        description: String,
        source: SkillSource,
        installStatus: [String: SkillInstallStatus] = [:],
        markdownContent: String? = nil,
        metadata: SkillMetadata? = nil
    ) {
        self.id = id ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.description = description
        self.source = source
        self.installStatus = installStatus
        self.markdownContent = markdownContent
        self.metadata = metadata
    }

    /// Check if installed on any agent
    var isInstalled: Bool {
        installStatus.values.contains { $0.isInstalled }
    }

    /// Check if update available on any agent
    var hasUpdateAvailable: Bool {
        installStatus.values.contains { $0.needsUpdate }
    }

    /// Get agents where this skill is installed
    var installedAgents: [String] {
        installStatus.filter { $0.value.isInstalled }.map { $0.key }
    }

    /// Get agents where update is available
    var agentsWithUpdates: [String] {
        installStatus.filter { $0.value.needsUpdate }.map { $0.key }
    }

    /// Create a sample skill for previews
    static func sample(name: String = "frontend-design", description: String = "Create distinctive, production-grade frontend interfaces") -> Skill {
        Skill(
            name: name,
            description: description,
            source: .github(owner: "vercel-labs", repo: "agent-skills", path: nil),
            markdownContent: nil,
            metadata: SkillMetadata(internal: false)
        )
    }
}

/// Additional metadata for a skill
struct SkillMetadata: Codable, Equatable, Hashable, Sendable {
    let `internal`: Bool
    let version: String?
    let author: String?
    let tags: [String]?
    let compatibleAgents: [String]?

    init(internal: Bool = false, version: String? = nil, author: String? = nil, tags: [String]? = nil, compatibleAgents: [String]? = nil) {
        self.internal = `internal`
        self.version = version
        self.author = author
        self.tags = tags
        self.compatibleAgents = compatibleAgents
    }
}

// MARK: - Parsing helpers

extension Skill {
    /// Parse skills from CLI `skills list` output
    static func parseListOutput(_ output: String) -> [Skill] {
        var skills: [Skill] = []
        let lines = output.components(separatedBy: .newlines)

        var currentSkill: (name: String, agents: [String: String])?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and headers
            if trimmed.isEmpty || trimmed.hasPrefix("Skills") || trimmed.hasPrefix("=") || trimmed.hasPrefix("-") {
                continue
            }

            // Check for skill name line (usually starts the block)
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") && trimmed.contains(":") == false {
                // If we have a previous skill, save it
                if let current = currentSkill {
                    let skill = Skill(
                        name: current.name,
                        description: "",
                        source: .registry(url: "skills.sh"),
                        installStatus: current.agents.mapValues { SkillInstallStatus.installed(version: $0.isEmpty ? nil : $0) }
                    )
                    skills.append(skill)
                }
                currentSkill = (name: trimmed, agents: [:])
            }

            // Check for agent installation line (usually indented)
            if line.hasPrefix("  ") || line.hasPrefix("\t") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2, let current = currentSkill {
                    let agentId = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let version = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    currentSkill?.agents[agentId] = version
                }
            }
        }

        // Don't forget the last skill
        if let current = currentSkill {
            let skill = Skill(
                name: current.name,
                description: "",
                source: .registry(url: "skills.sh"),
                installStatus: current.agents.mapValues { SkillInstallStatus.installed(version: $0.isEmpty ? nil : $0) }
            )
            skills.append(skill)
        }

        return skills
    }

    /// Parse skills from CLI `skills find` or `skills add --list` output
    static func parseFindOutput(_ output: String, source: SkillSource) -> [Skill] {
        var skills: [Skill] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines, headers, and info messages
            if trimmed.isEmpty || trimmed.hasPrefix("Found") || trimmed.hasPrefix("Skills") || trimmed.hasPrefix("=") || trimmed.hasPrefix("-") {
                continue
            }

            // Try to parse skill name and description
            // Format is usually: "skill-name - Description here" or just "skill-name"
            if let dashIndex = trimmed.firstIndex(of: "-") {
                let name = String(trimmed[..<dashIndex]).trimmingCharacters(in: .whitespaces)
                let description = String(trimmed[trimmed.index(after: dashIndex)...]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    skills.append(Skill(name: name, description: description, source: source))
                }
            } else if !trimmed.isEmpty {
                skills.append(Skill(name: trimmed, description: "", source: source))
            }
        }

        return skills
    }
}
