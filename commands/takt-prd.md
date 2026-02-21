---
name: takt-prd
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
source_id: takt
version: 2.0.0
---

# PRD Generator

Create detailed Product Requirements Documents through a gated what/why/why-not flow using AskUserQuestion checkpoints.

---

## The Job

1. Read project context
2. **Gate: Why** — Confirm motivation and problem
3. **Gate: What** — Confirm scope and technical decisions
4. **Gate: What Not** — Confirm explicit exclusions
5. Write the PRD
6. **Gate: Review** — Present summary and offer conversion to stories.json

**Important:** Do NOT start implementing. Just create the PRD.

---

## Step 1: Read Project Context

Before asking any questions, read the project's **CLAUDE.md** to understand:

- Tech stack, frameworks, and conventions
- Key files and architecture
- Any project-specific rules or constraints

If the feature targets a specific area (e.g., "add a settings page"), also glance at the relevant directory to see what's already there. But don't do a broad codebase scan — CLAUDE.md should cover the big picture.

## Step 2: Gate — Why

Use **AskUserQuestion** to confirm the motivation.

Present your understanding of the "why" based on what the user said and what you learned from the codebase. Ask the user to confirm or correct.

```
AskUserQuestion:
  question: "Here's my understanding of the motivation. Is this correct?"
  header: "Why"
  options:
    - label: "Yes, that's right"
      description: "<your 1-2 sentence summary of the motivation/problem>"
    - label: "Partially — let me clarify"
      description: "I'll refine the why based on your correction"
    - label: "No — different motivation"
      description: "I'll ask you to describe the actual problem"
```

If the user corrects, incorporate their feedback before proceeding.

## Step 3: Gate — What

Use **AskUserQuestion** to confirm scope and key technical decisions.

Present a scoped list of what you understand needs to be built. If there are genuine technical decisions (e.g., which auth method, which storage approach), present them as options.

```
AskUserQuestion:
  question: "Here's what I plan to include in scope. Is this correct?"
  header: "What"
  options:
    - label: "Yes, build this"
      description: "<bulleted list of features/deliverables>"
    - label: "Adjust scope"
      description: "I'll modify the scope based on your feedback"
    - label: "Too broad — reduce scope"
      description: "I'll cut it down to a smaller deliverable"
```

If the feature involves genuine technical choices (not ones you can answer from CLAUDE.md), ask a follow-up AskUserQuestion with the specific options. Only ask about real ambiguities — don't ask about things the codebase already answers.

## Step 4: Gate — What Not

Use **AskUserQuestion** to confirm explicit exclusions.

Based on the confirmed scope, present what you're explicitly excluding. This maps directly to the PRD's Non-Goals section.

```
AskUserQuestion:
  question: "Here's what I'm explicitly excluding. Anything else out of scope?"
  header: "What not"
  options:
    - label: "Exclusions look right"
      description: "<bulleted list of non-goals>"
    - label: "Add more exclusions"
      description: "I'll add additional items to the non-goals list"
    - label: "Something here should be in scope"
      description: "I'll move items back into scope"
```

## Step 5: Write PRD

Based on the confirmed why/what/what-not, write the PRD. No gate needed — just write it using the confirmed answers.

### PRD Structure

#### 1. Introduction/Overview
Brief description of the feature and the problem it solves.

#### 2. Goals
Specific, measurable objectives (bullet list).

#### 3. User Stories
Each story needs:
- **Title:** Short descriptive name
- **Description:** "As a [user], I want [feature] so that [benefit]"
- **Acceptance Criteria:** Verifiable checklist of what "done" means

##### Story Scope

- **Prefer fewer stories with broader scope** over many tiny stories. A single story can touch 3-4 files — that's fine.
- **Aim for 3-5 stories** for most features, not 7-10.
- **Roll ancillary work into the story that needs it.** If a story requires a config file, migration, or doc update, that's part of the story — not a separate story.

##### Acceptance Criteria Rules

