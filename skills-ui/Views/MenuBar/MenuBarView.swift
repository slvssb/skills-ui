//
//  MenuBarView.swift
//  skills-ui
//
//  Menu bar popover content
//

import SwiftUI

struct MenuBarView: View {
    @Environment(SkillsStore.self) private var skillsStore
    @Environment(AgentsStore.self) private var agentsStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.openWindow) private var openWindow

    @State private var searchText = ""
    @State private var isSearching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with scope indicator
            headerView

            Divider()

            // Quick search
            quickSearchView
                .padding()

            Divider()

            // Recent skills
            if !recentlyInstalledSkills.isEmpty {
                recentSkillsSection
                Divider()
            }

            // Actions
            actionsSection
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Skills")
                    .font(.headline)
                Text(settingsStore.scopeDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Update badge
            if skillsStore.hasUpdatesAvailable {
                Text("\(skillsStore.updateCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: - Quick Search

    private var quickSearchView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search skills...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        performSearch()
                    }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Search results
            if !searchText.isEmpty {
                searchResultsView
            }
        }
    }

    @ViewBuilder
    private var searchResultsView: some View {
        let results = filteredSkills

        if results.isEmpty {
            Text("No skills found")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(results.prefix(5)) { skill in
                        QuickSkillRow(skill: skill) {
                            quickInstall(skill: skill)
                        }
                    }
                }
            }
            .frame(maxHeight: 150)
        }
    }

    // MARK: - Recent Skills

    private var recentSkillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently Installed")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            ForEach(recentlyInstalledSkills.prefix(3)) { skill in
                QuickSkillRow(skill: skill) {
                    // Open in main window
                    skillsStore.selectedSkill = skill
                    openWindow(id: "main")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 0) {
            Button {
                openWindow(id: "main")
            } label: {
                Label("Open Skills Window", systemImage: "rectangle.stack")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if skillsStore.hasUpdatesAvailable {
                Button {
                    Task {
                        try? await skillsStore.updateAllSkills()
                    }
                } label: {
                    Label("Update All (\(skillsStore.updateCount))", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Divider()

            Button {
                // Check for updates
                Task {
                    await skillsStore.checkForUpdates()
                }
            } label: {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Skills", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Computed Properties

    private var filteredSkills: [Skill] {
        if searchText.isEmpty {
            return skillsStore.availableSkills
        }
        return skillsStore.availableSkills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(searchText) ||
            skill.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var recentlyInstalledSkills: [Skill] {
        let recentNames = settingsStore.recentlyInstalledSkills
        return recentNames.compactMap { name in
            skillsStore.installedSkills.first { $0.name == name } ??
            skillsStore.availableSkills.first { $0.name == name }
        }
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        isSearching = true
        Task {
            await skillsStore.search(query: searchText)
            isSearching = false
        }
    }

    private func quickInstall(skill: Skill) {
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
            } catch {
                // Error is handled by store
            }
        }
    }
}

// MARK: - Quick Skill Row

struct QuickSkillRow: View {
    let skill: Skill
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.subheadline)
                        .lineLimit(1)

                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if skill.isInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
