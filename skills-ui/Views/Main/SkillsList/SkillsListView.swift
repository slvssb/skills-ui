//
//  SkillsListView.swift
//  skills-ui
//
//  List of skills with search and filtering
//

import SwiftUI

struct SkillsListView: View {
    @Environment(SkillsStore.self) private var skillsStore
    @Environment(SettingsStore.self) private var settingsStore

    let onSelectSkill: (Skill) -> Void
    let onInstallSkill: (Skill) -> Void

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .name

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case recentlyInstalled = "Recently Installed"

        var icon: String {
            switch self {
            case .name: return "textformat"
            case .recentlyInstalled: return "clock"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(displayedSkills.count == 1 ? "1 skill" : "\(displayedSkills.count) skills")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            HStack {
                                Text(order.rawValue)
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // List
            if skillsStore.isLoadingAvailable {
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
        var skills = skillsStore.installedSkills.isEmpty ? skillsStore.availableSkills : skillsStore.installedSkills

        // Apply search filter
        if !searchText.isEmpty {
            skills = skills.filter { skill in
                skill.name.localizedCaseInsensitiveContains(searchText) ||
                skill.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sort
        switch sortOrder {
        case .name:
            skills.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .recentlyInstalled:
            let recent = settingsStore.recentlyInstalledSkills
            skills.sort { skill1, skill2 in
                let idx1 = recent.firstIndex(of: skill1.name) ?? Int.max
                let idx2 = recent.firstIndex(of: skill2.name) ?? Int.max
                return idx1 < idx2
            }
        }

        return skills
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
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Skills Found")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Try searching for skills or add a skill from a URL")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Add Skill from URL") {
                NotificationCenter.default.post(name: .showAddSkillSheet, object: nil)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var skillListView: some View {
        List(displayedSkills) { skill in
            SkillRowView(skill: skill)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectSkill(skill)
                }
                .onTapGesture(count: 2) {
                    onInstallSkill(skill)
                }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search skills...")
    }
}

// MARK: - Skill Row View

struct SkillRowView: View {
    let skill: Skill

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: skillIcon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(skill.name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    // Installed badges
                    if skill.isInstalled {
                        ForEach(skill.installedAgents.prefix(3), id: \.self) { agentId in
                            Text(agentId)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                }

                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label(skill.source.displayName, systemImage: sourceIcon)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if skill.hasUpdateAvailable {
                        Label("Update Available", systemImage: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var skillIcon: String {
        if skill.hasUpdateAvailable {
            return "sparkles.rectangle.stack.fill"
        } else if skill.isInstalled {
            return "checkmark.rectangle.stack.fill"
        }
        return "rectangle.stack"
    }

    private var iconColor: Color {
        if skill.hasUpdateAvailable {
            return .orange
        } else if skill.isInstalled {
            return .green
        }
        return .secondary
    }

    private var sourceIcon: String {
        switch skill.source {
        case .registry:
            return "globe"
        case .github:
            return "chevron.left.forwardslash.chevron.right"
        case .gitlab:
            return "chevron.left.forwardslash.chevron.right"
        case .git:
            return "arrow.down.circle"
        case .local:
            return "folder"
        }
    }
}

// MARK: - Preview

#Preview {
    SkillsListView(
        onSelectSkill: { _ in },
        onInstallSkill: { _ in }
    )
    .environment(SkillsStore())
    .environment(SettingsStore.shared)
    .frame(width: 400, height: 500)
}
