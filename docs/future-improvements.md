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
