# Skill / agent overlap with takt pipeline

Scope: read-only inventory, 2026-09-29. Paths: S = ~/.claude/skills, C = ~/.claude/commands, A = ~/.claude/agents, T = /Users/sebastianstrandberg/work/git/takt.
Evidence limits: /private/tmp/claude-501/bundled-skills/2.1.284 holds only `claude-api` files. The built-in `simplify`, `security-review`, `run`, `init` skills have NO file on disk, so their behavior is UNVERIFIED (only the one-line descriptions from the session skill list are known).
Symlinks: S/{diagnose,tdd,grill-with-docs,improve-codebase-architecture,zoom-out,write-a-skill,git-guardrails-claude-code} -> /Users/sebastianstrandberg/work/git/claude-tools/external/mattpocock-skills/skills/... (third-party).
S/deep-review/SKILL.md and C/deep-review.md are duplicates (differ only in source_id line 4: seb-claude-tools vs kraken-custom).

## 1. Inventory

Legend: NI = non-interactive capable. "in-session" = runs in the calling agent's context; "fan-out" = spawns subagents itself.

| Item | Does | Input | Output | Model | Invocation | NI? |
|---|---|---|---|---|---|---|
| S/code-review (174 l) | 25-check, 5-domain quality audit (structure, naming, errors, types, tests, deps); PASS/PARTIAL/FAIL + HIGH/MED/LOW | project root or path arg; reads whole codebase (not diff) | markdown `docs/audits/06-code-review.md` (SKILL.md:46) | caller's | in-session skill | Yes (no questions, 0 AskUserQuestion) |
| C/deep-review + S/deep-review (249 l) | Orchestrator spawns 4 parallel reviewers (framework, resources, security, absence) on `git diff base...HEAD`, dedups, triages block/followup/dismiss with 12-row decision tree, convergence bias on re-runs | optional base branch; reads CLAUDE.md; per-pass checklists in ~/.claude/docs/deep-review/{framework,resources,security,absence}.md | `deep-review-report.json` (project root), `<branch>-followups.md`, temp `/tmp/deep-review*.{diff,json}`; verdict CLEAN / BLOCKERS / CLEAN_WITH_FOLLOWUPS | reviewers `model: "sonnet"`, `mode: "bypassPermissions"`, run_in_background (SKILL.md Step 1); orchestrator = caller | in-session skill that fans out via Agent tool | Yes (no questions) but needs the Agent tool |
| S/security-audit (203 l) | 35-check, 7-domain audit, LLM/web-app oriented; CRITICAL..LOW | project or path; whole codebase | markdown report (Step 4, path under docs/audits per skill convention) | caller's | in-session skill | Yes |
| built-in security-review | UNVERIFIED (no file) | | | | | |
| built-in simplify | "Review changed code for reuse, simplification, efficiency ... then apply the fixes. Quality only" (skill-list description) | changed code | edits files | UNVERIFIED | in-session | UNVERIFIED |
| plugin code-simplifier:code-simplifier (~/.claude/plugins/cache/claude-plugins-official/code-simplifier/...) | Behavior-preserving simplification of recently modified code | recent diff | edits files | `model: opus` | subagent type (Agent tool) | Yes |
| plugin code-review:code-review (…/code-review/fbe07fb6ce7d/commands/code-review.md) | PR review: 5 parallel Sonnet agents (CLAUDE.md compliance, shallow bug scan, git blame, prior PR comments, code-comment compliance), Haiku confidence scoring, drops <80, posts `gh pr comment` | GitHub PR; allowed-tools are `gh` only | PR comment; skips closed/draft/trivial PRs | Sonnet + Haiku | slash command | Yes, but PR-bound (needs a pushed PR); posts externally |
| S/tdd (109 l, mattpocock) | Red-green-refactor, vertical tracer-bullet slices, behavior tests via public interface | feature/bug | tests + code | caller's | in-session skill | NO: Workflow step 1 requires "Confirm with user ... Get user approval on the plan" (tdd/SKILL.md, Planning) |
| S/diagnose (117 l, mattpocock) | 6 phases: build feedback loop, reproduce, 3-5 ranked hypotheses, instrument with `[DEBUG-xxxx]` tags, fix + regression test at correct seam, cleanup + post-mortem | bug report | code fix, regression test, hypothesis in commit msg; hands off to improve-codebase-architecture | caller's | in-session skill | Partly: Phase 1 says stop and ask user if no loop can be built; Phase 3 "show ranked list to user ... Don't block on it" |
| S/debug (69 l) | Breadcrumb tracker `debug-active.md` (resume across sessions, ~50 lines, deleted on resolve) | symptom | `debug-active.md` | caller's | in-session skill | Yes but low value unattended; state file is for session resume |
| S/harness-review (350 l) | 28-check + type-specific review of an agentic harness vs 6 harness patterns/21 patterns/26 anti-patterns | harness repo | markdown report w/ file:line | caller's | in-session | Yes |
| S/harness-architect (397 l) | Designs harness architecture from `harness-interview.md` | interview doc | `harness-architecture.md` | caller's | in-session | Yes (needs interview file) |
| S/agent-audit (211 l) | 23-point pass/fail predeploy audit of an agentic system, readiness score | repo | markdown scored report | caller's | in-session | Yes |
| A/skeptic (18 l) | Adversarial read-only reviewer; refutes diff vs ORIGINAL spec; re-runs validation; finds absence; must_fix/should_fix/nit; verdict approve/request_changes | diff + task spec | free-text verdict + findings (no fixed schema; a Workflow `schema` can impose one) | opus | subagent (`agentType: 'skeptic'`) | Yes |
| A/scout (16 l) | Read-only recon with file:line evidence | question | report | sonnet | subagent | Yes |
| A/builder / grunt / heavy | Implementation tiers (sonnet / haiku / opus); builder must paste real validation output | scoped task + DoD + validation cmds | diff + verbatim output | sonnet / haiku / opus | subagent | Yes |
| S/orchestrator (84 l) | Delegation doctrine: roster, delegation contract, 3 acceptance gates (paste validation output; skeptic before merge; explain failure before retry) | n/a (a mode) | n/a | caller's | in-session skill | n/a. Line 41: "The same roster serves takt" |
| S/spec (46 l) + QUESTION-BANK.md, SPEC-FORMAT.md | Adversarial spec interview (falsifiability, AC sufficiency, scope edges, budget, guardrails); adversarial self-check per story; emits `tasks/spec-<name>.md`, takt `sprint.json` AND `.takt/scenarios.json` (SPEC-FORMAT.md:44,75) | user goal | spec doc + sprint.json + scenarios.json | caller's | in-session skill | NO by design (AskUserQuestion grill loop). Pre-takt only |
| C/epic (239 l), C/feature (320 l), C/sprint (633 l), C/takt (234 l) | Planning chain Epic -> Feature (`tasks/feature-<name>.md`) -> sprint.json + `.takt/scenarios.json` (2-5 BDD scenarios/story, sprint.md:331,478) | interview / feature doc | files | caller's | slash commands | epic/feature/takt interactive (AskUserQuestion 15/13/10). sprint mostly mechanical (3 AskUserQuestion) |
| S/grill-me (10 l) | One-question-at-a-time plan interrogation | plan | conversation only | caller's | in-session | NO by definition |
| S/grill-with-docs (88 l, mattpocock) | grill-me plus CONTEXT.md / docs/adr updates inline | plan | CONTEXT.md, ADRs | caller's | in-session | NO |
| built-in workflow-authoring | Reference for writing Workflow scripts | | | | in-session | n/a (reference). Content UNVERIFIED on disk |
| S/improve-codebase-architecture, S/zoom-out | Refactor-opportunity finder; "map the area" prompt | codebase | suggestions / map | caller's | in-session | improve: mostly; zoom-out: yes (`disable-model-invocation: true`) |

