---
name: takt
description: "Convert PRDs to stories.json format for the takt autonomous agent system. Use when you have an existing PRD and need to convert it to takt's JSON format. Triggers on: convert this prd, turn this into takt format, create stories.json from this, takt json."
source_id: takt
version: 1.0.0
---

# takt PRD Converter

Converts existing PRDs to the stories.json format that takt uses for autonomous execution.

---

## The Job

Take a PRD (markdown file or text) and convert it to `stories.json` in the project root.

---

## Output Format

```json
{
  "project": "[Project Name]",
  "branchName": "takt/[feature-name-kebab-case]",
  "description": "[Feature description from PRD title/intro]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "type": "logic",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "size": "small",
      "passes": false,
      "verify": "inline",
      "startTime": "",
      "endTime": "",
      "dependsOn": []
    }
  ],
  "waves": []
}
```

---

## Verification Mode: Inline vs Deep

Each story has a `verify` field controlling how verification happens. This is a **token-efficiency** feature.

**Default to `"inline"`** - The same agent that implements the story verifies it before marking complete. No extra token cost.

**Assign `"deep"` when:**

| Condition | Why Deep Verification |
|-----------|----------------------|
| Story is the LAST in the PRD | Final verification before completion |
| Story touches security/auth | Critical code needs independent verification |
| Story is large/complex (5+ files) | Complex stories need thorough verification |
| Story has failed before | Previous attempts didn't work - verify harder |

**How it works:**
- `"verify": "inline"` - Agent verifies own work using Goal-Backward Verification in prompt.md (~0 extra tokens)
- `"verify": "deep"` - After all stories complete, takt spawns a separate verifier agent to independently confirm goals achieved (~50k-100k tokens)

**Token budget consideration:** In a typical 10-story PRD:
- 8-9 stories: `"verify": "inline"` (0 extra tokens)
- 1-2 stories: `"verify": "deep"` (~100k-200k extra tokens total)

This keeps verification thorough where it matters without burning tokens on simple stories.

---

## Wave Planning (Team Mode)

When the PRD has 6+ stories with 2+ independent dependency chains, add wave planning for `takt team` mode.

### dependsOn Field

Each story can have a `dependsOn` array listing story IDs it requires:

```json
{
  "id": "US-003",
  "dependsOn": ["US-001", "US-002"],
  ...
}
```

Stories without dependencies have `"dependsOn": []`.

### waves Field

Add a top-level `waves` array computed from `dependsOn`:

```json
{
  "waves": [
    { "wave": 1, "stories": ["US-001", "US-003", "US-005"] },
    { "wave": 2, "stories": ["US-002", "US-004"] }
  ]
}
```

**Wave computation rules:**
1. Wave 1: All stories with no dependencies (`dependsOn: []`)
2. Wave N+1: Stories whose dependencies are ALL in waves 1 through N
3. Stories in the same wave can run in parallel
4. Wave N+1 doesn't start until Wave N is fully merged

### When to Add Waves

- **Add waves** when: 6+ stories, 2+ independent chains, parallelism benefits
- **Skip waves** when: ≤5 stories, linear dependencies, simple feature → use `takt solo`

Include a note after the summary: "If waves are present, suggest `takt team` over `takt solo`."

---

## Story Type: Logic vs UI

Each story has a `type` field controlling the implementation workflow.

**Values:** `"logic"`, `"ui"`, `"hybrid"`

| Type | Workflow | Verification |
|------|----------|--------------|
| `logic` | **TDD:** Write failing tests FIRST, then implement, then refactor | Tests must pass |
| `ui` | **Build-only:** Implement directly, verify with `npm run build` | Build passes |
| `hybrid` | **Mixed:** TDD for logic parts, direct implementation for UI | Tests + build |

**Default to `"logic"`** for stories that involve:
- Database migrations and schema changes
- API endpoints and server actions
- Parsers, generators, utility functions
- State management hooks
- Business logic

**Assign `"ui"` for stories that are pure UI:**
- React component layouts
- Form rendering (not validation logic)
- Styling and visual changes
- Modal/dialog structure
- Tab navigation UI

**Assign `"hybrid"` for stories with both:**
- Form component with validation logic (UI + validation tests)
- Table component with sorting logic (UI + sorting tests)

**Why this matters:** TDD adds significant overhead. Writing tests for "does this button render" provides no value. Reserve TDD for code where tests catch real bugs.

---

## Story Size Assignment

Each story has a `size` field used for progress tracking and ETA estimation. takt tracks completion times per size category to improve estimates over time.

