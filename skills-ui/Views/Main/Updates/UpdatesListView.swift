//
//  UpdatesListView.swift
//  skills-ui
//
//  View showing skills with available updates
//

import SwiftUI

struct UpdatesListView: View {
    @Environment(SkillsStore.self) private var skillsStore
    @Environment(ToastManager.self) private var toastManager

    @State private var isUpdating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Available Updates")
                        .font(.headline)

                    Text("\(skillsStore.updateCount) update\(skillsStore.updateCount == 1 ? "" : "s") available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if skillsStore.hasUpdatesAvailable {
                    Button {
                        updateAllSkills()
                    } label: {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Update All")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUpdating)
                }
            }
            .padding()

            Divider()

            if skillsStore.hasUpdatesAvailable {
                // List of skills with updates
                List(skillsStore.skillsWithUpdates) { skill in
                    UpdateRowView(skill: skill) {
                        updateSkill(skill)
                    }
                }
                .listStyle(.inset)
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("All Skills Up to Date")
                        .font(.headline)

                    Text("No updates are currently available for your installed skills.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }

    private func updateAllSkills() {
        isUpdating = true

        Task {
            do {
                try await skillsStore.updateAllSkills()
                toastManager.success("Updates Complete", message: "All skills have been updated.")
            } catch {
                toastManager.error("Update Failed", message: error.localizedDescription)
            }

            isUpdating = false
        }
    }

    private func updateSkill(_ skill: Skill) {
        Task {
            do {
                try await skillsStore.updateAllSkills()
                toastManager.success("Updated", message: "\(skill.name) has been updated.")
            } catch {
                toastManager.error("Update Failed", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Update Row View

struct UpdateRowView: View {
    let skill: Skill
    let onUpdate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Update available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Update") {
                onUpdate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    UpdatesListView()
        .environment(SkillsStore())
        .environment(ToastManager())
        .frame(width: 300, height: 400)
}
