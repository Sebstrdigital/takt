---
name: sprint
description: "Convert Feature docs to sprint.json format for the takt autonomous agent system. This command is for Feature-to-sprint conversion ONLY. It does NOT handle run, debug, or retro — those are triggered by saying 'start takt', 'takt debug', or 'takt retro' directly in Claude Code, which reads the corresponding prompt file. Triggers on: convert this feature, turn this into takt format, create sprint.json from this, takt json."
source_id: takt
version: 1.0.0
---

# takt Sprint Converter

Converts existing Feature docs to the sprint.json format that takt uses for autonomous execution.

---

## Invocation Modes

### Single-doc mode (explicit argument)

When invoked with a specific Feature doc path (e.g. `/sprint tasks/feature-dark-mode.md`), convert that one Feature doc to `sprint.json`. This is the original behaviour — unchanged.

### Multi-doc mode (no argument)

When invoked **without** a specific Feature doc argument (e.g. the user just says `/sprint` or "convert my features to sprint.json"), execute the multi-doc detection flow:

1. **Scan** `tasks/` for all files matching `feature-*.md` (alphabetical order).
2. **Present the list** to the user:
   ```
   Found 3 Feature docs in tasks/:
     1. feature-dark-mode.md
     2. feature-notifications.md
     3. feature-user-profile.md

   Merge all into one sprint.json? [yes / no / select subset]
   ```
3. **Wait for confirmation.** If the user says no or selects a subset, adjust accordingly.
4. **If confirmed**, process each Feature doc in alphabetical filename order, collecting all stories.
5. **Renumber IDs globally** — see ID Renumbering section below.
6. **Compute a single wave plan** across all stories from all docs — see Wave Planning section.
7. **Write sprint.json** and `.takt/scenarios.json`.
8. **Print a merge summary** — see Merge Summary section.

**Story count warning:** If the combined story count would exceed 15 stories, warn the user before proceeding:
```
⚠️  Combined story count: 18 stories (recommended max: 15).
    Consider splitting into multiple sprints by running /sprint with a subset of Feature docs.
    Continue anyway? [yes / no]
```

---

## ID Renumbering

When merging multiple Feature docs, story IDs must be globally unique across the combined `userStories` array.

**Rules:**

1. Process Feature docs in alphabetical filename order.
2. The first Feature doc's stories keep their original IDs (e.g. US-001, US-002, US-003).
3. Each subsequent Feature doc's stories are renumbered starting from the next available ID after the last assigned ID.
4. All `dependsOn` references **within each Feature doc** are updated to the renumbered IDs before insertion into the combined array.

**Example:**
- `feature-dark-mode.md` has US-001, US-002, US-003 → kept as US-001, US-002, US-003
- `feature-notifications.md` has US-001, US-002 → renumbered to US-004, US-005 (dependsOn references updated)
- `feature-user-profile.md` has US-001, US-002, US-003 → renumbered to US-006, US-007, US-008

---

## Merge Summary

After writing sprint.json, print a merge summary before the standard "sprint.json ready" output:

```
Merged 3 Feature docs:
  feature-dark-mode.md     3 stories → US-001–US-003 (unchanged)
  feature-notifications.md  2 stories → US-004–US-005 (renumbered from US-001–US-002)
  feature-user-profile.md  3 stories → US-006–US-008 (renumbered from US-001–US-003)
```

---

## The Job

Take a Feature doc (markdown file or text) and convert it to `sprint.json` in the project root.

---

## Output Format