**Values:** `"small"`, `"medium"`, `"large"`

| Size | Typical Scope | Examples |
|------|--------------|----------|
| `small` | Single file, straightforward change | Add a database column, add a simple UI element, fix a typo |
| `medium` | 2-4 files, some coordination | Add a form with validation, create an API endpoint with tests |
| `large` | 5+ files, complex logic | Refactor a component system, add a feature touching multiple layers |

**Guidelines:**
- Default to `"small"` for most stories (they should be small per the sizing rules below)
- Use `"medium"` when multiple files need coordinated changes
- Use `"large"` sparingly - consider splitting if possible
**Time tracking fields:**
- `startTime` and `endTime` are populated by takt during execution
- Leave them as empty strings (`""`) when creating stories.json

---

## Story Scope: The Number One Rule

**Each story must be completable in ONE takt iteration (one context window).**

takt spawns a fresh Claude Code instance per iteration with no memory of previous work. If a story is too big, the LLM runs out of context before finishing and produces broken code.

### Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these):
- "Build the entire dashboard" - Split into: schema, queries, UI components, filters
- "Add authentication" - Split into: schema, middleware, login UI, session handling
- "Refactor the API" - Split into one story per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

---

## Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

**Wrong order:**
1. UI component (depends on schema that does not exist yet)
2. Schema change

---

## Acceptance Criteria: Must Be Behavioral and Verifiable

Each criterion must describe an **observable behavioral outcome** — something a user or QA engineer would see or measure. This is not just about being verifiable; it's about writing criteria that describe the system's behavior, not its implementation.

**Why behavioral criteria?** Behavioral criteria flow naturally into BDD scenarios. When acceptance criteria describe what a user observes ("when X happens, Y is visible"), the verifier can independently confirm the feature works from a QA perspective — rather than just checking that a file was created or a function was called.

### Good criteria (behavioral, observable):
- "When a new task is created, it has a default status of 'pending'"
- "When the filter is set to 'Active', only active tasks appear in the list"
- "When a user clicks delete, a confirmation dialog appears before the item is removed"
- "After changing status, the update persists across page refreshes"
- "Tests pass"

### Acceptable criteria (verifiable but implementation-leaning):
- "Filter dropdown has options: All, Active, Completed" — acceptable, describes visible UI
- "Typecheck passes" — acceptable, always required

### Bad criteria (implementation tasks, not outcomes):
- "Add `status` column to tasks table" — describes code change, not behavior
- "Works correctly" — vague
- "User can do X easily" — vague
- "Handles edge cases" — vague

### Always include as final criterion:
```
"Typecheck passes"
```

For stories with testable logic, also include:
```
"Tests pass"
```

### For stories that change UI, also include:
```
"Verify in browser using Chrome integration"
```

Frontend stories are NOT complete until visually verified. takt will use Chrome browser integration to navigate to the page, interact with the UI, and confirm changes work.

---

## Conversion Rules

1. **Each user story becomes one JSON entry**
2. **IDs**: Sequential (US-001, US-002, etc.)
3. **Priority**: Based on dependency order, then document order
4. **All stories**: `passes: false`
5. **branchName**: Derive from PRD filename, kebab-case, prefixed with `takt/` (e.g., `prd-dark-mode.md` → `takt/dark-mode`)
6. **Always add**: "Typecheck passes" to every story's acceptance criteria
7. **Type assignment**: Assign `"logic"` (TDD), `"ui"` (build-only), or `"hybrid"` based on story content (see Story Type section)
8. **Verify assignment**: Set `"verify": "deep"` for the final story, complex stories, and security-sensitive stories; otherwise `"verify": "inline"`
10. **Size assignment**: Assign `"small"`, `"medium"`, or `"large"` based on scope (see Story Size Assignment section)
11. **Time tracking**: Set `startTime` and `endTime` to empty strings (`""`)
12. **dependsOn assignment**: Identify dependencies between stories. Set `"dependsOn": []` for independent stories.
13. **Wave computation**: If 6+ stories with 2+ independent chains, compute `waves` from `dependsOn` graph.
14. **Scenario generation**: After writing stories.json, generate `.takt/scenarios.json` with 2-5 BDD scenarios per story (see Scenario Generation section). Scenarios describe observable behavioral outcomes, not implementation details. Create `.takt/` directory if it does not exist.

---

## Splitting Large PRDs

If a PRD has big features, split them:

**Original:**
> "Add user notification system"

**Split into:**
1. US-001: Add notifications table to database
2. US-002: Create notification service for sending notifications
3. US-003: Add notification bell icon to header
4. US-004: Create notification dropdown panel
5. US-005: Add mark-as-read functionality
6. US-006: Add notification preferences page

