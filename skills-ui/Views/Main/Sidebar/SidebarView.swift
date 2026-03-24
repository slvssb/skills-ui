//
//  SidebarView.swift
//  skills-ui
//
//  Navigation sidebar
//

import SwiftUI

struct SidebarView: View {
    @Environment(SkillsStore.self) private var skillsStore
    @Environment(AgentsStore.self) private var agentsStore
    @Environment(SettingsStore.self) private var settingsStore

    @State private var selectedSection: SidebarSection = .all

    var body: some View {
        List(selection: $selectedSection) {
            // Main sections
            Section("Browse") {
                Label("All Skills", systemImage: "rectangle.stack")
                    .tag(SidebarSection.all)

                Label("Installed", systemImage: "checkmark.rectangle.stack")
                    .tag(SidebarSection.installed)
                    .badge(skillsStore.installedSkills.count)

                if skillsStore.hasUpdatesAvailable {
                    Label("Updates", systemImage: "arrow.clockwise.circle")
                        .tag(SidebarSection.updates)
                        .badge(skillsStore.updateCount)
                }
            }

            // Source filter
            Section("Sources") {
                Label("Registry", systemImage: "globe")
                    .tag(SidebarSection.registry)

                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    .tag(SidebarSection.github)

                Label("Local", systemImage: "folder")
                    .tag(SidebarSection.local)
            }

            // Agent filter
            Section("Filter by Agent") {
                ForEach(agentsStore.detectedAgents) { agent in
                    AgentFilterRow(agent: agent)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Skills")
    }
}

// MARK: - Sidebar Section

enum SidebarSection: String, Identifiable, CaseIterable {
    case all = "all"
    case installed = "installed"
    case updates = "updates"
    case registry = "registry"
    case github = "github"
    case local = "local"

    var id: String { rawValue }
}

// MARK: - Agent Filter Row

struct AgentFilterRow: View {
    @Environment(AgentsStore.self) private var agentsStore
    let agent: Agent

    @State private var isSelected = true

    var body: some View {
        HStack {
            Toggle(isOn: $isSelected) {
                HStack(spacing: 8) {
                    Text(agent.name)
                        .lineLimit(1)
                }
            }
            .toggleStyle(.checkbox)
        }
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                agentsStore.selectAgent(agent.id)
            } else {
                agentsStore.deselectAgent(agent.id)
            }
        }
        .onAppear {
            isSelected = agentsStore.isSelected(agent.id)
        }
    }
}

// MARK: - Preview

#Preview {
    SidebarView()
        .environment(SkillsStore())
        .environment(AgentsStore.shared)
        .environment(SettingsStore.shared)
        .frame(width: 220, height: 500)
}
