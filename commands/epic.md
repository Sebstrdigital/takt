---
name: epic
description: "Define a high-level Epic before breaking it into Features. Use when starting a large piece of work, planning a major initiative, or when asked to create an Epic. Triggers on: create an epic, define epic for, plan this initiative, high-level plan for, break down into features."
source_id: takt
version: 1.0.0
---

# Epic Generator

Define a high-level Epic through a guided interview (problem, users, goals, constraints) that produces a structured epic doc with a proposed Feature breakdown and sequencing rationale.

---

## The Job

1. Check project context (CLAUDE.md)
2. **Gate: Project context** — If CLAUDE.md is missing or thin, offer scan or description
3. **Gate: Problem** — Confirm the problem being solved and target users
4. **Gate: Goals & Constraints** — Confirm goals and constraints
5. **Gate: Feature breakdown** — Confirm proposed Features and sequencing
6. Write the Epic doc
7. **Gate: Review** — Present summary and offer to proceed to `/feature`

**Important:** Do NOT start implementing. Just create the Epic doc.

---

## Step 1: Check Project Context

Before asking any questions, read the project's **CLAUDE.md** to understand:
- What the project does
- Tech stack and conventions
- Existing architecture

**If CLAUDE.md is missing, empty, or under ~20 lines with no meaningful project description (thin):**

Use **AskUserQuestion** to offer context options before proceeding:

```
AskUserQuestion:
  question: "I don't have enough project context to tailor this Epic. How should I proceed?"
  header: "Project context"
  options:
    - label: "I'll describe the project"
      description: "Tell me what the project does, its stack, and any key constraints — I'll use that as context"
    - label: "Run a quick codebase scan first"
      description: "I'll scan the repo structure and key files to infer the project before starting the interview"
```

If the user describes the project, use that as context.
If the user asks for a scan, do a quick scan (top-level directory listing, key config files, any existing docs) — then summarize what you found and proceed.

If CLAUDE.md exists and is substantive (20+ lines with a real project description), skip this gate and proceed directly to Step 2.

---

## Step 2: Gate — Problem & Users

Use **AskUserQuestion** to confirm the core problem and who it affects.

Present your understanding based on what the user said when invoking the skill, plus any project context.

```
AskUserQuestion:
  question: "Here's my understanding of the problem this Epic addresses. Is this correct?"
  header: "Problem & users"
  options:
    - label: "Yes, that's the problem"
      description: "<your 1-2 sentence summary of the problem and who it affects>"
    - label: "Partially — let me clarify"
      description: "I'll refine the problem statement based on your correction"
    - label: "No — different problem"
      description: "I'll ask you to describe the actual problem and target users"
```

If the user corrects, incorporate their feedback. The output of this gate feeds the Epic doc's Problem Statement and Target Users sections.

---

## Step 3: Gate — Goals & Constraints

Use **AskUserQuestion** to confirm what success looks like and what limits apply.

Present a proposed set of goals (what the Epic achieves when done) and constraints (time, budget, technical, regulatory, dependencies).

```
AskUserQuestion:
  question: "Here are the goals I'd set for this Epic, and the constraints I see. Does this match your expectations?"
  header: "Goals & constraints"
  options:
    - label: "Goals and constraints look right"
      description: "<bullet list of goals> | Constraints: <bullet list>"
    - label: "Adjust goals"
      description: "I'll revise the goals based on your feedback"
    - label: "Adjust constraints"
      description: "I'll update the constraints — tell me what I missed or got wrong"
```

If the user corrects, update before proceeding. Constraints are anything that limits how the Epic can be delivered (not implemented).

---

## Step 4: Gate — Feature Breakdown & Sequencing

Use **AskUserQuestion** to confirm how the Epic breaks into Features and the order they should be delivered.

Propose 2-5 Features that together deliver the Epic. Each Feature should be independently deliverable and represent a meaningful chunk of value. Include a brief sequencing rationale explaining why this order makes sense (e.g., dependencies, risk reduction, early value delivery).

```
AskUserQuestion:
  question: "Here's how I'd break this Epic into Features. Does this sequencing make sense?"
  header: "Feature breakdown"
  options:
    - label: "Yes, this breakdown works"
      description: "<numbered list: F-1: Name — one-line description, in delivery order>"
    - label: "Adjust the breakdown"
      description: "I'll revise the Features based on your feedback"
    - label: "Change the sequencing"
      description: "I'll reorder or re-group the Features based on your input"
```

