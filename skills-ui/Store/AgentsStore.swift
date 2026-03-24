//
//  AgentsStore.swift
//  skills-ui
//
//  Observable store for agents state
//

import Foundation
import SwiftUI

/// Store for AI coding agents
@Observable
final class AgentsStore {
    // MARK: - State

    /// All known agents
    var allAgents: [Agent] = Agent.allAgents

    /// Detected agents on this system
    var detectedAgents: [Agent] = []

    /// Selected agents for install operations
    var selectedAgentIds: Set<String> = []

    /// Loading state
    var isLoading: Bool = false

    /// Error state
    var error: Error?

    // MARK: - Computed Properties

    /// Agents selected for installation
    var selectedAgents: [Agent] {
        allAgents.filter { selectedAgentIds.contains($0.id) }
    }

    /// Whether any agents are selected
    var hasSelectedAgents: Bool {
        !selectedAgentIds.isEmpty
    }

    // MARK: - Services

    private let cliService = SkillsCLIService.shared

    // MARK: - Singleton

    static let shared = AgentsStore()

    private init() {
        // Initialize with detected agents
        Task {
            await detectAgents()
        }
    }

    // MARK: - Actions

    /// Detect installed agents
    @MainActor
    func detectAgents() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            // Use CLI service for detection
            let cliDetected = try await cliService.detectAgents()
            detectedAgents = cliDetected

            // Merge results
            for cliAgent in cliDetected {
                if let index = allAgents.firstIndex(where: { $0.id == cliAgent.id }) {
                    allAgents[index].isDetected = true
                    allAgents[index].isInstalled = cliAgent.isInstalled
                }
            }

            // Default select all detected agents
            selectedAgentIds = Set(detectedAgents.map { $0.id })
        } catch {
            // Silently fail - keep existing detection if any
            self.error = error
        }

        isLoading = false
    }

    /// Select an agent
    func selectAgent(_ agentId: String) {
        selectedAgentIds.insert(agentId)
    }

    /// Deselect an agent
    func deselectAgent(_ agentId: String) {
        selectedAgentIds.remove(agentId)
    }

    /// Toggle agent selection
    func toggleAgent(_ agentId: String) {
        if selectedAgentIds.contains(agentId) {
            selectedAgentIds.remove(agentId)
        } else {
            selectedAgentIds.insert(agentId)
        }
    }

    /// Select all detected agents
    func selectAllDetected() {
        selectedAgentIds = Set(detectedAgents.map { $0.id })
    }

    /// Deselect all agents
    func deselectAll() {
        selectedAgentIds.removeAll()
    }

    /// Select all agents
    func selectAll() {
        selectedAgentIds = Set(allAgents.map { $0.id })
    }

    /// Check if an agent is selected
    func isSelected(_ agentId: String) -> Bool {
        selectedAgentIds.contains(agentId)
    }

    /// Get agent by ID
    func agentById(_ id: String) -> Agent? {
        allAgents.first { $0.id == id }
    }

    /// Get selected agent IDs as array
    var selectedAgentIdArray: [String] {
        Array(selectedAgentIds)
    }

    /// Get agent name by ID
    func agentNameById(_ id: String) -> String {
        agentById(id)?.name ?? id
    }

    /// Clear error
    func clearError() {
        error = nil
    }

    /// Refresh detection
    @MainActor
    func refresh() async {
        await detectAgents()
    }
}