```json
{
  "project": "[Project Name]",
  "branchName": "takt/[feature-name-kebab-case]",
  "description": "[Feature description from Feature doc title/intro]",
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
      "complexity": "complex",
      "passes": false,
      "verify": "inline",
      "startTime": "",
      "endTime": "",
      "dependsOn": [],
      "knownIssues": []
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
| Story is the LAST in the Feature doc | Final verification before completion |
| Story touches security/auth | Critical code needs independent verification |
| Story is large/complex (5+ files) | Complex stories need thorough verification |
| Story has failed before | Previous attempts didn't work - verify harder |

**How it works:**
- `"verify": "inline"` - Agent verifies own work using Goal-Backward Verification in prompt.md (~0 extra tokens)
- `"verify": "deep"` - After all stories complete, takt spawns a separate verifier agent to independently confirm goals achieved (~50k-100k tokens)

**Token budget consideration:** In a typical 10-story Feature doc:
- 8-9 stories: `"verify": "inline"` (0 extra tokens)
- 1-2 stories: `"verify": "deep"` (~100k-200k extra tokens total)

This keeps verification thorough where it matters without burning tokens on simple stories.

---

## Wave Planning (Team Mode)

When the Feature doc has 6+ stories with 2+ independent dependency chains, add wave planning for parallel execution.

**In multi-doc mode:** Waves are computed from the **combined** `dependsOn` graph across ALL stories from ALL Feature docs — not per-Feature-doc. After ID renumbering (see ID Renumbering section), a story from `feature-notifications.md` renumbered to US-004 can depend on US-002 from `feature-dark-mode.md`, and the wave planner treats them as one unified graph.

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
- **Skip waves** when: ≤5 stories, linear dependencies, simple feature

`start takt` auto-detects sequential vs parallel from the presence of waves.

---

## Story Type: Categorization

Each story has a `type` field for categorization. All types use **direct implementation** — workers implement the code that satisfies acceptance criteria without a TDD workflow. BDD scenarios (in `.takt/scenarios.json`) are the quality gate, verified by a separate verifier agent.

**Values:** `"logic"`, `"ui"`, `"hybrid"`

| Type | Description | Examples |
|------|-------------|---------|
| `logic` | Backend, data, business rules | Database migrations, API endpoints, parsers, state management |
| `ui` | Pure visual/layout work | Component layouts, styling, modal structure, navigation UI |
| `hybrid` | Both logic and UI | Form with validation, table with sorting, interactive components |

**Default to `"logic"`** when uncertain. The type field helps the converter and verifier understand the nature of the story but does not change the worker's implementation approach — all types use direct implementation.

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
- Leave them as empty strings (`""`) when creating sprint.json

---

## Story Complexity: Model Tier Routing

Each story has a `complexity` field used to route it to the appropriate model tier. This is a **cost-efficiency** feature — simple stories don't need a powerful model.

**Values:** `"simple"` | `"complex"`

**Default: `"complex"`** — Stories without a complexity field are treated as complex. When in doubt, use `"complex"`.

### Auto-Classification Rules

**Assign `"simple"` when ALL of the following are true:**
- Single file change (one file to create or modify)
- Deterministic output (the change is obvious, no judgment calls)
- No cross-file reasoning (no need to understand how multiple modules interact)

**Assign `"complex"` when ANY of the following is true:**
- Multiple files need coordinated changes
- Logic decisions required (branching logic, data transformation, state management)
- Integration points (API calls, database queries, cross-module dependencies)

### Borderline Examples

| Story | Classification | Reason |
|-------|---------------|--------|
| "Add a `color` field to a config constant file" | `"simple"` | One file, no logic, no cross-file impact |
| "Update a UI label string in a single component" | `"simple"` | One file, deterministic, purely cosmetic |
| "Add a CSS class to a single component" | `"simple"` | One file, no logic reasoning needed |
| "Add a new route handler that calls an existing service" | `"complex"` | Multiple files (route + service), integration point |
| "Rename a function used in 3 files" | `"complex"` | Multiple files, cross-file reasoning required |
| "Add a form field with client-side validation" | `"complex"` | UI + validation logic = multiple concerns |

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
5. **branchName**: Derive from Feature doc filename, kebab-case, prefixed with `takt/` (e.g., `feature-dark-mode.md` → `takt/dark-mode`). In multi-doc mode, derive from the sprint/epic name or prompt the user for a branch name (e.g. `takt/sprint-1` or `takt/<feature-group-name>`).
6. **Always add**: "Typecheck passes" to every story's acceptance criteria
7. **Type assignment**: Assign `"logic"`, `"ui"`, or `"hybrid"` based on story content (see Story Type section)
8. **Verify assignment**: Set `"verify": "deep"` for the final story, complex stories, and security-sensitive stories; otherwise `"verify": "inline"`
10. **Size assignment**: Assign `"small"`, `"medium"`, or `"large"` based on scope (see Story Size Assignment section)
11. **Complexity assignment**: Assign `"simple"` or `"complex"` based on auto-classification rules (see Story Complexity section). Default to `"complex"` when uncertain.
12. **Time tracking**: Set `startTime` and `endTime` to empty strings (`""`)
13. **dependsOn assignment**: Identify dependencies between stories. Set `"dependsOn": []` for independent stories.
14. **Wave computation**: If 6+ stories with 2+ independent chains, compute `waves` from `dependsOn` graph.
15. **Scenario generation**: After writing sprint.json, generate `.takt/scenarios.json` with 2-5 BDD scenarios per story (see Scenario Generation section). Scenarios describe observable behavioral outcomes, not implementation details. Create `.takt/` directory if it does not exist.
16. **Known issues**: If the project has pre-existing failures (broken builds, flaky tests, incomplete migrations), add them to relevant stories as `"knownIssues": ["description of issue"]`. This prevents workers from wasting time diagnosing problems they didn't introduce. Leave as `[]` when there are no known issues.

---

## Splitting Large Feature Docs

If a Feature doc has big features, split them:

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

**Input Feature doc:**
```markdown
# Task Status Feature

Add ability to mark tasks with different statuses.

