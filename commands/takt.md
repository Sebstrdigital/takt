---
name: takt
description: "Entry point wrapper for the full takt planning flow. Detects existing artifacts and guides the user from Epic → Feature → Sprint → start takt. Use when starting any new piece of work or when unsure where to begin. Triggers on: /takt, start planning, new feature, where do I start."
source_id: takt
version: 1.0.0
---

# takt Entry Point

Single entry point for the full takt planning flow. Detects where you are and starts from there.

---

## The Flow

```
/epic → /feature → /sprint → start takt
```

Each step builds on the previous:
- `/epic` — Define a high-level Epic with Feature breakdown
- `/feature` — Write a detailed Feature doc with stories and acceptance criteria
- `/sprint` — Convert Feature doc to sprint.json for autonomous execution
- `start takt` — Execute stories autonomously

---

## Step 1: Detect Existing Artifacts

Before asking anything, scan the project for existing takt artifacts to determine where the user already is in the flow.

Check in this order (most complete first):

1. **`sprint.json`** — Sprint is ready to run → offer to start takt directly
2. **`tasks/feature-*.md`** — Feature doc exists → offer to convert to sprint.json
3. **`tasks/epic-*.md`** — Epic exists → offer to plan the next Feature
4. **None found** — No artifacts → start from scratch with `/epic`

Use the **first match** to determine the starting point. If multiple artifacts exist, use the most complete one.

---

## Step 2: Present Detected State and Options

Use **AskUserQuestion** to show what was found and offer where to start:

### Case A: sprint.json found

```
AskUserQuestion:
  question: "I found sprint.json — you're ready to run. What would you like to do?"
  header: "sprint.json found"
  options:
    - label: "Start takt (run stories)"
      description: "Execute the sprint autonomously — I'll say 'start takt' to kick it off"
    - label: "Review sprint.json first"
      description: "Show me the stories and let me check before running"
    - label: "Start over — plan something new"
      description: "Ignore existing sprint.json and start planning from /epic"
```

If the user chooses "Start takt": say `start takt` to trigger the orchestrator.
If the user chooses "Review": read and display sprint.json in a readable summary, then re-present options.
If the user chooses "Start over": proceed to Case D (no artifacts).

### Case B: tasks/feature-*.md found (no sprint.json)

List all feature files found. If there are multiple, ask which one to use.

```
AskUserQuestion:
  question: "I found <N> Feature doc(s). Ready to convert to sprint.json and run?"
  header: "Feature doc(s) found"
  options:
    - label: "Convert <feature-name> to sprint.json"
      description: "Run /sprint on this Feature doc to generate sprint.json + BDD scenarios"
    - label: "Pick a different Feature doc"
      description: "There are <N> docs — I'll list them so you can choose"
    - label: "Start over — create a new Epic"
      description: "Ignore existing Feature docs and start from /epic"
```

If the user chooses to convert: invoke `/sprint` with the selected Feature doc.
If the user chooses to start over: proceed to Case D.

### Case C: tasks/epic-*.md found (no feature doc, no sprint.json)

```
AskUserQuestion:
  question: "I found an Epic doc but no Feature docs yet. Ready to plan the first Feature?"
  header: "Epic found, no Feature yet"
  options:
    - label: "Plan next Feature with /feature"
      description: "Start the gated Feature planning flow for the next unplanned Feature in the Epic"
    - label: "Review Epic doc first"
      description: "Show me the Epic so I can check the Feature breakdown before proceeding"
    - label: "Start over — create a new Epic"
      description: "Create a brand new Epic instead"
```

If the user chooses to plan: invoke `/feature`, passing the Epic context and the first unplanned Feature.
If the user chooses to review: read and display the Epic doc, then re-present options.
If the user chooses to start over: proceed to Case D.

### Case D: No artifacts found

No artifacts exist — start from scratch.

```
AskUserQuestion:
  question: "No takt artifacts found. How would you like to start?"
  header: "Starting fresh"
  options:
    - label: "Quick path — 3-question interview (Recommended for small changes)"
      description: "Answer why/what/what-not and I'll generate sprint.json directly — no Feature doc needed. Best for focused changes or small features."
    - label: "Full flow — start with /epic"
      description: "Define a high-level Epic first, then break it into Features. Best for large or multi-feature initiatives."
    - label: "Skip Epic — go straight to /feature"
      description: "Jump directly to Feature planning. Best when you already know the scope of a single feature."
    - label: "I already have a Feature doc — convert to sprint.json"
      description: "I have a Feature doc already written — run /sprint to convert it"
```

If the user chooses Quick path: run the **Quick Path Interview** (see below).
If the user chooses full flow: invoke `/epic`.
If the user chooses skip Epic: invoke `/feature`.
If the user chooses convert: ask for the Feature doc path or content, then invoke `/sprint`.

