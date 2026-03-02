# Changelog

All notable improvements to takt are documented here. Managed by the retro agent.

- 2026-03-02: Add code review phase to solo.md and team-lead.md — automated must-fix/suggestion review gate between verification and completion
- 2026-03-02: Resolve alert — Opus too slow for worker agents (3 clean retros, Sonnet default holds)
- 2026-03-02: Resolve alert — Workbook generation inconsistent across workers (3 clean retros, consistent quality confirmed)
- 2026-03-02: Resolve alert — Stale workbooks accumulate across runs (retention policy enforced, cleanup reliable)
- 2026-03-02: Add `knownIssues` field to stories.json schema — workers skip pre-existing failures instead of wasting time diagnosing them
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
