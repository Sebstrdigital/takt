# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Spawned agents cannot use Bash or spawn sub-agents — intermediary orchestrator pattern is non-functional | 2026-03-07 | 2026-03-07 |
| mitigated | Prompt bloat — solo.md/team-lead.md embed ~9KB of instructions that agents can read from disk | 2026-03-07 | 2026-03-07 |
| mitigated | Workers cannot git commit — bypassPermissions mode only grants file edit access, not Bash | 2026-03-07 | 2026-03-07 |

---

## Retro: 2026-03-12 — takt/story-complexity-classification

### What Went Well
- **2/2 stories completed, zero blockers.** Clean, fast run on a well-scoped documentation-only change.
- **Binary complexity model (simple/complex) chosen over three tiers**: US-001 explicitly rejected a third tier — keeping classification unambiguous and sufficient for model routing. Pragmatic scoping decision.
- **Default of "complex" is safer**: US-001 documents the default as `"complex"` (safer to over-provision than under-provision), a sensible conservative default that avoids silent quality regressions.
- **Documentation-only stories are the fastest path**: Both stories were pure markdown changes — no build, no typecheck, no test overhead. Completed with zero friction.

### What Didn't Go Well
- **No negative patterns this run.** Both workbooks report zero blockers. Scope was entirely markdown documentation — the ideal case for takt.

### Patterns Observed
- **Schema-then-docs pattern**: US-001 updated the schema definition (sprint.md command), US-002 updated the user-facing docs (CLAUDE.md, README.md). This two-story decomposition cleanly separates "define the field" from "explain the field."
- **Prompt-only repos remain the fast path**: 8th consecutive retro confirming this. No build/test overhead, all stories complete quickly.
- **Three previous action items still unaddressed**: Neither install.sh deployment, end-to-end verification, nor takt-prd.md deletion were addressed this run (out of scope for a documentation sprint).

### Action Items
- [ ] [carried 2x] Run `./install.sh` to deploy updated prompts to `~/.claude/lib/takt/` (updated files were deployed manually this run, but install.sh should be re-run to ensure consistency)
- [ ] [carried 2x] Verify `start takt` end-to-end on a real project to confirm the unified orchestration works
- [ ] [carried 1x] Delete `commands/takt-prd.md` from the repo — replaced by `commands/feature.md`, no longer needed as a source file

### Metrics
- Stories completed: 2/2
- Stories blocked: 0
- Total workbooks: 2
- Previous action items carried: 3 (install.sh deploy carried 2x, end-to-end verification carried 2x, takt-prd.md deletion carried 1x)
- Previous action items addressed: 0 (documentation sprint — none in scope)
