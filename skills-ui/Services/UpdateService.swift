//
//  UpdateService.swift
//  skills-ui
//
//  Background service for checking skill updates
//

import Foundation
import Combine
import UserNotifications

/// Service for periodically checking for skill updates
@Observable
final class UpdateService {
    // MARK: - Singleton

    static let shared = UpdateService()

    // MARK: - Properties

    /// Whether an update check is in progress
    var isChecking: Bool = false

    /// Last update check time
    var lastCheckTime: Date?

    /// Skills with available updates
    var skillsWithUpdates: [Skill] = []

    /// Whether updates are available
    var hasUpdatesAvailable: Bool {
        !skillsWithUpdates.isEmpty
    }

    /// Number of updates available
    var updateCount: Int {
        skillsWithUpdates.count
    }

    // MARK: - Private

    private let cliService = SkillsCLIService.shared
    private var timer: Timer?
    private let settingsStore = SettingsStore.shared

    // MARK: - Init

    private init() {
        // Restore last check time
        lastCheckTime = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date

        // Start periodic checking
        startPeriodicCheck()
    }

    // MARK: - Public Methods

    /// Check for updates now
    @MainActor
    func checkForUpdates() async {
        guard !isChecking else { return }

        isChecking = true

        do {
            let result = try await cliService.checkUpdates()
            if result.succeeded {
                let updates = SkillsCLIParser.parseUpdateCheckOutput(result.standardOutput)
                skillsWithUpdates = updates
                lastCheckTime = Date()
                UserDefaults.standard.set(lastCheckTime, forKey: "lastUpdateCheck")

                // Post notification if updates found
                if !updates.isEmpty {
                    postUpdateNotification(count: updates.count)
                }
            }
        } catch {
            print("Update check failed: \(error)")
        }

        isChecking = false
    }

    /// Update all skills with available updates
    @MainActor
    func updateAllSkills() async throws {
        let result = try await cliService.updateSkills()

        if result.failed {
            throw result.error ?? CLIError(
                exitCode: result.exitCode,
                message: "Update failed",
                command: "skills",
                arguments: ["update"]
            )
        }

        // Clear updates list
        skillsWithUpdates = []
        lastCheckTime = Date()
        UserDefaults.standard.set(lastCheckTime, forKey: "lastUpdateCheck")
    }

    /// Start periodic update checking
    func startPeriodicCheck() {
        stopPeriodicCheck()

        let interval = settingsStore.updateCheckInterval

        // Don't schedule if interval is infinity (disabled)
        guard interval.isFinite else { return }

        // Convert hours to seconds
        let intervalSeconds = interval * 3600

        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdates()
            }
        }
    }

    /// Stop periodic update checking
    func stopPeriodicCheck() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private Methods

    private func postUpdateNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Skills Updates Available"
        content.body = "\(count) skill\(count == 1 ? "" : "s") have updates available."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "skills-update-check",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
