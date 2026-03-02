# PRD: Code Review Agent

## Introduction

Add an unbiased code review step to takt's pipeline, running after scenario verification passes and before completion. A read-only Sonnet agent reviews the final diff against project conventions (CLAUDE.md) and general code quality, producing structured review comments. Must-fix issues trigger a fix loop (max 2 cycles); suggestions are informational only.

This closes the quality gap identified across 6 project retros: convention violations, implicit dependencies, placeholder code, and naming mismatches all shipped uncaught because the scenario verifier only checks behavioral correctness, not code quality.

## Goals

- Catch code quality issues (naming, conventions, duplication, security hygiene) before completion
- Provide an unbiased second opinion — the reviewer never sees story instructions, only the resulting code
- Auto-fix must-fix issues via the existing Ralph Wiggum pattern (fresh fix workers)
- Keep suggestions out of the fix loop — they're informational for the human

## User Stories

### US-001: Create the code review agent prompt

**Description:** As a takt orchestrator, I want a reviewer agent prompt so that I can spawn a read-only agent to review the final codebase after verification passes.

**Acceptance Criteria:**
- When the reviewer agent is spawned with a diff and CLAUDE.md contents, it produces a `review-comments.json` file with structured comments (file, line, severity, comment)
- When a comment has severity `must-fix`, the orchestrator knows to trigger a fix loop; when severity is `suggestion`, no fix is attempted
- The reviewer agent never modifies source code — it only reads and writes its review output

### US-002: Wire review phase into solo.md orchestrator

**Description:** As a takt user running solo mode, I want the orchestrator to run a code review after scenario verification so that quality issues are caught before completion.

**Acceptance Criteria:**
- When scenario verification passes, the orchestrator spawns a reviewer agent before proceeding to completion
- When the reviewer finds must-fix issues, the orchestrator spawns fresh fix workers for each issue (max 2 review-fix cycles), then re-runs the reviewer
- When must-fix issues remain after 2 cycles, the orchestrator includes them in its completion output as known issues and proceeds (does not block completion)

### US-003: Wire review phase into team-lead.md orchestrator

**Description:** As a takt user running team mode, I want the same code review phase available in team executions.

**Acceptance Criteria:**
- When scenario verification passes in team mode, the team lead spawns a reviewer agent with the same prompt and flow as solo mode
- When must-fix issues are found, the team lead spawns fix workers and re-reviews (same 2-cycle limit as solo)
- When the review phase completes (pass or after 2 cycles), the team lead proceeds to completion with review results included in output

## Functional Requirements

- FR-1: The reviewer agent prompt must be stored at `lib/reviewer.md` (source) and installed to `~/.claude/lib/takt/reviewer.md`
- FR-2: The reviewer agent must read the project's CLAUDE.md to understand project-specific conventions
- FR-3: The reviewer agent must read the git diff of the feature branch against the base branch to see all changes
- FR-4: The reviewer must produce `review-comments.json` in the project root with this structure:
  ```json
  {
    "comments": [
      {
        "file": "src/foo.ts",
        "line": 42,
        "severity": "must-fix",
        "comment": "Implicit dependency on pyyaml — not in pyproject.toml"
      }
    ],
    "summary": "2 must-fix, 3 suggestions"
  }
  ```
- FR-5: Severity levels are `must-fix` (triggers fix loop) and `suggestion` (informational only)
- FR-6: The review-fix loop follows Ralph Wiggum pattern — fix workers receive only the review comment text, not the full review context
- FR-7: Max 2 review-fix cycles. After 2 cycles, any remaining must-fix items are reported but do not block completion
- FR-8: The reviewer agent must be spawned with `subagent_type: "general-purpose"`, `model: "sonnet"`, `mode: "bypassPermissions"`
- FR-9: `review-comments.json` must be added to the retro agent's cleanup list (deleted after retro along with other run artifacts)
- FR-10: `install.sh` must copy `reviewer.md` to `~/.claude/lib/takt/` alongside the other agent prompts

## Non-Goals

- No automated PR creation (separate future feature — Gap 3)
- No auto-retro triggering (separate future feature — Gap 4)
- No CI integration or deployment checks
- Reviewer does not run tests or execute code — read-only analysis only
- Suggestions are never auto-fixed — only must-fix items enter the fix loop
- No changes to the verifier agent, scenario verification flow, or scenarios.json
- No changes to the `/takt` converter or stories.json schema

## Technical Considerations

- The reviewer prompt must be embedded in the orchestrator prompt (same pattern as worker.md and verifier.md) — the session agent reads it and passes contents to the orchestrator
- The review phase slots between scenario verification and completion in both solo.md and team-lead.md — same structural position
- The orchestrator already reads CLAUDE.md contents for worker prompts, so passing it to the reviewer adds no new file reads
- Fix workers spawned from review comments use the same pattern as verify-fix workers (Bug Fix Assignment prompt), but the source is review comments rather than bugs.json
- `review-comments.json` is a run artifact (like `bugs.json`) — cleaned up by retro agent

## Success Metrics

- Convention violations that previously shipped (per retro action items) would be caught by the reviewer
- Must-fix issues are resolved within 2 cycles in the majority of runs
- Review phase adds < 5 minutes to a typical takt run
- Zero false-positive must-fix items that block the pipeline unnecessarily

## Open Questions

- Should the reviewer also check for files that were accidentally committed (e.g., `.DS_Store`, `node_modules`, debug logs)?
- Should `review-comments.json` suggestions be included in the orchestrator's completion output (for eventual PR body use in Gap 3)?