- **Max 3-4 acceptance criteria per story.** Each criterion must describe an observable behavioral outcome — what a user or QA engineer would see, not how the code achieves it.
- **"Typecheck passes" and "lint passes" are ASSUMED** for every story — never list them as explicit criteria.
- Criteria must describe behaviors, not implementation tasks. "Add `status` column to tasks table" is an implementation task. "When a new task is created, it has a default status of 'pending'" is a behavioral outcome.
- **For any story with UI changes:** Always include "Verify in browser using Chrome integration" as one of the criteria.

**Why behavioral outcomes?** Behavioral criteria flow naturally into BDD scenarios used by the verifier. When criteria describe what a user observes, the verifier can independently confirm the feature works — rather than just confirming the worker followed instructions.

**Format:**
```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Observable behavioral outcome (what happens when X)
- [ ] Another behavioral outcome (max 3-4 total)
- [ ] **[UI stories only]** Verify in browser using Chrome integration
```

**Good criteria (behavioral outcomes):**
- "When a new task is created, it has a default status of 'pending'"
- "When a user clicks delete, a confirmation dialog appears before the item is removed"
- "When filtered by 'High' priority, only high-priority tasks are visible in the list"
- "After changing status to 'Done', the change persists across page refreshes"

**Bad criteria (implementation tasks):**
- "Add `status` column to tasks table" — describes code change, not behavior
- "Create migration file" — describes an artifact, not an outcome
- "Update API endpoint" — describes what to build, not what it does

##### Anti-Patterns (What NOT to Do)

- **BAD: Separate story for documentation.** Roll doc updates into the story they document.
- **BAD: Separate story for config files or migrations.** Roll into the story that needs them.
- **BAD: 7+ acceptance criteria per story.** Trim to the 3-4 that actually matter.
- **BAD: "Typecheck passes" as an explicit AC.** It's assumed for every story.
- **BAD: 7-10 tiny stories for a feature that could be 3-4 broader ones.** Fewer stories = less overhead, faster delivery.
- **BAD: Implementation checklists as acceptance criteria.** "Add column", "Create file", "Update function" are implementation tasks, not verifiable behavioral outcomes.

#### 4. Functional Requirements
Numbered list of specific functionalities:
- "FR-1: The system must allow users to..."
- "FR-2: When a user clicks X, the system must..."

Be explicit and unambiguous.

#### 5. Non-Goals (Out of Scope)
What this feature will NOT include. Populated from the confirmed "What Not" gate.

#### 6. Design Considerations (Optional)
- UI/UX requirements
- Link to mockups if available
- Relevant existing components to reuse

#### 7. Technical Considerations (Optional)
- Known constraints or dependencies
- Integration points with existing systems
- Performance requirements

#### 8. Success Metrics
How will success be measured?

#### 9. Open Questions
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

## Step 6: Gate — Review

After writing the PRD, present a summary and use **AskUserQuestion** to offer next steps:

```
AskUserQuestion:
  question: "PRD saved to tasks/prd-<name>.md (<N> stories). What next?"
  header: "Next step"
  options:
    - label: "Convert to stories.json (Recommended)"
      description: "Run /takt to generate stories.json + scenarios for autonomous execution"
    - label: "Review PRD first"
      description: "I'll open the PRD so you can read through it before converting"
    - label: "Done for now"
      description: "Keep the PRD, I'll convert it later"
```

If the user chooses to convert:
1. Use the `/takt` command
2. Convert the specified PRD to `stories.json`
3. After conversion, suggest the appropriate takt mode:
   - **takt solo** — <=5 stories, mostly linear dependencies
   - **takt team** — 6+ stories, 2+ independent chains, parallelism pays off

---

## Checklist

Before saving the PRD:

- [ ] Read project CLAUDE.md for context
- [ ] Confirmed "why" via AskUserQuestion gate
- [ ] Confirmed "what" (scope) via AskUserQuestion gate
- [ ] Confirmed "what not" (exclusions) via AskUserQuestion gate
- [ ] 3-5 stories with broad scope (not 7-10 tiny ones)
- [ ] Max 3-4 acceptance criteria per story, all behavioral outcomes
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals section populated from confirmed exclusions
- [ ] Saved to `tasks/prd-[feature-name].md`
