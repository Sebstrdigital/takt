# Takt — Future Improvements

Ideas and risk mitigations to revisit after real-world usage. Don't implement until the need is proven through `takt retro` findings.

---

## Lights-Out Factory — Gap Report (2026-02-21)

**Vision:** Human sets intent, approves spec, merges final PR. Everything between is autonomous.

### Current State

```
Human: "Build X"
  → PRD gates (why/what/what not — human approves)
  → stories.json + scenarios (human reviews)
  ━━━━ LIGHTS OUT ━━━━━━━━━━━━━━━━━━━
  │ Execute (solo/team)              │
  │ Verify scenarios (up to 3 fixes) │
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  → Human manually creates PR
  → Human merges
  → Human runs retro
```

### Target State

```
Human: "Build X"
  → PRD gates (human approves spec)
  → stories.json (human approves scope)
  ━━━━ LIGHTS OUT ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  │ Execute (solo/team)                          │
  │ Verify scenarios (behavior — up to 3 fixes)  │
  │ Review code (quality — up to 2 fixes)        │
  │ Create PR (structured body + run summary)    │
  │ Retro (auto-triggered, feeds next run)       │
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  → Human merges PR (or auto-merge if CI green)
```

### Gaps (in implementation order)

#### Gap 1: Code Review Agent

**What:** Read-only Sonnet agent that reviews the final codebase after scenario verification passes. Checks naming, patterns, duplication, security hygiene, consistency with project conventions (CLAUDE.md). Produces structured review comments.

**Design:**
- Runs once after verification passes (not per-story — too expensive)
- Read-only agent, never writes code
- Output: `review-comments.json` with file, line, severity (must-fix / suggestion), comment
- Only `must-fix` items trigger a fix loop; suggestions go into PR body as notes

**Open question:** Should this reuse the verify-fix loop pattern (spawn fresh fix workers from review comments) or a simpler single-pass fix agent?

#### Gap 2: Review-Fix Loop

**What:** When the review agent finds must-fix issues, spawn fresh workers to address them. Same Ralph Wiggum pattern — fix workers get review comments (behavioral descriptions of quality issues), not the full review context.

**Design:**
- Max 2 cycles (review → fix → re-review → fix → final review)
- If must-fix items remain after 2 cycles, include them in PR body as known issues
- Suggestions are never fixed automatically — they're informational

#### Gap 3: Automated PR Creation

**What:** After verification + review pass, automatically create a PR using `gh pr create` with a structured body generated from run artifacts.

**PR body structure:**
- Summary (from PRD intro)
- Stories completed (from stories.json)
- Verification results (pass/fail counts, fix cycles needed)
- Review notes (suggestions from review agent)
- Run metrics (time, stories, commits)
- Link to retro if available

**Design:**
- Orchestrator runs `gh pr create` as final step before completion signal
- PR targets the base branch (usually `main`)
- Draft PR if any review suggestions exist; ready PR if clean

#### Gap 4: Auto-Retro

**What:** Retro runs automatically after PR creation instead of requiring the user to say "takt retro". The retro entry is committed to the PR branch so it's included in the PR.

**Design:**
- Orchestrator spawns retro agent as final step after PR creation
- Retro agent reads workbooks, generates entry, commits to branch
- PR body updated with retro summary (or retro is a separate commit on the branch)

#### Gap 5: CI-Aware Merge (optional, furthest out)

**What:** If the project has CI configured, wait for CI to pass on the PR before signaling completion. If CI fails, attempt automated fix (read CI logs → spawn fix worker → push → re-check).

**Design:**
- Poll `gh pr checks` after PR creation
- If all checks pass → signal complete (or auto-merge if configured)
- If checks fail → read failure logs, spawn fix worker, push, re-poll (max 2 attempts)
- If still failing → flag for human in PR comment

**When to implement:** Only after Gaps 1-4 are stable. CI integration adds external system dependency.

### Implementation Priority

