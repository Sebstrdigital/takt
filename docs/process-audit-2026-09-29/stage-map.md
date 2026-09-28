# takt stage map (read-only recon, 2026-09-29)

Source: /Users/sebastianstrandberg/work/git/takt (lib/, agents/, commands/). Installed copy ~/.claude/lib/takt matches source byte-for-byte for every file I diffed (`diff -rq lib ~/.claude/lib/takt`); the only differences are two installed-only files: `run-local.md` (89 lines, user-owned, munin + validation-VM overrides) and `verifier.md` (copied from `agents/verifier.md` by install.sh:107; `diff` = identical).

Evidence of real run shape: /Users/sebastianstrandberg/work/git/dikta (current branch takt/shadow-participant): sprint.json has 6 stories, all `complexity: "complex"`, `waves: []` (so sequential, one story per wave); scenarios.json has 25 scenarios (4,5,4,4,4,4); bugs.json holds 2 bugs; review-comments.json is BLOCKED with 1 must-fix after gate cycle 2 (4 must-fix in cycle 1, MF-1..MF-4); .takt/stats.json shows `runs: 9`, `overhead.avg: 2025` s (~34 min, verify+gate), no `retries` block yet.

## Summary table

Typical run = 6 stories, all complex, sequential (waves absent), 1 verify cycle that passes, 1 gate cycle that passes, local validation on, gh present.

| Stage | Agent / model | Spawns (typical) | Prompt lines | Consumers of output | Ritual smells |
|---|---|---|---|---|---|
| Plan: /takt wrapper | session | 0 | takt.md 234 | routes to next skill | 4 gate branches; quick path duplicates sprint rules |
| Plan: /epic | session | 0 | epic.md 239 | /feature (loop) | 4 AskUserQuestion gates + review gate; optional |
| Plan: /feature | session | 0 | feature.md 320 | /sprint | 3 why/what/what-not gates + review gate; conflicts with sprint.md rules |
| Plan: /sprint incl. hidden BDD | session (same context that wrote the criteria) | 0 | sprint.md 633 (scenario part 476-559 = 84) | run.md, worker, verifier, merge | "independent" scenarios written by same model in same context; typecheck rule contradiction; wave rules |
| Init (.takt/config.json) | session | 0 (once) | init.md 72 | run.md 0.1, takt-run.js args | mislabelled phases; references non-existent `/worker` skill |
| Phase 0/1 setup | session | 0 | run.md 1-78 | Workflow args | jCodeMunch indexing + tool probes + ETA + retro alerts on every run |
| Worker | grunt/haiku (simple), builder/sonnet (complex) | 6 | worker.md 69 + prompt builder ~25 | merge stage, retro (workbook) | workbook mandatory, read only on merge conflict + retro |
| Merge/commit stage | grunt/haiku (in place) or builder/sonnet (worktrees) | 6 (one per wave) | ~40 (takt-run.js:222-263) | sprint.json passes/attempts, feature branch | LLM does git add/commit + jq that a script could do |
| Verifier + verify-fix loop | general-purpose/sonnet; fixers builder; commit grunt | 1 (0 fix). Failure cycle adds 1 verifier + N fixers + 1 commit | verifier.md 126 + ~15 | script (verdict/bugs via schema); bugs.json and full report unread | full markdown report + bugs.json file nobody reads; hidden-info isolation is partly theater |
| Review gate + review-fix loop | general-purpose/fable; fixers builder; commit grunt | 1 (0 fix). Failure cycle adds N fixers + 1 commit + 1 gate | final-gate.md 173 + ~13 | script (verdict/mustFix via schema); review-comments.json, review.diff, printed report unread | 4 personas, web-centric checklists, "zero defects" rhetoric; reads every changed file in full on Fable |
| Local validation | builder/sonnet + AskUserQuestion | 1 | run.md 131-152 (~22) | .takt/validation-report.md read by session | blocking human prompt inside an autonomous run |
| PR creation | session | 0 | run.md 156-162 (~7) | human | fine |
| Auto-retro | general-purpose/sonnet | 1 | retro.md 191 | run.md alerts, sprint.md chronic debt, stats -> ETA, CHANGELOG | carry-count/alert lifecycle machinery; snapshot workaround; duplicate cleanup |
| Completion report | session | 0 | run.md 185-203 (~19) | human | duplicate cleanup |
| Debug mode | general-purpose (implied) | 1 per bug | debug.md 86 | human | no orchestrator; overlaps /diagnose and /debug |

