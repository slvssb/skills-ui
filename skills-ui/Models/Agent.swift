//
//  Agent.swift
//  skills-ui
//
//  AI Coding Agent model
//

import Foundation

/// Represents an AI coding agent that can have skills installed
struct Agent: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let projectPath: String
    let globalPath: String
    var isInstalled: Bool
    var isDetected: Bool

    /// All supported agents with their paths
    static let allAgents: [Agent] = [
        Agent(id: "claude-code", name: "Claude Code", projectPath: ".claude/skills/", globalPath: "~/.claude/skills/", isInstalled: false, isDetected: false),
        Agent(id: "cursor", name: "Cursor", projectPath: ".cursor/skills/", globalPath: "~/.cursor/skills/", isInstalled: false, isDetected: false),
        Agent(id: "codex", name: "Codex", projectPath: ".codex/skills/", globalPath: "~/.codex/skills/", isInstalled: false, isDetected: false),
        Agent(id: "opencode", name: "OpenCode", projectPath: ".opencode/skills/", globalPath: "~/.opencode/skills/", isInstalled: false, isDetected: false),
        Agent(id: "cline", name: "Cline", projectPath: ".cline/skills/", globalPath: "~/.cline/skills/", isInstalled: false, isDetected: false),
        Agent(id: "windsurf", name: "Windsurf", projectPath: ".windsurf/skills/", globalPath: "~/.codeium/windsurf/skills/", isInstalled: false, isDetected: false),
        Agent(id: "goose", name: "Goose", projectPath: ".goose/skills/", globalPath: "~/.config/goose/skills/", isInstalled: false, isDetected: false),
        Agent(id: "gemini-cli", name: "Gemini CLI", projectPath: ".gemini/skills/", globalPath: "~/.gemini/skills/", isInstalled: false, isDetected: false),
        Agent(id: "github-copilot", name: "GitHub Copilot", projectPath: ".github/skills/", globalPath: "~/.copilot/skills/", isInstalled: false, isDetected: false),
        Agent(id: "continue", name: "Continue", projectPath: ".continue/skills/", globalPath: "~/.continue/skills/", isInstalled: false, isDetected: false),
        Agent(id: "junie", name: "Junie", projectPath: ".junie/skills/", globalPath: "~/.junie/skills/", isInstalled: false, isDetected: false),
        Agent(id: "kiro-cli", name: "Kiro CLI", projectPath: ".kiro/skills/", globalPath: "~/.kiro/skills/", isInstalled: false, isDetected: false),
        Agent(id: "roo", name: "Roo Code", projectPath: ".roo/skills/", globalPath: "~/.roo/skills/", isInstalled: false, isDetected: false),
        Agent(id: "trae", name: "Trae", projectPath: ".trae/skills/", globalPath: "~/.trae/skills/", isInstalled: false, isDetected: false),
        Agent(id: "qwen-code", name: "Qwen Code", projectPath: ".qwen/skills/", globalPath: "~/.qwen/skills/", isInstalled: false, isDetected: false),
        Agent(id: "openhands", name: "OpenHands", projectPath: ".openhands/skills/", globalPath: "~/.openhands/skills/", isInstalled: false, isDetected: false),
        Agent(id: "amp", name: "Amp", projectPath: ".agents/skills/", globalPath: "~/.config/agents/skills/", isInstalled: false, isDetected: false),
        Agent(id: "kimi-cli", name: "Kimi Code CLI", projectPath: ".agents/skills/", globalPath: "~/.config/agents/skills/", isInstalled: false, isDetected: false),
        Agent(id: "replit", name: "Replit", projectPath: ".agents/skills/", globalPath: "~/.config/agents/skills/", isInstalled: false, isDetected: false),
        Agent(id: "antigravity", name: "Antigravity", projectPath: ".agents/skills/", globalPath: "~/.gemini/antigravity/skills/", isInstalled: false, isDetected: false),
        Agent(id: "augment", name: "Augment", projectPath: ".augment/skills/", globalPath: "~/.augment/skills/", isInstalled: false, isDetected: false),
        Agent(id: "openclaw", name: "OpenClaw", projectPath: "skills/", globalPath: "~/.openclaw/skills/", isInstalled: false, isDetected: false),
        Agent(id: "codebuddy", name: "CodeBuddy", projectPath: ".codebuddy/skills/", globalPath: "~/.codebuddy/skills/", isInstalled: false, isDetected: false),
        Agent(id: "command-code", name: "Command Code", projectPath: ".commandcode/skills/", globalPath: "~/.commandcode/skills/", isInstalled: false, isDetected: false),
        Agent(id: "crush", name: "Crush", projectPath: ".crush/skills/", globalPath: "~/.config/crush/skills/", isInstalled: false, isDetected: false),
        Agent(id: "cortex", name: "Cortex Code", projectPath: ".cortex/skills/", globalPath: "~/.snowflake/cortex/skills/", isInstalled: false, isDetected: false),
        Agent(id: "deepagents", name: "Deep Agents", projectPath: ".agents/skills/", globalPath: "~/.deepagents/agent/skills/", isInstalled: false, isDetected: false),
        Agent(id: "droid", name: "Droid", projectPath: ".factory/skills/", globalPath: "~/.factory/skills/", isInstalled: false, isDetected: false),
        Agent(id: "iflow-cli", name: "iFlow CLI", projectPath: ".iflow/skills/", globalPath: "~/.iflow/skills/", isInstalled: false, isDetected: false),
        Agent(id: "kilo", name: "Kilo Code", projectPath: ".kilocode/skills/", globalPath: "~/.kilocode/skills/", isInstalled: false, isDetected: false),
        Agent(id: "kode", name: "Kode", projectPath: ".kode/skills/", globalPath: "~/.kode/skills/", isInstalled: false, isDetected: false),
        Agent(id: "mcpjam", name: "MCPJam", projectPath: ".mcpjam/skills/", globalPath: "~/.mcpjam/skills/", isInstalled: false, isDetected: false),
        Agent(id: "mistral-vibe", name: "Mistral Vibe", projectPath: ".vibe/skills/", globalPath: "~/.vibe/skills/", isInstalled: false, isDetected: false),
        Agent(id: "mux", name: "Mux", projectPath: ".mux/skills/", globalPath: "~/.mux/skills/", isInstalled: false, isDetected: false),
        Agent(id: "pi", name: "Pi", projectPath: ".pi/skills/", globalPath: "~/.pi/agent/skills/", isInstalled: false, isDetected: false),
        Agent(id: "qoder", name: "Qoder", projectPath: ".qoder/skills/", globalPath: "~/.qoder/skills/", isInstalled: false, isDetected: false),
        Agent(id: "neovate", name: "Neovate", projectPath: ".neovate/skills/", globalPath: "~/.neovate/skills/", isInstalled: false, isDetected: false),
        Agent(id: "pochi", name: "Pochi", projectPath: ".pochi/skills/", globalPath: "~/.pochi/skills/", isInstalled: false, isDetected: false),
        Agent(id: "adal", name: "AdaL", projectPath: ".adal/skills/", globalPath: "~/.adal/skills/", isInstalled: false, isDetected: false),
        Agent(id: "zencoder", name: "Zencoder", projectPath: ".zencoder/skills/", globalPath: "~/.zencoder/skills/", isInstalled: false, isDetected: false),
        Agent(id: "warp", name: "Warp", projectPath: ".agents/skills/", globalPath: "~/.agents/skills/", isInstalled: false, isDetected: false),
        Agent(id: "universal", name: "Universal", projectPath: ".agents/skills/", globalPath: "~/.config/agents/skills/", isInstalled: false, isDetected: false),
    ]

    /// Get agent by ID
    static func byId(_ id: String) -> Agent? {
        allAgents.first { $0.id == id }
    }

    /// Expand tilde in path
    func expandPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}
