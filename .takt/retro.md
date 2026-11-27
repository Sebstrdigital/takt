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

---

## Retro: 2026-11-27 — takt/review-lenses-devops

### What Went Well
- 5/5 stories passed on first attempt (attempts=1 each), smallest at 12s (US-002), largest 63s (US-001); the parallel wave of US-001/US-003 merged in 8s.
- Gate cycle 1 found real defects verification missed: run_timeout did not enforce a deadline (MF-002), HTTPS userinfo could leak into hints (MF-010), a security-declined relay overwrote review history (MF-006), PASSED accepted after a declined security lens (MF-009). All fixed in 10 sequential fix workers (287s total).
- Workers recorded environment-vs-code distinctions (gh_push FAIL because the active gh account lacks push, MF-001/US-003/US-004 workbooks).

### What Didn't Go Well
- First Workflow run failed verification: `.takt/scenarios.json` was missing because sprint.json was hand-written, not generated by /sprint. Costly re-run needed a patch to takt-run.js (c5d692b) to allow an empty stories list.
- Gate ended BLOCKED after 2 cycles (823s of the run) with 9 open must-fix items; triage put 4 as follow-ups and 5 plus SF-001 as scope creep. Cycle 2 raised new items (MF-011 to MF-017) rather than converging.
- Unattributed overhead was 1826s, mostly the gap between the verify re-run and manual steps around the two Workflow runs.

### Patterns Observed
- Fresh gate cycles keep surfacing new edge cases in the same new script (lib/devops-checks.sh: MF-001, 002, 007, 010, 011, 013, 017) — a new shell script with network/auth parsing attracts many findings.
- Prompt-doc changes drifted from CLAUDE.md (MF-015), same install/sync-style drift seen in the 2026-03-14 retro.

### Tooling issues
- Installed takt-run.js path was refused as Workflow scriptPath (outside working dir); the repo copy was used (run-report toolingIssues).
- Hand-written sprint.json bypasses scenario generation; takt-run.js/run.md do not detect a missing scenarios.json until verify fails.
- Active gh account sebstr-dg was not a collaborator; PR created with Sebstrdigital token (run-report toolingIssues).
- Workers' worktree sandbox refused compound git commands (US-001 workbook).

### Project follow-ups
- Treat a Workflow gate result as PASSED only when no must-fix findings remain open (lib/takt-run.js:635, MF-016).
- Update CLAUDE.md lines 42 and 134 to describe the Codex relay gate with Sonnet fallback (MF-015).
- Add a stop and report branch in run.md Phase 0 for a preflight that exits before producing check results (MF-012).
- Reject malformed sprint data in run.md's normal start path instead of treating it as a verify-and-review rerun (MF-014).

### Metrics
- Stories: 5/5 passed, 0 blocked; retried on heavy: 0 (blocked after retry: 0)
- Total workbooks: 15
- Avg story duration: 30s (small), 63s (medium), n/a (large)
- Verify: 2 cycles, 70s total
- Gate: 2 cycles, 823s total
- Fix workers: 10, 287s total
- Merge/commit agents: 2, 9s total
- Unattributed overhead: 1826s

---

## Retro: 2026-11-27 — takt/review-scope

### What Went Well
- All 5 stories passed; 4 of 5 on the first attempt. Verify passed in 1 cycle both times (24s and 21s) with scenarios present.
- Workers recorded decisions with file references (US-002 verified model name against skeptic.md:5; US-005 confirmed `notes` was already in the VERDICT schema), so no rework from misreading scope.
- MF-001 (cycle 2 fix range used stale `git log --grep` and missed untracked files) was caught by the gate and fixed with a per-cycle baseline.

### What Didn't Go Well
- US-002 needed the heavy retry: attempt 1 had correct edits but did not commit, treating the CLAUDE.md install.sh HARD RULE as a hard block (workbook US-002).
- The gate ended BLOCKED after 2 cycles in both Workflow runs, with MF-002 and MF-003 still open on edge cases in the fix-only re-review diff in lib/takt-run.js. Cycle 2 of the first run reviewed without the MF-001..004 fixes because the commit stage refused.
- Unattributed overhead was 2099s: the verify-only rerun and manual commit approval sat between the two Workflow runs.

### Patterns Observed
- Repeat from the previous entry: gate does not converge in 2 cycles and new must-fix items appear in cycle 2.
- Repeat: the story run needed a second, verify-only Workflow run.
- install.sh ask-before-commit rule blocks automated commits (US-002 attempt 1, US-004/US-005 workbooks all flag it).

### Tooling issues
- The Workflow review-fix commit stage refused to commit because of the install.sh ask-before-commit rule in CLAUDE.md (run-report.json: commits[review-1].committed=false, gate.note); needs a takt-run exception. The session agent committed as a750521 after user approval.
- US-002 attempt 1 hit the same rule in the story worker and cost a heavy retry.
- git push over ssh port 22 timed out once; the retry succeeded.

### Project follow-ups
- MF-002 and MF-003: edge cases in the fix-only re-review diff in lib/takt-run.js, left open by the gate.
- Commit stage and story workers should be allowed to commit prompt-source changes despite the install.sh rule.

### Metrics
- Stories: 5/5 passed, 0 blocked; retried on heavy: 1 (blocked after retry: 0)
- Total workbooks: 9
- Avg story duration: 37s (small, 4), 24s (medium, 1), n/a (large)
- Verify: 2 cycles, 45s total
- Gate: 4 cycles, 1071s total
- Fix workers: 5, 114s total
- Merge/commit agents: 2, 1s total
- Unattributed overhead: 2099s
