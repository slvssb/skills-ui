//
//  SkillsListView.swift
//  skills-ui
//
//  List of skills with search and filtering
//

import SwiftUI

struct SkillsListView: View {
    @EnvironmentObject private var skillsStore: SkillsStore

    let onSelectSkill: (Skill) -> Void

    var body: some View {
        Group {
            if skillsStore.isLoadingInstalled {
                loadingView
            } else if displayedSkills.isEmpty {
                emptyStateView
            } else {
                skillListView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Computed Properties

    private var displayedSkills: [Skill] {
        skillsStore.filteredInstalledSkills.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
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

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading skills...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Installed Skills")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("This scope does not currently have any installed skills.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var skillListView: some View {
        VStack(spacing: 0) {
            listHeader(title: "All Skills", count: displayedSkills.count)

            List(selection: selectedSkillID) {
                ForEach(displayedSkills) { skill in
                    SkillRowView(skill: skill)
                        .tag(skill.id)
                }
            }
            .listStyle(.plain)
        }
    }

    private func listHeader(title: String, count: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text("\(count) skill\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Skill Row View

struct SkillRowView: View {
    let skill: Skill

    var body: some View {
        HStack(spacing: 8) {
            Text(skill.name)
                .font(.body)
                .lineLimit(1)

            Spacer(minLength: 0)

            if skill.hasUpdateAvailable {
                Text("Update")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}
