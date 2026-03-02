# takt Solo Mode

This file has two sections. The **session agent** (you) reads "How to Launch". The spawned orchestrator Task follows "Orchestrator Instructions".

---

## How to Launch

You are the session agent. Your job is to launch the orchestrator as a background Task and monitor its progress. You do NOT orchestrate or write code yourself.

### 1. Read stories.json

```bash
cat stories.json
```

Validate it has a `userStories` array. Print the story matrix:

```
takt solo — <branchName> (<N> stories)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
US-001  <title>         pending
US-002  <title>         pending  (needs: US-001)
US-003  <title>         pending
```

### 2. Read supporting files

Read all four files and store their contents — you will pass them in the orchestrator prompt:

```bash
cat ~/.claude/lib/takt/worker.md
cat ~/.claude/lib/takt/verifier.md
cat ~/.claude/lib/takt/reviewer.md
```

Also read the orchestrator instructions from the section below ("## Orchestrator Instructions" onward in this file).

### 3. Spawn orchestrator Task

Spawn ONE Task with ALL context embedded in the prompt:

- **subagent_type**: `"general-purpose"`
- **model**: `"sonnet"`
- **mode**: `"bypassPermissions"`
- **run_in_background**: `true`
- **description**: `"takt solo — <branchName>"`
- **prompt**: Compose from:
  ```
  # takt Solo Orchestrator

  ## Project Working Directory
  <absolute path to project root>

  ## stories.json
  <full contents of stories.json>

  ## Worker Instructions
  <contents of worker.md>

  ## Verifier Instructions
  <contents of verifier.md>

  ## Reviewer Instructions
  <contents of reviewer.md>

  ## Orchestrator Instructions
  <contents of the "Orchestrator Instructions" section from this file>
  ```

### 4. Monitor progress

Loop until the orchestrator completes:

1. `TaskOutput(block=true, timeout=30000)` — wait for output
2. Read `stories.json` to check for status changes
3. Print one-liner updates as stories complete:
   ```
   US-001 completed (4 min)
   US-003 completed (3 min)
   Verification: PASSED
   ```

### 5. On completion

When the orchestrator finishes (or you see `<promise>COMPLETE</promise>` in its output):

```
All stories complete. Run `takt retro` to wrap up.
```

If the orchestrator reports failure, relay the failure summary to the user.

---

## Orchestrator Instructions

You are the solo orchestrator for a takt execution. You process ALL stories in `stories.json`, spawning a fresh worker agent for each story. **You never write code yourself — you only coordinate.**

**Execution order:** Stories run in priority order. Stories with no unmet `dependsOn` can be started in parallel — solo mode optimizes throughput by running independent stories concurrently when possible, then waits for all to complete before starting dependent stories. This is intentional: "solo" means one orchestrator (no TeamCreate), not necessarily sequential execution.

The stories.json content, worker instructions, verifier instructions, and reviewer instructions are provided in your prompt above. Do NOT read these files from disk — use the content you were given.

## Startup

1. Parse the stories.json content from your prompt
2. Validate it has a `userStories` array
3. Read any existing `workbook-*.md` files in `.takt/workbooks/` for context from previous runs
4. Create or switch to the feature branch specified in `branchName`:
   ```bash
   # Check if branch exists
   git show-ref --verify --quiet "refs/heads/<branchName>" && \
     git checkout <branchName> || \
     git checkout -b <branchName>
   ```
5. Ensure `.takt/workbooks/` directory exists:
   ```bash
   mkdir -p .takt/workbooks
   ```

## Story Loop

Get incomplete stories sorted by priority:
```bash
jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[] | .id' stories.json
```

For each incomplete story (in priority order):

### 1. Check Dependencies

Before starting a story, verify all its `dependsOn` stories have `passes: true`:
```bash
jq -r --arg id "<STORY-ID>" '
  .userStories[] | select(.id == $id) | .dependsOn[]
' stories.json
```

For each dependency ID, check it passes. If any dependency has `passes: false`, **skip this story** and continue to the next. Log: "Skipping <STORY-ID>: dependency <DEP-ID> not yet complete."

### 2. Record Start Time

```bash
jq --arg id "<STORY-ID>" --arg time "$(date +"%Y-%m-%d %H:%M")" \
  '(.userStories[] | select(.id == $id) | .startTime) = $time' \
  stories.json > stories.json.tmp && mv stories.json.tmp stories.json
```

### 3. Build Worker Prompt

Read the full story object from stories.json:
```bash
jq --arg id "<STORY-ID>" '.userStories[] | select(.id == $id)' stories.json
```

Compose the task prompt by combining:

```
# Story Assignment: <STORY-ID> - <Story Title>

## Project Working Directory
<absolute path to project root>

## Story Details
<full story JSON object>

## Acceptance Criteria
<list each criterion>

## Worker Instructions
<contents of worker.md from your prompt>

## Important Rules for This Execution

1. **Do NOT modify stories.json** — the orchestrator handles this
2. **Use absolute paths everywhere** — never use `cd` to change directories
3. **Write your workbook to**: .takt/workbooks/workbook-<STORY-ID>.md
4. **Commit format**: feat: <STORY-ID> - <Story Title>
5. **Do NOT report status via SendMessage** — you are running as a Task, not a team member
6. **Focus only on your assigned story** — do not touch other stories
```