Each is one focused change that can be completed and verified independently.

---

## Example

**Input PRD:**
```markdown
# Task Status Feature

Add ability to mark tasks with different statuses.

## Requirements
- Toggle between pending/in-progress/done on task list
- Filter list by status
- Show status badge on each task
- Persist status in database
```

**Output stories.json:**
```json
{
  "project": "TaskApp",
  "branchName": "takt/task-status",
  "description": "Task Status Feature - Track task progress with status indicators",
  "userStories": [
    {
      "id": "US-001",
      "title": "Add status field to tasks table",
      "description": "As a developer, I need to store task status in the database.",
      "type": "logic",
      "acceptanceCriteria": [
        "Add status column: 'pending' | 'in_progress' | 'done' (default 'pending')",
        "Generate and run migration successfully",
        "Typecheck passes"
      ],
      "priority": 1,
      "size": "small",
      "passes": false,
      "verify": "inline",
      "startTime": "",
      "endTime": "",
      "dependsOn": []
    },
    {
      "id": "US-002",
      "title": "Display status badge on task cards",
      "description": "As a user, I want to see task status at a glance.",
      "type": "ui",
      "acceptanceCriteria": [
        "Each task card shows colored status badge",
        "Badge colors: gray=pending, blue=in_progress, green=done",
        "Typecheck passes"
      ],
      "priority": 2,
      "size": "small",
      "passes": false,
      "verify": "inline",
      "startTime": "",
      "endTime": "",
      "dependsOn": ["US-001"]
    },
    {
      "id": "US-003",
      "title": "Add status toggle to task list rows",
      "description": "As a user, I want to change task status directly from the list.",
      "type": "hybrid",
      "acceptanceCriteria": [
        "Each row has status dropdown or toggle",
        "Changing status saves immediately",
        "UI updates without page refresh",
        "Typecheck passes"
      ],
      "priority": 3,
      "size": "medium",
      "passes": false,
      "verify": "inline",
      "startTime": "",
      "endTime": "",
      "dependsOn": ["US-001"]
    },
    {
      "id": "US-004",
      "title": "Filter tasks by status",
      "description": "As a user, I want to filter the list to see only certain statuses.",
      "type": "ui",
      "acceptanceCriteria": [
        "Filter dropdown: All | Pending | In Progress | Done",
        "Filter persists in URL params",
        "Typecheck passes"
      ],
      "priority": 4,
      "size": "medium",
      "passes": false,
      "verify": "deep",
      "startTime": "",
      "endTime": "",
      "dependsOn": ["US-002", "US-003"]
    }
  ],
  "waves": [
    { "wave": 1, "stories": ["US-001"] },
    { "wave": 2, "stories": ["US-002", "US-003"] },
    { "wave": 3, "stories": ["US-004"] }
  ]
}
```

Note:
- **Type assignments:** US-001 is `"logic"` (database), US-002/US-004 are `"ui"` (visual), US-003 is `"hybrid"` (UI + save logic)
- US-004 has `"verify": "deep"` because it's the **final story** — gets independent verification before completion
- Size assignments: US-001, US-002 are `"small"` (single concern), US-003, US-004 are `"medium"` (multiple files/logic)

---

## PRD File Naming Convention

The PRD filename and branchName must match so takt can archive the correct file on completion:

- PRD file: `tasks/prd-dark-mode.md`
- branchName: `takt/dark-mode`

**On completion**, takt derives the PRD filename from branchName and moves it to archive:
- `takt/dark-mode` → looks for `tasks/prd-dark-mode.md`
- Moves to: `tasks/archive/YYYY-MM-DD-dark-mode/prd-dark-mode.md`

---

## Scenario Generation

When converting a PRD, ALSO generate `.takt/scenarios.json` alongside `stories.json`. Scenarios are used exclusively by the verifier — implementation workers never see this file.

### Why Scenarios Exist

Acceptance criteria tell workers what to build. Scenarios tell the verifier what to CHECK. They are independent on purpose: if scenarios were derived from the same acceptance criteria the worker reads, the verifier would just confirm the worker followed instructions — not that the feature actually works.

Scenarios must describe **observable behavioral outcomes** — what a QA engineer would manually test — not implementation details or copy-pasted acceptance criteria.

### Connection to BDD Criteria

When PRD acceptance criteria are already written as behavioral outcomes ("when X happens, the user sees Y"), scenario generation becomes natural. Behavioral criteria and BDD scenarios speak the same language: observable outcomes from a user's perspective.

