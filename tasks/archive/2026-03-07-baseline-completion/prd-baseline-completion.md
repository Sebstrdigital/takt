# PRD: takt Baseline Completion

## Introduction

takt's lights-out factory pipeline has two gaps remaining before the "baseline" tier is complete: automated PR creation and auto-retro. Additionally, two confirmed hygiene issues need fixing: the session agent misroutes "takt retro" through the `/takt` PRD converter skill, and retro action items accumulate indefinitely with no escalation mechanism. This PRD closes all four issues in one run, completing the baseline autonomous pipeline: execute stories, verify scenarios, review code, create PR, run retro — all without human intervention between spec approval and PR merge.

## Goals

- Eliminate the confirmed retro routing bug so "takt retro" always triggers the retro agent, never the PRD converter
- Add escalation for stale retro action items so recurring issues don't silently accumulate across runs
- Automate PR creation as an orchestrator phase after code review passes (Gap 3)
- Automate retro as the final orchestrator phase after PR creation (Gap 4)
- After this PRD, the human touchpoints are: approve spec, approve stories, merge PR

## User Stories

### US-001: Fix retro routing confusion

**Description:** As a takt user, I want "takt retro" to always trigger the retro agent so that I don't accidentally end up in the PRD converter.

**Acceptance Criteria:**
- [ ] When a user says "takt retro" in Claude Code, the session agent reads `~/.claude/lib/takt/retro.md` and runs the retro flow — never the `/takt` slash command
- [ ] The `/takt` command description explicitly states it is for PRD-to-stories conversion only and should not handle retro requests
- [ ] The takt CLAUDE.md documents the correct routing for all takt phrases (solo, team, debug, retro)

### US-002: Stale action item escalation in retro agent

**Description:** As a takt user, I want the retro agent to detect and escalate stale action items so that recurring issues get addressed instead of silently carrying forward across retros.

**Acceptance Criteria:**
- [ ] When the retro agent finds an action item carried forward from 3+ previous retros without being addressed, it escalates the corresponding alert from potential to confirmed and appends a suggested story description to fix it
- [ ] The retro entry's "Action Items" section marks carried-forward items with their carry count (e.g., "[carried 4x]") so staleness is visible
- [ ] When an action item is addressed (checked off or no longer relevant), the escalation resets

### US-003: Automated PR creation phase

**Description:** As a takt orchestrator, I want to automatically create a GitHub PR after code review passes so that the human only needs to merge.

**Acceptance Criteria:**
- [ ] After the code review phase completes, the orchestrator runs `gh pr create` with a structured body containing: summary (from stories.json description), stories completed, verification result, review notes (suggestions if any), and run metrics
- [ ] The PR is created as a draft if unresolved review suggestions exist, or as ready if the review was clean
- [ ] Both solo.md and team-lead.md include the PR creation phase in the same position (after code review, before retro)

### US-004: Auto-retro phase

**Description:** As a takt orchestrator, I want the retro to run automatically after PR creation so that the full pipeline completes without manual intervention.

**Acceptance Criteria:**
- [ ] After PR creation, the orchestrator spawns a retro agent Task that reads workbooks, generates a retro entry, and commits the result to the feature branch
- [ ] The session agent's "on completion" message no longer suggests "run takt retro" — instead it reports the PR URL and retro summary
- [ ] Both solo.md and team-lead.md include the auto-retro phase as the final step before the completion signal

## Functional Requirements

- FR-1: The `/takt` command (commands/takt.md) must include a guard clause: "This command converts PRDs to stories.json. It does NOT run retro, solo, team, or debug modes."
- FR-2: The takt CLAUDE.md must include a routing table mapping each phrase to its prompt file (solo → solo.md, team → team-lead.md, debug → debug.md, retro → retro.md)
- FR-3: The retro agent must read the previous retro entry's action items before deleting it (already specified), AND compare each unchecked item against the current run's workbooks to detect carry-forward
- FR-4: Carry-forward detection: if an action item text (fuzzy match) appears unchecked in the previous entry AND is not addressed by any workbook in the current run, increment its carry count
- FR-5: At carry count >= 3, the retro agent must: (a) escalate the related alert to "confirmed", (b) append a one-liner story suggestion in the action items section: "Suggested story: <description>"
- FR-6: The PR creation phase runs `gh pr create --title "<branchName summary>" --body "<structured body>"` targeting the base branch (usually `main`)
- FR-7: PR body structure: Summary, Stories Completed (list with pass/fail), Verification Results (pass + fix cycles if any), Review Notes (suggestions from review-comments.json if present), Run Metrics (story count, time, commits)
- FR-8: If review-comments.json contains unresolved suggestions (severity != must-fix), create as draft PR (`--draft`). If no suggestions, create as ready PR.
- FR-9: The auto-retro phase spawns a retro agent Task with the retro.md instructions, project working directory, and branch name
- FR-10: The retro agent commits its output (retro.md updates, CHANGELOG.md updates, workbook cleanup) to the feature branch, then pushes to update the PR
- FR-11: The orchestrator's completion output includes the PR URL (parsed from `gh pr create` output) and a one-line retro summary
- FR-12: The session agent's "on completion" message changes from "Run takt retro to wrap up" to reporting the PR URL and retro highlights

## Non-Goals

- No changes to `/takt-prd` skill (PRD generation is unchanged)
- No CI-aware merge (Gap 5) — that's project-specific tier
- No headless mode (Gap 6) — that's project-specific tier
- No auto-merge after PR creation — human merges
- No changes to worker.md or verifier.md — only orchestrator-level changes
- No scenario verification changes (separate PRD already exists)
- No changes to retro content structure — only how/when retro is triggered and how stale items escalate

## Technical Considerations

- All changes are to markdown prompt files — no binary or script changes
- `gh` CLI must be available in the project environment for PR creation. If `gh` is not available, the orchestrator should skip PR creation and fall back to the current behavior (suggest manual PR)
- The retro agent's commit-and-push step means the feature branch must have a remote tracking branch. The PR creation step (`gh pr create`) handles the initial push, so the retro agent can `git push` after committing
- The auto-retro spawns the retro agent as a Task, not inline — this keeps the retro isolated and consistent with the Ralph Wiggum pattern
- Stale action item detection uses fuzzy text matching (substring match on action item text) since action items may be slightly reworded between retros

## Success Metrics

- The "takt retro routed through /takt" alert in dua-cs-agent is resolvable (no more misrouting)
- Action items that have been carried forward 3+ times are visibly flagged in the next retro
- After a takt run completes, a PR exists on GitHub without manual intervention
- After a takt run completes, the retro entry is committed to the PR branch without the user saying "takt retro"

## Open Questions

- Should the PR creation fall back gracefully if `gh auth status` fails (not logged in), or should it error out and block completion?
- Should the auto-retro push trigger a PR update notification, or is a silent push sufficient?