If the user corrects, update before writing the doc. The sequencing rationale must explain why F-1 comes before F-2 (e.g., "F-1 establishes the data model that F-2 and F-3 depend on").

---

## Step 5: Write Epic Doc

Based on the confirmed problem/users, goals, constraints, and Feature breakdown, write the Epic doc. No gate needed — just write it using the confirmed answers.

### Epic Doc Structure

#### 1. Problem Statement
What problem does this Epic solve? Be concrete. Who experiences this problem and when?

#### 2. Target Users
Who are the primary users or stakeholders affected by this Epic? Include secondary users if relevant.

#### 3. Goals
Specific, measurable objectives this Epic achieves (bullet list). Goals should be observable outcomes, not implementation tasks.

#### 4. Constraints
Anything that limits how the Epic can be delivered:
- Technical constraints (existing systems, platforms, languages)
- Time or budget constraints
- Regulatory or compliance requirements
- Dependencies on external teams or systems

#### 5. Feature Breakdown

Numbered list of Features in delivery order:

```
### F-1: [Feature Name]
**Scope:** One paragraph describing what this Feature delivers and why.
**Depends on:** (none, or F-X)

### F-2: [Feature Name]
...
```

#### 6. Sequencing Rationale
2-4 sentences explaining why the Features are ordered the way they are. Reference specific dependencies, risk reduction goals, or early value delivery.

#### 7. Out of Scope
What this Epic will NOT include. Be explicit — this prevents scope creep across all Features.

#### 8. Open Questions
Any unresolved questions that need answers before or during delivery.

---

## Output

- **Format:** Markdown (`.md`)
- **Location:** `tasks/`
- **Filename:** `epic-[epic-name].md` (kebab-case, derived from the Epic title)

---

## Step 6: Gate — Review & Automatic Feature Loop

After writing the Epic doc, present a summary and use **AskUserQuestion** to offer next steps:

```
AskUserQuestion:
  question: "Epic doc saved to tasks/epic-<name>.md (<N> Features). What next?"
  header: "Next step"
  options:
    - label: "Start Feature Planning (Recommended)"
      description: "I'll loop through all Features and create Feature docs for F-1, F-2, etc. — each with the full why/what/what-not interview"
    - label: "Review Epic doc first"
      description: "I'll open the Epic doc so you can read through it before moving to Feature planning"
    - label: "Done for now"
      description: "Keep the Epic doc, I'll plan Features later"
```

### If the user chooses "Start Feature Planning":

1. For each Feature in the confirmed Feature breakdown (F-1, F-2, ... F-N):
   - Invoke the `/feature` skill with context about which Feature is being planned
   - **Wait for the Feature doc to be written** (the skill will return after the Feature doc is saved)
   - Do NOT proceed to the next Feature until the current one's doc is saved
2. After all Feature docs are written:
   - Collect the filenames of all created Feature docs (e.g., `feature-auth-flow.md`, `feature-user-profiles.md`)
   - Present a summary showing all Feature docs created
   - Use **AskUserQuestion** to offer handoff to `/sprint`:

   ```
   AskUserQuestion:
     question: "Feature planning complete. I've created Feature docs for all <N> Features. What next?"
     header: "Planning complete"
     options:
       - label: "Merge Features into sprint.json"
         description: "Run /sprint to combine all Feature docs into a single sprint.json with scenarios"
       - label: "Review Feature docs first"
         description: "I'll open each Feature doc so you can review before converting to sprint"
       - label: "Done for now"
         description: "Keep the Feature docs, I'll convert to sprint later"
   ```

   If the user chooses to merge: invoke `/sprint` with all Feature doc filenames

### If the user chooses "Review Epic doc first" or "Done for now":
- Proceed as before (user will manually invoke `/feature` later, or end the flow)

---

## Checklist

Before saving the Epic doc:

- [ ] Checked CLAUDE.md — if thin/missing, offered scan or description gate
- [ ] Confirmed problem statement and target users via AskUserQuestion gate
- [ ] Confirmed goals and constraints via AskUserQuestion gate
- [ ] Confirmed Feature breakdown and sequencing via AskUserQuestion gate
- [ ] 2-5 Features, each independently deliverable
- [ ] Sequencing rationale explains the order
- [ ] Out of scope section populated
- [ ] Saved to `tasks/epic-[epic-name].md`
