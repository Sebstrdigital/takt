# Feature: Review lenses in the final gate + DevOps preflight

## Goal

1. The takt final gate reviews with the three shared lenses (functional,
   technical, security) from `~/.claude/docs/review-lenses.md` instead of its
   own four passes. Functional review against the sprint's acceptance criteria
   is the gap today: no pass reads the spec.
2. A security lens the reviewer declines never passes silently.
3. A plain, no-LLM preflight script (`devops-checks.sh`) makes Munin, the
   validation VM, Codex and GitHub push access hard prerequisites of a run.

## Context (already done, outside this repo)

- `~/.claude/docs/review-lenses.md` exists (agent-tools). It holds all
  checklist content: Lens 1 functional, Lens 2 technical (old passes 1, 2 and
  the non-spec part of 4), Lens 3 security (old pass 3, expanded, defensive
  wording, `security: declined`).
- The `skeptic` relay (agent-tools) already compiles its Codex brief from that
  file, gathers project rules (CLAUDE.md, AGENTS.md,
  `.takt/final-gate-checklist.md`, Munin) and surfaces `security: declined`.
- `~/.claude/lib/codex-review.sh` runs Codex with liveness checks.

## Decisions

- One review only: the final gate on the whole branch (the PR review). No
  per-story Codex review; the verifier stays as the per-story behaviour check.
- `final-gate.md` keeps only takt mechanics: inputs, cycles, ids, status
  vocabulary, `review-comments.json` shape, verdicts, return contract. All
  checklist content moves out (it now lives in review-lenses.md).
- `review-comments.json` buckets become `functional`, `technical`, `security`
  (were `pass1_conventions`, `pass2_sre`, `pass3_security`, `pass4_adversary`).
  Ids, statuses and summary fields are unchanged.
- The gate is given the sprint's acceptance criteria (`sprint.json` path) so
  the functional lens has a spec.
- `security: declined` from Codex → the gate result carries
  `securityDeclined: true` → takt re-runs the gate once in direct mode on
  sonnet (same path as `codexUnavailable`).
- `devops-checks.sh` is plain bash, deterministic, zero tokens. Required checks
  failing → takt stops in Phase 0 with the fix hint. No DevOps skill or scout.

## Stories

- **US-001** Gate uses the three lenses (final-gate.md, takt-run.js gate
  prompts, README).
- **US-002** `securityDeclined` fallback in takt-run.js.
- **US-003** `lib/devops-checks.sh` + install.
- **US-004** run.md Phase 0 runs the preflight and stops on failure.
- **US-005** README.md brought up to date with all of the above (wave 3).

## Out of scope

- Editing anything under `~/.claude/` (installed copies, `run-local.md`): the
  session agent syncs those after the run.
- A Pi/OMP reviewer. Codex stays the reviewer.
