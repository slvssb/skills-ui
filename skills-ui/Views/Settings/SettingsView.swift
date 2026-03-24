//
//  SettingsView.swift
//  skills-ui
//
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AgentsStore.self) private var agentsStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ProjectsSettingsView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            AgentsSettingsView()
                .tabItem {
                    Label("Agents", systemImage: "cpu")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        @Bindable var settings = settingsStore
        Form {
            Section("Installation Defaults") {
                Picker("Default Scope", selection: $settings.defaultScope) {
                    Text("Project").tag(InstallScope.project)
                    Text("Global").tag(InstallScope.global)
                }

                Picker("Default Method", selection: $settings.defaultMethod) {
                    Text("Symlink (Recommended)").tag(InstallMethod.symlink)
                    Text("Copy").tag(InstallMethod.copy)
                }
            }

            Section("Updates") {
                HStack {
                    Text("Check for updates every")

                    Picker("", selection: $settings.updateCheckInterval) {
                        Text("1 hour").tag(1.0)
                        Text("6 hours").tag(6.0)
                        Text("12 hours").tag(12.0)
                        Text("24 hours").tag(24.0)
                        Text("Never").tag(Double.infinity)
                    }
                    .frame(width: 100)
                }

                if let lastCheck = settingsStore.lastUpdateCheck {
                    LabeledContent("Last checked") {
                        Text(lastCheck, style: .relative)
                    }
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text("1.0.0")
                }

                LabeledContent("CLI Status") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(settingsStore.isCLIAvailable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(settingsStore.isCLIAvailable ? "Available" : "Not Available")
                    }
                }

                Button("Check for App Updates...") {
                    // Would integrate with Sparkle
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Projects Settings

struct ProjectsSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Recent Projects") {
                    if settingsStore.recentProjects.isEmpty {
                        Text("No recent projects")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(settingsStore.recentProjects, id: \.self) { url in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent)
                                        .font(.subheadline)

                                    Text(url.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    settingsStore.removeRecentProject(url)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Clear All") {
                    settingsStore.clearRecentProjects()
                }
                .disabled(settingsStore.recentProjects.isEmpty)

                Spacer()

                Button("Open Project...") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.message = "Select a project directory"

                    if panel.runModal() == .OK, let url = panel.url {
                        settingsStore.setCurrentProject(url)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Agents Settings

struct AgentsSettingsView: View {
    @Environment(AgentsStore.self) private var agentsStore

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Detected Agents") {
                    Text("Agents that are installed on your system")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(agentsStore.detectedAgents) { agent in
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundStyle(.green)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name)
                                    .font(.subheadline)

                                Text(agent.globalPath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                Section("All Supported Agents") {
                    Text("Agents that can be used with Skills")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(Agent.allAgents) { agent in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name)
                                    .font(.subheadline)

                                Text(agent.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if agentsStore.detectedAgents.contains(where: { $0.id == agent.id }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Refresh Detection") {
                    Task {
                        await agentsStore.refresh()
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    @State private var showingClearCacheConfirmation = false

    var body: some View {
        @Bindable var settings = settingsStore
        Form {
            Section("Internal Skills") {
                Toggle("Show Internal Skills", isOn: $settings.showInternalSkills)

                Text("Internal skills are work-in-progress or meant only for internal tooling")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("CLI Configuration") {
                LabeledContent("Environment Variable") {
                    Text("INSTALL_INTERNAL_SKILLS")
                        .font(.system(.caption, design: .monospaced))
                }

                Text("Set environment variables to control CLI behavior")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Debug") {
                Button("Reload CLI") {
                    settingsStore.checkCLIAvailability()
                }

                Button("Clear Cache") {
                    showingClearCacheConfirmation = true
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CLI Path")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("The app uses `npx skills` which requires Node.js to be installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Install Node.js") {
                        NSWorkspace.shared.open(URL(string: "https://nodejs.org")!)
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog(
            "Clear Cache?",
            isPresented: $showingClearCacheConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Cache", role: .destructive) {
                // Clear cached data
                UserDefaults.standard.removeObject(forKey: "recentProjects")
                UserDefaults.standard.removeObject(forKey: "recentlyInstalledSkills")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear recent projects and recently installed skills data.")
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(SettingsStore.shared)
        .environment(AgentsStore.shared)
}
