//
//  InstallOptions.swift
//  skills-ui
//
//  Options for installing skills
//

import Foundation

/// Installation scope
enum InstallScope: String, Codable, CaseIterable, Sendable {
    case project = "project"
    case global = "global"

    var displayName: String {
        switch self {
        case .project:
            return "Project"
        case .global:
            return "Global"
        }
    }

    var description: String {
        switch self {
        case .project:
            return "Install to ./<agent>/skills/ - Shared with your team"
        case .global:
            return "Install to ~/<agent>/skills/ - Available across all projects"
        }
    }

    var cliFlag: String? {
        switch self {
        case .project:
            return nil  // Default, no flag needed
        case .global:
            return "-g"
        }
    }
}

/// Installation method
enum InstallMethod: String, Codable, CaseIterable, Sendable {
    case symlink = "symlink"
    case copy = "copy"

    var displayName: String {
        switch self {
        case .symlink:
            return "Symlink (Recommended)"
        case .copy:
            return "Copy"
        }
    }

    var description: String {
        switch self {
        case .symlink:
            return "Creates symlinks - single source of truth, easy updates"
        case .copy:
            return "Creates independent copies - use when symlinks aren't supported"
        }
    }

    var cliFlag: String? {
        switch self {
        case .symlink:
            return nil  // Default, no flag needed
        case .copy:
            return "--copy"
        }
    }
}

/// Options for installing a skill
struct InstallOptions: Codable, Sendable {
    var scope: InstallScope
    var method: InstallMethod
    var agentIds: [String]
    var skillNames: [String]
    var source: SkillSource
    var skipConfirmation: Bool
    var showInternal: Bool

    init(
        scope: InstallScope = .project,
        method: InstallMethod = .symlink,
        agentIds: [String] = [],
        skillNames: [String] = [],
        source: SkillSource,
        skipConfirmation: Bool = false,
        showInternal: Bool = false
    ) {
        self.scope = scope
        self.method = method
        self.agentIds = agentIds
        self.skillNames = skillNames
        self.source = source
        self.skipConfirmation = skipConfirmation
        self.showInternal = showInternal
    }

    /// Build CLI arguments from options
    func toCLIArguments() -> [String] {
        var args = ["add", source.cliString]

        // Add scope flag
        if let scopeFlag = scope.cliFlag {
            args.append(scopeFlag)
        }

        // Add method flag
        if let methodFlag = method.cliFlag {
            args.append(methodFlag)
        }

        // Add agent flags
        for agentId in agentIds {
            args.append(contentsOf: ["-a", agentId])
        }

        // Add skill flags
        for skillName in skillNames {
            args.append(contentsOf: ["-s", skillName])
        }

        // Add skip confirmation
        if skipConfirmation {
            args.append("-y")
        }

        // Add all flag if installing all skills
        if skillNames.contains("*") {
            args.append("--all")
        }

        return args
    }

    /// Default options for quick install
    static func quickInstall(source: SkillSource, agentIds: [String] = []) -> InstallOptions {
        InstallOptions(
            scope: .project,
            method: .symlink,
            agentIds: agentIds,
            skillNames: [],
            source: source,
            skipConfirmation: true,
            showInternal: false
        )
    }
}

/// Options for removing a skill
struct RemoveOptions: Codable, Sendable {
    var scope: InstallScope
    var agentIds: [String]
    var skillNames: [String]
    var removeAll: Bool

    init(
        scope: InstallScope = .project,
        agentIds: [String] = [],
        skillNames: [String] = [],
        removeAll: Bool = false
    ) {
        self.scope = scope
        self.agentIds = agentIds
        self.skillNames = skillNames
        self.removeAll = removeAll
    }

    /// Build CLI arguments from options
    func toCLIArguments() -> [String] {
        var args = ["remove"]

        // Add scope flag
        if scope == .global {
            args.append("-g")
        }

        // Add agent flags
        for agentId in agentIds {
            args.append(contentsOf: ["-a", agentId])
        }

        // Add skill names
        args.append(contentsOf: skillNames)

        // Add remove all flag
        if removeAll {
            args.append("--all")
        }

        return args
    }
}