---

## Quick Path Interview

Run this when the user selects the Quick path option. Ask all three questions in a **single prompt** — do not split them into separate turns.

```
AskUserQuestion:
  question: "Answer these 3 questions and I'll generate sprint.json directly:\n\n1. Why — What's the motivation? What problem or goal drives this change?\n2. What — What needs to be built or changed? (scope of this sprint)\n3. What not — What is explicitly out of scope? What won't you change?"
  header: "Quick path: 3 questions"
```

Once the user answers all three:

1. **Synthesize the answers** into a feature description (no file saved — this is ephemeral).
2. **Estimate story count** from the "what" scope:
   - Break the "what" into right-sized user stories (as you would for `/sprint`)
   - Count the total stories
   - If count > 5, present a warning to the user and offer two paths:
     ```
     ⚠️  Quick path estimate: X stories (recommended max for quick path: 5).
         Large scope is better handled with a full Feature doc so you can review and refine the scope.

         How would you like to proceed?
     ```
     Then use **AskUserQuestion**:
     ```
     AskUserQuestion:
       question: "Quick path estimate: X stories. How would you like to proceed?"
       header: "Story count too large for quick path"
       options:
         - label: "Continue with quick path anyway"
           description: "Generate sprint.json + scenarios.json now (X stories, may be large for one sprint)"
         - label: "Save as Feature doc instead"
           description: "I'll save your answers as a Feature doc for review and planning"
     ```
     If the user chooses "Continue": proceed to step 3.
     If the user chooses "Save as Feature doc": write a Feature doc to `tasks/feature-[slug].md` based on the answers (using the same format as `/feature` generates) and present summary without generating sprint.json. Exit after the Feature doc is written — do NOT generate sprint.json.
3. **Generate sprint.json** directly at the project root using the same rules as `/sprint`:
   - Break the "what" into right-sized user stories
   - Apply dependency ordering, type, size, complexity, verify fields
   - Set `branchName` from a kebab-case slug of the feature description
   - Use the "why" to write story descriptions and acceptance criteria
   - Use the "what not" to exclude scope that might otherwise creep in
4. **Generate `.takt/scenarios.json`** alongside sprint.json — ALWAYS required, never skipped (same rules as `/sprint`).
5. **Do NOT create a Feature doc** — no `tasks/feature-*.md` artifact is saved (UNLESS the user chose the Feature doc path above).
6. **Present the summary and offer to start**, same as `/sprint` does after conversion:

```
✅ sprint.json ready! (Quick path — no Feature doc created)
✅ .takt/scenarios.json generated (always required, quality gate never skipped)

Branch: takt/[feature-slug]
Stories: X total (Y small, Z medium, W large)
  - US-001: [title] (small, inline)
  - ...

Would you like me to start the takt?
```

If the user says yes: say `start takt`.

**If the user chose the Feature doc path** (when story count > 5), the output is different:

```
✅ Feature doc created!

Saved to: tasks/feature-[slug].md

This Feature doc can now be:
1. Reviewed and refined before conversion
2. Converted to sprint.json later with /sprint when ready
3. Used for wider team planning and discussion
```

In this case, exit after presenting the Feature doc location. Do NOT generate sprint.json or scenarios.json on this path.

---

## Confirmation Gates at Each Transition

Each skill (`/epic`, `/feature`, `/sprint`) already has its own internal confirmation gates. This wrapper respects those — do not bypass them. When invoking a downstream skill, hand off cleanly and let it run its own gated flow.

The transition gates in this wrapper are:
- Detecting state → presenting options (above)
- After `/epic` completes → ask if ready to proceed to `/feature`
- After `/feature` completes → ask if ready to proceed to `/sprint`
- After `/sprint` completes → ask if ready to run `start takt`

Each gate uses **AskUserQuestion** so the user is always in control of when to advance.

---

## Checklist

- [ ] Scanned for `sprint.json`, `tasks/feature-*.md`, `tasks/epic-*.md` before asking anything
- [ ] Presented the correct case (A/B/C/D) based on what was found
- [ ] Case D included both "Quick path" and "Full flow" options
- [ ] Quick path asked all 3 interview questions (why/what/what-not) in a single prompt
- [ ] Quick path estimates story count AFTER user answers all 3 questions
- [ ] Quick path warns if story count > 5 and offers choice: continue or save as Feature doc
- [ ] Quick path generates sprint.json + .takt/scenarios.json without creating a Feature doc artifact (unless user chose Feature doc path)
- [ ] .takt/scenarios.json is ALWAYS generated on quick path (never skipped, mandatory quality gate)
- [ ] Used AskUserQuestion for all state-presentation gates
- [ ] Did not bypass downstream skill gates (`/epic`, `/feature`, `/sprint` handle their own flow)
- [ ] Each transition offered a "start over" or "go back" path
