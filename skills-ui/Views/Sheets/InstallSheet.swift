//
//  InstallSheet.swift
//  skills-ui
//
//  Sheet for installing a skill with options
//

import SwiftUI

struct InstallSheet: View {
    @Environment(SkillsStore.self) private var skillsStore
    @Environment(AgentsStore.self) private var agentsStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.dismiss) private var dismiss

    let skill: Skill
    let onComplete: () -> Void

    @State private var scope: InstallScope = .project
    @State private var method: InstallMethod = .symlink
    @State private var selectedAgentIds: Set<String> = []
    @State private var isInstalling = false
    @State private var installProgress: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Install Skill")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(skill.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Scope selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installation Scope")
                            .font(.headline)

                        Picker("Scope", selection: $scope) {
                            ForEach([InstallScope.project, .global], id: \.self) { s in
                                VStack(alignment: .leading) {
                                    Text(s.displayName)
                                    Text(s.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(s)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }

                    // Method selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installation Method")
                            .font(.headline)

                        Picker("Method", selection: $method) {
                            ForEach([InstallMethod.symlink, .copy], id: \.self) { m in
                                VStack(alignment: .leading) {
                                    Text(m.displayName)
                                    Text(m.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(m)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }

                    // Agent selection
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Agents")
                                .font(.headline)

                            Spacer()

                            Button("Select All") {
                                selectedAgentIds = Set(agentsStore.detectedAgents.map { $0.id })
                            }
                            .buttonStyle(.link)
                            .font(.caption)

                            Button("None") {
                                selectedAgentIds.removeAll()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }

                        if agentsStore.detectedAgents.isEmpty {
                            Text("No agents detected. Install Claude Code, Cursor, or another AI coding tool.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(agentsStore.detectedAgents) { agent in
                                    AgentSelectionRow(
                                        agent: agent,
                                        isSelected: selectedAgentIds.contains(agent.id)
                                    ) {
                                        if selectedAgentIds.contains(agent.id) {
                                            selectedAgentIds.remove(agent.id)
                                        } else {
                                            selectedAgentIds.insert(agent.id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Summary
                    if !selectedAgentIds.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Summary")
                                .font(.headline)

                            HStack {
                                Text("Will install to:")
                                Spacer()
                                Text("\(selectedAgentIds.count) agent\(selectedAgentIds.count == 1 ? "" : "s")")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)

                            HStack {
                                Text("Location:")
                                Spacer()
                                Text(scope == .global ? "~/" : "./")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                if isInstalling {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(installProgress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(true)
                } else {
                    Button("Cancel") {
                        dismiss()
                    }

                    Spacer()

                    Button("Install") {
                        performInstall()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedAgentIds.isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Initialize with defaults
            scope = settingsStore.defaultScope
            method = settingsStore.defaultMethod
            selectedAgentIds = Set(agentsStore.detectedAgents.map { $0.id })
        }
    }

    // MARK: - Actions

    private func performInstall() {
        isInstalling = true
        installProgress = "Installing..."

        Task {
            do {
                let options = InstallOptions(
                    scope: scope,
                    method: method,
                    agentIds: Array(selectedAgentIds),
                    skillNames: [skill.name],
                    source: skill.source,
                    skipConfirmation: true
                )

                try await skillsStore.installSkill(skill, options: options)

                toastManager.success("Installed \(skill.name)")
                onComplete()
                dismiss()
            } catch {
                installProgress = ""
                isInstalling = false
                toastManager.error("Installation Failed", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Agent Selection Row

struct AgentSelectionRow: View {
    let agent: Agent
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    if agent.isDetected {
                        Text("Detected")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    InstallSheet(skill: Skill.sample()) {}
        .environment(SkillsStore())
        .environment(AgentsStore.shared)
        .environment(SettingsStore.shared)
        .environment(ToastManager())
}
