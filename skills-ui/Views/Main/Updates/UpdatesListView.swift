//
//  UpdatesListView.swift
//  skills-ui
//
//  View showing skills with available updates
//

import SwiftUI

struct UpdatesListView: View {
    @EnvironmentObject private var skillsStore: SkillsStore

    let onSelectSkill: (Skill) -> Void

    var body: some View {
        Group {
            if skillsStore.isCheckingUpdates {
                loadingView
            } else if !skillsStore.skillsWithUpdates.isEmpty {
                updatesListView
            } else {
                emptyStateView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var displayedSkills: [Skill] {
        skillsStore.filteredSkillsWithUpdates.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var selectedSkillID: Binding<Skill.ID?> {
        Binding(
            get: { skillsStore.selectedSkill?.id },
            set: { newValue in
                guard let selectedSkill = displayedSkills.first(where: { $0.id == newValue }) else {
                    skillsStore.selectedSkill = nil
                    return
                }

                onSelectSkill(selectedSkill)
            }
        )
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Checking for updates...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var updatesListView: some View {
        VStack(spacing: 0) {
            listHeader

            List(selection: selectedSkillID) {
                Section {
                    ForEach(displayedSkills) { skill in
                        UpdateRowView(skill: skill)
                            .tag(skill.id)
                    }
                } footer: {
                    Text("The skills CLI only supports updating all tracked skills at once.")
                }

                if !skillsStore.skippedUpdateSkills.isEmpty {
                    Section("Cannot Be Checked Automatically") {
                        ForEach(skillsStore.skippedUpdateSkills) { skipped in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(skipped.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(skipped.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(skipped.updateCommand)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if !skillsStore.failedUpdateSkills.isEmpty {
                    Section("Could Not Be Checked") {
                        ForEach(skillsStore.failedUpdateSkills) { failed in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(failed.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(failed.source)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var listHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Updates")
                    .font(.headline)
                Text("\(skillsStore.filteredSkillsWithUpdates.count) skill\(skillsStore.filteredSkillsWithUpdates.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: skillsStore.hasCheckedForUpdates ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(skillsStore.hasCheckedForUpdates ? .green : .secondary)

            Text(emptyTitle)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyTitle: String {
        if !skillsStore.hasCheckedForUpdates {
            return "No Update Check Yet"
        }
        return "All Skills Up to Date"
    }

    private var emptyMessage: String {
        if !skillsStore.hasCheckedForUpdates {
            return "Run Check Updates to compare your tracked skills against their sources."
        }

        if !skillsStore.skippedUpdateSkills.isEmpty {
            return "\(skillsStore.skippedUpdateSkills.count) skill\(skillsStore.skippedUpdateSkills.count == 1 ? "" : "s") cannot be checked automatically."
        }

        return "No updates are currently available for your tracked skills."
    }
}

struct UpdateRowView: View {
    let skill: Skill

    var body: some View {
        HStack(spacing: 8) {
            Text(skill.name)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text("Update")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 2)
    }
}
