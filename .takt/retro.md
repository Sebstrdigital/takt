# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| mitigated | Opus too slow for worker agents | 2026-02-19 | 2026-02-21 |
| mitigated | Workbook generation inconsistent across workers | 2026-02-19 | 2026-02-21 |
| mitigated | Stale workbooks accumulate across runs | 2026-02-19 | 2026-02-21 |

---

## Retro: 2026-02-21 — takt/v3-refinements

### What Went Well
- **All 5 stories passed first attempt, zero retries**: Clean execution across the board. Every worker produced a workbook and committed successfully.
- **Sonnet workers were fast** (US-001, US-003): Both completed in ~4 minutes. US-002 in ~2 minutes. US-004 in ~6 minutes. Confirms the Sonnet default decision from the previous retro.
- **Zero blockers across all 5 workers**: No permission issues, no file conflicts, no merge problems. Previous retro's Bash permission denial pattern was not observed.
- **Workbook quality improved**: All 5 workers produced well-structured workbooks with clear decisions, files changed, and verification sections. The workbook-inconsistency alert from the previous retro appears resolved.
- **US-005 handled complex multi-part task well**: Merged 14 items from 2 source docs, deleted 5 stale docs, updated 2 prompt files with BDD guidance — all in one story without confusion.

### What Didn't Go Well
- **Solo mode ran parallel despite "solo" name**: The orchestrator spawned US-001, US-003, US-004 concurrently and then US-002, US-005 concurrently. Solo mode is documented as "sequential" but the orchestrator optimized by parallelizing independent stories. This isn't a bug per se, but the naming creates false expectations.
- **US-005 was the slowest at ~6 minutes**: This story had 4 acceptance criteria touching 7+ files across docs, commands, and future-improvements.md. It was the largest story and could have been split.
- **Retention policy not yet installed**: The workers added the retention policy to `lib/retro.md` (source), but the installed version at `~/.claude/lib/takt/retro.md` still lacks it. The retro agent running NOW is using the old prompt without steps 5-6.

### Patterns Observed
- **Prompt-only features consistently fast on Sonnet**: 3rd consecutive retro confirming this pattern. All 5 stories were markdown-only edits and completed in 2-6 minutes each.
- **Self-referential work (takt improving takt) executes cleanly**: Workers modifying their own prompt files had no issues — they can read and edit the prompts without confusion.
- **Parallel solo execution**: The solo orchestrator naturally parallelized independent stories despite "solo" implying sequential. This is actually beneficial for throughput — worth documenting as intended behavior or renaming.
- **5 workers, 0 file conflicts**: Despite US-001 and US-002 both touching team-lead.md, the dependency chain (US-002 depends on US-001) prevented conflicts. Wave ordering works.

### Action Items
- [x] Run `./install.sh` to deploy updated prompts (retention policy, git discipline, model defaults) to `~/.claude/` (2026-03-02)
- [x] Clarify solo mode's parallelization behavior in solo.md documentation — documented as "parallel where possible" (2026-03-02)
- [ ] Consider splitting stories with 4+ acceptance criteria and 7+ files (like US-005) into smaller units in future PRDs

### Metrics
- Stories completed: 5/5
- Stories blocked: 0
- Total workbooks: 5
- Verification: 15/15 scenarios confirmed (deep verification on US-005)
- Execution time: ~11 minutes total (09:53 — 10:04)
- Worker times: US-001 ~4min, US-002 ~2min, US-003 ~4min, US-004 ~6min, US-005 ~6min
