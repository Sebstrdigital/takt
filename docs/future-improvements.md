# Takt — Future Improvements

Ideas and risk mitigations to revisit after real-world usage. Don't implement until the need is proven through `takt retro` findings.

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
