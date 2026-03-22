# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Spawned agents cannot use Bash or spawn sub-agents — intermediary orchestrator pattern is non-functional | 2026-03-07 | 2026-03-07 |
| mitigated | Prompt bloat — solo.md/team-lead.md embed ~9KB of instructions that agents can read from disk | 2026-03-07 | 2026-03-07 |
| mitigated | Workers cannot git commit — bypassPermissions mode only grants file edit access, not Bash | 2026-03-07 | 2026-03-07 |
| mitigated | install.sh not re-run after prompt updates — manual sync is error-prone | 2026-03-07 | 2026-03-14 |
| resolved | No end-to-end verification of `start takt` on a real project after orchestrator unification — validated through real use across multiple projects (kraken, uven, nettobrand, simplybrf, etc.) week of 2026-03-17 | 2026-03-07 | 2026-03-22 |

---

## Retro: 2026-03-14 — takt/orchestrator-resilience

### What Went Well
- **3/3 stories completed, zero blockers.** Clean run on a short resilience sprint.
- **US-001** (Surface retro alerts before sprint start) — new Phase 1 step in `run.md` reads `.takt/retro.md` and prints `[takt warn] <alert>` for each `confirmed` alert before the start line. Non-blocking; sprint proceeds regardless. Workers also synced the installed copy directly via `cp`, so the change is live immediately.
- **US-002** (Install.sh sync rule and shipping checklist) — resolved the install.sh action item carried 5x. CLAUDE.md now has a "Development Workflow" HARD RULE section with an explicit sync rule and shipping checklist (run install.sh, test real project, verify all phases). The sync rule is behavioral, matching the project's prompt-based architecture.
- **US-003** (Sequential fallback note in completion report) — `run.md` Phase 2 now sets `parallelFallback = true` when `TeamCreate` fails or parallel spawning is unavailable. Phase 7 report conditionally prints the fallback note with estimated extra minutes (from stats.json avg). Omitted entirely when parallel ran as expected or sequential was always intended.
- **Prompt-only repo, fast execution**: All 3 stories completed with zero blockers. Avg small story: 97s.
- **Workers self-synced the installed copy**: US-001 and US-003 both synced `~/.claude/lib/takt/run.md` directly via `cp` — install.sh wasn't needed because workers handled it.

### What Didn't Go Well
- **End-to-end verification still not done**: No workbook or sprint evidence shows `start takt` was tested on a real project after the changes. The shipping checklist now exists as a rule, but compliance hasn't been demonstrated.

### Patterns Observed
- **Carried items eventually become stories**: The install.sh item carried 5x before becoming a dedicated US-002. The pattern suggests that items carried 4+ times reliably get promoted to sprint stories — the escalation mechanism is working.
- **Resilience sprint pattern**: Small, defensive stories (surface alerts, explain fallback, enforce sync) addressing operational blind spots. Distinct from feature-building sprints; overhead lower, stories tighter in scope.

### Action Items
- [ ] [carried 5x] Verify `start takt` end-to-end on a real project to confirm unified orchestration + updated planning commands work as expected. Suggested story: Run takt against a simple 2-story feature on dua-cs-agent, confirm workers complete and PR is created
- [ ] [carried 2x] Verify Merge Strategist placeholder in run.md is filled correctly at runtime — workbook from previous run notes the prompt uses `<list of story IDs, dependencies, and workbook summaries>` as a placeholder that the orchestrator fills in by reading workbooks (carried from 2026-03-12 role-based-model-architecture run). Suggested story: Trace run.md merge-planning section and confirm placeholder substitution is implemented or remove it

### Metrics
- Stories completed: 3/3
- Stories blocked: 0
- Total workbooks: 3
- Story sizes: US-001 small (95s), US-002 small (80s), US-003 small (115s)
- Avg small story duration: 97s
- Phase overhead: ~410s (estimated, retro start vs last story endTime)
- Previous action items resolved: 1 (install.sh sync — addressed by US-002)
- Previous action items carried: 2 (end-to-end verification at 5x, Merge Strategist at 2x)
