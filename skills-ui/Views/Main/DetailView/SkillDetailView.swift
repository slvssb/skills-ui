//
//  SkillDetailView.swift
//  skills-ui
//
//  Detail view for a single skill
//

import SwiftUI
import WebKit

struct SkillDetailView: View {
    @Environment(SkillsStore.self) private var skillsStore
    @Environment(AgentsStore.self) private var agentsStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ToastManager.self) private var toastManager

    @State private var showingInstallSheet = false
    @State private var showingRemoveConfirmation = false
    @State private var isLoadingContent = false
    @State private var markdownContent: String?

    let skill: Skill

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                headerView
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Content
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    if !skill.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            Text(skill.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Installation status
                    installStatusSection

                    // Actions
                    actionsSection

                    // Markdown content
                    if let content = markdownContent {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.headline)
                            MarkdownWebView(htmlContent: markdownToHTML(content))
                                .frame(minHeight: 200)
                        }
                    }

                    // Source info
                    sourceInfoSection
                }
                .padding()
            }
        }
        .navigationTitle(skill.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if skill.isInstalled {
                    Button("Remove") {
                        showingRemoveConfirmation = true
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Install") {
                        showingInstallSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showingInstallSheet) {
            InstallSheet(skill: skill) {
                showingInstallSheet = false
            }
        }
        .confirmationDialog(
            "Remove \(skill.name)?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove from all agents", role: .destructive) {
                removeSkill()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the skill from all agents where it's installed.")
        }
        .onAppear {
            loadSkillContent()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(skill.source.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if skill.hasUpdateAvailable {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Update Available")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Quick install button
            if !skill.isInstalled {
                Button("Quick Install") {
                    quickInstall()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Install Status Section

    private var installStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Installation Status")
                .font(.headline)

            if skill.installStatus.isEmpty {
                Text("Not installed on any agent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(skill.installStatus.keys.sorted()), id: \.self) { agentId in
                    if let status = skill.installStatus[agentId],
                       let agent = agentsStore.agentById(agentId) {
                        HStack {
                            Circle()
                                .fill(statusColor(for: status))
                                .frame(width: 8, height: 8)
                            Text(agent.name)
                            Spacer()
                            statusText(for: status)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusColor(for status: SkillInstallStatus) -> Color {
        switch status {
        case .notInstalled:
            return .secondary
        case .installed:
            return .green
        case .updateAvailable:
            return .orange
        }
    }

    private func statusText(for status: SkillInstallStatus) -> Text {
        switch status {
        case .notInstalled:
            return Text("Not installed").foregroundStyle(.secondary)
        case .installed(let version):
            if let v = version {
                return Text("v\(v)").foregroundStyle(.secondary)
            }
            return Text("Installed").foregroundStyle(.green)
        case .updateAvailable(let current, let new):
            if let c = current, let n = new {
                return Text("\(c) → \(n)").foregroundStyle(.orange)
            }
            return Text("Update available").foregroundStyle(.orange)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        HStack(spacing: 12) {
            if skill.isInstalled {
                if skill.hasUpdateAvailable {
                    Button {
                        updateSkill()
                    } label: {
                        Label("Update", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(role: .destructive) {
                    showingRemoveConfirmation = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    showingInstallSheet = true
                } label: {
                    Label("Install with Options", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    quickInstall()
                } label: {
                    Label("Quick Install", systemImage: "bolt")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Source Info Section

    private var sourceInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.headline)

            HStack {
                Image(systemName: sourceIcon)
                Text(skill.source.cliString)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sourceIcon: String {
        switch skill.source {
        case .registry: return "globe"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .gitlab: return "chevron.left.forwardslash.chevron.right"
        case .git: return "arrow.down.circle"
        case .local: return "folder"
        }
    }

    // MARK: - Actions

    private func loadSkillContent() {
        // For now, use placeholder content
        // In a real implementation, we'd fetch the SKILL.md content
        markdownContent = skill.markdownContent ?? """
        # \(skill.name)

        \(skill.description)

        ## When to Use

        This skill should be used when working with tasks that require specialized knowledge
        about \(skill.name.lowercased()).

        ## Steps

        1. First, understand the context
        2. Then apply the skill
        3. Finally, verify the results
        """
    }

    private func quickInstall() {
        Task {
            do {
                let options = InstallOptions(
                    scope: settingsStore.defaultScope,
                    method: settingsStore.defaultMethod,
                    agentIds: Array(agentsStore.selectedAgentIds),
                    skillNames: [skill.name],
                    source: skill.source,
                    skipConfirmation: true
                )
                try await skillsStore.installSkill(skill, options: options)
                toastManager.success("Installed \(skill.name)")
            } catch {
                toastManager.error("Installation Failed", message: error.localizedDescription)
            }
        }
    }

    private func updateSkill() {
        Task {
            do {
                try await skillsStore.updateAllSkills()
                toastManager.success("Updated \(skill.name)")
            } catch {
                toastManager.error("Update Failed", message: error.localizedDescription)
            }
        }
    }

    private func removeSkill() {
        Task {
            do {
                let options = RemoveOptions(
                    scope: settingsStore.defaultScope,
                    agentIds: skill.installedAgents,
                    skillNames: [skill.name]
                )
                try await skillsStore.removeSkill(skill, options: options)
                toastManager.success("Removed \(skill.name)")
            } catch {
                toastManager.error("Removal Failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Markdown Helpers

    private func markdownToHTML(_ markdown: String) -> String {
        // Simple markdown to HTML conversion
        // In production, use a proper markdown library
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 14px;
                    line-height: 1.6;
                    padding: 10px;
                    color: #333;
                }
                h1 { font-size: 24px; margin-bottom: 10px; }
                h2 { font-size: 18px; margin-top: 20px; }
                h3 { font-size: 16px; }
                code {
                    background: #f4f4f4;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: 'SF Mono', Monaco, monospace;
                    font-size: 13px;
                }
                pre {
                    background: #f4f4f4;
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                }
                pre code {
                    background: none;
                    padding: 0;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #e0e0e0; }
                    code, pre { background: #2a2a2a; }
                }
            </style>
        </head>
        <body>
        """

        // Simple conversion
        var content = markdown
        content = content.replacingOccurrences(of: "**", with: "<strong>")
        content = content.replacingOccurrences(of: "*", with: "<em>")
        content = content.replacingOccurrences(of: "`", with: "<code>")

        // Headers
        content = content.replacingOccurrences(of: "# ", with: "<h1>")
        content = content.replacingOccurrences(of: "## ", with: "<h2>")
        content = content.replacingOccurrences(of: "### ", with: "<h3>")

        // Paragraphs
        let paragraphs = content.components(separatedBy: "\n\n")
        let wrapped = paragraphs.map { p in
            if p.hasPrefix("<h") {
                return p + "</h" + String(p.dropFirst().prefix(1)) + ">"
            }
            return "<p>\(p)</p>"
        }.joined(separator: "\n")

        html += wrapped
        html += "\n</body>\n</html>"
        return html
    }
}

// MARK: - Markdown WebView

struct MarkdownWebView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - Preview

#Preview {
    SkillDetailView(skill: Skill.sample())
        .environment(SkillsStore())
        .environment(AgentsStore.shared)
        .environment(SettingsStore.shared)
        .environment(ToastManager())
        .frame(width: 400, height: 600)
}
