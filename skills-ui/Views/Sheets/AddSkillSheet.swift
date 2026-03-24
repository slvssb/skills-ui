//
//  AddSkillSheet.swift
//  skills-ui
//
//  Sheet for adding a skill from URL or local path
//

import SwiftUI
import UniformTypeIdentifiers

struct AddSkillSheet: View {
    @Environment(SkillsStore.self) private var skillsStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.dismiss) private var dismiss

    @State private var sourceType: SourceType = .github
    @State private var sourceURL: String = ""
    @State private var localPath: String = ""
    @State private var isDiscovering = false
    @State private var discoveredSkills: [Skill] = []
    @State private var selectedSkillIds: Set<String> = []
    @State private var showingInstallSheet = false
    @State private var skillToInstall: Skill?
    @State private var showingFilePicker = false

    enum SourceType: String, CaseIterable, Identifiable {
        case github = "GitHub"
        case gitlab = "GitLab"
        case git = "Git URL"
        case local = "Local Path"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .github: return "chevron.left.forwardslash.chevron.right"
            case .gitlab: return "chevron.left.forwardslash.chevron.right"
            case .git: return "arrow.down.circle"
            case .local: return "folder"
            }
        }

        var placeholder: String {
            switch self {
            case .github:
                return "owner/repo or https://github.com/owner/repo"
            case .gitlab:
                return "https://gitlab.com/owner/repo"
            case .git:
                return "git@github.com:owner/repo.git"
            case .local:
                return "/path/to/skill or ~/skills/my-skill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Skill")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Install skills from any source")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Source type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source Type")
                            .font(.headline)

                        HStack(spacing: 12) {
                            ForEach(SourceType.allCases) { type in
                                SourceTypeButton(
                                    type: type,
                                    isSelected: sourceType == type
                                ) {
                                    sourceType = type
                                }
                            }
                        }
                    }

                    // Source input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sourceType == .local ? "Local Path" : "Source URL")
                            .font(.headline)

                        HStack {
                            if sourceType == .local {
                                TextField(sourceType.placeholder, text: $localPath)
                                    .textFieldStyle(.roundedBorder)

                                Button("Browse...") {
                                    openFilePicker()
                                }
                            } else {
                                TextField(sourceType.placeholder, text: $sourceURL)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        // Examples
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Examples:")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            ForEach(exampleURLs, id: \.self) { url in
                                Button(url) {
                                    if sourceType == .local {
                                        localPath = url
                                    } else {
                                        sourceURL = url
                                    }
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                            }
                        }
                    }

                    // Discover button
                    Button {
                        discoverSkills()
                    } label: {
                        HStack {
                            if isDiscovering {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isDiscovering ? "Discovering..." : "Discover Skills")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(sourceString.isEmpty || isDiscovering)

                    // Discovered skills
                    if !discoveredSkills.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Available Skills")
                                    .font(.headline)

                                Spacer()

                                Text("\(discoveredSkills.count) found")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(discoveredSkills) { skill in
                                DiscoveredSkillRow(
                                    skill: skill,
                                    isSelected: selectedSkillIds.contains(skill.id)
                                ) {
                                    if selectedSkillIds.contains(skill.id) {
                                        selectedSkillIds.remove(skill.id)
                                    } else {
                                        selectedSkillIds.insert(skill.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                if !selectedSkillIds.isEmpty {
                    Button("Install Selected (\(selectedSkillIds.count))") {
                        if let firstSkillId = selectedSkillIds.first,
                           let firstSkill = discoveredSkills.first(where: { $0.id == firstSkillId }) {
                            skillToInstall = firstSkill
                            showingInstallSheet = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 550, height: 650)
        .sheet(item: $skillToInstall) { skill in
            InstallSheet(skill: skill) {
                dismiss()
            }
        }
    }

    // MARK: - Computed Properties

    private var sourceString: String {
        switch sourceType {
        case .local:
            return localPath
        default:
            return sourceURL
        }
    }

    private var exampleURLs: [String] {
        switch sourceType {
        case .github:
            return [
                "vercel-labs/agent-skills",
                "https://github.com/vercel-labs/agent-skills",
            ]
        case .gitlab:
            return [
                "https://gitlab.com/owner/repo",
            ]
        case .git:
            return [
                "git@github.com:vercel-labs/agent-skills.git",
            ]
        case .local:
            return [
                "~/skills/my-skill",
                "./my-local-skills",
            ]
        }
    }

    // MARK: - Actions

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a skill directory containing SKILL.md"

        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
        }
    }

    private func discoverSkills() {
        guard !sourceString.isEmpty else { return }

        isDiscovering = true
        discoveredSkills = []

        Task {
            do {
                let source = SkillSource.parse(from: sourceString)
                let skills = try await skillsStore.loadSkillsFromSource(source)

                await MainActor.run {
                    discoveredSkills = skills
                    // Select all by default
                    selectedSkillIds = Set(skills.map { $0.id })
                    isDiscovering = false
                }
            } catch {
                await MainActor.run {
                    isDiscovering = false
                    toastManager.error("Discovery Failed", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Source Type Button

struct SourceTypeButton: View {
    let type: AddSkillSheet.SourceType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.title3)
                Text(type.rawValue)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Discovered Skill Row

struct DiscoveredSkillRow: View {
    let skill: Skill
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(8)
            .background(isSelected ? Color.blue.opacity(0.05) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AddSkillSheet()
        .environment(SkillsStore())
        .environment(SettingsStore.shared)
        .environment(ToastManager())
}
