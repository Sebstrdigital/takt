# Workbook: US-001 - Create solo orchestrator prompt

## Decisions

- **Prompt-only deliverable**: `lib/solo.md` is a prompt document, not executable code. It instructs a Claude Code agent on how to orchestrate solo execution natively, replacing the bash-based `takt_solo()` function in `bin/takt.sh`.

- **Workers must NOT update prd.json**: The old `prompt.md` (single-story agent) updated prd.json itself. The new architecture centralizes prd.json ownership in the orchestrator. Worker prompts include an explicit "Do NOT modify prd.json" rule. This prevents race conditions and ensures a single source of truth.

- **Task agent spawning pattern**: Each worker is spawned via Claude Code's Task tool with `subagent_type: "general-purpose"`, `mode: "bypassPermissions"`, and `run_in_background: true`. This matches the pattern established in `team-lead.md` but adapted for sequential (not parallel) execution.

- **Dependency-aware execution**: Unlike the old `takt_solo()` which processed stories purely by priority and relied on single-story-per-session agents, the new orchestrator checks `dependsOn` arrays before starting each story, skipping stories whose dependencies haven't passed yet. A second pass catches stories that were initially skipped.

- **Retry strategy**: Max 1 retry per story (2 total attempts). On retry, the worker receives context about what went wrong in the first attempt. If both attempts fail, the story is marked blocked and dependent stories are skipped. This matches the team-lead's approach but is simpler (no model escalation).

- **Deep verification as a post-loop phase**: Deep verification runs only after ALL stories pass, not inline during the loop. This matches the existing `takt.sh` behavior. If verification fails, the orchestrator spawns a fix worker and re-verifies, creating a tight fix-verify cycle.

- **Workbook location**: Workers write workbooks to `.takt/workbooks/` (not project root), aligning with the new convention established in US-002/US-003 for cleaner project organization.

- **Installed paths**: The prompt references `~/.claude/lib/takt/worker.md` and `~/.claude/lib/takt/verifier.md` since these are the installed locations. The orchestrator reads from installed paths, not from the repo source.

- **No SendMessage in solo mode**: Workers run as Task agents, not team members. They have no team lead to report to. The orchestrator checks completion by inspecting git history and file presence, not by waiting for messages.

## Files Changed

- `lib/solo.md` (created) - Solo orchestrator prompt for native Claude Code execution

## Blockers Encountered

- None

## Notes

- The old `prompt.md` is a single-story-per-session agent that picks and implements one story, then stops. The new `solo.md` is an orchestrator that loops through ALL stories, delegating implementation to fresh Task agents. These serve fundamentally different roles.
- The `takt.sh` bash script currently handles branch management, timeouts, progress tracking, stats, and post-completion actions (merge/PR prompts). Some of this logic (branch management) is replicated in `solo.md`. Other parts (timeouts, stats, interactive merge prompts) are intentionally omitted since Claude Code Task agents handle their own lifecycle and interactive prompts don't apply in an autonomous agent context.
- US-005 will clean up the old infrastructure. This prompt is designed to work independently of `takt.sh`.