Typical spawn total = 6 workers + 6 merge + 1 verify + 1 gate + 1 local validation + 1 retro = 16. The last dikta run was heavier: 6 + 6 + 2 verifier + 2 bug fixers + 1 commit + 2 gate + 4 review fixers + 1 commit + validation + retro = about 26 (inferred from bugs.json / review-comments.json / workbooks list: BUG-001, BUG-002, MF-1..4 workbooks exist).

Prompt line totals: run.md 218, takt-run.js 532 (prompt-builder text lines 181-325 = 145), worker 69, verifier 126, final-gate 173, retro 191, debug 86, init 72, tooling 22, planning commands 1426 (epic 239 + feature 320 + sprint 633 + takt 234), CLAUDE.md 141, README 293, CHANGELOG 51. Whole repo prompt corpus about 3,400 lines.

---

## Stage detail

### A. Planning: /takt, /epic, /feature

- Purpose (takt.md:10): "Single entry point for the full takt planning flow. Detects where you are and starts from there." Flow (takt.md:17): `/epic -> /feature -> /sprint -> start takt`.
- Mechanics: all run in the session model, zero agent spawns. Every step is an AskUserQuestion gate.
  - /takt: artifact detection then Case A-D branch (takt.md:28-127), plus a Quick Path interview (131-204).
  - /epic: 4 gates (context, problem, goals, breakdown, epic.md:28-124) + write + review gate (180-195), then auto-loops /feature for each Feature (199-202).
  - /feature: why / what / what-not gates (feature.md:37-96), write doc, review gate (284-299).
  - Interview count for the full flow with 4 features: about 5 + 4*4 + 1 = 22 human gates before sprint.json. Quick path is 1 prompt (takt.md:137).
- Inputs/outputs: /epic writes tasks/epic-*.md; /feature writes tasks/feature-*.md; consumers are /sprint and takt.md detection (takt.md:34-37). retro.md:180 archives the feature doc by deriving its name from branchName. Epic doc has no downstream consumer except /feature loop.
- Duplicated/contradictory rules:
  - Story size: feature.md:118-119 "Prefer fewer stories with broader scope ... Aim for 4-8 stories" vs sprint.md:239-256 "Each story must be completable in ONE takt iteration ... If you cannot describe the change in 2-3 sentences, it is too big" and sprint.md:41 warns at 15. Quick path caps at 5 (takt.md:147).
  - "Typecheck passes": feature.md:127 says "ASSUMED ... never list them as explicit criteria" and feature.md:160 lists explicit listing as an anti-pattern, but sprint.md:299-302 and 325 make it "Always include as final criterion" and mandatory rule 6. Also mandated as checklist item sprint.md:568. Applies to every project regardless of language (dikta is Swift, has no "typecheck" command).
  - Behavioral-criteria rule stated in feature.md:126-131 and again sprint.md:276-314.
  - takt.md:169 quick path says "Apply dependency ordering, type, size, complexity, verify fields"; `type` and `verify` fields do not exist in the sprint.json schema (sprint.md:105-132). README:197 also mentions "verification modes". Stale from an older schema.
- Ritual smells: the /epic auto-loop forces a full 3-gate interview per Feature; the /feature "4-8 stories" and "roll ancillary work into stories" text (feature.md:116-122, 155-162) is anti-pattern policing that exists only because /sprint splits later. All Fable/Opus-level analysis for the gates is done by the session model, no leverage from a skill like /grill-me or /spec (overlap, see below).
- Hard rules that break if removed: takt.md:34 detection is what routes "sprint.json exists" to `start takt`. Removing /feature and /epic breaks nothing at runtime; run.md only needs sprint.json (run.md:59).

### B. Planning: /sprint (Feature doc to sprint.json + hidden BDD scenarios)