## Requirements
- Toggle between pending/in-progress/done on task list
- Filter list by status
- Show status badge on each task
- Persist status in database
```

**Output sprint.json:**
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
      "complexity": "complex",
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
      "complexity": "simple",
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
      "complexity": "complex",
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
      "complexity": "complex",
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
- **Type assignments:** US-001 is `"logic"` (database), US-002/US-004 are `"ui"` (visual), US-003 is `"hybrid"` (UI + save logic). All types use direct implementation; BDD scenarios are the verification layer.
- US-004 has `"verify": "deep"` because it's the **final story** — gets independent verification before completion
- Size assignments: US-001, US-002 are `"small"` (single concern), US-003, US-004 are `"medium"` (multiple files/logic)
- **Complexity assignments:** US-001 is `"complex"` (migration touches schema + migration file), US-002 is `"simple"` (adds a badge to one component, no logic), US-003/US-004 are `"complex"` (multiple files, logic decisions, integration points)

---

## Feature Doc File Naming Convention

The Feature doc filename and branchName must match so takt can archive the correct file on completion:

- Feature doc file: `tasks/feature-dark-mode.md`
- branchName: `takt/dark-mode`

**On completion**, takt derives the Feature doc filename from branchName and moves it to archive:
- `takt/dark-mode` → looks for `tasks/feature-dark-mode.md`
- Moves to: `tasks/archive/YYYY-MM-DD-dark-mode/feature-dark-mode.md`

**In multi-doc mode**, the branchName is not derived from a single Feature doc filename. All merged Feature docs are archived on completion — takt archives each doc individually using its own name.

---

## Scenario Generation

When converting a Feature doc, ALSO generate `.takt/scenarios.json` alongside `sprint.json`. Scenarios are used exclusively by the verifier — implementation workers never see this file.

### Why Scenarios Exist

Acceptance criteria tell workers what to build. Scenarios tell the verifier what to CHECK. They are independent on purpose: if scenarios were derived from the same acceptance criteria the worker reads, the verifier would just confirm the worker followed instructions — not that the feature actually works.

Scenarios must describe **observable behavioral outcomes** — what a QA engineer would manually test — not implementation details or copy-pasted acceptance criteria.

### Connection to BDD Criteria

When Feature doc acceptance criteria are already written as behavioral outcomes ("when X happens, the user sees Y"), scenario generation becomes natural. Behavioral criteria and BDD scenarios speak the same language: observable outcomes from a user's perspective.

If Feature doc criteria are implementation-leaning ("add column X", "create endpoint Y"), you must translate them into behavioral scenarios before writing. Ask: "What would a QA engineer verify to confirm this works?" That translation is your scenario.

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
7. **Hidden from workers** — `.takt/` is gitignored and not referenced by run.md or worker.md. Only `verifier.md` reads this file.

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

Before writing sprint.json, verify:

- [ ] **branchName matches Feature doc filename** (e.g., `feature-dark-mode.md` → `takt/dark-mode`). In multi-doc mode, branchName is confirmed with the user.
- [ ] Each story is completable in one iteration (small enough)
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser using Chrome integration" as criterion (optional if Chrome disabled)
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
- [ ] **Type assigned** to each story (`"logic"`, `"ui"`, or `"hybrid"` for categorization)
- [ ] **Verify assigned** to each story (`"inline"` default, `"deep"` for final story and complex/security stories)
- [ ] **Size assigned** to each story (`"small"`, `"medium"`, or `"large"`)
- [ ] **Complexity assigned** to each story (`"simple"` or `"complex"`, default `"complex"`)
- [ ] **Time fields** set to empty strings (`"startTime": ""`, `"endTime": ""`)
- [ ] **dependsOn** set for each story (empty array if no dependencies)
- [ ] **waves** computed if 6+ stories with independent chains (in multi-doc mode: computed from the combined cross-Feature graph after ID renumbering)
- [ ] **scenarios.json** generated at `.takt/scenarios.json` with 2-5 BDD scenarios per story
- [ ] **knownIssues** populated for stories affected by pre-existing failures (empty array if none)

---

## After Creating sprint.json

Once you have saved `sprint.json` and `.takt/scenarios.json`, present a summary and offer to start the loop.

**Single-doc mode output:**
```
✅ sprint.json ready!
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

**Multi-doc mode output** (includes merge summary before the story list):
```
✅ sprint.json ready!
✅ .takt/scenarios.json generated (hidden from workers, used by verifier)

Merged 3 Feature docs:
  feature-dark-mode.md      3 stories → US-001–US-003 (unchanged)
  feature-notifications.md  2 stories → US-004–US-005 (renumbered from US-001–US-002)
  feature-user-profile.md   3 stories → US-006–US-008 (renumbered from US-001–US-003)

Branch: takt/sprint-1
Stories: 8 total (Y small, Z medium, W large)
  - US-001: [title] (small, inline)
  ...

Would you like me to start the takt?
This will:
1. Create the feature branch (takt/sprint-1)
2. Run all stories autonomously
3. Ask about merge/PR when complete
```

If the user says yes:
1. Say `start takt` (it handles branch creation automatically)

**Note:** The user can review sprint.json before starting. This is their last checkpoint before autonomous execution begins.
