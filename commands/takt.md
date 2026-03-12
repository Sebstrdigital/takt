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
  question: "No takt artifacts found. Where would you like to start?"
  header: "Starting fresh"
  options:
    - label: "Full flow — start with /epic (Recommended)"
      description: "Define a high-level Epic first, then break it into Features. Best for large or multi-feature initiatives."
    - label: "Skip Epic — go straight to /feature"
      description: "Jump directly to Feature planning. Best when you already know the scope of a single feature."
    - label: "I already have a Feature doc — convert to sprint.json"
      description: "I have a Feature doc already written — run /sprint to convert it"
```

If the user chooses full flow: invoke `/epic`.
If the user chooses skip Epic: invoke `/feature`.
If the user chooses convert: ask for the Feature doc path or content, then invoke `/sprint`.

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
- [ ] Used AskUserQuestion for all state-presentation gates
- [ ] Did not bypass downstream skill gates (`/epic`, `/feature`, `/sprint` handle their own flow)
- [ ] Each transition offered a "start over" or "go back" path
