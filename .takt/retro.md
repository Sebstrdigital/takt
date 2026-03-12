# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Spawned agents cannot use Bash or spawn sub-agents — intermediary orchestrator pattern is non-functional | 2026-03-07 | 2026-03-07 |
| mitigated | Prompt bloat — solo.md/team-lead.md embed ~9KB of instructions that agents can read from disk | 2026-03-07 | 2026-03-07 |
| mitigated | Workers cannot git commit — bypassPermissions mode only grants file edit access, not Bash | 2026-03-07 | 2026-03-07 |

---

## Retro: 2026-03-12 — takt/scrum-vocabulary-redesign

### What Went Well
- **4/4 stories completed, zero blockers across all workbooks.** Clean execution on a well-scoped rename/restructure run.
- **install.sh glob loop required no changes for US-003 and US-004**: The existing `for f in commands/*.md` pattern automatically picks up new command files — no manual wiring needed. Demonstrates the value of convention over configuration in install.sh.
- **Cross-story naming consistency maintained**: US-001 renamed `stories.json` → `sprint.json`, US-002 introduced `/feature` and `/sprint`, US-003 introduced `/epic`, US-004 created `/takt` as the unified entry point — vocabulary chain (Epic → Feature → Sprint) is consistent end-to-end.
- **Artifact detection hierarchy in US-004 was well-reasoned**: `sprint.json` > `tasks/feature-*.md` > `tasks/epic-*.md` > none, preventing the user from being pushed backward in the flow if they've already progressed further.

### What Didn't Go Well
- **No negative patterns this run.** All 4 workbooks report zero blockers. Scope was well-defined markdown-only changes — the ideal case for takt.

### Patterns Observed
- **Scrum vocabulary redesign was a coordinated multi-file rename**: US-001 required updating 14+ source files plus installed copies. Having workers handle both source and installed copies in the same story avoided a second pass.
- **Old command files left in repo (takt-prd.md, takt.md-old) with deferred cleanup**: US-002 notes that `commands/takt-prd.md` still exists in the repo as a historical source. Post-merge cleanup may be needed.
- **Prompt-only repos remain the fast path**: 7th consecutive retro confirming this. No build/test overhead, all stories complete quickly.
- **Entry-point wrapper pattern (US-004) as a UX improvement**: `/takt` as a context-aware entry point that detects existing artifacts and presents targeted options is a strong UX pattern — applicable to future multi-step workflows.

### Action Items
- [ ] [carried 1x] Run `./install.sh` to deploy updated prompts to `~/.claude/lib/takt/` (updated files were deployed manually this run, but install.sh should be re-run to ensure consistency)
- [ ] [carried 1x] Verify `start takt` end-to-end on a real project to confirm the unified orchestration works
- [ ] Delete `commands/takt-prd.md` from the repo — replaced by `commands/feature.md`, no longer needed as a source file

### Metrics
- Stories completed: 4/4
- Stories blocked: 0
- Total workbooks: 4
- Previous action items carried: 2 (install.sh deploy, end-to-end verification)
- Previous action items addressed: 0 (neither was addressed this run)
