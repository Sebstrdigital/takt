---
name: takt-prd
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
source_id: takt
version: 1.0.0
---

# PRD Generator

Create detailed Product Requirements Documents that are clear, actionable, and suitable for implementation.

---

## The Job

1. Receive a feature description from the user
2. Read the project's CLAUDE.md for architecture, conventions, and key files
3. Ask targeted clarifying questions about genuine ambiguities (skip if the request is already clear)
4. Generate a structured PRD based on project context and answers
5. Save to `tasks/prd-[feature-name].md`

**Important:** Do NOT start implementing. Just create the PRD.

---

## Step 1: Read Project Context

Before asking any questions, read the project's **CLAUDE.md** to understand:

- Tech stack, frameworks, and conventions
- Key files and architecture
- Any project-specific rules or constraints

If the feature targets a specific area (e.g., "add a settings page"), also glance at the relevant directory to see what's already there. But don't do a broad codebase scan — CLAUDE.md should cover the big picture.

## Step 2: Clarifying Questions (Adaptive)

**Only ask about genuine ambiguities.** If the user's description + codebase context already answers a question, skip it.

### Rules:

- **No fixed count.** Ask 0 questions if the request is crystal clear. Ask 6 if it's genuinely ambiguous. The right number depends on the request.
- **Implementation-focused.** Ask about technical decisions, not product basics the user already stated.
- **Informed by CLAUDE.md.** Reference what you know from the project context — don't ask questions you could answer by reading CLAUDE.md.
- **Lettered options for speed.** When asking, provide options so users can respond with "1A, 2C" etc.

### Good questions (informed, specific):

```
1. I see you have a `notifications` table but no in-app notification UI yet.
   Should this feature include an in-app notification center, or just email?
   A. In-app only
   B. Email only
   C. Both
   D. Other: [please specify]

2. Your current auth uses NextAuth with session strategy.
   Should the new admin role use the same session system or a separate JWT-based approach?
   A. Same NextAuth sessions (simpler)
   B. Separate JWT for admin (more isolated)
```

### Bad questions (generic, answerable from context):

- "What is the primary goal?" — The user just told you.
- "Who is the target user?" — Obvious from the feature description.
- "What tech stack are you using?" — It's in CLAUDE.md.

---

## Step 3: PRD Structure

Generate the PRD with these sections:

### 1. Introduction/Overview
Brief description of the feature and the problem it solves.

### 2. Goals
Specific, measurable objectives (bullet list).

### 3. User Stories
Each story needs:
- **Title:** Short descriptive name
- **Description:** "As a [user], I want [feature] so that [benefit]"
- **Acceptance Criteria:** Verifiable checklist of what "done" means

#### Story Scope

- **Prefer fewer stories with broader scope** over many tiny stories. A single story can touch 3-4 files — that's fine.
- **Aim for 3-5 stories** for most features, not 7-10.
- **Roll ancillary work into the story that needs it.** If a story requires a config file, migration, or doc update, that's part of the story — not a separate story.

#### Acceptance Criteria Rules

- **Max 3-4 acceptance criteria per story.** Each criterion should describe a real behavior or outcome.
- **"Typecheck passes" and "lint passes" are ASSUMED** for every story — never list them as explicit criteria.
- Criteria must be verifiable, not vague. "Works correctly" is bad. "Button shows confirmation dialog before deleting" is good.
- **For any story with UI changes:** Always include "Verify in browser using Chrome integration" as one of the criteria.

**Format:**
```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable behavior or outcome
- [ ] Another criterion (max 3-4 total)
- [ ] **[UI stories only]** Verify in browser using Chrome integration
```

#### Anti-Patterns (What NOT to Do)

- **BAD: Separate story for documentation.** Roll doc updates into the story they document.
- **BAD: Separate story for config files or migrations.** Roll into the story that needs them.
- **BAD: 7+ acceptance criteria per story.** Trim to the 3-4 that actually matter.
- **BAD: "Typecheck passes" as an explicit AC.** It's assumed for every story.
- **BAD: 7-10 tiny stories for a feature that could be 3-4 broader ones.** Fewer stories = less overhead, faster delivery.

### 4. Functional Requirements
Numbered list of specific functionalities:
- "FR-1: The system must allow users to..."
- "FR-2: When a user clicks X, the system must..."

