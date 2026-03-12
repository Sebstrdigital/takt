# Changelog

All notable improvements to takt are documented here. Managed by the retro agent.

- 2026-03-12: Remove /tdd command — BDD scenarios are the quality gate; TDD workflow redundant
- 2026-03-12: Add planning flow redesign — /epic auto-loops all Features, /feature scope recalibrated to 4-8 stories, /sprint merges multiple Feature docs with ID renumbering and cross-Feature wave computation, /takt Quick path (3-question why/what/what-not → sprint.json + scenarios.json directly)
- 2026-03-12: Add role-based model architecture — complexity-based worker routing active (simple → Haiku, complex → Sonnet), Merge Strategist (Opus) spawned once per wave in parallel mode to determine optimal merge order

- 2026-03-07: Clean up stale solo/team references — delete solo.md + team-lead.md, update all commands/prompts to use 'start takt', gitignore ephemeral artifacts
- 2026-03-07: Fix install.sh CLAUDE.md replacement — awk multi-line string bug silently skipped section updates, replaced with sed+append
- 2026-03-07: Add silent execution — orchestrator prints only start line (with ETA) and final report, no intermediate output
- 2026-03-07: Add per-project timing stats (.takt/stats.json) — retro computes per-size averages and phase overhead, orchestrator uses them for ETA
- 2026-03-07: Fix sprint.json lifecycle — never committed, treated as ephemeral run artifact deleted by retro
- 2026-03-07: Mitigate intermediary orchestrator failure — session agent is now the orchestrator via unified run.md
- 2026-03-07: Mitigate prompt bloat — pointer-based agent spawns replace 9KB embedded prompts (82% reduction)
- 2026-03-07: Mitigate worker git commit failures — workers scoped to file edits only, session agent owns git
- 2026-03-07: Unify solo.md + team-lead.md into single run.md with auto-detection of sequential vs parallel
- 2026-03-07: Drop TDD enforcement from worker.md — BDD scenarios are the verification layer
- 2026-03-07: Add 'start takt' as primary command, deprecate 'takt solo'/'takt team'
- 2026-03-07: Add automated PR creation phase to solo.md and team-lead.md
- 2026-03-07: Add auto-retro phase — orchestrator spawns retro agent after PR creation
- 2026-03-07: Fix retro routing confusion — add routing table to CLAUDE.md and guard to /takt command
- 2026-03-07: Add stale action item escalation to retro agent (carry count tracking, auto-escalation at 3+)
- 2026-03-02: Add code review phase to solo.md and team-lead.md — automated must-fix/suggestion review gate between verification and completion
- 2026-03-02: Resolve alert — Opus too slow for worker agents (3 clean retros, Sonnet default holds)
- 2026-03-02: Resolve alert — Workbook generation inconsistent across workers (3 clean retros, consistent quality confirmed)
- 2026-03-02: Resolve alert — Stale workbooks accumulate across runs (retention policy enforced, cleanup reliable)
- 2026-03-02: Add `knownIssues` field to sprint.json schema — workers skip pre-existing failures instead of wasting time diagnosing them
- 2026-03-02: Enforce workbook verification in team-lead.md merge planning — team lead must confirm workbook exists before merging
- 2026-03-02: Document solo mode parallel execution behavior — clarify that independent stories run concurrently
- 2026-02-22: Add agent type safety rule to install script — survives reinstalls as source of truth
- 2026-02-22: Add agent type safety rule — enforce `general-purpose` for all takt Task spawns, never custom agents
- 2026-02-21: Add CHANGELOG.md for permanent improvement tracking
- 2026-02-21: Add retro retention policy (alerts + last 1 entry only)
- 2026-02-21: Adopt BDD mindset for requirements and acceptance criteria
- 2026-02-21: Clean up stale DuaLoop-era planning docs
- 2026-02-21: Default all workers and verifiers to Sonnet 4.6 (no Opus drift)
- 2026-02-21: Enforce git status → selective add → commit discipline in workers
- 2026-02-21: Switch team mode to native worktree isolation (Claude Code 2.1.49)
