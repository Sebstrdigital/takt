# takt Lean Cleanup Plan — 2026-04-16

Based on: 17 retro files (Feb 21 – Apr 15), full codebase audit, 5 commits since last review (Mar 29).

---

## TL;DR

run.md grew from ~450 to 590 lines in 2.5 weeks. 4 quality gates after workers finish (verifier → reviewer → final-gate → local-validation). The reviewer and final-gate overlap significantly — merge them. Extract repeated boilerplate. Close the chronic-debt-to-sprint gap.

**Net effect:** -1 agent, -1 fix cycle, -140 prompt lines, better maintainability.

---

## 1. Merge Reviewer into Final Gate (HIGH — saves time + tokens)

**Problem:** Phase 4 (reviewer, Sonnet) and Phase 4b (final-gate, Opus) both read the same diff. Overlap:
- Reviewer checks "security hygiene" — final-gate has a full Security pass
- Reviewer checks "correctness" — final-gate's Adversary pass covers this deeper
- Both produce JSON output → both trigger fix cycles → double the fix overhead

**Proposal:** Absorb reviewer scope into final-gate as Pass 0. Delete reviewer.md.

New final-gate structure:
- **Pass 0: Convention & Quality** (former reviewer) — naming, dependencies, placeholders, duplication, accidental files, CLAUDE.md violations
- **Pass 1: SRE / Infrastructure** (unchanged)
- **Pass 2: Security** (unchanged, absorbs reviewer's "security hygiene")
- **Pass 3: Adversary** (unchanged)

All at Opus quality. One output file. One fix cycle.

**run.md changes:**
- Delete Phase 4 entirely (reviewer spawn, fix loop, re-diff)
- Rename Phase 4b → Phase 4
- Phase 4c → Phase 4b (renumber)
- ~50 lines removed from run.md

**Saves per run:**
- 1 agent spawn + TaskStop (~30-60s)
- 1 potential fix cycle (~2-5 min when must-fix items exist)
- Slightly higher Opus token cost vs Sonnet for convention checks, but marginal since Opus is already running

**Files affected:** run.md, final-gate.md, reviewer.md (deleted), install.sh (remove reviewer copy)

---

## 2. Extract Shared Tooling Boilerplate (MEDIUM — maintainability)

**Problem:** "Optional Tooling" block (~23 lines) is copy-pasted in 4 files: worker.md, reviewer.md (going away if #1 happens), verifier.md, final-gate.md. When tooling changes, 4 files must be updated.

**Proposal:** Create `~/.claude/lib/takt/tooling.md` — a shared reference file. Each agent prompt says:

```
## Optional Tooling
Read ~/.claude/lib/takt/tooling.md for optional tool configuration.
```

**Saves:** ~70 redundant lines (after reviewer deletion). One place to update when tools change.

**Files affected:** new tooling.md, worker.md, verifier.md, final-gate.md, install.sh

---

## 3. Simplify Phase 0 Config Block (MEDIUM — prompt weight)

**Problem:** Phase 0.1 (config creation) is 75 lines of AskUserQuestion YAML that runs ONCE per project, then is dead weight on every subsequent run. The session agent reads all 590 lines every run but only uses ~10 of those 75 lines after first run.

**Proposal:** Extract first-run config to a separate file `~/.claude/lib/takt/init.md`. Phase 0.1 becomes:

```
### 0.1 Ensure .takt/config.json exists
If `.takt/config.json` is missing or incomplete, read ~/.claude/lib/takt/init.md and follow its instructions.
```

**Saves:** ~65 lines from run.md (moved, not deleted). Faster comprehension on repeat runs.

**Files affected:** run.md, new init.md, install.sh

---

## 4. Close the Chronic Debt → Sprint Gap (MEDIUM — process)

**Problem:** Retros surface chronic items faithfully (nettobrand: 18, dikta: 10, uven: 6). The escalation mechanism writes "Suggested story: ..." but nothing feeds that into the next `/sprint` or `/feature`. Items just accumulate forever.

**Proposal:** Add a step to the `/sprint` command:

```
Before generating stories, check if .takt/retro.md exists.
If it has a "Chronic Tech Debt" section, extract items with carry count >= 5.
Present them to the user: "These chronic items have been carried N sprints. Include any as stories?"
```

**Files affected:** commands/sprint.md

---

## 5. Fix Stale sprint.json Cleanup (LOW — bug fix)

**Problem:** 3 projects have stale sprint.json files that retro should have deleted:
- simplybrf-wrapper/sprint.json (Mar 31)
- kraken-wrapper/kraken/sprint.json (Apr 3)  
- uven/sprint.json (Apr 16 — possibly active)

**Root cause:** Retro agent step 8 says "delete sprint.json" but the agent may fail silently or skip cleanup if an earlier step errors.

**Proposal:** Add a safety net — the orchestrator (run.md Phase 7) checks for and deletes stale artifacts after retro completes, rather than relying solely on the retro agent.

**Files affected:** run.md (Phase 7), retro.md (add explicit error handling to step 8)

---

## 6. Clean install.sh Legacy Cleanup Blocks (LOW — hygiene)

**Problem:** install.sh has 30 lines of cleanup for artifacts that no longer exist in any installation:
- dua-loop directory removal (lines 95-105)
- takt-prd.md rename (lines 107-112)  
- tdd.md removal (lines 114-119)
- dua-loop CLAUDE.md section (lines 121-124)
- takt.sh removal (lines 127-129)
- solo.md/team-lead.md/prompt.md removal (lines 137-142)

These are from 2+ months ago. Anyone still running old versions would have updated by now.

**Proposal:** Remove all legacy cleanup blocks. Add a comment with the date they were removed for git history reference.

**Files affected:** install.sh (~35 lines removed)

---

## 7. Delete Stale Artifacts Across Projects (LOW — hygiene)

Manual cleanup pass:
- `rm ~/work/git/simplybrf-wrapper/sprint.json`
- `rm ~/work/git/kraken-wrapper/kraken/sprint.json`
- Check if `~/work/git/uven/sprint.json` is from an active run before deleting

---

## Implementation Order

| Priority | Item | Effort | Impact |
|----------|------|--------|--------|
| 1 | Merge reviewer into final-gate | ~1hr | -1 agent, -1 fix cycle, -50 lines run.md |
| 2 | Extract tooling boilerplate | ~20min | -70 lines, better maintainability |
| 3 | Simplify Phase 0 config | ~20min | -65 lines from run.md |
| 4 | Chronic debt → sprint gap | ~15min | Process improvement |
| 5 | Fix stale cleanup | ~10min | Bug fix |
| 6 | Clean install.sh | ~5min | Hygiene |
| 7 | Delete stale artifacts | ~2min | Hygiene |

**Total: ~2.5hr for the full cleanup. Items 1-3 are the high-value ones.**

---

## What NOT to Cut

- **Verifier (Phase 3)** — fundamentally different scope (behavioral verification via scenarios). Not review.
- **Local validation (Phase 4c)** — runtime checks that no static review can replace. Optional and project-toggleable. Lean.
- **Retro agent** — solid, well-structured, earning its keep.
- **Worker prompt** — minimal at 91 lines. No fat.
- **Phase 0.2-0.4** (tool probes, indexing, local overrides, session.json) — all earn their keep.
- **Output discipline** — the silent-until-done pattern is a core takt strength.
- **stats.json / ETA estimation** — low overhead, high user value.

---

## Metrics After Cleanup

| Metric | Before | After |
|--------|--------|-------|
| run.md lines | 590 | ~460 |
| Agent files | 7 | 6 (-reviewer.md, +tooling.md, +init.md) |
| Quality gates | 4 (verifier, reviewer, final-gate, local-val) | 3 (verifier, review+gate, local-val) |
| Repeated boilerplate lines | ~120 | ~10 |
| Agent spawns per run | 4-5 | 3-4 |
| Fix cycles | 2 (review + gate) | 1 (unified) |
