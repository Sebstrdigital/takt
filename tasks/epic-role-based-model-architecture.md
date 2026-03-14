# Epic: Role-Based Model Architecture

## 1. Problem Statement

takt assigns the same model (Sonnet 4.6) to every agent regardless of what the task actually requires. A worker renaming a variable runs the same model as a worker making complex cross-file architectural decisions. This wastes tokens on simple work and misses opportunities to use faster, cheaper models where they're sufficient. Users running long parallel sprints pay the same token cost whether stories are trivial or complex.

## 2. Target Users

**Primary:** takt users on Claude's Max subscription who run multi-story sprints and want to optimize cost and wall-clock time.

**Secondary:** Any takt user who wants model selection to reflect the actual cognitive demand of each task.

## 3. Goals

- Assign models by role and task complexity: Opus for bounded high-stakes reasoning, Sonnet for orchestration and complex implementation, Haiku for simple/mechanical work
- Reduce token spend on simple stories (boilerplate, renames, scaffolding) by routing them to Haiku
- Reduce wall-clock time on parallel runs — Haiku is 3-5x faster than Sonnet
- Make complexity classification explicit in sprint.json so users can override it
- Introduce a one-shot Opus Merge Strategist for parallel runs — the only place Opus reasoning is worth the cost

## 4. Constraints

- **Claude Code API limitation:** The Agent/Task tool only exposes model family names (`sonnet`, `opus`, `haiku`) — no version selection, no reasoning toggle. The tier map must be model-family-only.
- **Pure prompt-based:** takt has no runtime config system. Model routing must live in prompt files, not a config layer.
- **Backward compatibility:** Existing sprint.json files without a `complexity` field must still run. Default behavior must be preserved (no complexity field = treated as `complex` → Sonnet).
- **Haiku subscription segmentation unknown:** Whether the Max subscription pools Haiku separately from Sonnet/Opus is unconfirmed. Speed benefit is certain; token quota benefit is unconfirmed.

## 5. Feature Breakdown

### F-1: Story Complexity Classification
**Scope:** Add a `complexity` field (`"simple"` | `"complex"`) to sprint.json stories. Update `/sprint` (the Feature-to-sprint converter) to automatically classify each story based on its scope. Update `/feature` and documentation to explain the field. Simple = single file, deterministic, no cross-file reasoning. Complex = multiple files, logic decisions, integration points.
**Depends on:** none

### F-2: Orchestrator Model Routing
**Scope:** Update `lib/run.md` so the orchestrator reads each story's `complexity` field and spawns workers with the appropriate model: `haiku` for simple, `sonnet` for complex. Stories without a `complexity` field default to `sonnet`. Update `lib/worker.md` if needed for any model-tier-specific instructions.
**Depends on:** F-1 (needs the complexity field to exist in sprint.json)

### F-3: Merge Strategist Agent
**Scope:** Add a one-shot Opus agent to `lib/run.md` that is spawned only when parallel waves exist. The Merge Strategist receives all worktree diffs and dependency information, outputs a recommended merge order, and is then dismissed. The orchestrator (Sonnet) executes merges in that order. This is the only role where Opus is used.
**Depends on:** F-2 (parallel mode must be model-aware before adding a new agent to it)

## 6. Sequencing Rationale

F-1 must come first because the complexity field is the data foundation that F-2 and F-3 both depend on. Without the field in sprint.json, the orchestrator has nothing to read when making routing decisions. F-2 comes before F-3 because the orchestrator needs to be model-aware in general before adding a new agent type (the Merge Strategist) to the parallel flow specifically. F-3 is last and optional — it only activates in parallel runs with waves, so it can ship independently without blocking F-1 or F-2.

## 7. Out of Scope

- Per-project model configuration file (e.g., `takt.config.yml`) — no config system in this Epic
- Reasoning toggle — not exposed by Claude Code's Agent/Task tool
- Model versioning (e.g., `claude-sonnet-4-6` vs `claude-sonnet-4-7`) — only family names available
- Automatic escalation from Haiku to Sonnet on failure — may be a future improvement, not in this Epic
- Cost tracking per story or per run — separate future improvement
- Changes to verifier, reviewer, retro, or debug agent model assignments

## 8. Open Questions

- Does the Max subscription segment Haiku token quota separately from Sonnet/Opus? If yes, Haiku simple workers are a compounding win. If no, benefit is speed-only. Needs confirmation before shipping F-2.
- Should the `/sprint` converter default unclassifiable stories to `"simple"` or `"complex"`? Recommend `"complex"` (safer, no regression risk) but worth confirming with the user.
- Should the Merge Strategist write its recommended order to a file (e.g., `.takt/merge-order.json`) for auditability, or just pass it inline to the orchestrator?
