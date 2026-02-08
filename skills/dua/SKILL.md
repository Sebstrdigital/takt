---
name: dua
description: "Convert PRDs to prd.json format for the DuaLoop autonomous agent system. Use when you have an existing PRD and need to convert it to DuaLoop's JSON format. Triggers on: convert this prd, turn this into dualoop format, create prd.json from this, dua json."
source_id: seb-claude-tools
version: 1.0.0
---

# DuaLoop PRD Converter

Converts existing PRDs to the prd.json format that DuaLoop uses for autonomous execution.

---

## The Job

Take a PRD (markdown file or text) and convert it to `prd.json` in the project root.

---

## Output Format

```json
{
  "project": "[Project Name]",
  "branchName": "dua/[feature-name-kebab-case]",
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
      "model": "sonnet",
      "verify": "inline",
      "startTime": "",
      "endTime": ""
    }
  ]
}
```

---

## Model Assignment: Sonnet vs Opus

Each story should have a `model` field indicating which model should implement it.

**Default to `"sonnet"`** - Most stories should use Sonnet. It's faster, cheaper, and excellent for well-defined tasks with clear acceptance criteria.

**Assign `"opus"` when the story involves:**

| Complexity Indicator | Example |
|---------------------|---------|
| Refactoring across 5+ files | "Rename userId to memberId throughout codebase" |
| Architectural changes | "Convert REST endpoints to GraphQL" |
| Complex debugging | "Fix race condition in async queue processing" |
| Subtle logic | "Implement conflict resolution for concurrent edits" |
| Multiple interacting systems | "Add caching layer with invalidation across services" |
| Performance optimization | "Optimize N+1 queries in dashboard aggregations" |
| Security-sensitive code | "Implement RBAC permission system" |

**Keep `"sonnet"` for:**
- Adding a database column/migration
- Creating a new UI component
- Adding a filter/sort to a list
- Simple CRUD operations
- Adding validation rules
- UI styling changes

**Rule of thumb:** If you hesitate about whether Sonnet can handle it, assign Opus. The cost difference is worth avoiding a failed iteration.

---

## Verification Mode: Inline vs Deep

Each story has a `verify` field controlling how verification happens. This is a **token-efficiency** feature.

**Default to `"inline"`** - The same agent that implements the story verifies it before marking complete. No extra token cost.

**Assign `"deep"` when:**

| Condition | Why Deep Verification |
|-----------|----------------------|
| Story has `"model": "opus"` | Complex stories need thorough verification |
| Story is the LAST in the PRD | Final verification before completion |
| Story touches security/auth | Critical code needs independent verification |
| Story has failed before | Previous attempts didn't work - verify harder |

**How it works:**
- `"verify": "inline"` - Agent verifies own work using Goal-Backward Verification in prompt.md (~0 extra tokens)
- `"verify": "deep"` - After all stories complete, DuaLoop spawns a separate verifier agent to independently confirm goals achieved (~50k-100k tokens)

**Auto-assignment rule:** If you assign `"model": "opus"`, also assign `"verify": "deep"`. They go together.

**Token budget consideration:** In a typical 10-story PRD:
- 8-9 stories: `"verify": "inline"` (0 extra tokens)
- 1-2 stories: `"verify": "deep"` (~100k-200k extra tokens total)

This keeps verification thorough where it matters without burning tokens on simple stories.

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

Each story has a `size` field used for progress tracking and ETA estimation. DuaLoop tracks completion times per size category to improve estimates over time.

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
- Stories with `"model": "opus"` are typically `"medium"` or `"large"`

**Time tracking fields:**
- `startTime` and `endTime` are populated by DuaLoop during execution
- Leave them as empty strings (`""`) when creating prd.json

---

## Story Scope: The Number One Rule

**Each story must be completable in ONE DuaLoop iteration (one context window).**

DuaLoop spawns a fresh Claude Code instance per iteration with no memory of previous work. If a story is too big, the LLM runs out of context before finishing and produces broken code.

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

## Acceptance Criteria: Must Be Verifiable

Each criterion must be something DuaLoop can CHECK, not something vague.

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Clicking delete shows confirmation dialog"
- "Typecheck passes"
- "Tests pass"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"
- "Handles edge cases"

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

Frontend stories are NOT complete until visually verified. DuaLoop will use Chrome browser integration to navigate to the page, interact with the UI, and confirm changes work.

---

## Conversion Rules

