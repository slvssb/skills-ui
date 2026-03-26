//
//  MainWindow.swift
//  skills-ui
//
//  Main application window
//

import SwiftUI

struct MainWindow: View {
    @EnvironmentObject private var skillsStore: SkillsStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var isRefreshing = false
    @State private var selectedSection: MainSection = .installed
    @State private var isUpdatingAll = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationSidebarView(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 240)
        } content: {
            contentPane
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 380)
        } detail: {
            if let selectedSkill = skillsStore.selectedSkill {
                SkillDetailView(
                    skill: selectedSkill,
                    scopeLabel: settingsStore.scopeDisplayName,
                    canUpdateAll: skillsStore.hasUpdatesAvailable,
                    onCheckUpdates: {
                        Task {
                            await skillsStore.checkForUpdates()
                        }
                    },
                    onUpdateAll: {
                        Task {
                            await updateAllSkills()
                        }
                    }
                )
            } else {
                EmptyDetailView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(selectedSection.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                refreshButton
            }

            ToolbarItem(placement: .primaryAction) {
                checkUpdatesButton
            }

            if selectedSection == .updates {
                ToolbarItem(placement: .primaryAction) {
                    updateAllButton
                }
            }
        }
        .searchable(text: $skillsStore.searchQuery, placement: .toolbar, prompt: "Search skills...")
        .onAppear {
            Task {
                await reloadInstalledSkills()
            }
        }
        .onChange(of: selectedSection) { _, _ in
            syncSelectedSkill()
        }
        .onChange(of: skillsStore.searchQuery) { _, _ in
            syncSelectedSkill()
        }
    }

    private var refreshButton: some View {
        Button {
            Task {
                await reloadInstalledSkills()
            }
        } label: {
            if isRefreshing || skillsStore.isLoadingInstalled {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .help("Refresh")
    }

    private var checkUpdatesButton: some View {
        Button {
            Task {
                await skillsStore.checkForUpdates()
            }
        } label: {
            if skillsStore.isCheckingUpdates {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
        }
        .help("Check Updates")
    }

    private var updateAllButton: some View {
        Button {
            Task {
                await updateAllSkills()
            }
        } label: {
            if isUpdatingAll {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.down.circle")
            }
        }
        .disabled(isUpdatingAll || skillsStore.isCheckingUpdates || !skillsStore.hasUpdatesAvailable)
        .help("Update All")
    }

    @ViewBuilder
    private var contentPane: some View {
        switch selectedSection {
        case .installed:
            SkillsListView { skill in
                skillsStore.selectedSkill = skill
            }
        case .updates:
            UpdatesListView { skill in
                skillsStore.selectedSkill = skill
            }
        }
    }

    private var currentScope: InstallScope {
        settingsStore.isGlobalScope ? .global : .project
    }

    private var visibleSkills: [Skill] {
        switch selectedSection {
        case .installed:
            return skillsStore.filteredInstalledSkills
        case .updates:
            return skillsStore.filteredSkillsWithUpdates
        }
    }

    @MainActor
    private func reloadInstalledSkills() async {
        isRefreshing = true
        await skillsStore.loadInstalledSkills(scope: currentScope)
        syncSelectedSkill()
        isRefreshing = false
    }

    @MainActor
    private func updateAllSkills() async {
        isUpdatingAll = true
        defer { isUpdatingAll = false }

        do {
            try await skillsStore.updateAllSkills(scope: currentScope)
            selectedSection = .updates
            syncSelectedSkill()
        } catch {
            skillsStore.error = error
        }
    }

    private func syncSelectedSkill() {
        guard let selectedSkill = skillsStore.selectedSkill else {
            return
        }

        let normalizedSelectedName = selectedSkill.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        skillsStore.selectedSkill = visibleSkills.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedSelectedName
        }
    }
}

enum MainSection: String, CaseIterable, Identifiable {
    case installed
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .installed:
            return "All Skills"
        case .updates:
            return "Updates"
        }
    }
}

// MARK: - Empty Detail View

struct EmptyDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select a skill")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose a skill to inspect its status, actions, and source.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
