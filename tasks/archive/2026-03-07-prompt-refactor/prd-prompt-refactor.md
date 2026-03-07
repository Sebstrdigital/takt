# PRD: Unified Session-Level Orchestration

## Introduction

takt currently has two orchestrator files (solo.md, team-lead.md) built around a broken assumption: that a spawned intermediary agent can use Bash and spawn sub-agents. In practice, spawned agents only have file edit access. This causes stalls, commit failures, and wasted time. Additionally, prompts embed ~9KB of instructions agents can read from disk, and the user has to decide "solo or team?" when the orchestrator can figure that out from stories.json.

This PRD merges solo and team modes into a single unified orchestrator prompt where the session agent IS the orchestrator. It auto-detects mode from the waves field, uses file-path pointers instead of embedded copies, and drops TDD in favor of BDD scenario verification.

## Goals

- Merge solo.md and team-lead.md into a single orchestrator file — user just says "takt"
- Auto-detect execution mode: sequential (no waves) or parallel (waves present) from stories.json
- Eliminate the intermediary orchestrator layer — session agent orchestrates directly
- Cut prompt sizes from ~20KB to ~3KB using file-path pointers
- Clarify worker boundary: file edits only, no git, no TDD — BDD scenarios are the quality gate
- Make takt runs zero-friction: no stalls, no manual commits, no mode selection

## User Stories

### US-001: Create unified orchestrator prompt (run.md)

**Description:** As the session agent, I want a single orchestrator file that handles both sequential and parallel execution so I don't need separate solo/team modes.

**Acceptance Criteria:**
- [ ] A new `lib/run.md` replaces both `lib/solo.md` and `lib/team-lead.md` — single flat document addressed to the session agent
- [ ] When stories.json has no `waves` or all waves have 1 story: execute sequentially (spawn workers one at a time or parallel if independent)
- [ ] When stories.json has `waves` with 2+ stories in any wave: use TeamCreate + `isolation: "worktree"` for parallel wave execution
- [ ] All phases present in order: story loop, scenario verification, code review, PR creation, auto-retro, completion

### US-002: Implement lean agent prompts in run.md

**Description:** As the session agent, I want to spawn workers/verifiers/reviewers with minimal prompts that point to instruction files instead of embedding them.

**Acceptance Criteria:**
- [ ] Worker prompts contain only: story JSON + project path + "Read ~/.claude/lib/takt/worker.md for your instructions"
- [ ] Verifier and reviewer prompts follow the same pointer pattern — no embedded copies of verifier.md or reviewer.md
- [ ] Session agent handles all git operations (add, commit, push) — workers never touch git

### US-003: Update worker.md — file-edit-only scope, drop TDD

**Description:** As a worker agent, I want clear instructions that my job is file edits only, with BDD scenarios as the quality gate.

**Acceptance Criteria:**
- [ ] worker.md git section replaced with: "Do NOT run git commands — the session agent handles all git operations after you complete your edits"
- [ ] TDD workflow (RED/GREEN/REFACTOR) removed — workers implement directly, BDD scenarios are the verification layer
- [ ] The /takt converter (commands/takt.md) story type section simplified to reflect no TDD enforcement at worker level

### US-004: Update CLAUDE.md, install.sh, and routing

**Description:** As a takt user, I want the documentation, installer, and routing to reflect the unified "takt" command.

**Acceptance Criteria:**
- [ ] CLAUDE.md routing table updated: "start takt" maps to `run.md`, "takt solo" and "takt team" are deprecated aliases that also read `run.md`
- [ ] install.sh updated: installs `run.md`, removes solo.md and team-lead.md from install targets
- [ ] The global CLAUDE.md instructions (in `~/.claude/CLAUDE.md` takt section) updated to reflect unified command

## Functional Requirements

- FR-1: `lib/run.md` is a flat session-agent document — no section split, no intermediary orchestrator spawn
- FR-2: Mode auto-detection: check `stories.json` for `waves` field. If waves exist with 2+ stories in any wave → parallel mode (TeamCreate + worktree). Otherwise → sequential mode (direct Agent spawns).
- FR-3: Story loop: read stories.json, check dependencies, spawn worker Agent (lean prompt), wait for completion, verify workbook exists, git add + git commit, update stories.json, continue.
- FR-4: Worker Agent spawns use: `subagent_type: "general-purpose"`, `model: "sonnet"`, `mode: "bypassPermissions"`, `run_in_background: true`.
- FR-5: Worker prompts must be under 1KB: story JSON + project path + pointer to worker.md.
- FR-6: After all stories pass, session agent spawns verifier with lean prompt (scenarios path + pointer to verifier.md).
- FR-7: Before spawning reviewer, session agent writes `git diff main...HEAD` to `.takt/review.diff` (unified diff format — native git output, optimal for LLM parsing). Reviewer prompt points to reviewer.md + `.takt/review.diff`. Session agent re-generates the diff file between review-fix cycles. `.takt/review.diff` is cleaned up by the retro agent.
- FR-8: Verify-fix loop and review-fix loop logic retained — only prompt format changes.
- FR-9: PR creation and auto-retro phases retained from baseline-completion.
- FR-10: worker.md must state: "You have file edit access only. Do not run git commands."
- FR-11: worker.md must remove TDD workflow. Workers implement directly.
- FR-12: commands/takt.md story type section simplified — `type` field retained but does not change worker workflow.
- FR-13: install.sh must install `lib/run.md` and remove `lib/solo.md` + `lib/team-lead.md` from install targets.
- FR-14: User triggers execution by saying "start takt". "takt solo" and "takt team" remain as deprecated aliases that also read `run.md`. Separate modes (takt debug, takt retro) stay as distinct commands.

## Non-Goals

- No changes to retro.md (retro agent instructions stay as-is)
- No changes to /takt-prd slash command
- No changes to scenarios.json format or verifier.md content
- No changes to reviewer.md content
- No new features — this is a pure architectural refactor + simplification
- No project-specific tier work (gaps 5-8)

## Technical Considerations

- `lib/run.md` replaces `lib/solo.md` (~495 lines) and `lib/team-lead.md` (~492 lines) with a single ~150-200 line document
- The mode detection branch is small: ~10 lines of "if waves exist, use TeamCreate; else, spawn sequentially"
- Workers spawned via Agent tool with `mode: "bypassPermissions"` CAN use Read, Edit, Write, Glob, Grep. They CANNOT use Bash or spawn sub-agents.
- The session agent (Opus) has a large context window — running orchestration directly is not a concern
- Old solo.md and team-lead.md should be deleted from the repo (git history preserves them)

## Success Metrics

- User says "start takt" and execution starts — no mode selection needed
- takt runs complete without orchestrator stalls
- No manual commits needed — session agent handles all git
- Worker prompts under 1KB
- Total line count: run.md (~150-200 lines) vs old solo.md + team-lead.md (~987 lines combined)

## Open Questions

- Should "takt solo" and "takt team" be kept as aliases or fully removed?
