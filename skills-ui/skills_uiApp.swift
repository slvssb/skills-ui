//
//  skills_uiApp.swift
//  skills-ui
//
//  Main app entry point
//

import SwiftUI

@main
struct skills_uiApp: App {
    @State private var skillsStore = SkillsStore()
    @State private var agentsStore = AgentsStore.shared
    @State private var settingsStore = SettingsStore.shared
    @State private var toastManager = ToastManager()

    var body: some Scene {
        // Main Window
        WindowGroup {
            MainWindow()
                .environment(skillsStore)
                .environment(agentsStore)
                .environment(settingsStore)
                .environment(toastManager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1000, height: 700)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("Add Skill from URL...") {
                    NotificationCenter.default.post(name: .showAddSkillSheet, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open Project...") {
                    NotificationCenter.default.post(name: .showProjectPicker, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Refresh Skills") {
                    Task {
                        await skillsStore.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            // View menu
            CommandGroup(after: .toolbar) {
                Button("Check for Updates") {
                    Task {
                        await skillsStore.checkForUpdates()
                        if skillsStore.hasUpdatesAvailable {
                            NotificationCenter.default.post(name: .showUpdatesAvailable, object: nil)
                        }
                    }
                }
                .keyboardShortcut("u", modifiers: .command)
            }
        }

        // Menu Bar Extra
        MenuBarExtra("Skills", systemImage: menuBarIcon) {
            MenuBarView()
                .environment(skillsStore)
                .environment(agentsStore)
                .environment(settingsStore)
                .environment(toastManager)
        }
        .menuBarExtraStyle(.window)

        // Settings
        Settings {
            SettingsView()
                .environment(settingsStore)
                .environment(agentsStore)
                .frame(width: 500, height: 400)
        }
    }

    /// Menu bar icon with update badge
    private var menuBarIcon: String {
        if skillsStore.hasUpdatesAvailable {
            return "sparkles.rectangle.stack.fill"
        }
        return "rectangle.stack"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showAddSkillSheet = Notification.Name("showAddSkillSheet")
    static let showProjectPicker = Notification.Name("showProjectPicker")
    static let showUpdatesAvailable = Notification.Name("showUpdatesAvailable")
    static let skillInstalled = Notification.Name("skillInstalled")
    static let skillRemoved = Notification.Name("skillRemoved")
}
