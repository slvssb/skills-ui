# Three-Pane Installed Skills UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the installed-skills app into a three-pane layout with navigational sidebar, toolbar search, and raw SKILL.md content on the right while preserving installed-skills and updates behavior.

**Architecture:** Keep the existing installed-skills/update data flows in `SkillsStore`, add lightweight UI state for section selection and search filtering, and extend the installed skill model/parser to retain filesystem paths so the raw markdown can be loaded from disk. The window composition changes to a three-pane split without reintroducing registry browsing, add/install flows, or agent filters.

**Tech Stack:** SwiftUI, Combine, Foundation, `npx skills` CLI

---

### Task 1: Extend installed skill data for raw file viewing

**Files:**
- Modify: `skills-ui/Models/Skill.swift`
- Modify: `skills-ui/Services/SkillsCLIService.swift`
- Test: `xcodebuild -scheme skills-ui -project skills-ui.xcodeproj -derivedDataPath /tmp/skills-ui-derived CODE_SIGNING_ALLOWED=NO build`

- [ ] Add a stable way to retain the installed skill directory/file path from `skills list --json`.
- [ ] Populate the installed-skill path during JSON parsing.
- [ ] Load raw `SKILL.md` content from disk for the selected skill without changing CLI-parity behavior.
- [ ] Build the app to verify the parser/model changes compile.

### Task 2: Add navigation and searchable three-pane layout

**Files:**
- Create: `skills-ui/Views/Main/Sidebar/NavigationSidebarView.swift`
- Modify: `skills-ui/Views/Main/MainWindow.swift`
- Modify: `skills-ui/Views/Main/SkillsList/SkillsListView.swift`
- Modify: `skills-ui/Store/SkillsStore.swift`
- Test: `xcodebuild -scheme skills-ui -project skills-ui.xcodeproj -derivedDataPath /tmp/skills-ui-derived CODE_SIGNING_ALLOWED=NO build`

- [ ] Introduce navigation-only sections for `All Skills` and `Updates`.
- [ ] Convert the main window to a three-pane composition.
- [ ] Move search into the top toolbar and filter only the visible middle-pane list.
- [ ] Preserve installed/update selection syncing across panes.
- [ ] Build the app to verify the layout/state changes compile.

### Task 3: Replace the right pane with raw content viewing

**Files:**
- Modify: `skills-ui/Views/Main/DetailView/SkillDetailView.swift`
- Modify: `skills-ui/Store/SkillsStore.swift`
- Test: `xcodebuild -scheme skills-ui -project skills-ui.xcodeproj -derivedDataPath /tmp/skills-ui-derived CODE_SIGNING_ALLOWED=NO build`

- [ ] Show the raw `SKILL.md` content for the selected installed skill.
- [ ] Keep installation/update metadata visible without inventing content when the file is unavailable.
- [ ] Ensure updates view still surfaces skipped/failed checks.
- [ ] Build the app to verify the detail changes compile.
