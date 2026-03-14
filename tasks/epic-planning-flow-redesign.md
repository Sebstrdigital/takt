# Epic: Planning Flow Redesign

## 1. Problem Statement

The takt planning flow has too much overhead and too much granularity at the Feature level. Going through `/epic` → `/feature` → `/sprint` manually takes almost as long as the actual takt run — eroding the time-savings benefit of autonomous execution. Two specific problems:

1. **Ceremony overhead:** `/epic` hands off after one Feature at a time, `/sprint` only handles one Feature doc, and there is no quick path for small changes that don't need full Epic/Feature ceremony.

2. **Feature granularity too fine:** The `/epic` skill breaks initiatives into too many small Features (e.g. 3 Features with 1-3 stories each) when 1-2 broader Features would be appropriate. Feature docs don't need to be tiny — the story decomposition that workers need lives in `sprint.json`, not in how many Feature docs exist.

---

## 2. Target Users

- **takt users** planning new features or changes — they experience the planning overhead directly
- **takt itself** — the orchestrator consumes sprint.json and scenarios.json; planning flow improvements feed it better input

---

## 3. Goals

- `/epic` loops through the full Feature breakdown in one session before handing off to `/sprint` — no manual F-1 → F-2 → F-3 hand-holding
- Feature docs cover initiative-level scope (not sub-task scope) — one Feature doc per meaningful chunk of work
- `/sprint` merges multiple Feature docs into one `sprint.json` with wave computation across all Features
- A quick path in `/takt` lets users describe a change, run a lean why/what/what-not interview, and get `sprint.json` + `.takt/scenarios.json` directly — no Feature doc artifact

---

## 4. Constraints

- **Pure prompt-based:** takt has no runtime code — all changes are to `.md` prompt files and slash command files
- **Quality gate preserved:** `scenarios.json` must always be generated, even in the quick path — this is non-negotiable
- **Backward-compatible:** Existing `sprint.json` files (no Feature doc) must continue to work with `start takt` unchanged
- **Install.sh:** Any changes to `lib/` or `commands/` files require a run of `./install.sh` to take effect

---

## 5. Feature Breakdown

### F-1: Epic Loops All Features
**Scope:** Update `/epic` so that after confirming the Feature breakdown, it iterates through every Feature in sequence — running the full `/feature` interview for F-1, then F-2, then F-3 — before handing off to `/sprint`. Today it stops after F-1 and requires the user to manually trigger `/feature` for each subsequent Feature. The full Feature planning session should complete in one invocation.
**Depends on:** none

### F-2: Broader Feature Scope Guidelines
**Scope:** Update the `/feature` skill prompt to calibrate scope upward. Feature docs should cover initiative-level work — multiple related stories that deliver a user-visible outcome — not sub-task granularity. Add explicit guidance: a Feature doc should produce 4-8 stories in sprint.json; if it would produce fewer than 3, consider rolling it into a sibling Feature. Update the example in `/feature` to reflect broader scope.
**Depends on:** F-1 (F-1 changes how Features are planned; F-2 changes what they contain)

### F-3: /sprint Merges Multiple Feature Docs
**Scope:** Update the `/sprint` skill to detect all `tasks/feature-*.md` files and offer to combine them into one `sprint.json`. When multiple Feature docs are merged, wave computation runs across all stories from all docs. The combined sprint.json should be cleaner than running /sprint on each doc separately — deduplicating any overlapping dependencies and computing a single coherent wave plan.
**Depends on:** F-1 (produces multiple Feature docs that F-3 must merge)

### F-4: Quick Path — Why/What/What-Not to Sprint
**Scope:** Add a quick path in `/takt` for small or clear changes that don't need Epic/Feature ceremony. The user describes a change; `/takt` immediately runs a lean why/what/what-not interview (3 questions, max 2 rounds); then converts the answers directly into `sprint.json` + `.takt/scenarios.json`. No Feature doc artifact is created. The quality gate (scenarios.json) is always preserved. This path is always a 3-question interview — no conditional "if clear enough, skip" logic. Business-driven development at the speed of a conversation.
**Depends on:** none (can ship independently)

---

## 6. Sequencing Rationale

F-1 ships first because it changes the shape of the planning session — all subsequent Features are now planned in one go. F-2 ships second because it changes what those Feature docs contain; it depends on F-1 establishing the loop. F-3 ships third because it consumes the output of the F-1+F-2 flow — merging multiple, correctly-scoped Feature docs into one sprint.json. F-4 is independent and can ship at any point, but is sequenced last so it benefits from the improved Feature scope guidance in F-2 (the quick path's why/what/what-not interview should reflect the same scope calibration).

---

## 7. Out of Scope

- Changes to `lib/run.md`, `lib/worker.md`, or any orchestrator/worker behaviour — this Epic is planning-flow only
- Automatic scenario generation improvements — scenarios.json format is unchanged
- Per-project Feature templates or classification rules
- Changes to how `start takt` executes once sprint.json exists
- UI or dashboard for planning flow

---

## 8. Open Questions

- **F-3 conflict resolution:** When two Feature docs define stories with the same ID (e.g. both have US-001), how should /sprint resolve the conflict? Recommend: auto-renumber (first doc keeps US-001, second doc starts at US-00N+1) and note the renaming in the summary.
- **F-4 scope boundary:** How many stories is "too many" for the quick path before suggesting the user do a full Feature doc instead? Recommend: if the why/what/what-not interview produces more than 5 stories, warn the user and offer to save as a Feature doc instead.