| Gap | Effort | Impact | Priority |
|-----|--------|--------|----------|
| 1. Code review agent | Medium | High — quality gate | First |
| 2. Review-fix loop | Small | High — closes the loop | Second (with #1) |
| 3. Automated PR | Small | High — removes manual step | Third |
| 4. Auto-retro | Small | Medium — convenience | Fourth |
| 5. CI-aware merge | Large | Medium — full automation | Last |

Gaps 1+2 are one PRD. Gap 3 could be a second small PRD. Gap 4 is a single story. Gap 5 is its own PRD.

---

## Orchestrator Redundancy

**Risk:** Scrum master (Opus 4.6) is a single point of failure. Bad decisions cascade.

**Potential mitigation:** Second Opus 4.6 agent reviewing key decisions (merge order, retry strategy, story assignments). Consensus mechanism — if both agree, proceed; if they disagree, flag for human.

**When to implement:** When retro entries show orchestrator mistakes causing wave failures or wasted retries.

**Cost consideration:** Doubles Opus 4.6 token usage for orchestration. Only worth it if orchestrator errors are frequent enough to justify the cost.

---

## Dynamic Wave Starts

**Risk:** Wave rigidity — all stories in wave N must complete before wave N+1 starts. Fast stories cause idle agents.

**Potential mitigation:** Allow wave N+1 stories to start as soon as their specific `dependsOn` stories are merged, rather than waiting for the entire wave. Scrum master would track per-story readiness instead of per-wave.

**When to implement:** When retro entries show significant idle time between waves.

**Complexity:** Increases merge planning complexity. Stories from different waves could be in-flight simultaneously.

---

## Drift Detection

**Risk:** Orchestrator or agents hallucinate progress, claim things work when they don't.

**Potential mitigation:** Automated checks that compare agent claims against reality:
- Agent says "tests pass" → verify by actually running tests independently (haiku agent)
- Agent says "file modified" → verify file was actually changed in git diff
- Token usage spike without corresponding git commits → flag as potential drift

**When to implement:** When retro entries show agents claiming false completion.

---

## Fail-Fast on Spec Problems

**Risk:** 2 retries is wasteful when the root cause is a bad spec, not bad implementation.

**Potential mitigation:** Scrum master categorizes failure reason before retrying:
- `implementation_error` → retry makes sense
- `spec_unclear` or `spec_impossible` → fail fast, flag for human immediately, don't burn retries

**When to implement:** When retro entries show retries consistently failing with the same root cause.

---

## Separate risks.md

**Risk:** Active alerts section in `retro.md` grows too large to scan.

**Potential mitigation:** Split alerts into dedicated `risks.md` with full lifecycle tracking, cross-references to retro entries, and trend graphs.

**When to implement:** When active alerts exceed ~10 items.

---

## Workbook Agent ID Resume

**Risk:** Agent context window fills up during complex stories, losing ability to help with merge conflicts.

**Potential mitigation:** Workbooks store agent ID. Agent can be shut down and a new agent can be spawned that reads the workbook to reconstruct context. Not as good as preserved context, but better than nothing.

**When to implement:** When retro entries show agents unable to help with merge conflicts due to context limits.

---

## Cost Tracking Per Story/Run

**Idea:** Track token cost per story and per full takt run. Display cost in the retro summary alongside time estimates.

**Benefit:** Helps users understand the cost/story trade-off for `inline` vs `deep` verification and `solo` vs `team` mode. Improves ETA accuracy for future estimates.

**When to implement:** When users start asking "how much did this run cost?" regularly.

---

## Lightweight Roadmap and State Files

**Idea:** Optional `ROADMAP.md` for near-term milestones and `STATE.md` for current focus, decisions, and blockers. Keep them small and updated during iteration cadence.

**When to implement:** When teams running takt want a lightweight planning artifact alongside stories.json.

---

## Optional Per-Story Plan Artifact

**Idea:** Store a short task list per story in `plans/` or `PLAN.md` before implementation begins. Keep steps atomic to reduce variance across iterations. Use as a reference when a story spans multiple files.

**When to implement:** When retro entries show agents making poor implementation ordering decisions.

---

## Phase Wrapper Checklist

**Idea:** Lightweight phase folders (e.g., `phases/01/`) with a checklist template to enforce consistency across iterations: discuss → plan → execute → verify. Allows batching stories while keeping context fresh.

**When to implement:** When teams need more structure around story execution phases.

---

## Per-Iteration Summary Artifact

**Idea:** Short `SUMMARY.md` per iteration capturing what changed and how it was verified. Useful for later review and as a restart point if context is lost.

**When to implement:** When retro entries show difficulty reconstructing what happened in a previous iteration.

---

## Per-Story Verification Notes

**Idea:** Minimal checklist or `verifications/` entry per story that ties acceptance criteria to actual verification steps and outcomes. Provides traceable QA records.

**When to implement:** When deep verification failures are hard to diagnose because verification steps aren't recorded.

---

## Track Deep Verification Status Per Story

**Idea:** Add a `deepVerified` field to user stories in stories.json. Skip re-verifying stories that already passed deep verification. Reset `deepVerified` to false if the story changes after verification.

**When to implement:** When full re-verification runs after small changes waste significant tokens.

---

## Better Error Recovery When Iteration Fails Mid-Story

**Idea:** When a worker agent fails mid-story (crashes, context exceeded, tool error), the orchestrator should resume from a checkpoint rather than re-running the full story. Workbook state could serve as the checkpoint.

**When to implement:** When retro entries show wasted work from mid-story failures.

---

## Integration with GitHub Issues and PRs

**Idea:** Automatically create or link GitHub Issues for each story, and open a PR when takt completes. Stories would reference their Issue number; completion updates the Issue.

**When to implement:** When teams want takt execution visible in their existing GitHub workflow.

---

## Web Dashboard for Monitoring

**Idea:** A lightweight web UI showing live takt run progress: stories status, wave progress, time elapsed, estimated completion. Could read from stories.json directly.

**When to implement:** When teams running `takt team` want visibility into parallel agent progress beyond terminal output.

---

## Slack and Discord Notifications on Completion

**Idea:** Send a completion notification to a Slack or Discord channel when a takt run finishes, including a summary of stories completed and any failures.

**When to implement:** When teams want async visibility into takt runs without watching the terminal.

---

## Auto-Improvement of Skills

**Idea:** Project skills may evolve to be better than the source skills in `~/.claude/lib/takt/`. Need a mechanism to surface improvements back to the source so future projects benefit.

**When to implement:** When retro entries show consistent project-level skill improvements that would benefit all projects.

---

## Bidirectional Skill Sync

**Idea:** The current install pattern overwrites installed skills with source. Consider a merge strategy that preserves project-specific improvements when upgrading, rather than overwriting.

**When to implement:** When projects have made meaningful improvements to their local skill copies that would be lost on upgrade.

---

## Completion Summary with Verified Metrics and Qualitative Analysis

**Idea:** Generate a rich completion summary when all stories pass. Two parts:
- **Verified metrics (from git/tools, not LLM):** story count, commit count, lines changed, files changed, test results, total time
- **Qualitative analysis (from LLM):** implementation quality observations, workflow notes, key decisions

**When to implement:** When retro entries show demand for a post-run summary artifact beyond the workbooks.
