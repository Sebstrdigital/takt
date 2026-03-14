# Feature: Merge Strategist Agent

## 1. Introduction / Overview

In parallel mode, the orchestrator (Sonnet) currently decides merge order on its own — a bounded but high-stakes reasoning task. A wrong decision causes merge conflicts and wasted retry cycles. This Feature adds a one-shot Opus agent (the Merge Strategist) that is spawned once per wave in parallel mode, receives full context (worktree diffs + wave dependencies), recommends a merge order, and is dismissed. The orchestrator executes merges in that order. Opus reasoning is justified here because it is one call per wave, not per story.

---

## 2. Goals

- Replace ad-hoc orchestrator merge ordering with a dedicated Opus reasoning agent
- Reduce merge conflicts in parallel runs by making order decisions with full diff context
- Keep Opus usage bounded: one call per wave, dismissed immediately after

---

## 3. User Stories

### US-001: Add Merge Strategist to parallel mode merge loop

**Description:** As a takt user running a parallel sprint, I want merge order to be decided by a reasoning agent with full context so that conflicts are minimised and merges succeed on first attempt more often.

**Acceptance Criteria:**
- [ ] In parallel mode, before each wave's merge loop begins, a one-shot Opus agent is spawned with the wave's worktree diffs and dependency graph
- [ ] The Merge Strategist outputs an ordered list of story IDs to merge, and the orchestrator merges in that order
- [ ] In sequential mode (no waves), the Merge Strategist is never spawned — behaviour is unchanged
- [ ] CLAUDE.md model matrix is updated to document the Merge Strategist role as Opus

---

## 4. Functional Requirements

- **FR-1:** The Merge Strategist is spawned only when `waves` is non-empty in sprint.json (parallel mode). Sequential runs are unaffected.
- **FR-2:** The Merge Strategist receives: list of story IDs in the current wave, their `dependsOn` relationships, and a summary of each worktree's changes (files modified, brief description from workbook).
- **FR-3:** The Merge Strategist outputs a single ordered list of story IDs — the recommended merge sequence. No other output is required.
- **FR-4:** The orchestrator merges worktrees strictly in the order returned by the Merge Strategist. If the Merge Strategist fails or times out, the orchestrator falls back to priority order (existing behaviour).
- **FR-5:** The Merge Strategist is spawned with `model: "opus"`, `subagent_type: "general-purpose"`, `mode: "bypassPermissions"`. It is not run in the background — the orchestrator waits for its response before beginning merges.
- **FR-6:** CLAUDE.md model matrix table must be updated to add a Merge Strategist row: `opus`, spawned once per wave in parallel mode.

---

## 5. Non-Goals (Out of Scope)

- Merge Strategist does not write output to a file — response is inline only
- No conflict resolution — existing retry logic handles merge failures
- No consensus mechanism (second Opus agent) — single Strategist only
- Sequential mode is completely unchanged

---

## 6. Technical Considerations

- The Merge Strategist prompt must be lean — pass only what it needs: story IDs, dependencies, and workbook summaries. Full diffs are too large and not necessary for ordering decisions.
- Workbook summaries are available at `.takt/workbooks/workbook-<STORY-ID>.md` — the orchestrator reads these to build the context packet before spawning the Strategist.
- Fallback to priority order on Strategist failure ensures no regression if the agent fails.

---

## 7. Success Metrics

- Parallel runs with waves spawn a Merge Strategist before each wave's merge loop
- Sequential runs are unaffected
- Merge conflicts in parallel runs decrease compared to before (observable via retro entries)

---

## 8. Open Questions

- Should the Merge Strategist's recommended order be logged to the workbook or retro for post-run auditability? Recommend yes — a single line in the retro entry noting the merge order used.