## 2. Direct comparison to T/lib/final-gate.md (four passes)

final-gate.md (173 l): sole gate, reads `.takt/review.diff` + full changed files + CLAUDE.md + optional `.takt/final-gate-checklist.md`; passes run SEQUENTIALLY in ONE agent (personas: Convention & Quality, SRE, Security, Adversary); output `review-comments.json` with keys pass1_conventions/pass2_sre/pass3_security/pass4_adversary/summary; severities must-fix|suggestion; verdict PASSED | BLOCKED. takt-run.js runs it as `general-purpose`, `model: 'fable'`, schema GATE (takt-run.js:513), with a review-fix loop by `builder` (:523).

Mapping to deep-review:
| final-gate pass | deep-review pass | overlap |
|---|---|---|
| 1 Conventions (naming, undeclared deps, TODO/stubs, duplication, committed junk, CLAUDE.md violations) | framework (ORM/Next.js/React/Supabase specifics) | Partial only. deep-review has no undeclared-dependency, committed-artifact or stub checks; its CLAUDE.md rule is triage row 5 |
| 2 SRE (resource lifecycle, singletons, prod/dev divergence, load sim, transactions, timeouts) | resources | Near-identical intent (docs/deep-review/resources.md: singleton clients, cleanup on error, load simulation) |
| 3 Security (injection, auth, secrets, privilege, error leakage) | security | Near-identical; deep-review deeper (OWASP-numbered) |
| 4 Adversary (name vs behavior, comment lies, dead branches, works-by-accident, copy-paste ghosts) | absence | Different emphasis: deep-review absence = what is MISSING (error handling, validation, access control); final-gate adversary = cold-read of what is PRESENT. Complementary, not the same |