- Purpose (sprint.md:10): "Converts existing Feature docs to the sprint.json format that takt uses for autonomous execution."
- Mechanics: session model, 633 lines, single-doc or multi-doc mode (14-46), ID renumbering (50-64), chronic-tech-debt check that reads .takt/retro.md and asks the human (81-93), wave planning only when 6+ stories with 2+ chains (136-180), size (184-201) and complexity (206-236) classification, scenario generation (476-559), 13-item pre-save checklist (561-578), start prompt via AskUserQuestion (614-633).
- Hidden BDD generation, exactly:
  - Rule 12 (sprint.md:331): "After writing sprint.json, generate `.takt/scenarios.json` with 2-5 BDD scenarios per story ... Scenarios describe observable behavioral outcomes".
  - Stated independence rationale (sprint.md:482): "if scenarios were derived from the same acceptance criteria the worker reads, the verifier would just confirm the worker followed instructions".
  - Contradiction: sprint.md:490-492 says the pipeline is "behavioral criteria -> behavioral scenarios" and rule 4 (535) says "Reframe, don't copy" criteria. Scenarios are therefore derived from the same criteria, by the same model, in the same context window, seconds after writing them. The independence is only from the worker, not from the author's blind spots. Unverified whether this has measurable value; dikta's verify cycle found 2 bugs, both test/logging coverage gaps (bugs.json BUG-001, BUG-002), not behavioral failures.
  - Hidden from workers: sprint.md:538 "`.takt/` is gitignored and not referenced by run.md or worker.md". Enforced by worker.md:67 rule 8 "NEVER read `.takt/` except to write your own workbook", bugFixPrompt takt-run.js:298, run.md:82/211.
  - Format includes a `type` field (behavioral/contract/edge, sprint.md:536) that nothing reads (verifier.md never branches on it; verified by grep of verifier.md).
- Outputs consumed: sprint.json read by run.md:59 (userStories, branchName, waves), takt-run.js (stories, priority, complexity, dependsOn, size only for ETA), merge stage jq update (takt-run.js:251). `size` consumed only by ETA (run.md:71) and retro stats. `knownIssues` consumed by worker.md:29. `description`, `project` and `startTime/endTime` init: no reader other than retro.
- Smells: waves only for 6+ stories (sprint.md:177) yet memory/retro says multi-story waves are broken (run.md:93 "Known limitation (2026-09-28)" plus retro alert "cuts multi-story-wave Workflow worktrees from the launch-time HEAD"). Also run.md:93 says the wave schema `{wave, stories}` in sprint.md:161-166 must be converted to `[[ids]]` by the session agent (retro alert too). Scenario count 2-5 per story is a fixed ritual number (dikta: 25 scenarios for 6 stories).
- Hard rules if removed: scenarios.json is the only input to the verifier stage (takt-run.js:272). Removing scenario generation removes the verify loop's purpose.

### C. Init (lib/init.md, 72 lines)

- Purpose (init.md:3): "read by the orchestrator (run.md Phase 0.1) only when `.takt/config.json` is missing or incomplete."
- Mechanics: 3 AskUserQuestion toggles (final_gate, local_validation, worker_runner) plus external cmd. Session agent; no spawns; once per project. dikta's config.json is dated Apr 17 and all three are the defaults.
- Consumers: `final_gate` -> takt-run.js:49 `finalGate`; `local_validation` -> run.md:133; `worker_runner`/external cmd -> takt-run.js:47-48, 204-219.
- Smells: mislabels ("Phase 4b - Final Gate", init.md:16, but the gate is Phases 2-4 inside the workflow; Phase 4b is local validation). External worker default command references "running /worker skill" (init.md:47,65) and no `/worker` command exists in commands/ or ~/.claude/commands (ls). Gate warning text duplicated in init.md:71 and run.md:21. `worker_runner: external` path (takt-run.js:204-219) adds a second worker prompt; whether any project uses it: unverified (dikta uses `anthropic`).

### D. Phase 0/1 setup (run.md 9-78)

