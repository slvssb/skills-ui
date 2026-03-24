//
//  ToastView.swift
//  skills-ui
//
//  Toast notification components
//

import SwiftUI

/// Toast message severity
enum ToastSeverity: Equatable {
    case success
    case error
    case warning
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

/// A toast message
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let severity: ToastSeverity
    let title: String
    let message: String?
    let duration: TimeInterval

    init(severity: ToastSeverity, title: String, message: String? = nil, duration: TimeInterval = 3.0) {
        self.severity = severity
        self.title = title
        self.message = message
        self.duration = duration
    }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manager for toast notifications
@Observable
final class ToastManager {
    var currentToast: ToastMessage?
    private var dismissTask: Task<Void, Never>?

    func show(_ toast: ToastMessage) {
        // Cancel previous dismiss task
        dismissTask?.cancel()

        // Show new toast
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = toast
        }

        // Auto dismiss
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                currentToast = nil
            }
        }
    }

    func success(_ title: String, message: String? = nil) {
        show(ToastMessage(severity: .success, title: title, message: message))
    }

    func error(_ title: String, message: String? = nil) {
        show(ToastMessage(severity: .error, title: title, message: message, duration: 5.0))
    }

    func warning(_ title: String, message: String? = nil) {
        show(ToastMessage(severity: .warning, title: title, message: message))
    }

    func info(_ title: String, message: String? = nil) {
        show(ToastMessage(severity: .info, title: title, message: message))
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = nil
        }
    }
}

/// Toast view modifier
struct ToastModifier: ViewModifier {
    @Environment(ToastManager.self) private var toastManager

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast) {
                        toastManager.dismiss()
                    }
                    .padding()
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .zIndex(1000)
                }
            }
    }
}

/// Individual toast view
struct ToastView: View {
    let toast: ToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.severity.icon)
                .font(.title2)
                .foregroundStyle(toast.severity.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let message = toast.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .frame(maxWidth: 400)
    }
}

// MARK: - View Extension

extension View {
    func toast() -> some View {
        modifier(ToastModifier())
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Content")
    }
    .frame(width: 400, height: 300)
    .toast()
    .environment(ToastManager())
}
