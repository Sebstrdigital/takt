# Workbook: US-002 - Fix worker and team-lead prompts for native execution

## Decisions
- Added "CRITICAL: No Directory Changes" as a standalone section in worker.md (before Implementation Workflow) for maximum visibility, plus reinforced it in the Rules section
- Placed a note after the Verify step (former step 5, now last workflow step) explaining workers should not update prd.json, rather than leaving a gap where step 6 used to be
- In team-lead.md, prd.json updates happen per-story during Merge Execution (step 5: "On success: update prd.json"), with a verification pass in Completion for anything missed
- Updated workbook path references in team-lead.md (Startup and Merge Planning sections) to match the new `.takt/workbooks/` location
- Completion cleanup uses `rm -rf .worktrees/` and `git branch --list 'takt/*' | xargs -r git branch -D` for thorough cleanup

## Files Changed
- `lib/worker.md` — Removed step 6 (jq prd.json update), added CRITICAL section about no `cd`, changed workbook path to `.takt/workbooks/`, added rules 6 and 7
- `lib/team-lead.md` — Changed subagent_type to `general-purpose` with warning against custom types, added per-merge prd.json update (step 5), updated workbook path references, replaced Completion cleanup with thorough `.worktrees/` removal and branch cleanup

## Blockers Encountered
- None

## Notes for Merge
- No structural changes to step numbering in team-lead.md (Merge Execution gained step 5 and renumbered step 6)
- Worker.md task list still shows 6 steps but step 6 is now "Report done" (was already there), the old step 6 (Update PRD) is removed from the Implementation Workflow section
