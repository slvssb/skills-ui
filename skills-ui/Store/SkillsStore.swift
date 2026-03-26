//
//  SkillsStore.swift
//  skills-ui
//
//  Observable store for skills state
//

import Foundation
import Combine
import SwiftUI

/// Main store for skills data
final class SkillsStore: ObservableObject {
    // MARK: - State

    /// Installed skills (from skills list)
    @Published var installedSkills: [Skill] = []

    /// Currently selected skill for detail view
    @Published var selectedSkill: Skill?

    /// Skills with updates available according to `skills check`
    @Published var skillsWithUpdates: [Skill] = []

    /// Skills that the CLI cannot check automatically
    @Published var skippedUpdateSkills: [SkillUpdateSkipped] = []

    /// Skills that failed update checks
    @Published var failedUpdateSkills: [SkillUpdateError] = []

    /// Loading states
    @Published var isLoadingInstalled: Bool = false
    @Published var isCheckingUpdates: Bool = false

    /// Whether an explicit update check has completed in this session
    @Published var hasCheckedForUpdates: Bool = false

    /// Error state
    @Published var error: Error?

    @Published var searchQuery: String = ""

    // MARK: - Computed

    var hasUpdatesAvailable: Bool {
        !skillsWithUpdates.isEmpty
    }

    var updateCount: Int {
        skillsWithUpdates.count
    }

    var filteredInstalledSkills: [Skill] {
        filter(skills: installedSkills)
    }

    var filteredSkillsWithUpdates: [Skill] {
        filter(skills: skillsWithUpdates)
    }

    // MARK: - Services

    private let cliService = SkillsCLIService.shared

    // MARK: - Actions

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
                applyUpdateMarkers()
                syncSelectedSkill()
            } else {
                error = result.error
            }
        } catch {
            self.error = error
        }

        isLoadingInstalled = false
    }

    /// Clear error
    func clearError() {
        error = nil
    }

    /// Check for skill updates using `npx skills check`
    @MainActor
    func checkForUpdates() async {
        guard !isCheckingUpdates else { return }

        isCheckingUpdates = true
        error = nil

        do {
            let result = try await cliService.checkUpdates()
            if result.succeeded {
                let summary = SkillsCLIParser.parseUpdateCheckOutput(result.standardOutput)
                skippedUpdateSkills = summary.skipped
                failedUpdateSkills = summary.errors
                hasCheckedForUpdates = true
                applyUpdateMarkers(using: Set(summary.updates.map(\.name)))
                syncSelectedSkill()
            } else {
                error = result.error
            }
        } catch {
            self.error = error
        }

        isCheckingUpdates = false
    }

    /// Update all tracked skills using `npx skills update`
    @MainActor
    func updateAllSkills(scope: InstallScope = .project) async throws {
        let result = try await cliService.updateSkills()

        if result.failed {
            throw result.error ?? CLIError(
                exitCode: result.exitCode,
                message: "Update failed",
                command: "skills",
                arguments: ["update"]
            )
        }

        await loadInstalledSkills(scope: scope)
        await checkForUpdates()
    }

    // MARK: - Private Helpers

    private func normalizedSkillName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func filter(skills: [Skill]) -> [Skill] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return skills }

        return skills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(trimmedQuery)
                || (skill.markdownContent?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
                || skill.installedAgents.contains(where: { $0.localizedCaseInsensitiveContains(trimmedQuery) })
        }
    }

    private func applyUpdateMarkers(using updateNames: Set<String>? = nil) {
        let normalizedUpdates = updateNames ?? Set(skillsWithUpdates.map { normalizedSkillName($0.name) })

        installedSkills = installedSkills.map { skill in
            let hasUpdate = normalizedUpdates.contains(normalizedSkillName(skill.name))
            var updatedSkill = skill
            updatedSkill.installStatus = skill.installStatus.mapValues { status in
                switch (status, hasUpdate) {
                case (.installed, true):
                    return .updateAvailable(currentVersion: nil, newVersion: nil)
                case (.updateAvailable, false):
                    return .installed(version: nil)
                default:
                    return status
                }
            }
            return updatedSkill
        }

        skillsWithUpdates = installedSkills.filter { normalizedUpdates.contains(normalizedSkillName($0.name)) }
    }

    private func syncSelectedSkill() {
        guard let selectedSkill else { return }

        let selectedName = normalizedSkillName(selectedSkill.name)
        self.selectedSkill = installedSkills.first {
            normalizedSkillName($0.name) == selectedName
        }
    }
}
