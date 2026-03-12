# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Spawned agents cannot use Bash or spawn sub-agents — intermediary orchestrator pattern is non-functional | 2026-03-07 | 2026-03-07 |
| mitigated | Prompt bloat — solo.md/team-lead.md embed ~9KB of instructions that agents can read from disk | 2026-03-07 | 2026-03-07 |
| mitigated | Workers cannot git commit — bypassPermissions mode only grants file edit access, not Bash | 2026-03-07 | 2026-03-07 |
| confirmed | install.sh not re-run after prompt updates — manual sync is error-prone | 2026-03-07 | 2026-03-12 |
| confirmed | No end-to-end verification of `start takt` on a real project after orchestrator unification | 2026-03-07 | 2026-03-12 |

---

## Retro: 2026-03-12 — takt/planning-flow-redesign

### What Went Well
- **6/6 stories completed, zero blockers.** Clean run across all six stories.
- **US-001** transformed `/epic` into a full-session planning coordinator — sequential Feature loop with wait-for-completion semantics and a `/sprint` handoff summary. Pure prompt change with no build overhead.
- **US-002** added concrete initiative-scope guidance to `/feature`: 4-8 story target, IMPORTANT note on decomposition responsibility, and a worked example (User Task Filtering and Sorting) with explanatory context.
- **US-003 + US-004** worked well as a two-story sequence: US-003 established the multi-doc merge capability in `/sprint`, US-004 added cross-Feature wave computation without duplicating work or conflicting with US-003's changes.
- **US-005 + US-006** similarly complemented each other: US-005 added the Quick Path interview, US-006 immediately hardened it with a story count guard (>5 → Feature doc warning) and a mandatory scenarios.json requirement.
- **Prompt-only repo remains the fast path**: 4th consecutive retro on takt itself — no build/test overhead.

### What Didn't Go Well
- **sprint.json timestamps are coarse placeholders** — all wave-1 stories share identical start/end times (00:15–00:20), making per-story duration stats unusable this run. Stats not updated to avoid polluting running averages.
- **install.sh sync gap continues**: None of the 6 workbooks mention running `./install.sh` to deploy updated commands to `~/.claude/commands/`. US-003, US-004, US-005 all note this in their "Notes for Merge" section — the gap is well-documented but unresolved.
- **End-to-end verification still not done**: No workbook references a real-project test of `start takt` with the updated planning commands.

### Patterns Observed
- **Epic → Feature → Sprint pipeline now fully wired**: The redesign delivers a cohesive pipeline. `/epic` loops all Features, `/feature` uses initiative scope, `/sprint` merges all Feature docs, `/takt` offers a quick path for small changes. Each command is now a proper handoff point.
- **Guard pattern appearing in prompt design**: US-006's story count guard (>5 stories → escalate to Feature doc) mirrors the pattern seen in previous runs where explicit validation gates prevent user mistakes. Likely to recur.
- **install.sh sync gap is now a structural issue**: Carried 4x. Every run that modifies `commands/` or `lib/` files hits this. Needs a story to resolve.

### Action Items
- [ ] [carried 4x] Run `./install.sh` to deploy updated prompts to `~/.claude/commands/` and `~/.claude/lib/takt/` — manual sync used again this run (US-003, US-004, US-005 workbooks all note it). Suggested story: Add a post-implementation step to run.md that reminds the session agent to run ./install.sh when commands/ or lib/ files are modified
- [ ] [carried 4x] Verify `start takt` end-to-end on a real project to confirm unified orchestration + updated planning commands work as expected. Suggested story: Run takt against a simple 2-story feature on dua-cs-agent, confirm workers complete and PR is created
- [ ] Verify Merge Strategist placeholder in run.md is filled correctly at runtime — workbook from previous run notes the prompt uses `<list of story IDs, dependencies, and workbook summaries>` as a placeholder that the orchestrator fills in by reading workbooks (carried from 2026-03-12 role-based-model-architecture run)

### Metrics
- Stories completed: 6/6
- Stories blocked: 0
- Total workbooks: 6
- Story sizes: US-001 small, US-002 small, US-003 medium, US-004 medium, US-005 medium, US-006 small
- Story durations: not recorded (coarse placeholder timestamps, all 5-min blocks)
- Previous action items carried: 3 (install.sh at 4x, end-to-end verification at 4x, Merge Strategist at 1x)
- Previous action items resolved: 0
