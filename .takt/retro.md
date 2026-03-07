# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Spawned agents cannot use Bash or spawn sub-agents — intermediary orchestrator pattern is non-functional | 2026-03-07 | 2026-03-07 |
| mitigated | Prompt bloat — solo.md/team-lead.md embed ~9KB of instructions that agents can read from disk | 2026-03-07 | 2026-03-07 |
| mitigated | Workers cannot git commit — bypassPermissions mode only grants file edit access, not Bash | 2026-03-07 | 2026-03-07 |

---

## Retro: 2026-03-07 — takt/prompt-refactor

### What Went Well
- **4/4 stories completed, clean execution.** Unified orchestrator (US-001), pointer prompts (US-002), worker scope fix (US-003), and routing/install updates (US-004) all delivered.
- **All 6 previous action items addressed** — including 2 items that had been carried twice. The prompt-refactor run was purpose-built to resolve the previous retro's findings.
- **82% prompt reduction**: run.md is ~180 lines vs ~987 combined in the old solo.md + team-lead.md (US-001 workbook). Pointer-based spawns keep worker prompts under 1KB.
- **No blockers across any story** — all 4 workbooks report zero blockers. The scope was well-defined and the stories were properly decomposed.
- **Cross-story alignment was tight**: US-001 created run.md assuming workers don't git commit, US-003 made that explicit in worker.md, US-002 verified the pointer pattern, US-004 wired up routing. No conflicts or rework needed.

### What Didn't Go Well
- **No negative patterns observed this run.** All stories completed without blockers or workarounds. The run was scoped to markdown-only changes in a prompt-only repo, which is the ideal case for takt.

### Patterns Observed
- **Retro-driven PRDs produce focused runs**: Every story in this run traced directly to a previous retro action item or alert. The retro-to-PRD pipeline generated a clean, no-waste backlog.
- **Prompt-only repos remain the fast path**: 6th consecutive retro confirming this. All stories are markdown edits, all complete quickly, no build/test overhead.
- **Session-agent-as-orchestrator is now canonical**: US-001 formally codified the pattern discovered in the previous run. The intermediary orchestrator layer is eliminated.
- **Backward compatibility preserved**: US-002 kept embedded-diff fallback in reviewer.md; US-004 kept `takt solo`/`takt team` as deprecated aliases. No breaking changes.

### Action Items
- [ ] Run `./install.sh` to deploy run.md and updated prompts to `~/.claude/lib/takt/`
- [ ] Delete `lib/solo.md` and `lib/team-lead.md` from the repo (run.md replaces them)
- [ ] Verify `start takt` end-to-end on a real project to confirm the unified orchestration works

### Metrics
- Stories completed: 4/4
- Stories blocked: 0
- Total workbooks: 4
- Previous action items addressed: 6/6 (including 2 carried-2x items)
