//
//  SkillSource.swift
//  skills-ui
//
//  Source type for where a skill originates from
//

import Foundation

/// Represents the source of a skill
enum SkillSource: Codable, Equatable, Hashable, Identifiable {
    case registry(url: String)  // skills.sh or custom registry
    case github(owner: String, repo: String, path: String?)
    case gitlab(url: String)
    case git(url: String)
    case local(path: String)

    var id: String {
        switch self {
        case .registry(let url):
            return "registry:\(url)"
        case .github(let owner, let repo, let path):
            if let path = path {
                return "github:\(owner)/\(repo):\(path)"
            }
            return "github:\(owner)/\(repo)"
        case .gitlab(let url):
            return "gitlab:\(url)"
        case .git(let url):
            return "git:\(url)"
        case .local(let path):
            return "local:\(path)"
        }
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .registry:
            return "Skills Registry"
        case .github(let owner, let repo, _):
            return "\(owner)/\(repo)"
        case .gitlab(let url):
            return URL(string: url)?.host ?? "GitLab"
        case .git(let url):
            return URL(string: url)?.lastPathComponent ?? "Git"
        case .local(let path):
            return URL(fileURLWithPath: path).lastPathComponent
        }
    }

    /// CLI-compatible source string
    var cliString: String {
        switch self {
        case .registry(let url):
            return url
        case .github(let owner, let repo, let path):
            if let path = path {
                return "https://github.com/\(owner)/\(repo)/tree/main/\(path)"
            }
            return "\(owner)/\(repo)"
        case .gitlab(let url):
            return url
        case .git(let url):
            return url
        case .local(let path):
            return path
        }
    }

    /// Parse a source string into a SkillSource
    static func parse(from string: String) -> SkillSource {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for local path (starts with /, ./, or ~)
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("./") || trimmed.hasPrefix("~") {
            let expandedPath = (trimmed as NSString).expandingTildeInPath
            return .local(path: expandedPath)
        }

        // Check for GitHub shorthand (owner/repo)
        if !trimmed.contains("://") && trimmed.contains("/") && trimmed.split(separator: "/").count == 2 {
            let parts = trimmed.split(separator: "/")
            return .github(owner: String(parts[0]), repo: String(parts[1]), path: nil)
        }

        // Check for GitHub URL
        if let url = URL(string: trimmed),
           url.host == "github.com" {
            let pathComponents = url.pathComponents
            if pathComponents.count >= 3 {
                let owner = pathComponents[1]
                let repo = pathComponents[2]
                // Check if it's a tree/blob link to a specific skill
                if pathComponents.count > 4,
                   (pathComponents[3] == "tree" || pathComponents[3] == "blob") {
                    let skillPath = pathComponents[4...].joined(separator: "/")
                    return .github(owner: owner, repo: repo, path: skillPath)
                }
                return .github(owner: owner, repo: repo, path: nil)
            }
        }

        // Check for GitLab URL
        if let url = URL(string: trimmed),
           url.host?.contains("gitlab") == true {
            return .gitlab(url: trimmed)
        }

        // Check for git URL (git@ or ends with .git)
        if trimmed.hasPrefix("git@") || trimmed.hasSuffix(".git") {
            return .git(url: trimmed)
        }

        // Default to registry URL
        return .registry(url: trimmed)
    }
}
