//
//  SkillsStore.swift
//  skills-ui
//
//  Observable store for skills state
//

import Foundation
import SwiftUI

/// Main store for skills data
@Observable
final class SkillsStore {
    // MARK: - State

    /// All available skills (from registry)
    var availableSkills: [Skill] = []

    /// Installed skills (from skills list)
    var installedSkills: [Skill] = []

    /// Skills with updates available
    var skillsWithUpdates: [Skill] = []

    /// Currently selected skill for detail view
    var selectedSkill: Skill?

    /// Search query
    var searchQuery: String = ""

    /// Loading states
    var isLoadingAvailable: Bool = false
    var isLoadingInstalled: Bool = false
    var isCheckingUpdates: Bool = false

    /// Error state
    var error: Error?

    // MARK: - Computed Properties

    /// Filtered available skills based on search
    var filteredAvailableSkills: [Skill] {
        if searchQuery.isEmpty {
            return availableSkills
        }
        return availableSkills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(searchQuery) ||
            skill.description.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    /// Filtered installed skills based on search
    var filteredInstalledSkills: [Skill] {
        if searchQuery.isEmpty {
            return installedSkills
        }
        return installedSkills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(searchQuery) ||
            skill.description.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    /// Number of skills with updates
    var updateCount: Int {
        skillsWithUpdates.count
    }

    /// Whether any updates are available
    var hasUpdatesAvailable: Bool {
        !skillsWithUpdates.isEmpty
    }

    // MARK: - Services

    private let cliService = SkillsCLIService.shared

    // MARK: - Actions

    /// Load available skills from registry
    @MainActor
    func loadAvailableSkills() async {
        guard !isLoadingAvailable else { return }

        isLoadingAvailable = true
        error = nil

        do {
            let result = try await cliService.findSkills(query: nil)
            if result.succeeded {
                availableSkills = SkillsCLIParser.parseFindOutput(result.standardOutput)
            } else {
                error = result.error
            }
        } catch {
            self.error = error
        }

        isLoadingAvailable = false
    }

    /// Load installed skills
    @MainActor
    func loadInstalledSkills(scope: InstallScope = .project) async {
        guard !isLoadingInstalled else { return }

        isLoadingInstalled = true
        error = nil

        do {
            let result = try await cliService.listSkills(scope: scope)
            if result.succeeded {
                installedSkills = SkillsCLIParser.parseListOutput(result.standardOutput)
            } else {
                error = result.error
            }
        } catch {
            self.error = error
        }

        isLoadingInstalled = false
    }

    /// Check for skill updates
    @MainActor
    func checkForUpdates() async {
        guard !isCheckingUpdates else { return }

        isCheckingUpdates = true

        do {
            let result = try await cliService.checkUpdates()
            if result.succeeded {
                let updates = SkillsCLIParser.parseUpdateCheckOutput(result.standardOutput)
                // Update skillsWithUpdates based on parsed data
                skillsWithUpdates = installedSkills.filter { installed in
                    updates.contains { $0.name == installed.name }
                }
            }
        } catch {
            // Silently fail update checks
            print("Update check failed: \(error)")
        }

        isCheckingUpdates = false
    }

    /// Search for skills
    @MainActor
    func search(query: String) async {
        searchQuery = query

        if query.isEmpty {
            return
        }

        isLoadingAvailable = true

        do {
            let result = try await cliService.findSkills(query: query)
            if result.succeeded {
                availableSkills = SkillsCLIParser.parseFindOutput(result.standardOutput)
            }
        } catch {
            self.error = error
        }

        isLoadingAvailable = false
    }

    /// Install a skill
    @MainActor
    func installSkill(_ skill: Skill, options: InstallOptions) async throws {
        var installOptions = options
        installOptions.skillNames = [skill.name]

        let result = try await cliService.installSkills(options: installOptions)

        if result.failed {
            throw result.error ?? CLIError(
                exitCode: result.exitCode,
                message: "Installation failed",
                command: "skills",
                arguments: []
            )
        }

        // Refresh installed skills
        await loadInstalledSkills()

        // Add to recently installed
        SettingsStore.shared.addRecentlyInstalledSkill(skill)
    }

    /// Remove a skill
    @MainActor
    func removeSkill(_ skill: Skill, options: RemoveOptions) async throws {
        var removeOptions = options
        removeOptions.skillNames = [skill.name]

        let result = try await cliService.removeSkills(options: removeOptions)

        if result.failed {
            throw result.error ?? CLIError(
                exitCode: result.exitCode,
                message: "Removal failed",
                command: "skills",
                arguments: []
            )
        }

        // Refresh installed skills
        await loadInstalledSkills()
    }

    /// Update all skills
    @MainActor
    func updateAllSkills() async throws {
        let result = try await cliService.updateSkills()

        if result.failed {
            throw result.error ?? CLIError(
                exitCode: result.exitCode,
                message: "Update failed",
                command: "skills",
                arguments: []
            )
        }

        // Refresh data
        await loadInstalledSkills()
        await checkForUpdates()
    }

    /// Load skills from a specific source
    @MainActor
    func loadSkillsFromSource(_ source: SkillSource) async throws -> [Skill] {
        let result = try await cliService.listAvailableSkills(source: source)

        if result.failed {
            throw result.error ?? CLIError(
                exitCode: result.exitCode,
                message: "Failed to list skills from source",
                command: "skills",
                arguments: []
            )
        }

        return SkillsCLIParser.parseAvailableSkillsOutput(result.standardOutput, source: source)
    }

    /// Clear error
    func clearError() {
        error = nil
    }

    /// Refresh all data
    @MainActor
    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAvailableSkills() }
            group.addTask { await self.loadInstalledSkills() }
            group.addTask { await self.checkForUpdates() }
        }
    }
}
