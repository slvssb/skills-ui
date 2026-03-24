//
//  ErrorView.swift
//  skills-ui
//
//  Inline error display component
//

import SwiftUI

/// Inline error display view
struct ErrorView: View {
    let title: String
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let retryAction = retryAction {
                Button("Try Again") {
                    retryAction()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Compact inline error banner
struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            if let onDismiss = onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Empty state view for errors
struct EmptyErrorView: View {
    let title: String
    let message: String
    let systemImage: String
    var action: (() -> Void)?
    var actionTitle: String = "Try Again"

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Previews

#Preview("Error View") {
    ErrorView(
        title: "Failed to Load Skills",
        message: "Could not connect to the skills registry. Please check your internet connection.",
        retryAction: { print("Retry") }
    )
    .padding()
}

#Preview("Error Banner") {
    ErrorBanner(
        message: "Network error occurred",
        onDismiss: { print("Dismiss") }
    )
    .padding()
}

#Preview("Empty Error View") {
    EmptyErrorView(
        title: "No Skills Found",
        message: "We couldn't find any skills matching your search.",
        systemImage: "magnifyingglass",
        action: { print("Reset") },
        actionTitle: "Clear Search"
    )
}
