//
//  MainWindow.swift
//  skills-ui
//
//  Main application window
//

import SwiftUI

struct MainWindow: View {
    @Environment(SkillsStore.self) private var skillsStore
    @Environment(AgentsStore.self) private var agentsStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ToastManager.self) private var toastManager

    @State private var searchText = ""
    @State private var showingAddSkillSheet = false
    @State private var showingInstallSheet = false
    @State private var skillToInstall: Skill?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                // Toolbar
                toolbarView

                Divider()

                // Main content
                HSplitView {
                    // Skills list
                    SkillsListView(
                        onSelectSkill: { skill in
                            skillsStore.selectedSkill = skill
                        },
                        onInstallSkill: { skill in
                            skillToInstall = skill
                            showingInstallSheet = true
                        }
                    )
                    .frame(minWidth: 300, idealWidth: 400)

                    // Detail view
                    if let selectedSkill = skillsStore.selectedSkill {
                        SkillDetailView(skill: selectedSkill)
                            .frame(minWidth: 300, idealWidth: 400)
                    } else {
                        EmptyDetailView()
                            .frame(minWidth: 300, idealWidth: 400)
                    }
                }
            }
        }
        .navigationTitle(settingsStore.scopeDisplayName)
        .toolbar {
            ToolbarItemGroup {
                // Scope picker
                Menu {
                    Button("Global") {
                        settingsStore.useGlobalScope()
                        Task { await skillsStore.loadInstalledSkills(scope: .global) }
                    }
                    Divider()
                    Button("Choose Project...") {
                        NotificationCenter.default.post(name: .showProjectPicker, object: nil)
                    }
                    if !settingsStore.recentProjects.isEmpty {
                        Divider()
                        ForEach(settingsStore.recentProjects, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                settingsStore.setCurrentProject(url)
                                Task { await skillsStore.loadInstalledSkills(scope: .project) }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        Text(settingsStore.scopeDisplayName)
                    }
                }

                // Search field
                ToolbarSearchField(text: $searchText) {
                    Task {
                        await skillsStore.search(query: searchText)
                    }
                }

                // Refresh button
                Button {
                    Task {
                        await skillsStore.refresh()
                        toastManager.success("Refreshed", message: "Skills data has been updated")
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh skills")

                // Updates button
                if skillsStore.hasUpdatesAvailable {
                    Button {
                        NotificationCenter.default.post(name: .showUpdatesAvailable, object: nil)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("\(skillsStore.updateCount)")
                        }
                        .foregroundStyle(.orange)
                    }
                    .help("Updates available")
                }
            }
        }
        .sheet(isPresented: $showingAddSkillSheet) {
            AddSkillSheet()
        }
        .sheet(item: $skillToInstall) { skill in
            InstallSheet(skill: skill) {
                showingInstallSheet = false
                skillToInstall = nil
            }
        }
        .toast()
        .onAppear {
            Task {
                await skillsStore.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddSkillSheet)) { _ in
            showingAddSkillSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showUpdatesAvailable)) { _ in
            // Could show an updates sheet
        }
    }

    // MARK: - Toolbar View

    private var toolbarView: some View {
        HStack {
            // Left side info
            HStack(spacing: 8) {
                if skillsStore.isLoadingInstalled || skillsStore.isLoadingAvailable {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Text("\(skillsStore.filteredInstalledSkills.count) installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right side actions
            HStack(spacing: 12) {
                Button {
                    showingAddSkillSheet = true
                } label: {
                    Label("Add Skill", systemImage: "plus")
                }

                if skillsStore.hasUpdatesAvailable {
                    Button("Update All") {
                        Task {
                            do {
                                try await skillsStore.updateAllSkills()
                                toastManager.success("Skills Updated")
                            } catch {
                                toastManager.error("Update Failed", message: error.localizedDescription)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Toolbar Search Field

struct ToolbarSearchField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.delegate = context.coordinator
        searchField.bezelStyle = .roundedBezel
        searchField.isBezeled = true
        searchField.drawsBackground = true
        searchField.placeholderString = "Search skills..."
        searchField.focusRingType = .exterior
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        let parent: ToolbarSearchField

        init(_ parent: ToolbarSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let searchField = obj.object as? NSSearchField else { return }
            parent.text = searchField.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onSubmit()
        }

        func searchFieldDidStartSearching(_ sender: NSSearchField) {
            // Search started
        }

        func searchFieldDidEndSearching(_ sender: NSSearchField) {
            parent.text = ""
            parent.onSubmit()
        }
    }
}

// MARK: - Empty Detail View

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Select a Skill")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Choose a skill from the list to view details and installation options")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    MainWindow()
        .environment(SkillsStore())
        .environment(AgentsStore.shared)
        .environment(SettingsStore.shared)
        .environment(ToastManager())
        .frame(width: 1000, height: 700)
}
