# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| potential | Opus too slow for worker agents | 2026-02-19 | 2026-02-19 |
| potential | Workbook generation inconsistent across workers | 2026-02-19 | 2026-02-19 |
| potential | Stale workbooks accumulate across runs | 2026-02-19 | 2026-02-19 |

---

## Retro: 2026-02-19 — takt/scenario-verification

### What Went Well
- **Rename was surgical and complete** (US-001): Broad grep found all references including install.sh and docs/dua-v2-planning.md — no stale `prd.json` mentions left in active prompt files. The `replace_all` approach was efficient.
- **Sonnet workers were fast**: US-002 through US-004 completed in ~1-3 minutes each on Sonnet 4.6. The prompt-only nature of this feature (no app code, just markdown edits) was a good fit for the model.
- **Clean linear execution**: 4 stories, linear dependencies, all passed first attempt. Zero retries needed.
- **Scenario generation instructions are well-documented** (US-002): Included good/bad examples, 7 rules, and a writing guide — should produce quality scenarios in future `/takt` runs.

### What Didn't Go Well
- **Opus was too slow for US-001**: The Opus worker completed all edits and verification but took 30+ minutes before being manually interrupted. Had to stop the agent, manually commit its work, and switch to Sonnet for remaining stories. This wasted significant time.
- **Workbook inconsistency**: US-001 and US-002 have workbooks. US-003 and US-004 from the scenario-verification run do not have workbooks in `.takt/workbooks/` (the workers may not have written them, or they were committed differently). This means retro data is incomplete for half the run.
- **Stale workbooks from prior run**: Workbooks US-003, US-004, US-005 in `.takt/workbooks/` are from the previous takt v2 native execution run, NOT from this run. They were never cleaned up because `takt retro` wasn't run after that execution.

### Patterns Observed
- **Prompt-only features execute fast**: When stories only modify markdown files (no app code, no tests, no builds), Sonnet completes them in 1-3 minutes. Good candidate for default model selection.
- **Model selection matters**: The gap between Opus (~30min timeout) and Sonnet (~2min) for prompt-editing stories is dramatic. Workers should default to Sonnet unless the story requires deep reasoning.
- **Workbook hygiene needs enforcement**: Two runs' worth of workbooks accumulated because retro wasn't run between them. The new cleanup step in retro.md should prevent this going forward.

### Action Items
- [ ] Default worker model to Sonnet — only use Opus for stories explicitly marked as complex reasoning tasks
- [ ] Investigate why US-003 and US-004 workers didn't produce workbooks — may need stricter enforcement in worker.md
- [ ] Run `takt retro` after every execution to prevent workbook accumulation (consider adding a reminder to solo.md completion output)

### Metrics
- Stories completed: 4/4
- Stories blocked: 0
- Retries: 0 (US-001 was manually rescued, not auto-retried)
- Total workbooks analyzed: 5 (2 from this run, 3 from prior run)
- Execution time: ~45 min total (30 min wasted on Opus, ~15 min actual work on Sonnet)

---

## Retro: 2026-02-19 — takt v2 native execution (retroactive)

*Note: These workbooks (US-003, US-004, US-005) were not analyzed after the original run. Capturing observations now.*

### What Went Well
- **Retro agent got self-improvement** (US-003): Added early-exit, `.takt/` path consolidation, and workbook cleanup — eating our own dogfood.
- **PRD generation got leaner** (US-004): Reduced story count targets (3-5 not 7-10), capped ACs at 3-4, added anti-patterns. Should reduce over-specification in future PRDs.
- **Clean removal of dead code** (US-005): bin/takt.sh, bats tests, and fixtures removed. install.sh updated with cleanup logic for existing installations.

### What Didn't Go Well
- **No retro was run after this execution** — workbooks sat in `.takt/workbooks/` until now, mixing with the next run's workbooks.

### Patterns Observed
- Self-referential features (takt improving takt) execute cleanly because the agent understands the codebase deeply by the time it reaches later stories.

### Action Items
- [ ] (Addressed) Workbook cleanup now built into retro.md — should prevent accumulation going forward.

### Metrics
- Stories analyzed retroactively: 3 (US-003, US-004, US-005)