Differences that matter:
- deep-review checklists are web-stack specific (Drizzle, Next.js, Supabase/Supavisor, serverless; docs/deep-review/framework.md:17-28, resources.md:17-19). Dikta is Swift/WhisperKit; most items do not apply (unverified against dikta code, judged from checklist text).
- deep-review runs 4 agents in parallel and triages block/followup/dismiss; final-gate is single-agent, no triage, no dismiss bucket. deep-review's convergence bias (after run 1 only regressions and rows 1-5 block) would directly cut review-fix loops.
- Output shapes differ: `deep-review-report.json` (findings[] with triage, regression_from_fix) vs `review-comments.json` (per-pass arrays). The Workflow GATE schema and bugFixPrompt consume the takt shape; an adapter is needed.
- deep-review is an in-session skill that itself calls the Agent tool with `run_in_background` and `TaskStop`. Whether a Workflow-spawned agent may spawn agents is UNVERIFIED (worker.md rule 10 forbids it for workers; gate agent is general-purpose). Safer: lift the four pass docs, not the skill.
- deep-review writes to `/tmp/deep-review*.json` and `<branch>-followups.md` in repo root: extra ephemeral files not in takt's EPHEMERAL list (takt-run.js:67).
- code-review plugin does NOT cover it: PR-bound, posts to GitHub, confidence filter drops SRE-type findings, no fix loop feed.
- S/code-review (25-check audit) is whole-codebase and writes to docs/audits; it is not a diff gate.

