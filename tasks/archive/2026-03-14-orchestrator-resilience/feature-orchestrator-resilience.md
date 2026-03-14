# Feature: Orchestrator Resilience & Developer Workflow

## Introduction

The takt orchestrator silently ignores retro alerts, provides no guidance on prompt file shipping, and doesn't explain sequential fallback behavior. These gaps cause repeated manual work (re-discovering stale retro items), forgotten install.sh runs (prompt drift between source and installed files), and confusion when parallel sprints run sequentially without explanation. This feature closes all three gaps with minimal changes to run.md and CLAUDE.md.

## Goals

- Retro alerts with status `confirmed` are visible to the human before a sprint starts
- Developers are prompted to sync install.sh when prompt files change
- A documented shipping checklist exists for releasing takt prompt changes
- The completion report explains when sequential fallback occurred and its time impact

## User Stories

### US-001: Surface retro alerts before sprint start
**Description:** As a takt user, I want to see confirmed retro alerts before a sprint begins so that I can decide whether to address them in this run.

**Acceptance Criteria:**
- [ ] When `.takt/retro.md` exists and contains alerts with status `confirmed`, they are printed as warnings before the start line
- [ ] When no confirmed alerts exist (or no retro.md), the sprint starts normally with no extra output
- [ ] Alerts are non-blocking — the sprint proceeds after printing them

### US-002: Install.sh sync rule in CLAUDE.md
**Description:** As a takt developer, I want Claude Code to remind me to run install.sh when I've modified prompt files so that installed prompts never drift from source.

**Acceptance Criteria:**
- [ ] CLAUDE.md contains a development workflow rule that triggers when files in lib/, commands/, or agents/ are modified
- [ ] The rule instructs Claude Code to ask the user whether to run install.sh before committing or pushing
- [ ] The rule is specific enough that Claude Code can follow it without ambiguity

### US-003: Shipping checklist in CLAUDE.md
**Description:** As a takt developer, I want a documented checklist for releasing prompt changes so that every change is verified end-to-end before shipping.

**Acceptance Criteria:**
- [ ] CLAUDE.md contains a shipping checklist section covering: run install.sh, test in a real project with `start takt`, verify all phases complete
- [ ] The checklist is positioned in the development workflow section alongside the sync rule

### US-004: Sequential fallback note in completion report
**Description:** As a takt user, I want the completion report to explain when waves were present but stories ran sequentially so that I understand the time impact and know it wasn't a bug.

**Acceptance Criteria:**
- [ ] When sprint.json has waves but stories executed sequentially, the completion report includes a note explaining the fallback
- [ ] The note mentions that parallel Task spawning was unavailable and estimates the additional time taken
- [ ] When stories ran in parallel as expected, no fallback note appears

## Functional Requirements

- FR-1: run.md Phase 1 must read `.takt/retro.md` after reading sprint.json and before printing the start line
- FR-2: Alert parsing must look for the alerts table in retro.md and filter for rows with status `confirmed`
- FR-3: Warning format must be concise — one line per alert with the alert description
- FR-4: CLAUDE.md sync rule must reference the specific directories (lib/, commands/, agents/) that contain prompt files
- FR-5: CLAUDE.md shipping checklist must be actionable steps, not aspirational guidelines
- FR-6: Sequential fallback detection must compare the presence of `waves` in sprint.json against actual execution mode
- FR-7: The fallback note must appear in the final report section, not mid-execution

## Non-Goals

- Green/yellow auto-classification of action items (future improvement, parked in future-improvements.md)
- Auto-injecting retro items as stories into sprint.json
- Git hooks or pre-commit scripts for install.sh sync
- Blocking the sprint on unresolved alerts (warnings only)
- Fixing the dua-erp stale retro alert (separate repo, trivial fix)

## Technical Considerations

- run.md is a prompt file, not executable code — changes are natural language instructions to the orchestrator LLM
- CLAUDE.md is read by Claude Code at session start — rules there are enforced by the LLM, not by tooling
- The retro.md alerts table format is already defined in retro.md's output structure (markdown table with columns: Alert, Status, Carried, Source)
- Sequential fallback detection is implicit — if waves exist but the orchestrator chose sequential execution, it knows why

## Success Metrics

- Zero retro items carried more than 2 sprints without the human seeing them
- install.sh is never forgotten after prompt file changes (no more "out of sync" surprises)
- Users understand sequential fallback without asking "why did this take so long?"

## Open Questions

None — all decisions confirmed through gates.