Be explicit and unambiguous.

### 5. Non-Goals (Out of Scope)
What this feature will NOT include. Critical for managing scope.

### 6. Design Considerations (Optional)
- UI/UX requirements
- Link to mockups if available
- Relevant existing components to reuse

### 7. Technical Considerations (Optional)
- Known constraints or dependencies
- Integration points with existing systems
- Performance requirements

### 8. Success Metrics
How will success be measured?
- "Reduce time to complete X by 50%"
- "Increase conversion rate by 10%"

### 9. Open Questions
Remaining questions or areas needing clarification.

---

## Writing for Junior Developers

The PRD reader may be a junior developer or AI agent. Therefore:

- Be explicit and unambiguous
- Avoid jargon or explain it
- Provide enough detail to understand purpose and core logic
- Number requirements for easy reference
- Use concrete examples where helpful

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** `tasks/`
- **Filename:** `prd-[feature-name].md` (kebab-case)

---

## Example PRD

```markdown
# PRD: Task Priority System

## Introduction

Add priority levels to tasks so users can focus on what matters most. Tasks can be marked as high, medium, or low priority, with visual indicators and filtering.

## Goals

- Allow assigning priority (high/medium/low) to any task
- Provide clear visual differentiation between priority levels
- Enable filtering and sorting by priority

## User Stories

### US-001: Priority field and display
**Description:** As a user, I want tasks to have a visible priority level so I can see what needs attention first.

**Acceptance Criteria:**
- [ ] Priority column added to tasks table ('high' | 'medium' | 'low', default 'medium')
- [ ] Each task card shows colored priority badge (red=high, yellow=medium, gray=low)
- [ ] Verify in browser using Chrome integration

### US-002: Set and change priority
**Description:** As a user, I want to set or change a task's priority so I can reprioritize as things evolve.

**Acceptance Criteria:**
- [ ] Priority dropdown in task edit modal, pre-selected to current value
- [ ] Saves immediately on selection change
- [ ] Verify in browser using Chrome integration

### US-003: Filter and sort by priority
**Description:** As a user, I want to filter the task list by priority so I can focus on high-priority items.

**Acceptance Criteria:**
- [ ] Filter dropdown with options: All | High | Medium | Low
- [ ] Filter persists in URL params
- [ ] Tasks sorted by priority within each status column (high → medium → low)

## Functional Requirements

- FR-1: Add `priority` field to tasks table ('high' | 'medium' | 'low', default 'medium')
- FR-2: Display colored priority badge on each task card
- FR-3: Include priority selector in task edit modal
- FR-4: Add priority filter/sort to task list

## Non-Goals

- No priority-based notifications or reminders
- No automatic priority assignment based on due date
- No priority inheritance for subtasks

## Technical Considerations

- Reuse existing badge component with color variants
- Filter state managed via URL search params

## Success Metrics

- Users can change priority in under 2 clicks
- High-priority tasks immediately visible at top of lists

## Open Questions

- Should we add keyboard shortcuts for priority changes?
```

---

## Checklist

Before saving the PRD:

- [ ] Read project CLAUDE.md for context
- [ ] Asked clarifying questions only where genuinely ambiguous
- [ ] Incorporated user's answers
- [ ] 3-5 stories with broad scope (not 7-10 tiny ones)
- [ ] Max 3-4 acceptance criteria per story, no boilerplate
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section defines clear boundaries
- [ ] Saved to `tasks/prd-[feature-name].md`

---

## After Creating PRD(s)

Once you have saved the PRD file(s), present a summary and offer to continue:

```
✅ PRD(s) created:
- tasks/prd-feature-name.md (X user stories)
- tasks/prd-another-feature.md (Y user stories)  [if multiple]

Would you like me to convert the first one to prd.json for takt execution?
```

If the user says yes:
1. Use the `/takt` command
2. Convert the specified PRD to `prd.json`

This creates a smooth handoff from planning to execution.

---

## Mode Suggestion

After creating the PRD, suggest the appropriate takt mode:

- **takt solo** — ≤5 stories, mostly linear dependencies, simple feature
- **takt team** — 6+ stories, 2+ independent chains, parallelism pays off
- **takt debug** — Bug fixing, strict verification discipline

Include this in your summary after creating the PRD.