Verdict: /deep-review covers final-gate passes 2 and 3 well, pass 1 and 4 only partially. It is NOT a drop-in. Best reuse: point the gate at the four docs/deep-review/*.md pass files (or merge them into final-gate.md / `.takt/final-gate-checklist.md`), add triage + convergence bias.

## 3. Per-stage candidates

| takt stage (source) | Candidate | Fit | One-line reason |
|---|---|---|---|
| Story worker (T/lib/worker.md; takt-run.js:359 agentType grunt/builder/heavy) | A/builder, A/heavy, A/grunt | Already used (drop-in) | The roster IS the workers; worker.md rules layered on top |
| | S/tdd | With adaptation | Vertical-slice discipline is valuable, but the skill demands user plan approval; would need a stripped, non-interactive excerpt in the worker prompt. Also conflicts with worker.md hiding `.takt/` scenarios only if tests are derived from them (they are not) |
| | plugin code-simplifier | With adaptation | Could run per story after green, but worker.md rule "no unrelated changes" and merge-stage timing make it a gate-time step at best |
| Merge stage (takt-run.js:222-262, builder/grunt) | none | No fit | Git worktree merge with exact command sequence is bespoke; no skill covers it |
| Verifier vs hidden BDD (T/agents/verifier.md; takt-run.js:265,480; sonnet general-purpose) | A/skeptic | With adaptation | Same refute-not-confirm stance, and re-runs validation, but reviews a diff against a spec, does not execute scenarios; sonnet vs opus cost tradeoff |
| | S/tdd | No fit as replacement | tdd writes visible tests that the worker sees; verifier's value is hidden, independently derived scenarios (sprint.md:482 "independent on purpose"). Overlap is only in philosophy (behavior over implementation) |
| | S/spec (SPEC-FORMAT.md:75) | Drop-in for scenario AUTHORING | Already emits `.takt/scenarios.json`; adversarial self-check "would a lazy implementation pass these AC" strengthens the hidden scenarios |
| Verify-fix loop (takt-run.js:487-494) | S/diagnose (Phase 1-2 only) | With adaptation | Feedback-loop-first and reproduce-before-fix would harden the bug-fix worker; needs the interactive checkpoints removed |
| Review gate (T/lib/final-gate.md) | C/deep-review | With adaptation (see section 2) | Strong on SRE + security, adds triage/convergence; web-stack checklists, Agent-in-Workflow unverified, output shape differs |
| | A/skeptic | With adaptation | Good as a fifth cross-check or as gate replacement for spec-compliance ("did the diff satisfy the story"), which final-gate does not check at all |
| | plugin code-review:code-review | No fit | Requires a GitHub PR, posts comments, confidence filter |
| | S/code-review, S/security-audit | No fit as gate | Whole-repo audits writing docs/audits; fine as periodic project audits, too slow/broad per sprint |
| | built-in simplify / security-review | UNVERIFIED | No file on disk to read |
| Local validation (run.md:131-154) | none | No fit | Project-specific `.takt/local-validation.md`; `AskUserQuestion` manual check is interactive by design. Built-in `run` skill (launch and drive app) could execute the steps, UNVERIFIED |
| Retro (T/lib/retro.md, sonnet) | none | No fit | Workbook-mining + retro.md alerts + stats.json is bespoke. Closest: S/agent-review/harness-review for harness quality, not run retros |
| Debug loop (T/lib/debug.md) | S/diagnose | With adaptation (best-covered stage) | See below |
| | S/debug | Partial | Only the breadcrumb file; overlaps nothing in debug.md's `.takt/workbooks/workbook-debug-*` |
| PRD / feature / sprint planning | C/epic, C/feature, C/sprint, C/takt | Already the planning chain (drop-in) | Interactive, fine before the workflow |
| | S/spec | Drop-in, pre-workflow | Produces sprint.json + scenarios.json plus guardrails; adversarial AC check is stronger than sprint.md alone. Overlaps feature+sprint; decide which is canonical |
| | S/grill-me, S/grill-with-docs | Pre-workflow only | Interactive by definition; useful to harden a feature doc before /sprint |
| Orchestration doctrine | S/orchestrator | Already aligned | Its three acceptance gates map to verifier + gate + heavy-retry; line 41 names takt |
| Harness quality of takt itself | S/harness-review, S/agent-audit, S/harness-architect | Meta use | Could audit takt-run.js/lib as a harness; not runtime stages |

## 4. Does /diagnose cover lib/debug.md?

T/lib/debug.md (86 l): 5 steps: reproduce (stop and report to human if cannot), root cause with file:line, minimal fix (max 3 files else pause), verify with full suite, write `.takt/workbooks/workbook-debug-<timestamp>.md`; input `bugs.json` ({id, description, steps, expected, actual}); one bug at a time; human verifies evidence at end.
S/diagnose covers reproduce, root cause, fix, verify and goes further: mandatory fast deterministic feedback loop (10 construction strategies), 3-5 falsifiable hypotheses, tagged instrumentation `[DEBUG-xxxx]`, regression test at a correct seam, cleanup, post-mortem, architecture handoff. It is a strict superset of the method.
Not covered by diagnose: `bugs.json` intake, workbook file format, 3-file scope cap, "minimal fix / no refactor" rule (diagnose allows adding a regression test and hands architecture back), one-bug-at-a-time loop, human-evidence handoff. Interaction: diagnose Phase 1 escape hatch and Phase 3 "show the user" are interactive; takt debug is human-supervised so this is acceptable there. Inside the unattended verify-fix loop (bugFixPrompt, takt-run.js:282) diagnose would need those pauses turned into "record and continue / return blocked".
Fit: WITH ADAPTATION as an addition, not a replacement: keep debug.md wrapper (bugs.json, workbook, scope cap), import diagnose Phases 1, 3, 5.

## 5. Gaps (no skill equivalent)

1. Merge stage (worktree merge, conflict resolution, sprint.json update).
2. Hidden-scenario verifier execution (nothing runs Given/When/Then against a real app; only takt's verifier.md).
3. Retro / alerts / stats.json / workbook mining.
4. Local validation runner (project `.takt/local-validation.md`) other than the UNVERIFIED built-in `run`.
5. Story-vs-spec compliance check inside the gate (skeptic is the closest; final-gate has none).
6. Native-app (Swift/Xcode) review checklists: all deep-review/security-audit pass docs are web/serverless oriented.
7. Non-interactive TDD: no unattended variant exists.
8. Workflow-script authoring/runtime checks of takt-run.js itself (workflow-authoring is reference only, content unverified).

## 6. Out-of-scope observations (not pursued)

- T/lib/final-gate.md says "four focused passes" but the verdict text reads "zero must-fix findings across all three passes" and the Rules list says "three passes" (verdict section and Rule text); stale after Adversary pass was added.
- takt-run.js:33 labels the gate model 'fable'; /Users/sebastianstrandberg/.claude/CLAUDE.md says "the review gate uses `opus`". Docs and script disagree.
- takt-run.js:15 says taktLib holds verifier.md; T/lib has no verifier.md (it lives at T/agents/verifier.md, installed to ~/.claude/lib/takt/verifier.md). Repo `lib/` alone is incomplete; ~/.claude/lib/takt/ also has `run-local.md` not in repo lib/. final-gate.md and verifier.md diffed identical between repo and ~/.claude/lib/takt.
- Duplicate deep-review definitions (skill and command) with different source_id; also ~/.claude/docs/deep-review has `sebstrdigital-*` variants of all four pass docs (not diffed; which one the skill reads is the un-prefixed name per SKILL.md).
- Orphaned code-review plugin cache versions under ~/.claude/plugins/cache/claude-plugins-official/code-review/ (many `.orphaned_at` markers).
- Available but NOT installed (marketplace only): pr-review-toolkit, feature-dev, security-guidance, ralph-loop, claude-security under ~/.claude/plugins/marketplaces/claude-plugins-official/plugins/. Not read.
- Project working tree on takt/shadow-participant has untracked sprint.json, bugs.json, review-comments.json (takt ephemerals) as of session start.