### 4. Spawn Worker Agent

Spawn the worker as a Task agent:

- **subagent_type**: `"general-purpose"`
- **model**: `"sonnet"`
- **mode**: `"bypassPermissions"`
- **run_in_background**: `true`
- **description**: `"Implement <STORY-ID> - <Story Title>"`
- **prompt**: The composed prompt from step 3

Wait for the task to complete by checking its output.

### 5. Verify Completion

After the worker finishes, verify the story was implemented:

1. Check git log for the expected commit:
   ```bash
   git log --oneline -5 | grep "<STORY-ID>"
   ```
2. Check that the workbook was written:
   ```bash
   ls .takt/workbooks/workbook-<STORY-ID>.md
   ```
3. If both checks pass, the story is considered complete.

### 6. Update stories.json

If verification passes, mark the story as complete:
```bash
jq --arg id "<STORY-ID>" '(.userStories[] | select(.id == $id) | .passes) = true' \
  stories.json > stories.json.tmp && mv stories.json.tmp stories.json
```

Record end time:
```bash
jq --arg id "<STORY-ID>" --arg time "$(date +"%Y-%m-%d %H:%M")" \
  '(.userStories[] | select(.id == $id) | .endTime) = $time' \
  stories.json > stories.json.tmp && mv stories.json.tmp stories.json
```

### 7. Handle Failure

If verification fails (no commit found or worker reported errors):

1. **Retry once** — spawn a fresh worker with the same prompt, plus context about what went wrong:
   ```
   ## Previous Attempt Failed
   The previous worker failed to complete this story. Error context:
   <error details from the failed attempt>

   Please try again from scratch. Read the codebase first, then implement.
   ```
2. **If retry also fails** — mark the story as blocked and continue:
   - Do NOT set `passes: true`
   - Log: "BLOCKED: <STORY-ID> failed after 2 attempts"
   - Continue to the next story, skipping any stories that `dependsOn` this one

### 8. Continue Loop

After processing a story (success, skip, or block), move to the next incomplete story. Repeat until all stories are processed.

If stories were skipped due to blocked dependencies, make a second pass — some may have become unblocked if their dependencies were completed in a different order.

## Scenario Verification Phase

After the story loop completes, check if ALL stories have `passes: true`:

```bash
jq '[.userStories[] | select(.passes == false)] | length' stories.json
```

If any stories still have `passes: false`, report which stories are incomplete and why, then STOP. Do not output the completion signal.

If ALL stories pass, run scenario verification:

**CRITICAL: NEVER read `.takt/scenarios.json` content — only pass the file path to the verifier. The orchestrator must remain isolated from scenario data.**

1. Get the recent git changes:
   ```bash
   git log --oneline -20
   ```

2. Spawn a SINGLE verifier Task agent for all stories:
   - **subagent_type**: `"general-purpose"`
   - **model**: `"sonnet"`
   - **mode**: `"bypassPermissions"`
   - **run_in_background**: `true`
   - **prompt**:
     ```
     # Scenario Verification

     ## Scenarios File Path
     .takt/scenarios.json

     ## Verifier Instructions
     <contents of verifier.md from your prompt>

     ## Recent Changes
     <git log output>

     Read .takt/scenarios.json and verify each scenario against the codebase.
     ```

3. If verifier reports `VERIFICATION: FAILED`, enter the **verify-fix loop**:

   Track a cycle counter starting at 1 (the initial verification above counts as cycle 1).

   **While cycle <= 3 and verification is FAILED:**

   a. Read `bugs.json` from the project root:
      ```bash
      cat bugs.json
      ```
      The orchestrator MAY read bugs.json — it contains only behavioral descriptions, no scenario data.

   b. For each bug in bugs.json, spawn a fresh fix worker (Ralph Wiggum pattern — no scenario context):
      - **subagent_type**: `"general-purpose"`
      - **model**: `"sonnet"`
      - **mode**: `"bypassPermissions"`
      - **run_in_background**: `true`
      - **prompt**:
        ```
        # Bug Fix Assignment: <BUG-ID>

        ## Project Working Directory
        <absolute path to project root>

        ## Bug Description
        <bug.description>

        ## Expected Behavior
        <bug.expected>

        ## Actual Behavior
        <bug.actual>

        ## Instructions
        Investigate the codebase and fix the described bug. Do not ask for clarification.
        Commit your fix with message: fix: <BUG-ID> - <short description>
        Use absolute paths everywhere. Do NOT modify stories.json.
        ```

      Wait for all fix workers to complete before proceeding.

   c. Increment the cycle counter.

   d. Re-run scenario verification: spawn a fresh verifier Task agent (same prompt structure as step 2 above).

   e. If `VERIFICATION: PASSED` -> exit the loop and proceed to Completion.
      If `VERIFICATION: FAILED` and cycle <= 3 -> repeat from step (a).
      If `VERIFICATION: FAILED` and cycle > 3 -> exit the loop with failure (see step 4).

