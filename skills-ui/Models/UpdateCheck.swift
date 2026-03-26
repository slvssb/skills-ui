//
//  UpdateCheck.swift
//  skills-ui
//
//  Models for `npx skills check` results
//

import Foundation

struct SkillUpdate: Identifiable, Hashable, Sendable {
    let name: String
    let source: String

    var id: String { name }
}

struct SkillUpdateSkipped: Identifiable, Hashable, Sendable {
    let name: String
    let reason: String
    let updateCommand: String

    var id: String { name }
}

struct SkillUpdateError: Identifiable, Hashable, Sendable {
    let name: String
    let source: String

    var id: String { name }
}

struct UpdateCheckResult: Sendable {
    let updates: [SkillUpdate]
    let skipped: [SkillUpdateSkipped]
    let errors: [SkillUpdateError]
    let isUpToDate: Bool

    static let empty = UpdateCheckResult(
        updates: [],
        skipped: [],
        errors: [],
        isUpToDate: false
    )
}
