//
//  SettingsStore.swift
//  skills-ui
//
//  Observable store for app settings
//

import Foundation
import Combine
import SwiftUI

/// Store for app settings and preferences
final class SettingsStore: ObservableObject {
    // MARK: - State

    /// Current project path (nil = global scope)
    @Published var currentProjectPath: URL?

    /// Recent projects
    @Published var recentProjects: [URL] = []

    /// Recently installed skills (stored as skill names)
    @Published var recentlyInstalledSkills: [String] = []

    /// Default installation scope
    @Published var defaultScope: InstallScope = .project

    /// Default installation method
    @Published var defaultMethod: InstallMethod = .symlink

    /// Show internal skills
    @Published var showInternalSkills: Bool = false

    /// Background update check interval (hours)
    @Published var updateCheckInterval: Double = 6.0

    /// Last update check time
    @Published var lastUpdateCheck: Date?

    /// Whether the CLI is available
    @Published var isCLIAvailable: Bool = false

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let currentProjectPath = "currentProjectPath"
        static let recentProjects = "recentProjects"
        static let recentlyInstalledSkills = "recentlyInstalledSkills"
        static let defaultScope = "defaultScope"
        static let defaultMethod = "defaultMethod"
        static let showInternalSkills = "showInternalSkills"
        static let updateCheckInterval = "updateCheckInterval"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    // MARK: - Singleton

    static let shared = SettingsStore()

    private init() {
        loadFromUserDefaults()
        checkCLIAvailability()
    }

    // MARK: - Computed Properties

    /// Whether we're in global scope
    var isGlobalScope: Bool {
        currentProjectPath == nil
    }

    /// Scope display name
    var scopeDisplayName: String {
        if let path = currentProjectPath {
            return path.lastPathComponent
        }
        return "Global"
    }

    // MARK: - Actions

    /// Set current project
    func setCurrentProject(_ url: URL?) {
        currentProjectPath = url
        if let url = url {
            addRecentProject(url)
        }
        saveToUserDefaults()
    }

    /// Switch to global scope
    func useGlobalScope() {
        currentProjectPath = nil
        saveToUserDefaults()
    }

    /// Add a recent project
    func addRecentProject(_ url: URL) {
        // Remove if already exists
        recentProjects.removeAll { $0 == url }
        // Add to front
        recentProjects.insert(url, at: 0)
        // Keep only last 10
        if recentProjects.count > 10 {
            recentProjects = Array(recentProjects.prefix(10))
        }
        saveToUserDefaults()
    }

    /// Remove a recent project
    func removeRecentProject(_ url: URL) {
        recentProjects.removeAll { $0 == url }
        saveToUserDefaults()
    }

    /// Clear recent projects
    func clearRecentProjects() {
        recentProjects.removeAll()
        saveToUserDefaults()
    }

    /// Add a recently installed skill
    func addRecentlyInstalledSkill(_ skill: Skill) {
        let skillId = skill.name
        // Remove if already exists
        recentlyInstalledSkills.removeAll { $0 == skillId }
        // Add to front
        recentlyInstalledSkills.insert(skillId, at: 0)
        // Keep only last 5
        if recentlyInstalledSkills.count > 5 {
            recentlyInstalledSkills = Array(recentlyInstalledSkills.prefix(5))
        }
        saveToUserDefaults()
    }

    /// Clear recently installed skills
    func clearRecentlyInstalledSkills() {
        recentlyInstalledSkills.removeAll()
        saveToUserDefaults()
    }

    /// Update last update check time
    func setLastUpdateCheck(_ date: Date = Date()) {
        lastUpdateCheck = date
        saveToUserDefaults()
    }

    /// Check if update check is due
    func isUpdateCheckDue() -> Bool {
        guard let lastCheck = lastUpdateCheck else {
            return true
        }
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        return hoursSinceLastCheck >= updateCheckInterval
    }

    /// Check CLI availability
    func checkCLIAvailability() {
        Task {
            isCLIAvailable = await SkillsCLIService.shared.checkAvailability()
        }
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard

        if let pathString = defaults.string(forKey: Keys.currentProjectPath) {
            currentProjectPath = URL(fileURLWithPath: pathString)
        }

        if let projectPaths = defaults.stringArray(forKey: Keys.recentProjects) {
            recentProjects = projectPaths.map { URL(fileURLWithPath: $0) }
        }

        recentlyInstalledSkills = defaults.stringArray(forKey: Keys.recentlyInstalledSkills) ?? []

        if let scopeString = defaults.string(forKey: Keys.defaultScope),
           let scope = InstallScope(rawValue: scopeString) {
            defaultScope = scope
        }

        if let methodString = defaults.string(forKey: Keys.defaultMethod),
           let method = InstallMethod(rawValue: methodString) {
            defaultMethod = method
        }

        showInternalSkills = defaults.bool(forKey: Keys.showInternalSkills)
        updateCheckInterval = defaults.double(forKey: Keys.updateCheckInterval)
        if updateCheckInterval == 0 {
            updateCheckInterval = 6.0
        }

        if let lastCheck = defaults.object(forKey: Keys.lastUpdateCheck) as? Date {
            lastUpdateCheck = lastCheck
        }
    }

    private func saveToUserDefaults() {
        let defaults = UserDefaults.standard

        if let path = currentProjectPath {
            defaults.set(path.path, forKey: Keys.currentProjectPath)
        } else {
            defaults.removeObject(forKey: Keys.currentProjectPath)
        }

        defaults.set(recentProjects.map { $0.path }, forKey: Keys.recentProjects)
        defaults.set(recentlyInstalledSkills, forKey: Keys.recentlyInstalledSkills)
        defaults.set(defaultScope.rawValue, forKey: Keys.defaultScope)
        defaults.set(defaultMethod.rawValue, forKey: Keys.defaultMethod)
        defaults.set(showInternalSkills, forKey: Keys.showInternalSkills)
        defaults.set(updateCheckInterval, forKey: Keys.updateCheckInterval)

        if let lastCheck = lastUpdateCheck {
            defaults.set(lastCheck, forKey: Keys.lastUpdateCheck)
        }
    }
}
