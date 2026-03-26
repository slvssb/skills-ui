//
//  NavigationSidebarView.swift
//  skills-ui
//
//  Minimal navigation sidebar for installed skills UI
//

import SwiftUI

struct NavigationSidebarView: View {
    @EnvironmentObject private var skillsStore: SkillsStore

    @Binding var selectedSection: MainSection

    var body: some View {
        List(selection: $selectedSection) {
            Section("Library") {
                Label("All Skills", systemImage: "tray.full")
                    .tag(MainSection.installed)
                    .badge(skillsStore.installedSkills.count)

                Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                    .tag(MainSection.updates)
                    .badge(skillsStore.updateCount)
            }
        }
        .listStyle(.sidebar)
    }
}
