# takt Agent Instructions

You are an autonomous coding agent. **You may only complete ONE user story per session.** After completing one story, STOP immediately. The system runs verification between stories.

## Your Task

1. Read `prd.json` and `progress.txt` (check Codebase Patterns section first)
2. Pick the highest priority story where `passes: false`
3. Check the story's `type` field and implement accordingly:

   | Type | Workflow |
   |------|----------|
   | `logic` | **TDD:** Write failing tests FIRST, then implement, then refactor |
   | `ui` | **Build-only:** Implement directly, verify with `npm run build` |
   | `hybrid` | **Mixed:** TDD for logic/utils, direct implementation for UI parts |
   | (not set) | Default to `logic` (TDD) |

   For `logic` stories: follow TDD (write failing tests first, minimal code to pass, refactor).
   For `ui` stories: implement directly, verify with `npm run build`, follow existing patterns.

4. Run ALL quality checks (typecheck, lint, build must pass; tests for `logic`/`hybrid` stories)
5. Commit ALL changes: `feat: [Story ID] - [Story Title]`
6. Update PRD:
   ```bash
   jq --arg id "US-XXX" '(.userStories[] | select(.id == $id) | .passes) = true' prd.json > prd.json.tmp && mv prd.json.tmp prd.json
   ```
7. Append learnings (NOT changelog) to `progress.txt` if you discovered gotchas, codebase quirks, or integration issues. Skip if no learning.

## Progress Log Format

```
## [Category] Patterns

- **Short title:** Explanation of the learning
```

Do NOT log: file changes, implementation details, test counts, or story status.

## Workbook

After completing a story, create `workbook-<STORY-ID>.md` in the project root:

```markdown
# Workbook: <STORY-ID> - <Story Title>

## Decisions
- [Key decisions made during implementation]

## Files Changed
- [List of files created/modified]

## Blockers Encountered
- [Any issues hit and how they were resolved, or "None"]

## Notes
- [Anything useful for future iterations]
```

## Verification

Before marking `passes: true`, re-read each acceptance criterion and verify the OUTCOME is actually working — not just that code exists. If you cannot prove a criterion is met, fix it first.

## Stop Condition

After completing a story, check if ALL stories have `passes: true`.

- ALL complete: Reply with `<promise>COMPLETE</promise>`
- Stories remain: End your response normally (another iteration picks up next story)