4. After 3 failed cycles (cycle counter exceeded 3 with status still FAILED), output a **failure report** and STOP:

   ```
   ## Verification Failure Report

   Scenario verification failed after 3 fix cycles. The following behaviors remain broken:

   <for each bug in the final bugs.json, list: bug.id — bug.description>

   No further automatic fixing will be attempted. Manual intervention required.
   ```

   Do NOT include scenario IDs, Given/When/Then text, or any content from scenarios.json in this report. Only use the behavioral descriptions from bugs.json.

   Do NOT output `<promise>COMPLETE</promise>`.

5. If verifier reports `VERIFICATION: PASSED` (either on the first run or after a fix cycle), proceed to the Code Review Phase.

## Code Review Phase

After scenario verification passes, run a code review before proceeding to completion.

**CRITICAL: The reviewer agent is completely isolated — it receives only the diff and CLAUDE.md, never story instructions or scenario data.**

1. Get the feature branch diff:
   ```bash
   git diff main...HEAD
   ```

2. Read the project's CLAUDE.md:
   ```bash
   cat CLAUDE.md
   ```

3. Spawn a SINGLE reviewer Task agent:
   - **subagent_type**: `"general-purpose"`
   - **model**: `"sonnet"`
   - **mode**: `"bypassPermissions"`
   - **run_in_background**: `true`
   - **prompt**:
     ```
     # Code Review

     ## Project Working Directory
     <absolute path to project root>

     ## CLAUDE.md Contents
     <contents of CLAUDE.md>

     ## Feature Branch Diff
     <output of git diff main...HEAD>

     ## Reviewer Instructions
     <contents of reviewer.md from your prompt>

     Review the diff against the project conventions and general code quality. Write review-comments.json to the project root.
     ```

4. After the reviewer completes, read `review-comments.json`:
   ```bash
   cat review-comments.json
   ```

5. Count must-fix items:
   - If zero must-fix items → proceed to Completion
   - If one or more must-fix items → enter the **review-fix loop**

### Review-Fix Loop

Track a review cycle counter starting at 1 (the initial review above counts as cycle 1). **Max 2 cycles.**

**While cycle <= 2 and must-fix items remain:**

a. For each must-fix comment in `review-comments.json`, spawn a fresh fix worker (Ralph Wiggum pattern — receives only the comment text):
   - **subagent_type**: `"general-purpose"`
   - **model**: `"sonnet"`
   - **mode**: `"bypassPermissions"`
   - **run_in_background**: `true`
   - **prompt**:
     ```
     # Code Review Fix: <file>:<line>

     ## Project Working Directory
     <absolute path to project root>

     ## Issue to Fix
     <comment text from review-comments.json>

     ## Instructions
     Investigate the codebase and fix the described issue. Do not ask for clarification.
     Commit your fix with message: fix: review - <short description>
     Use absolute paths everywhere. Do NOT modify stories.json.
     ```

   Wait for all fix workers to complete before proceeding.

b. Increment the cycle counter.

c. Re-run the reviewer: spawn a fresh reviewer Task agent (same prompt structure as step 3 above, with an updated diff).

d. Read the new `review-comments.json` and count must-fix items.

e. If zero must-fix items → exit the loop and proceed to Completion.
   If must-fix items remain and cycle <= 2 → repeat from step (a).
   If must-fix items remain and cycle > 2 → exit the loop and proceed to Completion with known issues.

### Review Phase Completion

After the review-fix loop:
- If **no must-fix items remain**: proceed to Completion normally.
- If **must-fix items still remain after 2 cycles**: include them in the completion output and proceed (do NOT block completion):
  ```
  ## Code Review — Known Issues (unresolved after 2 fix cycles)

  <for each remaining must-fix comment: file:line — comment text>

  These issues were not automatically resolved. Manual review recommended.
  ```

## Completion

After all stories pass (including deep verification):

1. Run any project-level quality checks if a test suite exists:
   ```bash
   # Check for common test runners and run if found
   [ -f "package.json" ] && npm test 2>/dev/null || true
   [ -f "Makefile" ] && make test 2>/dev/null || true
   ```

2. Commit the final stories.json state:
   ```bash
   git add stories.json
   git commit -m "chore: mark all stories complete in stories.json" --allow-empty
   ```

3. Output the completion signal:
   ```
   <promise>COMPLETE</promise>
   ```

4. Suggest next steps:
   ```
   All stories complete. Suggested next steps:
   - Run `takt retro` to generate retrospective and clean up run artifacts
   - Create a PR for branch <branchName>
   ```

## Rules

1. **Never write code** — you orchestrate, you do not implement
2. **Fresh agent per story** — each story gets a new Task agent with no prior context (Ralph Wiggum pattern)
3. **Only you update stories.json** — workers must NOT touch stories.json
4. **Respect priority order** — process stories lowest priority number first
5. **Respect dependencies** — never start a story whose dependencies have not passed
6. **Max 1 retry** — if a story fails twice, mark it blocked and move on
7. **Use absolute paths** — never rely on relative paths or `cd`
8. **Log progress** — after each story, print a status summary showing completed/remaining/blocked counts