- Steps: config check, tool probes (jCodeMunch, context-mode), jCodeMunch indexing via index_repo and CLAUDE.md edit (run.md:30-34), local overrides file (36-38), session.json write (40-53), branch checkout, submodule check, mode detection, ETA from stats.json (71), retro confirmed-alert printing (72), start line.
- session.json consumers: tooling.md:3 (which workers read it) and run.md's own later steps. worker.md:67 says never read `.takt/`, but worker.md:23 sends workers to tooling.md whose line 3 reads `.takt/session.json`. Direct contradiction; harmless in practice but shows unowned rules.
- ETA (run.md:71): consumes .takt/stats.json; dikta data shows small stories avg 236 s while max 1772 s, overhead avg 2025 s (34 min) vs the "overhead default 480" (run.md:71). Printed start line hardcodes "~15-25 min" (run.md:75) while also computing an estimate: inconsistent.
- Smell: jCodeMunch index + probes on every run are silent best-effort work whose only consumer is the worker's optional tooling read.

### E. Worker (lib/worker.md 69 + prompt builder takt-run.js:181-202)

- Purpose (worker.md:3): "You implement ONE story in your assigned working directory."
- Mechanics: `grunt` (haiku) for `complexity: simple`, else `builder` (sonnet); retry once on `heavy` (opus) with prior failure text (takt-run.js:350-364, 391-409). In a wave of 2+ stories: `isolation: 'worktree'` (388, 361). Structured return schema WORKBOOK (92-107) with 9 fields.
- Reads: story JSON in prompt, worker.md, tooling.md. Must not: `cd`, run git beyond one rev-parse, touch sprint.json, read `.takt/`, spawn agents (worker.md:58-69).
- Writes: code, workbook at ${projectDir}/.takt/workbooks/workbook-<id>.md (takt-run.js:198).
- Each worker is told to run `pwd`, `git rev-parse --abbrev-ref HEAD`, and `date -u +%s` twice (takt-run.js:188-191) just so the script can report them. These are ceremony driven by the script not being able to touch the filesystem (takt-run.js:4-6).
- Consumers: merge stage reads workbook only on conflict (takt-run.js:246, "read the workbook"); retro reads all workbooks (retro.md:7). Workbook "Notes for Merge" and "Blockers Encountered" have no consumer except retro. Workbook template (worker.md:39-53) is a fixed 4-section form the agent must fill even for trivial stories (rule 4, worker.md:63 "Always write the workbook — even if the story was trivial").
- Duplication: git prohibition stated worker.md:17-19, 68 and takt-run.js:199; ephemeral rule worker.md:66-67 vs takt-run.js:67.
- Reactive additions (CHANGELOG): "Add `knownIssues` field ... workers skip pre-existing failures" (2026-03-02, worker.md:29); "Mitigate worker git commit failures — workers scoped to file edits only, session agent owns git" (2026-03-07, worker.md:17-19); "Drop TDD enforcement from worker.md" (2026-03-07).
- Overlap: TDD (removed), quality checks "typecheck/lint/tests the project defines" (worker.md:33).

### F. Merge/commit stage (takt-run.js:222-263, 431-460)

- Purpose: "takt merge stage" — commit story files, merge worktree branches, remove worktrees, update sprint.json.
- Mechanics: one agent per wave (`mergeType = isolate ? 'builder' : 'grunt'`, takt-run.js:431); for a sequential run every story is its own wave, so a haiku agent is spawned per story just to `git add -- files`, `git commit`, and run a fixed `jq` update on sprint.json (takt-run.js:239-253). `overlapOrder` (331-348) sorts stories by file overlap in JS. Conflict resolution rule (246): "resolve so BOTH stories' behaviour survives" — the only place an LLM judgment is needed.
- Inputs: worker results (workDir, branch, times, files). Outputs: commits, sprint.json fields `passes/startTime/endTime/attempts` (consumers: retro stats, ETA, run.md Phase 7 timing), merged/failed schema (consumed by JS 450-459).
- Cruft handling: `cleanFiles()` (73-86), ephemeral filtering in 4 places (73-86, 67, 239, 243), stale-worktree cleanup text (435-446). Existing bug documented in run.md:93: worktrees cut from launch HEAD, later waves do not see earlier merges.
- Smell: the in-place case (the dikta case, 6 spawns) needs no LLM at all. Design constraint driving this: the script "never touches the filesystem" (takt-run.js:5).
- Hard rules: sprint.json `passes` is set only here (README:197); run.md:127 relies on it.

