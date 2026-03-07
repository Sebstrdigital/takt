# PRD: Scenario-Based Verification for takt

## Introduction

Add a hidden scenario-based verification layer to takt. Instead of relying on workers self-verifying against visible acceptance criteria, an independent verifier agent checks implementations against hidden BDD scenarios that workers never see. This prevents agents from gaming tests and ensures genuine feature implementation.

Also renames `prd.json` to `stories.json` for clear file naming: the PRD is `prd.md`, the executable stories are `stories.json`, and the hidden QA plan is `scenarios.json`.

## Goals

- Prevent workers from gaming verification by hiding test scenarios from implementation agents
- Introduce independent QA-style verification using BDD scenarios (Given/When/Then)
- Rename `prd.json` to `stories.json` for clarity across all takt prompt files
- Generate `scenarios.json` alongside `stories.json` during `/takt` conversion
- Add a verify-fix loop (max 3 cycles) that produces bug tickets — not scenario leakage

## User Stories

### US-001: Rename prd.json to stories.json

**Description:** As a takt user, I want the executable stories file clearly named `stories.json` so it's distinct from the PRD document (`prd.md`).

**Acceptance Criteria:**
- [ ] All prompt files (solo.md, worker.md, team-lead.md, verifier.md, debug.md, retro.md) reference `stories.json` instead of `prd.json`
- [ ] `/takt` slash command outputs `stories.json` instead of `prd.json`
- [ ] CLAUDE.md and README.md updated to reference `stories.json`

### US-002: Generate scenarios.json from PRD

**Description:** As a takt user, I want the `/takt` command to generate hidden BDD scenarios alongside stories so that verification is independent from implementation.

**Acceptance Criteria:**
- [ ] `/takt` command generates `.takt/scenarios.json` alongside `stories.json`
- [ ] Each story gets 2-5 BDD scenarios in Given/When/Then format
- [ ] Scenarios describe behavioral outcomes, not implementation details
- [ ] Scenario structure: `{ "stories": { "US-001": [{ "id": "SC-001", "given": "...", "when": "...", "then": "...", "type": "behavioral" }] } }`

### US-003: Scenario-based verification phase

**Description:** As a takt orchestrator, I want to run a verification phase against hidden scenarios after all stories complete, so that quality is independently validated.

**Acceptance Criteria:**
- [ ] Solo orchestrator spawns verifier with `.takt/scenarios.json` path after all stories pass
- [ ] Team lead spawns verifier after all waves merge
- [ ] Verifier reads scenarios, checks each one, produces per-scenario and per-story pass/fail scoring
- [ ] Information isolation enforced: orchestrator never reads scenarios.json content (only passes path), workers explicitly forbidden from reading `.takt/` directory

### US-004: Bug ticket generation and fix loop

**Description:** As a takt orchestrator, I want failed scenarios to produce bug tickets that workers fix without seeing the original scenarios, looping up to 3 cycles.

**Acceptance Criteria:**
- [ ] Verifier generates `bugs.json` from failed scenarios with behavioral bug descriptions (no scenario text leaked)
- [ ] Orchestrator spawns fresh workers to fix bug tickets using existing Ralph Wiggum pattern
- [ ] Verify-fix loop: verify, generate bugs, fix, re-verify — max 3 cycles
- [ ] After 3 failed cycles, mark feature as failed with detailed report

## Functional Requirements

- FR-1: `/takt` command produces two files: `stories.json` (project root) and `.takt/scenarios.json` (hidden in .takt directory)
- FR-2: Scenarios use BDD Given/When/Then format, 2-5 scenarios per story
- FR-3: Scenarios describe behavioral outcomes observable from outside the code (not implementation assertions)
- FR-4: Verifier agent receives only: `.takt/scenarios.json` path + git log of recent changes. It does NOT receive story acceptance criteria
- FR-5: Verifier outputs scoring: per-scenario pass/fail, per-story pass/fail, overall percentage
- FR-6: On failure, verifier generates `bugs.json` with behavioral bug descriptions compatible with `takt debug` format
- FR-7: Bug tickets describe what's broken, not what scenario failed. Example: "Form accepts empty email without validation error" — NOT "SC-003 Given/When/Then failed"
- FR-8: All references to `prd.json` across all takt prompt files renamed to `stories.json`
- FR-9: Worker prompts include explicit rule: "NEVER read files in `.takt/` — they are system-managed"
- FR-10: Orchestrator prompts include explicit rule: "NEVER read `.takt/scenarios.json` content — only pass the file path to the verifier"
- FR-11: Max 3 verification-fix cycles, then declare failure with report of remaining broken scenarios (described as behaviors, not scenario IDs)

## Non-Goals

- No cryptographic or filesystem-level isolation between agents (prompt-level architectural isolation is sufficient)
- No changes to the PRD generation process (`/takt-prd` remains unchanged, still outputs `prd.md`)
- No scenario editing UI or manual scenario management
- No partial pass thresholds — 100% scenario pass required
- No changes to `takt retro` mode in this iteration
- Workers may still write their own unit tests if they want — but these are not the quality gate

## Technical Considerations

- All changes are to markdown prompt files and the `/takt` slash command — no binary or script changes needed
- `.takt/scenarios.json` lives in `.takt/` which is already treated as system-managed space
- Bug ticket format reuses the existing `bugs.json` schema from `takt debug`
- The rename from `prd.json` to `stories.json` is a breaking change for existing projects — document in README
- Consider adding `.takt/scenarios.json` to worker instructions as an explicit "do not read" path
- In team mode with worktrees, `.takt/scenarios.json` exists only in the main worktree (not copied to story worktrees)

## Information Flow Diagram

```
/takt command (human reviews)
    ├── stories.json    → orchestrator → workers (feature implementation)
    └── .takt/scenarios.json → verifier ONLY (QA verification)
                                    │
                              100%? → DONE
                              <100%?→ bugs.json → fresh workers (fix)
                                                      │
                                                 re-verify (max 3 cycles)
```

**Who sees what:**
| File | Orchestrator | Worker | Verifier | Fix Worker |
|------|-------------|--------|----------|------------|
| stories.json | reads | reads (via prompt) | never | never |
| scenarios.json | passes path only | never | reads | never |
| bugs.json | reads (routing) | never | writes | reads (via prompt) |

## Success Metrics

- Workers cannot access or reference scenario content during implementation
- Verification catches issues that worker self-verification missed
- Bug ticket descriptions are actionable without revealing underlying scenarios
- Full verify-fix-re-verify loop completes within 3 cycles for typical features

## Open Questions

- Should `scenarios.json` be gitignored to prevent team-mode workers from reading it via git?
- Should we add a `takt migrate` helper for existing projects that have `prd.json` files?
- Should the `/takt-prd` PRD template include a "Verification Scenarios" section to seed better scenario generation, or keep PRD and scenarios fully decoupled?