1. **Each user story becomes one JSON entry**
2. **IDs**: Sequential (US-001, US-002, etc.)
3. **Priority**: Based on dependency order, then document order
4. **All stories**: `passes: false`
5. **branchName**: Derive from PRD filename, kebab-case, prefixed with `dua/` (e.g., `prd-dark-mode.md` → `dua/dark-mode`)
6. **Always add**: "Typecheck passes" to every story's acceptance criteria
7. **Type assignment**: Assign `"logic"` (TDD), `"ui"` (build-only), or `"hybrid"` based on story content (see Story Type section)
8. **Model assignment**: Evaluate each story's complexity and assign `"sonnet"` (default) or `"opus"` (see Model Assignment section)
9. **Verify assignment**: Set `"verify": "deep"` for opus stories and the final story; otherwise `"verify": "inline"`
10. **Size assignment**: Assign `"small"`, `"medium"`, or `"large"` based on scope (see Story Size Assignment section)
11. **Time tracking**: Set `startTime` and `endTime` to empty strings (`""`)

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

**Output prd.json:**
```json
{
  "project": "TaskApp",
  "branchName": "dua/task-status",
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
      "model": "sonnet",
      "verify": "inline",
      "startTime": "",
      "endTime": ""
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
      "model": "sonnet",
      "verify": "inline",
      "startTime": "",
      "endTime": ""
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
      "model": "sonnet",
      "verify": "inline",
      "startTime": "",
      "endTime": ""
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
      "model": "sonnet",
      "verify": "deep",
      "startTime": "",
      "endTime": ""
    }
  ]
}
```

Note:
- **Type assignments:** US-001 is `"logic"` (database), US-002/US-004 are `"ui"` (visual), US-003 is `"hybrid"` (UI + save logic)
- All stories use `"sonnet"` because they're straightforward CRUD and UI work
- US-004 has `"verify": "deep"` because it's the **final story** - gets independent verification before completion
- Size assignments: US-001, US-002 are `"small"` (single concern), US-003, US-004 are `"medium"` (multiple files/logic)
- If there was a story like "Refactor existing task components" touching 10+ files, it would get `"model": "opus"`, `"verify": "deep"`, and `"size": "large"`

---

## PRD File Naming Convention

The PRD filename and branchName must match so DuaLoop can archive the correct file on completion:

- PRD file: `tasks/prd-dark-mode.md`
- branchName: `dua/dark-mode`

**On completion**, DuaLoop derives the PRD filename from branchName and moves it to archive:
- `dua/dark-mode` → looks for `tasks/prd-dark-mode.md`
- Moves to: `tasks/archive/YYYY-MM-DD-dark-mode/prd-dark-mode.md`

---

## Checklist Before Saving

Before writing prd.json, verify:

- [ ] **branchName matches PRD filename** (e.g., `prd-dark-mode.md` → `dua/dark-mode`)
- [ ] Each story is completable in one iteration (small enough)
- [ ] Stories are ordered by dependency (schema to backend to UI)
- [ ] Every story has "Typecheck passes" as criterion
- [ ] UI stories have "Verify in browser using Chrome integration" as criterion (optional if Chrome disabled)
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
- [ ] **Type assigned** to each story (`"logic"` for TDD, `"ui"` for build-only, `"hybrid"` for mixed)
- [ ] **Model assigned** to each story (`"sonnet"` default, `"opus"` for complex work)
- [ ] **Verify assigned** to each story (`"inline"` default, `"deep"` for opus stories and final story)
- [ ] **Size assigned** to each story (`"small"`, `"medium"`, or `"large"`)
- [ ] **Time fields** set to empty strings (`"startTime": ""`, `"endTime": ""`)

---

## After Creating prd.json

Once you have saved `prd.json`, present a summary and offer to start the loop:

```
✅ prd.json ready!

Branch: dua/feature-name
Stories: X total (Y small, Z medium, W large)
  - US-001: [title] (small, sonnet, inline)
  - US-002: [title] (small, sonnet, inline)
  - US-003: [title] (medium, sonnet, deep) ← final verification

Would you like me to start the DuaLoop?
This will:
1. Create the feature branch (dua/feature-name)
2. Run all stories autonomously
3. Ask about merge/PR when complete
```

If the user says yes:
1. Run `dualoop` (it handles branch creation automatically)

**Note:** The user can review prd.json before starting. This is their last checkpoint before autonomous execution begins.