If PRD criteria are implementation-leaning ("add column X", "create endpoint Y"), you must translate them into behavioral scenarios before writing. Ask: "What would a QA engineer verify to confirm this works?" That translation is your scenario.

The pipeline is: behavioral criteria → behavioral scenarios → behavioral verification. Each step reinforces the same question: "Does the system behave as expected from the user's perspective?"

### Scenarios File Format

Store at `.takt/scenarios.json`. Create the `.takt/` directory if it does not exist.

```json
{
  "stories": {
    "US-001": [
      {
        "id": "SC-001",
        "given": "a database with no status column on the tasks table",
        "when": "the migration is run",
        "then": "the tasks table has a status column with default value 'pending' and the app starts without errors",
        "type": "behavioral"
      },
      {
        "id": "SC-002",
        "given": "an existing task row in the database",
        "when": "the status column is queried",
        "then": "the value is 'pending' without any explicit insert",
        "type": "behavioral"
      }
    ],
    "US-002": [
      {
        "id": "SC-003",
        "given": "a task with status 'in_progress'",
        "when": "the task list page is loaded",
        "then": "a blue badge is visible on that task card",
        "type": "behavioral"
      }
    ]
  }
}
```

### Scenario Rules

1. **2-5 scenarios per story** — enough to cover the spirit of the feature, not exhaustive.
2. **BDD Given/When/Then format** — each field is a complete clause, written in plain English.
3. **Observable outcomes only** — describe what a human tester would see, click, or measure. Never reference internal function names, variable names, or implementation choices.
4. **Not copy-pasted acceptance criteria** — acceptance criteria tell the worker what to build; scenarios test whether it actually works from a QA perspective. Reframe, don't copy.
5. **type field** — use `"behavioral"` for user-facing outcomes, `"contract"` for API/data contract checks, `"edge"` for boundary/error conditions.
6. **IDs are globally unique** — SC-001, SC-002, etc. across the entire file (not per story).
7. **Hidden from workers** — `.takt/` is gitignored and not referenced by solo.md or worker.md. Only `verifier.md` reads this file.

### Scenario Writing Guide

Ask yourself: "If I handed this app to a QA engineer with no code access, what would they test?"

Good scenario (behavioral, observable):
- Given: "a user is on the task list page"
- When: "they click the status dropdown on a task and select 'Done'"
- Then: "the task badge turns green and the change persists after page refresh"

Bad scenario (implementation detail):
- Given: "the updateTaskStatus server action is called"
- When: "it receives status='done'"
- Then: "it calls db.update() with the correct parameters"

Bad scenario (copy-pasted criterion):
- Given: "the filter dropdown exists"
- When: "it renders"
- Then: "it has options: All, Active, Completed" ← this is just restating the acceptance criterion

---

## Checklist Before Saving

Before writing stories.json, verify:

- [ ] **branchName matches PRD filename** (e.g., `prd-dark-mode.md` → `takt/dark-mode`)
- [ ] Each story is completable in one iteration (small enough)
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser using Chrome integration" as criterion (optional if Chrome disabled)
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
- [ ] **Type assigned** to each story (`"logic"` for TDD, `"ui"` for build-only, `"hybrid"` for mixed)
- [ ] **Verify assigned** to each story (`"inline"` default, `"deep"` for final story and complex/security stories)
- [ ] **Size assigned** to each story (`"small"`, `"medium"`, or `"large"`)
- [ ] **Time fields** set to empty strings (`"startTime": ""`, `"endTime": ""`)
- [ ] **dependsOn** set for each story (empty array if no dependencies)
- [ ] **waves** computed if 6+ stories with independent chains
- [ ] **scenarios.json** generated at `.takt/scenarios.json` with 2-5 BDD scenarios per story

---

## After Creating stories.json

Once you have saved `stories.json` and `.takt/scenarios.json`, present a summary and offer to start the loop:

```
✅ stories.json ready!
✅ .takt/scenarios.json generated (hidden from workers, used by verifier)

Branch: takt/feature-name
Stories: X total (Y small, Z medium, W large)
  - US-001: [title] (small, inline)
  - US-002: [title] (small, inline)
  - US-003: [title] (medium, deep) ← final verification

Would you like me to start the takt?
This will:
1. Create the feature branch (takt/feature-name)
2. Run all stories autonomously
3. Ask about merge/PR when complete
```

If the user says yes:
1. Run `takt` (it handles branch creation automatically)

**Note:** The user can review stories.json before starting. This is their last checkpoint before autonomous execution begins.
