# PRD: Scrum Vocabulary Redesign

## 1. Introduction / Overview

takt currently uses non-standard vocabulary — `PRD`, `stories.json`, `/takt-prd` — that has no grounding in Scrum or Agile frameworks. This creates unnecessary friction for practitioners who already think in Scrum terms. This feature renames artifacts, commands, and skills to align with standard Scrum vocabulary, and introduces two new skills (`/epic` and `/takt`) to complete the workflow hierarchy.

---

## 2. Goals

- Replace all takt-specific vocabulary with standard Scrum terms
- Introduce a full skill hierarchy: Epic → Feature → Sprint → Execute
- Make `/takt` the single entry point for the full planning-to-execution flow
- Ensure the `/epic` skill works in any project regardless of `CLAUDE.md` quality

---

## 3. User Stories

### US-001: Rename stories.json to sprint.json

**Description:** As a takt user, I want the executable story file to be called `sprint.json` so that the terminology matches standard Scrum vocabulary.

**Acceptance Criteria:**
- [ ] All references to `stories.json` in prompt files (run.md, worker.md, verifier.md, debug.md, retro.md, reviewer.md) are updated to `sprint.json`
- [ ] CLAUDE.md, README.md, and CHANGELOG.md reflect the new filename
- [ ] The install script (install.sh) correctly handles the rename if applicable

---

### US-002: Rename /takt-prd → /feature and /takt (converter) → /sprint

**Description:** As a takt user, I want slash commands to use Scrum names so that `/feature` creates a Feature doc and `/sprint` converts it to an executable sprint.

**Acceptance Criteria:**
- [ ] `commands/takt-prd.md` is renamed to `commands/feature.md` and updated to use Feature/Sprint vocabulary throughout
- [ ] `commands/takt.md` (the PRD-to-stories converter) is renamed to `commands/sprint.md` and updated to convert Feature docs to `sprint.json`
- [ ] Output filename convention changes from `tasks/prd-*.md` to `tasks/feature-*.md`
- [ ] install.sh installs the renamed files to `~/.claude/commands/` correctly

---

### US-003: Create /epic skill

**Description:** As a takt user, I want a `/epic` skill that guides me through defining a high-level Epic before breaking it into Features, so that I have a structured starting point for large pieces of work.

**Acceptance Criteria:**
- [ ] `/epic` conducts a guided interview (problem, users, goals, constraints) and produces `tasks/epic-*.md`
- [ ] If `CLAUDE.md` is missing or thin, the skill asks the user whether to describe the project themselves or let the agent run a quick codebase scan before starting the interview
- [ ] At the end of the interview, the skill asks if the user wants to proceed to `/feature`
- [ ] Epic output includes: problem statement, target users, goals, constraints, and a list of proposed Features with suggested sequencing

---

### US-004: Create /takt wrapper entry point

**Description:** As a takt user, I want to type `/takt` to start the full planning flow from scratch, so that I have a single entry point regardless of where I am in the process.

**Acceptance Criteria:**
- [ ] `/takt` guides the user through the full flow: Epic → Feature → Sprint → `start takt`
- [ ] Each stage transitions naturally to the next with a confirmation gate
- [ ] If the user already has artifacts (e.g., an existing `epic.md` or `feature.md`), the skill detects this and offers to skip ahead to the relevant stage
- [ ] install.sh installs the new `/takt` wrapper to `~/.claude/commands/takt.md`

---

## 4. Functional Requirements

- **FR-1:** `sprint.json` must be the canonical filename for the executable story list. No reference to `stories.json` should remain in any installed file.
- **FR-2:** `/feature` must produce output to `tasks/feature-*.md` (kebab-case). The skill body must use Feature/Sprint vocabulary, not PRD/stories vocabulary.
- **FR-3:** `/sprint` must read a `tasks/feature-*.md` file and produce `sprint.json` with the same structure as the current `stories.json`.
- **FR-4:** `/epic` must be project-agnostic. It must not fail or produce errors if `CLAUDE.md` is absent, empty, or contains no project context.
- **FR-5:** When `/epic` detects missing or thin project context, it must present an `AskUserQuestion` with two options: (a) user describes the project, (b) agent scans the codebase first.
- **FR-6:** `/epic` output (`tasks/epic-*.md`) must include a proposed Feature breakdown with suggested sequencing rationale.
- **FR-7:** `/takt` wrapper must detect existing artifacts (`epic.md`, `feature.md`, `sprint.json`) and offer to skip ahead to the appropriate stage.
- **FR-8:** All installed files (`~/.claude/commands/`, `~/.claude/lib/takt/`) must reflect the new vocabulary after `install.sh` runs.

---

## 5. Non-Goals (Out of Scope)

- Role-based model architecture (separate sprint)
- Changes to execution commands (`start takt`, `takt debug`, `takt retro`)
- Changes to workflow logic or agent behaviour inside run.md/worker.md beyond vocabulary
- Changes to `.takt/` folder structure (workbooks, stats.json, retro.md)
- Migration of existing `prd-*.md` files in `tasks/` — rename convention applies to new files only
- The `/takt` wrapper does not replace or modify `start takt` — it is a planning entry point only

---

## 6. Technical Considerations

- **install.sh** installs files from `commands/` → `~/.claude/commands/` and `lib/` → `~/.claude/lib/takt/`. The rename of `takt-prd.md` → `feature.md` and `takt.md` → `sprint.md` must be reflected in install.sh, including removal of old installed files if they exist.
- **Vocabulary scope:** Only prompt text and filenames change. No changes to JSON schema, field names inside `sprint.json`, or `.takt/` artifact structure.
- **CLAUDE.md references:** The project CLAUDE.md references command names and file names. All must be updated to new vocabulary.

---

## 7. Success Metrics

- `stories.json` no longer exists anywhere in the codebase or installed files
- `/takt-prd` no longer exists in `~/.claude/commands/`
- Running `/epic` in a fresh project produces a valid `tasks/epic-*.md` regardless of `CLAUDE.md` state
- Running `/takt` from scratch walks through the full flow to `start takt`
- A Scrum practitioner reading the command list understands the full workflow without explanation

---

## 8. Open Questions

- Should `tasks/` be renamed to something more Scrum-native (e.g., `backlog/`)? Held for a future sprint — `tasks/` is functional and this PRD is already a significant rename scope.
- Should the `tdd.md` command be renamed or repositioned in the hierarchy? Out of scope for this sprint.
