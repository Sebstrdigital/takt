# PRD: takt v2 — Claude Code Native Execution

## Introduction

Rewrite takt to run natively inside Claude Code. The current `takt.sh` bash wrapper shells out to `claude -p`, which is blocked inside Claude Code sessions. This makes all modes (solo, team, debug, retro) require manual human orchestration — defeating the purpose of autonomous execution.

v2 replaces the bash orchestration layer with Claude Code's native tools (Task, TeamCreate, SendMessage) so the user can say "takt solo" or "takt team", walk away, and come back to completed work.

## Goals

- Fully autonomous execution — zero permission prompts after kickoff
- Solo and team modes work natively inside Claude Code (no `claude -p`)
- Workers use generic agents, not specialized custom agents
- Artifacts don't pollute project root
- Workbooks are ephemeral — consumed by retro, then deleted
- PRDs produce leaner output (fewer stories, fewer ACs)

## User Stories

### US-001: Create solo orchestrator prompt
**Description:** As a user, I want to say "takt solo" in Claude Code and have it autonomously implement all stories in prd.json sequentially.

**Acceptance Criteria:**
- [ ] New `lib/solo.md` prompt that reads prd.json and loops through incomplete stories by priority
- [ ] Each story spawns a fresh Task agent (`subagent_type: "general-purpose"`, `mode: "bypassPermissions"`) with worker.md instructions
- [ ] Orchestrator updates prd.json (`passes: true`) after each story completes — workers don't touch prd.json
- [ ] After all stories pass, runs deep verification for stories marked `verify: "deep"`, then outputs `<promise>COMPLETE</promise>`

### US-002: Fix worker and team-lead prompts for native execution
**Description:** As an orchestrator agent, I want workers that execute cleanly in Claude Code without causing CWD drift, artifact pollution, or wrong agent types.

**Acceptance Criteria:**
- [ ] worker.md: remove prd.json update step, add "NEVER use `cd` — use absolute paths for all file and git operations", write workbooks to `.takt/workbooks/` instead of project root
- [ ] team-lead.md: specify `subagent_type: "general-purpose"` and `mode: "bypassPermissions"` for workers, centralize all prd.json updates in team lead only, add `.worktrees/` cleanup on completion
- [ ] Neither prompt references `claude -p`, custom agent types, or takt.sh

### US-003: Update retro agent with workbook cleanup
**Description:** As a user, I want retro to consume workbooks and then delete them so they don't accumulate across runs.

**Acceptance Criteria:**
- [ ] retro.md: read workbooks from `.takt/workbooks/`, write retro entry to `.takt/retro.md`
- [ ] After writing retro entry, delete all `workbook-*.md` files from `.takt/workbooks/`
- [ ] If no workbooks found, report clearly and exit (don't create empty retro entry)

### US-004: Leaner PRD generation
**Description:** As a user, I want `/takt-prd` to produce tighter PRDs that don't over-specify, so agents implement the right amount of code.

**Acceptance Criteria:**
- [ ] Max 3-4 acceptance criteria per story (enforce in prompt). "Typecheck passes" is assumed, not listed.
- [ ] Add guidance: prefer fewer stories with broader scope over many tiny stories. A single "logic" story can touch 3-4 files.
- [ ] Add anti-pattern examples: "Don't create a separate story for documentation. Don't create a story for config files. Roll these into the stories that need them."

### US-005: Remove takt.sh and update distribution
**Description:** As a maintainer, I want to remove the dead bash infrastructure and update docs to reflect the native execution model.

**Acceptance Criteria:**
- [ ] Delete `bin/takt.sh`, `tests/takt.bats`, `tests/test_helper.bash`, `tests/fixtures/`
- [ ] Update `install.sh` to install `lib/solo.md` and remove `bin/takt.sh` references
- [ ] Update `CLAUDE.md` and `README.md` to document the native execution model (no bash commands, just "say takt solo/team in Claude Code")

## Functional Requirements

- FR-1: Solo mode orchestrator (solo.md) spawns one Task agent per story, sequentially, with fresh context each time (Ralph Wiggum pattern preserved)
- FR-2: Team mode orchestrator (team-lead.md) uses TeamCreate + Task to spawn parallel workers per wave, with git worktrees for isolation
- FR-3: All spawned agents use `subagent_type: "general-purpose"` and `mode: "bypassPermissions"` — never custom agent types
- FR-4: Workers write workbooks to `.takt/workbooks/workbook-<STORY-ID>.md` and nowhere else
- FR-5: Only the orchestrator (solo or team lead) modifies prd.json
- FR-6: Retro agent reads from `.takt/workbooks/`, writes to `.takt/retro.md`, then deletes workbooks
- FR-7: CLAUDE.md entry point instructions tell Claude how to handle "takt solo", "takt team", "takt debug", "takt retro" by reading the appropriate prompt file and spawning a Task agent

## Non-Goals

- No web UI or dashboard
- No new prd.json format changes (existing format works)
- No changes to `/takt` (PRD-to-JSON converter) — it already works
- No changes to `agents/verifier.md` — deep verification works
- No changes to `lib/debug.md` — debug mode works (it doesn't use `claude -p`)
- No new test framework to replace BATS (prompt behavior isn't unit-testable the same way)

## Technical Considerations

- Claude Code's Task tool with `run_in_background: true` enables fire-and-forget execution
- `mode: "bypassPermissions"` is critical — without it, agents hit permission prompts that block autonomy
- The `subagent_type` parameter determines agent behavior. Using `"general-purpose"` gives a blank canvas that follows the prompt. Custom agents like "Seb the boss" layer on their own behaviors (excessive TDD) which conflict with the worker prompt.
- `.takt/` directory should be gitignored (workbooks are ephemeral). `retro.md` could be committed if the user wants persistent retrospectives — leave this as a user choice.

## Success Metrics

- User kicks off "takt solo" or "takt team" and returns to completed work with zero mid-run prompts
- Workbook count in project root after a full run: 0
- Agent-produced test count is proportional to code (not 4:1 test-to-code ratio)
- Total artifact files outside `.takt/` and committed code: 0

## Open Questions

- Should `.takt/retro.md` be committed to git (persistent history) or gitignored (ephemeral like workbooks)? Leaning toward committed — retros have long-term value.
- Should solo.md and team-lead.md include inline worker instructions, or should they read worker.md at runtime? Leaning toward read-at-runtime to keep a single source of truth.
