# PRD: takt v3 Refinements

## Introduction

takt's prompt files and documentation have accumulated stale references, suboptimal defaults, and missing workflow improvements identified through real-world usage (retro findings from takt and dikta projects) and the Claude Code 2.1.49 upgrade. This update brings the system in line with current best practices and available platform features.

## Why

- Workers default to the parent session's model (Opus 4.6), which causes slow execution and creative drift during implementation. Retro data shows Sonnet completing stories in 1-3 minutes vs 30+ minutes on Opus.
- Team mode manually manages git worktrees via bash commands when Claude Code 2.1.49 now provides native worktree isolation (`isolation: "worktree"`).
- Workers use `git add -A` which commits takt artifacts and unrelated files into feature branches (confirmed in dikta retro).
- Retro files grow unboundedly — no retention policy exists. Old entries are never referenced but accumulate forever.
- No persistent changelog tracks how takt itself evolves over time.
- Requirements and acceptance criteria are written as implementation checklists rather than behavioral outcomes, creating friction when generating BDD scenarios for verification.
- Five planning/migration docs from the DuaLoop era are fully implemented and stale, cluttering the docs folder.

## Goals

- All takt workers and verifiers run on Sonnet 4.6 explicitly, regardless of the orchestrator's model
- Team mode uses Claude Code's native worktree isolation instead of manual git commands
- Workers follow standard git discipline: status → selective add → commit
- Retro files stay lean: alerts table + last 1 entry only, with a CHANGELOG.md for permanent improvement history
- Requirements pipeline is BDD-aligned: behavioral criteria → behavioral scenarios → behavioral verification
- Documentation reflects current state — no stale planning docs, no outdated model references

## User Stories

### US-001: Explicit Sonnet 4.6 for all worker and verifier spawns
**Description:** As a takt user, I want workers and verifiers to always use Sonnet 4.6 so that execution is fast, predictable, and free from Opus drift.

**Acceptance Criteria:**
- [ ] When solo.md spawns a worker Task, it specifies `model: "sonnet"` explicitly
- [ ] When team-lead.md spawns worker and verifier Tasks, it specifies `model: "sonnet"` explicitly
- [ ] The example in `commands/takt.md` no longer includes a per-story `model` field

### US-002: Native worktree isolation in team mode
**Description:** As a takt user, I want team mode to use Claude Code's native `isolation: "worktree"` so that worktree management is handled by the platform instead of custom bash commands.

**Acceptance Criteria:**
- [ ] team-lead.md uses `isolation: "worktree"` when spawning worker agents instead of manual `git worktree add/remove`
- [ ] Manual worktree cleanup commands are removed from team-lead.md completion steps
- [ ] CLAUDE.md and README.md references to `.worktrees/` are updated to reflect native isolation

### US-003: Git commit discipline for workers
**Description:** As a takt user, I want workers to follow proper git discipline so that takt artifacts and unrelated files don't leak into feature commits.

**Acceptance Criteria:**
- [ ] worker.md instructs workers to run `git status` before staging
- [ ] worker.md instructs workers to selectively `git add` only story-relevant files, explicitly excluding `.takt/`, `stories.json`, and other takt artifacts
- [ ] The `git add -A` pattern is removed from worker.md

### US-004: Retro retention policy and CHANGELOG
**Description:** As a takt user, I want retro files to stay lean and improvements to be tracked in a changelog so that I have a clean operational view and a permanent record of how takt evolves.

**Acceptance Criteria:**
- [ ] `lib/retro.md` instructs the retro agent to keep only the alerts table + the most recent 1 entry, deleting older entries
- [ ] `lib/retro.md` instructs the retro agent to add a one-liner to `CHANGELOG.md` when an improvement is confirmed addressed
- [ ] A `CHANGELOG.md` file exists at the project root with entries for all changes in this update
- [ ] `.takt/retro.md` action items are marked done and alert statuses are updated

### US-005: BDD mindset for requirements and docs cleanup
**Description:** As a takt user, I want requirements written as behavioral outcomes and stale documentation removed so that the PRD-to-scenario pipeline flows naturally and the docs folder reflects current state.

**Acceptance Criteria:**
- [ ] `commands/takt-prd.md` guides acceptance criteria toward behavioral outcomes (observable user/system behavior) rather than implementation checklists
- [ ] `commands/takt.md` scenario generation guidance reinforces the BDD alignment from PRD criteria to scenarios
- [ ] Unchecked items from `TODO.md` and `IMPROVEMENTS.md` are merged into `future-improvements.md` where not already present
- [ ] Stale docs deleted: `CLAUDE_CODE_MIGRATION.md`, `dualoop-review.md`, `TODO.md`, `IMPROVEMENTS.md`, `dua-v2-planning.md`

## Functional Requirements

- FR-1: solo.md and team-lead.md must pass `model: "sonnet"` when spawning Task agents for workers and verifiers
- FR-2: team-lead.md must use `isolation: "worktree"` parameter instead of `git worktree add/remove` commands
- FR-3: worker.md must specify a `git status` → selective `git add` → `git commit` workflow, with explicit exclusion of `.takt/` and `stories.json`
- FR-4: lib/retro.md must enforce single-entry retention with changelog integration
- FR-5: CHANGELOG.md must exist and be maintained by the retro agent when improvements are confirmed
- FR-6: commands/takt-prd.md acceptance criteria guidance must use BDD behavioral language
- FR-7: commands/takt.md must not include a `model` field in the story schema or examples
- FR-8: All five stale docs must be deleted; unchecked future items preserved in future-improvements.md

## Non-Goals

- No new takt modes or agent roles (support/recon is future work)
- No changes to the solo.md or team-lead.md orchestration logic beyond model and worktree parameters
- No changes to the verifier.md verification logic
- No changes to the debug.md workflow
- No per-story model field — all workers use the same model
- No automated retro-to-changelog pipeline beyond the retro agent instructions

## Technical Considerations

- All changes are to markdown prompt files — no application code, no tests, no builds
- The `isolation: "worktree"` feature requires Claude Code 2.1.49+ (current version)
- The `model` parameter on Task tool accepts `"sonnet"`, `"opus"`, `"haiku"` as values
- Existing `.takt/retro.md` in the takt repo and dikta repo should be cleaned up as part of the retro housekeeping

## Success Metrics

- Workers complete stories in 1-3 minutes consistently (no more 30-minute Opus timeouts)
- No takt artifacts appear in feature branch commits
- Retro files stay under 50 lines across all projects
- CHANGELOG.md provides a scannable history of takt improvements

## Open Questions

- None — all decisions made during planning session on 2026-02-21
