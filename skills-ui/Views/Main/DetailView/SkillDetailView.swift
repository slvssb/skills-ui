//
//  SkillDetailView.swift
//  skills-ui
//
//  Detail view for a single skill
//

import AppKit
import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    let scopeLabel: String
    let canUpdateAll: Bool
    let onCheckUpdates: () -> Void
    let onUpdateAll: () -> Void

    @State private var isSourceExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                summarySection
                actionsSection
                metadataSection
                sourceSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(skill.name)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(skill.name)
                .font(.title2)
                .fontWeight(.semibold)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                InspectorBadge(
                    title: statusTitle,
                    systemImage: skill.hasUpdateAvailable ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill",
                    tint: skill.hasUpdateAvailable ? .orange : .secondary
                )

                if !skill.installedAgents.isEmpty {
                    InspectorBadge(
                        title: "\(skill.installedAgents.count) agent\(skill.installedAgents.count == 1 ? "" : "s")",
                        systemImage: "person.2.fill",
                        tint: .secondary
                    )
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Actions")

            HStack(alignment: .center, spacing: 10) {
                Button("Check Updates", action: onCheckUpdates)
                    .buttonStyle(.borderedProminent)

                Button("Update All", action: onUpdateAll)
                    .buttonStyle(.bordered)
                    .disabled(!canUpdateAll)

                Button("Reveal in Finder", action: revealInFinder)
                    .buttonStyle(.bordered)
                    .disabled(resolvedSkillURL == nil)

                Button("Copy Path", action: copyPath)
                    .buttonStyle(.bordered)
                    .disabled(resolvedSkillURL == nil)
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Overview")

            VStack(alignment: .leading, spacing: 0) {
                InspectorRow(label: "Status", value: statusTitle)
                InspectorRow(label: "Scope", value: scopeLabel)
                InspectorRow(label: "Source", value: sourceSummary)
                InspectorRow(label: "Installed For", value: agentsSummary)
                InspectorRow(label: "Path", value: resolvedSkillPath, isMonospaced: true, allowsSelection: true, showDivider: false)
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Source")

            DisclosureGroup(isExpanded: $isSourceExpanded) {
                Group {
                    if let markdownContent = skill.markdownContent, !markdownContent.isEmpty {
                        PlainTextSkillContentView(text: markdownContent)
                            .frame(minHeight: 240)
                    } else {
                        unavailableContentView
                    }
                }
                .padding(.top, 10)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Raw SKILL.md")
                        .font(.headline)

                    Text("Keep the source close, but secondary to management.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var unavailableContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SKILL.md unavailable")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("The installed skill content could not be read from disk.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(resolvedSkillPath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var summaryText: String {
        if skill.hasUpdateAvailable {
            return "Update attention is needed for this installed skill."
        }

        return "Installed skill details and management actions."
    }

    private var statusTitle: String {
        skill.hasUpdateAvailable ? "Update available" : "Installed"
    }

    private var sourceSummary: String {
        if case .registry(let url) = skill.source, url == "installed" {
            return "Local installed skill"
        }

        return skill.source.displayName
    }

    private var agentsSummary: String {
        let agents = skill.installedAgents.sorted()
        return agents.isEmpty ? "No linked agents" : agents.joined(separator: ", ")
    }

    private var resolvedSkillPath: String {
        skill.resolvedSkillFilePath ?? skill.installedPath ?? "Unavailable"
    }

    private var resolvedSkillURL: URL? {
        guard let path = skill.resolvedSkillFilePath ?? skill.installedPath else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }

    private func revealInFinder() {
        guard let url = resolvedSkillURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyPath() {
        guard resolvedSkillURL != nil else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resolvedSkillPath, forType: .string)
    }
}

private struct InspectorBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct InspectorRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    var allowsSelection: Bool = false
    var showDivider: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .leading)

                valueView
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showDivider {
                Divider()
                    .padding(.leading, 14)
            }
        }
    }

    private var valueFont: Font {
        isMonospaced ? .system(.caption, design: .monospaced) : .body
    }

    @ViewBuilder
    private var valueView: some View {
        if allowsSelection {
            Text(value)
                .font(valueFont)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        } else {
            Text(value)
                .font(valueFont)
                .foregroundStyle(.primary)
        }
    }
}

private struct PlainTextSkillContentView: NSViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.usesPredominantAxisScrolling = true

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.allowsUndo = false
        textView.textContainerInset = NSSize(width: 0, height: 12)
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        guard context.coordinator.text != text else {
            return
        }

        context.coordinator.text = text
        textView.string = text
    }

    final class Coordinator {
        var text: String

        init(text: String) {
            self.text = text
        }
    }
}