### G. Verifier + verify-fix loop (agents/verifier.md 126; takt-run.js:265-280, 477-496)

- Purpose (verifier.md:3): "You are an independent scenario verification agent ... checking real outcomes against the codebase, not just code presence."
- Mechanics: `general-purpose` + `sonnet`, up to `maxVerifyCycles = 3` (run.md:97). Per failed cycle: one `builder` per bug, sequential (takt-run.js:489-492), then one `grunt` commit (493-495), then next cycle re-verifies everything. On the last cycle no fix is attempted (486). Max 3 verifiers + 2 fix passes.
- Inputs: .takt/scenarios.json (path), "A git log of recent changes for context" (verifier.md:9) — but verifierPrompt (takt-run.js:265-280) never passes a git log (grep `git log` shows only verifier.md:9). Stale input.
- Outputs: (1) schema return VERDICT used by the script; (2) a bugs.json file (verifier.md:90-118, takt-run.js:277); (3) a full markdown "Scenario Verification Report" with per-scenario Given/When/Then echo (verifier.md:46-88). Only (1) is consumed. Grep: `bugs.json` appears in takt-run.js only at 67 (ephemeral list) and 277 (write instruction); run.md only in cleanup lists (201, 213). README:200 claims consumers "Session agent, fix workers" — no code reads it. Fix workers get the bug object inline (takt-run.js:282-299), not the file. (2) and (3) are unconsumed outputs.
- Information isolation: bug descriptions must be behavioral, no scenario text (verifier.md:94-101; takt-run.js:279). Purpose: keep scenarios hidden from fix workers. Consumed by fix workers via bugFixPrompt (takt-run.js:290).
- Ritual smells: the Then/When/Given per-scenario write-up (verifier.md:50-60, 66-80) is ceremony; the "Fix needed" field is in the report but not in the schema; fixers run one at a time; no cycle-level regression check on the story diff.
- Reactive: none in CHANGELOG specifically; README:15 sells "up to 3 cycles" as design.
- Hard rules if removed: run.md stop condition `verification.verdict != "PASSED"` (run.md:124); Phase 5 PR body includes verification result (run.md:160).
- Overlap: whole stage is a hand-rolled QA agent with a fixed loop; candidates /tdd (write tests first), /diagnose (bug loop, verifier.md:90 Step 5 + fix worker is a mini-diagnose), test suites. Verification methods list (verifier.md:37-44) tells the agent to use curl/fetch and Chrome integration; project-specific, not portable (dikta: Swift app).

### H. Review gate + review-fix loop (lib/final-gate.md 173; takt-run.js:313-325, 506-530)

