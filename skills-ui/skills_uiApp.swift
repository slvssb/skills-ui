//
//  skills_uiApp.swift
//  skills-ui
//
//  Main app entry point
//

import SwiftUI

@main
struct skills_uiApp: App {
    @StateObject private var skillsStore = SkillsStore()
    @StateObject private var agentsStore = AgentsStore.shared
    @StateObject private var settingsStore = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(skillsStore)
                .environmentObject(agentsStore)
                .environmentObject(settingsStore)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Refresh Installed Skills") {
                    Task {
                        let scope: InstallScope = settingsStore.isGlobalScope ? .global : .project
                        await skillsStore.loadInstalledSkills(scope: scope)
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button("Check for Updates") {
                    Task {
                        await skillsStore.checkForUpdates()
                    }
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }
    }
}
