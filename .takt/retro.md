# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Spawned agents cannot use Bash or spawn sub-agents — intermediary orchestrator pattern is non-functional | 2026-03-07 | 2026-03-07 |
| mitigated | Prompt bloat — solo.md/team-lead.md embed ~9KB of instructions that agents can read from disk | 2026-03-07 | 2026-03-07 |
| mitigated | Workers cannot git commit — bypassPermissions mode only grants file edit access, not Bash | 2026-03-07 | 2026-03-07 |
| confirmed | install.sh not re-run after prompt updates — manual sync is error-prone | 2026-03-12 | 2026-03-12 |
| confirmed | No end-to-end verification of `start takt` on a real project after orchestrator unification | 2026-03-12 | 2026-03-12 |

---

## Retro: 2026-03-12 — takt/role-based-model-architecture

### What Went Well
- **3/3 stories completed, zero blockers.** Clean run across all three stories.
- **Complexity routing implemented cleanly in US-001**: simple → Haiku, complex/unset → Sonnet. Default-safe (unset falls back to Sonnet). Pure markdown change with no build overhead.
- **US-002 doc accuracy**: CLAUDE.md and README.md now describe complexity routing as live behavior rather than a future plan — no stale "not yet active" language remains.
- **US-003 Merge Strategist design**: Lean prompt (story IDs + workbook summaries only, no full diffs), synchronous call, Opus model, fallback to priority order on failure. Correct scope: parallel mode only, sequential mode untouched.
- **Model matrix documented**: US-003 added a `### Model Matrix` subsection to CLAUDE.md listing all agent roles — useful single-source reference.
- **Fastest small story on record**: US-002 at 29 seconds.

### What Didn't Go Well
- **No negative patterns this run.** All three workbooks report zero blockers. The feature was entirely prompt/markdown changes.

### Patterns Observed
- **Role-based routing fully realized**: Haiku for simple workers, Sonnet for complex workers, Opus for the new Merge Strategist. Architecture now has a full three-tier model matrix rather than a flat Sonnet-for-everything design.
- **Prompt-only repos remain the fast path**: 3rd consecutive retro on takt itself — no build/test overhead, all stories complete in under 3 minutes combined.
- **install.sh sync gap persists**: US-001 notes that the installed `~/.claude/lib/takt/run.md` was updated manually in-place rather than via `./install.sh`. This is now a confirmed recurring pattern (carried 3x).
- **takt-prd.md action item resolved**: `commands/takt-prd.md` no longer exists in the repo — the deletion was completed without an explicit story, likely during a previous cleanup pass.

### Action Items
- [ ] [carried 3x] Run `./install.sh` to deploy updated prompts to `~/.claude/lib/takt/` — manual sync used again this run (US-001 workbook). Suggested story: Add a post-implementation step to run.md that reminds the session agent to run ./install.sh when lib/ files are modified
- [ ] [carried 3x] Verify `start takt` end-to-end on a real project to confirm unified orchestration works as expected. Suggested story: Run takt against a simple 2-story feature on dua-cs-agent, confirm workers complete and PR is created
- [ ] Verify Merge Strategist placeholder in run.md is filled correctly at runtime — US-003 notes the prompt uses `<list of story IDs, dependencies, and workbook summaries>` as a placeholder that the orchestrator fills in by reading workbooks

### Metrics
- Stories completed: 3/3
- Stories blocked: 0
- Total workbooks: 3
- Story durations: US-001=91s (medium), US-002=29s (small), US-003=179s (medium)
- Previous action items carried: 2 (install.sh at 3x, end-to-end verification at 3x)
- Previous action items resolved: 1 (takt-prd.md deletion — file no longer exists)