- Purpose (final-gate.md:3-5): "You are the sole review gate before code ships to a stakeholder ... Standard: ZERO defects reach the stakeholder. Not one."
- Mechanics: `general-purpose` + `fable` (takt-run.js:513), `maxReviewCycles = 2` (run.md:98). Steps in the agent prompt: write `git diff main...HEAD > .takt/review.diff`, read final-gate.md, run four passes, read CLAUDE.md, read optional `.takt/final-gate-checklist.md`, write review-comments.json. Rule 1 (final-gate.md:165): "Read every changed file end-to-end". On BLOCKED cycle 1: one `builder` per must-fix sequentially, one `grunt` commit, then a second full Fable gate. On BLOCKED cycle 2: no fix, stop (takt-run.js:519). Net: at most one fix pass, and its result is re-reviewed once.
- Passes: 1 Conventions (36-44, 7 checks), 2 SRE (54-61, 6 checks), 3 Security (69-75, 5 checks), 4 Adversary (85-93, 7 checks). 25 checklist items total.
- Web/DB-centric items with no meaning for dikta (Swift/macOS): SQL injection (71), auth boundary on endpoints (72), `NODE_ENV === 'production'` divergence (58), transactions BEGIN/COMMIT (60), singleton DB clients (57). No project checklist exists in dikta (`ls .takt/final-gate-checklist.md`: not found), so the "flywheel" (final-gate.md:170 rule 6) is unused there.
- Inconsistency: verdict rules say "zero must-fix findings across all three passes" (140) but there are four passes.
- Outputs: schema return GATE consumed by script; review-comments.json (final-gate.md:99-131) — grep shows no reader in takt-run.js or run.md (only cleanup lists run.md:201, 213); README:201 claims "Session agent". `.takt/review.diff` is written and read only by the gate itself (takt-run.js:320-321) and deleted later. The printed "Review Gate Report" (final-gate.md:143-161) has no consumer (workflow agents' text is not surfaced; run.md prints only its own template). `suggestionCount` is the only suggestion signal consumed: it decides `--draft` on the PR (run.md:161); suggestion contents are never surfaced anywhere. dikta's review-comments.json has 11 suggestions nobody sees.
- Reactive origin: run.md:21 / init.md:16,71: "static review alone has previously missed a stakeholder-facing production leak". CHANGELOG 2026-03-02 "Add code review phase"; 2026-09-29 "Review gate moves to Fable 5.1 (was Opus)". Doc drift: CLAUDE.md:42 still says gate uses `general-purpose` + `opus`; run.md:212, takt-run.js:513, CLAUDE.md:133 and install.sh:150 say fable.
- Ritual smells: four personas run "sequentially, do not merge them" (final-gate.md:26) inside one agent context, so they are one pass with four headings; "Print summary" duplicate of the JSON; must-fix vs suggestion classification rule 4 (168) "if not certain, classify as suggestion" partially contradicts "zero defects" framing; gate does not see the verifier's fixes as distinct. dikta run evidence: cycle 1 found MF-1..MF-4; cycle 2 BLOCKED with 1 more (review-comments.json summary), so the pipeline ended in a stop condition, and the remaining must-fix must be fixed by a human.
- Overlap: /code-review, /security-review, /deep-review (skill listing: "4 parallel specialized reviewers covering framework correctness, resource safety, security, and adversarial absence detection ... zero findings should survive"), /simplify (duplication check, final-gate.md:41), /diagnose (fix worker prompt). Pass 3 duplicates /security-review; the whole four-pass design is nearly the same as /deep-review.

### I. Local validation (run.md 131-152; run-local.md override)

- Purpose: "Local Validation (project-toggleable, interactive)".
- Mechanics: one `builder` agent (run_in_background, bypassPermissions) executes steps from `.takt/local-validation.md`; writes .takt/validation-report.md; session agent reads it; commits "fix: local validation" if the agent fixed things; then AskUserQuestion "All good - ship it / Found issues" (run.md:150-152). dikta local-validation.md exists (2018 bytes). run-local.md swaps in ssh to validation VM (run-local.md:47-70).
- Smells: mandatory human question blocks an otherwise silent background run (run.md:218 "You are a background process. Work silently."). The validation agent may "investigate the root cause and attempt to fix" (run.md:146), meaning a second code-writing path without review-gate coverage (the gate ran before). The validation-report.md consumer is the session agent only; the Phase 7 rm list deletes it.
- Overlap: /run skill, the dikta CLAUDE.md validation rule (docs/validation.md).

### J. PR creation (run.md 156-162)

- `gh pr create` with body from summary, stories, verification, gate, suggestionCount, duration; `--draft` if suggestionCount > 0. About 7 lines; no smell beyond the suggestion-only-count signal above.
- Overlap: none needed; global instruction says git commit/PR attribution lines (out of scope here).

### K. Auto-retro (lib/retro.md 191; run.md 166-181)

- Purpose (retro.md:3): "You analyze workbooks from a completed run and generate actionable insights."
- Mechanics: `general-purpose` + sonnet, background, `TaskStop` afterwards (run.md:181). Reads workbooks; writes/edits .takt/retro.md (alerts table + 1 entry, retention trimmed to 1, 119-124), CHANGELOG.md, .takt/stats.json (running averages, 138-175, hand-computed by the LLM), moves the feature doc to tasks/archive (180), deletes 7 artifact types (181), commits and pushes (run.md:178 "commit and push").
- Inputs: workbooks (incl. BUG-*/MF-* fix workbooks), sprint-snapshot.json.
- Outputs and consumers:
  - Active alerts: run.md:72 prints confirmed ones next start; that is the only runtime consumer of the lifecycle. dikta's alerts table (retro.md:1-16) has 15 alerts, several unrelated to takt process and open since Feb/Mar.
  - Action items: carried forward by retro itself (carry counts, 94-114); the only external consumer is sprint.md:81-93 (chronic tech debt with carry >=5, asks the human). Addressed-item check is "fuzzy-match substring against workbooks" (97).
  - stats.json: consumed by run.md:71 (ETA). `retries` block added 2026-09-29 and not yet populated in dikta (stats.json has none).
  - CHANGELOG entry per mitigated alert: no consumer.
- Compensating steps: sprint-snapshot (run.md:168, retro.md:142) exists because "timing stats unavailable" happened (CHANGELOG 2026-03-29). At retro time sprint.json still exists (deleted by retro step 8 and run.md:201), so the snapshot is redundant. Duplicate cleanup: retro.md:181 deletes the same list as run.md:201 "Stale artifact safety net". Both would be needed only if retro fails.
- Reactive additions from CHANGELOG: chronic tech debt tier (2026-03-29), stale action item escalation (2026-03-07), retention policy (2026-02-21), retro routing table (2026-03-07), snapshot (2026-03-29).
- Ritual smells: retro entry template with 5 sections (22-48) for a run whose output the alert table already summarizes; carry-count logic of about 25 lines; retro entry metrics duplicate stats.json; CHANGELOG entry with "only when concrete improvement" but triggered by alert status; commit+push after the PR is already open (order in run.md: PR at Phase 5, retro at Phase 6 pushes to the same branch).
- Overlap candidates: memory system / munin `remember` (run-local.md:84-89 stores the same outcomes); /insights weekly reports; git log.

### L. Completion report (run.md 185-203)

- Prints start line + final report only (run.md:188-198). Duration from earliest story startTime. Stale-artifact safety net `rm -f` (201). Silent-execution rule 8 (216) forbids any other output. Smells: none except duplicated cleanup and the ETA/start-line mismatch above.

### M. Debug mode (lib/debug.md 86)

- Purpose (debug.md:3): "strict debugging mode ... find and fix ONE bug with minimal, surgical changes. Confirm the bug exists before touching any code."
- Mechanics: five steps Reproduce / Root cause / Minimal fix / Verify / Present evidence, workbook template (32-54). Triggered by the phrase "takt debug" (CLAUDE.md:23,34). No orchestrator spawn is defined in any file I read; whether it runs as the session agent or an agent: unverified. Inputs: bug string or bugs.json (69, 86 "Process one bug at a time"). bugs.json format here (id/description/steps/expected/actual) differs from the verifier's four-field format (verifier.md:118 "exactly these four fields").
- Consumers: human reads the workbook (63). retro reads workbook-debug-*.md if run after (retro.md:7).
- Overlap: `/diagnose` (reproduce, minimise, hypothesise, instrument, fix, regression-test), `/debug` (user's global breadcrumb tracker), `/tdd`. Nearly identical discipline; the takt doc adds a 3-file scope pause (22) and the workbook.

---

## Duplicated instructions across files

| Rule | Places |
|---|---|
| Ephemeral files list / never commit | run.md:201, 213; takt-run.js:67; retro.md:16, 181; worker.md:66-67; README:197-205 |
| Never read scenarios.json | run.md:82, 211; sprint.md:538; README:98; takt-run.js:298; worker.md:67 (via .takt ban) |
| Agent/model roster | run.md:212; CLAUDE.md:42, 124-135; README:163; install.sh:150; takt-run.js:30-34, 350-364 (CLAUDE.md:42 says gate = opus, stale) |
| Worker git prohibition | worker.md:17-19, 68; takt-run.js:199, 219, 298; validation prompt run.md:147 |
| Wave rules | sprint.md:136-180; run.md:70, 93; CLAUDE.md:82; README:69 |
| Behavioral criteria | feature.md:124-131; sprint.md:276-314; takt.md:172 |
| Gate-disabled warning text | run.md:21; init.md:71 |
| Artifact cleanup | retro.md:181; run.md:201 |
| Story sizing policy | feature.md:116-122 vs sprint.md:239-256 (contradiction) |
| "Typecheck passes" | feature.md:127,160 (never) vs sprint.md:299, 325, 568 (always) (contradiction) |
| Optional tooling read | worker.md:23, verifier.md:14, final-gate.md:17, takt-run.js:293 all point to tooling.md (22 lines); tooling.md:3 reads `.takt/session.json` which worker.md:67 bans |

## Outputs nobody reads (verified by grep of takt-run.js and run.md)

- bugs.json (verifier writes; README:200 claims session agent + fix workers read it; nothing does).
- review-comments.json (gate writes; README:201 claims session agent reads; nothing does). Suggestion text (dikta: 11 suggestions) is never surfaced; only `suggestionCount` reaches the PR draft flag.
- Verifier's full markdown report and gate's "Review Gate Report" print (agent final text; workflow returns only schema values).
- Scenario `type` field (sprint.md:536).
- Workbook "Notes for Merge" outside conflict cases; workbooks for BUG-/MF- fix workers (bugFixPrompt:297) read only by retro.
- verifier.md "git log of recent changes" input (never supplied).
- `.takt/review.diff` (written and read by the gate agent itself only).

## Compensating / reactive additions (evidence)

- sprint-snapshot.json (run.md:168): CHANGELOG 2026-03-29 "fixes 'timing stats unavailable' in 4 repos this week"; now sprint.json still exists at retro time.
- Submodule detection (run.md:61-65): CHANGELOG 2026-03-29.
- knownIssues field: CHANGELOG 2026-03-02.
- Gate mandatory + Fable: run.md:21 warning, init.md:16, CHANGELOG 2026-09-29.
- Workers cannot commit; merge stage owns git: CHANGELOG 2026-03-07.
- `attempts` field / `retries` stats (CHANGELOG 2026-09-29): measurement plumbing added before any decision uses it; stats.json in dikta has no retries data yet.
- Multi-story wave known limitation text (run.md:93) added after a failed run (retro alert 2026-09-28).
- Verify/review cycle counts (3 and 2) are constants in run.md:97-98 with no data-derived rationale; dikta workbooks show cycle 1 always produced fixes.

## Skill / built-in overlap candidates

| takt piece | Overlaps |
|---|---|
| final-gate.md passes 1-4 | /code-review, /deep-review (4 parallel reviewers, near-identical theme), /security-review (Pass 3), /simplify (duplication) |
| bugFixPrompt + debug.md | /diagnose, /debug |
| verifier + scenarios | /tdd (tests as the spec), /spec (falsifiable acceptance criteria) |
| /feature, /epic gates | /grill-me, /grill-with-docs, /spec, /prd |
| /sprint conversion | /spec ("produces a spec doc plus takt-ready sprint.json") |
| retro | auto-memory, munin remember, /insights |
| local validation | /run skill, project docs/validation.md |
| Phase 0 jCodeMunch indexing | global CLAUDE.md session checklist already does it |
| worktree isolation | Agent `isolation: "worktree"`, EnterWorktree (already used) |

## Surprises / out-of-scope

- takt-run.js:4-6 design constraint (script never touches filesystem) is the root cause for per-wave merge agents, pwd/date ceremony in every worker, and jq-by-LLM.
- takt.md:169 and README:197 mention `type`/`verify`/"verification modes" fields that do not exist.
- `agents/verifier.md` lives in agents/ but installs to lib/takt/ (install.sh:107), so it is not a Claude Code sub-agent definition despite the directory name.
- dikta .takt/ currently contains stale review.diff (186,869 bytes), scenarios.json, workbooks from the in-flight run.
- dikta stats: overhead avg 2025 s over 6 counted runs, larger than most story times; ETA default 480 s (run.md:71) understates it.

## Open questions (unverified)

- Which takt-run.js agent text is surfaced to the user: unverified; assumed only schema output plus workflow logs.
- Whether any project uses `worker_runner: external`: unverified (only dikta config seen).
- How debug mode is launched (agent vs session): unverified; no spawn instructions in debug.md.
- Whether a Workflow script may write files itself: unverified; takt-run.js:5 asserts it does not.
