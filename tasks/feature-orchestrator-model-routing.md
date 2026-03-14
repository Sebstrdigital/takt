# Feature: Orchestrator Model Routing

## 1. Introduction / Overview

The `complexity` field added in F-1 is currently inert metadata. This Feature activates it by updating `lib/run.md` so the orchestrator reads each story's `complexity` field when spawning workers and selects the appropriate model: `haiku` for simple stories, `sonnet` for complex ones (or when the field is absent). All other agents remain on Sonnet.

---

## 2. Goals

- Wire up the complexity field to actual model selection in worker spawning
- Route simple stories to Haiku (faster, lower token cost)
- Preserve existing behaviour for all stories without a complexity field (default to Sonnet)
- Update documentation to remove the "not yet active" caveat

---

## 3. User Stories

### US-001: Update orchestrator to route workers by complexity

**Description:** As a takt user, I want simple stories to run on Haiku and complex stories on Sonnet so that mechanical work completes faster and consumes fewer tokens.

**Acceptance Criteria:**
- [ ] When a story has `complexity: "simple"`, the orchestrator spawns its worker with `model: "haiku"`
- [ ] When a story has `complexity: "complex"` or no complexity field, the orchestrator spawns its worker with `model: "sonnet"`
- [ ] All other agents (verifier, reviewer, retro, debug) continue to use `model: "sonnet"` — only worker spawning is affected

---

### US-002: Update documentation to reflect live routing

**Description:** As a takt user, I want CLAUDE.md and README.md to accurately describe the complexity field as active so I understand what model each story will use.

**Acceptance Criteria:**
- [ ] CLAUDE.md complexity field description no longer says "not yet active" — describes the live routing behaviour
- [ ] README.md sprint.json row reflects that complexity now actively controls model selection

---

## 4. Functional Requirements

- **FR-1:** In `lib/run.md`, the Worker Prompt Template section must document that the model is selected based on `story.complexity`: `haiku` if `"simple"`, `sonnet` if `"complex"` or absent.
- **FR-2:** The Sequential Mode spawn instruction in `lib/run.md` must read: `model: story.complexity === "simple" ? "haiku" : "sonnet"` (or equivalent prose instruction).
- **FR-3:** Parallel Mode worker spawning in `lib/run.md` must apply the same complexity-based model selection.
- **FR-4:** Bug fix worker spawning (verify-fix loop) and review fix worker spawning remain `model: "sonnet"` — complexity routing applies to story workers only.
- **FR-5:** CLAUDE.md and README.md must be updated to remove the "not yet active" caveat from the complexity field description.

---

## 5. Non-Goals (Out of Scope)

- Merge Strategist agent (F-3)
- Automatic escalation from Haiku to Sonnet on story failure
- Model routing for verifier, reviewer, retro, or debug agents
- Changes to `lib/worker.md` or any other lib/ file beyond `lib/run.md`

---

## 6. Technical Considerations

- The Agent/Task tool accepts `model: "haiku"` or `model: "sonnet"` — these are the only values needed
- `lib/run.md` is a prompt file, not code — the routing instruction is written in prose ("if complexity is simple, use haiku; otherwise use sonnet")
- The installed copy at `~/.claude/lib/takt/run.md` must also be updated — `install.sh` handles this on next run

---

## 7. Success Metrics

- A sprint with mixed simple/complex stories spawns Haiku workers for simple stories and Sonnet workers for complex ones
- No regression: a sprint.json with no complexity fields behaves identically to before (all Sonnet)

---

## 8. Open Questions

- None — implementation is straightforward given F-1 is complete.
