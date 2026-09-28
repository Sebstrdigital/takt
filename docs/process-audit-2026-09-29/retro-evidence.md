# takt stage evidence from retros, CHANGELOG, PRDs and git history

Scope: 22 `.takt/retro.md` files under `/Users/sebastianstrandberg/work/git/` (19 have stats.json or equivalent), `takt/CHANGELOG.md`, `takt/tasks/**`, plus git history of retro files (dikta 12 versions, uven 27, kraken-wrapper 24, nettobrand-wrapper 21, takt 13, nettobrand 12; retro retention keeps only the last entry, so history is recovered with `git show <hash>:.takt/retro.md`). Also read: dikta `review-comments.json` and `bugs.json` (current Shadow sprint), takt `lib/run.md`, `lib/takt-run.js`, `lib/final-gate.md`, `lib/debug.md`, commit bodies for stage-changing commits.

Path abbreviations: `R(dikta)` = `/Users/sebastianstrandberg/work/git/dikta/.takt/retro.md`; `R(uven)` etc. likewise. `hash:file` means `git show hash:.takt/retro.md` in that repo. Line numbers are of that file version.

Caveat that applies to everything below: retros are written by an LLM agent summarising workbooks. Counts are what retros and commits state, not independently re-verified against code. Sample is heavily weighted to dikta, uven, nettobrand, kraken.

---

## 1. Per-stage scorecard

| Stage | Caught real | Caught style/hygiene | Spec gap | False positive / wasted | Cycles seen | Overhead evidence | Verdict |
|---|---|---|---|---|---|---|---|
| Worker (story impl) | n/a (produces defects, see 2.1) | n/a | n/a | 1 opencode stall pattern, 1 broken-infra script | attempts field only added 2026-09-29, no data | story avg 236s small, 354s medium, 674s large (dikta) | Mixed, first-attempt rate unmeasurable |
| Merge stage | 0 | 0 | 0 | 3 incidents (workbook leak, missing StructuredOutput, stale worktree base) | n/a | not separable | Mixed, net failure source |
| Verifier (hidden BDD) | 3 (dikta SC-011, SC-014, parakeet regression) | 3 (uven polish bugs) | 2 (dikta Shadow BUG-001/002) | 2 cycles (dikta parakeet) + chronic hallucination (uven, 16x carried) | 1 to 3 | bundled in "phase overhead" | Mixed |
| Review gate (4-pass, ex reviewer + final gate) | at least 16 (see 2.4) | ~6 | 1 (kraken VOLUME) | 1 wrongly raised must-fix (uven), 1 hallucinated finding (uven), cycle-2 dikta finding invalidated cycle-1 fix | 1 to 3 | dikta 7032s, uven 25265s outliers | Helping |
| Local validation | 2 (uven BUG-002/003, real integration bugs) | 0 | 0 | 0 recorded | n/a | not separable | Helping where a runtime exists, unproven elsewhere |
| Auto-retro | finds tooling bugs (worktree HEAD, waves shape) | many | 0 | carries items it cannot resolve | n/a | not separable | Mixed to ritual |
| Debug mode (`lib/debug.md`) | 0 | 0 | 0 | 0 | n/a | n/a | No evidence of use |
| Scenario generation (/feature, /sprint) | see verifier | | | | | | Unmeasured on its own |

Overhead numbers (stats.json `overhead.avg`, seconds): dikta 2025 (n=6), munin 837 (n=2), nettobrand-wrapper 953 (n=11), kraken-wrapper 610 (n=9), nettobrand 614 (n=6), oribium 833 (n=4), takt 410 (n=1), dua-pulse 60 (n=1), uven not recorded in stats.json. "Overhead" is a single bucket: verify, review-fix, PR, retro start, and any idle time. `dua-erp` retro records 16061s and says "includes idle time between run completion and retro" (`dua-erp/.takt/retro.md:49`). The stages cannot be separated with the data that exists. Data missing: no per-stage timing anywhere.

---

## 2. Quoted evidence per stage

### 2.1 Worker (story implementation)

Defects that later stages found in worker output (worker-caused):
- uven, FK ON DELETE wrong twice in a row: "For the second consecutive sprint, the migration's FK ON DELETE behavior was wrong at first pass ... Workers treat FK declaration as boilerplate" (`uven 6aa48e9:.takt/retro.md:38`).
- uven, tz-naive datetime: "Worker noted the deprecated `utcnow()` usage in workbook-US-006 but did not flag the tz-awareness issue" (same file, line 39 region).
- uven, external worker: "External (opencode) worker for US-001 produced `podman run` with missing `${IMAGE}` variable ... First confirmed opencode-produces-broken-infra-script incident" (same file). Switching to Anthropic workers: "Medium avg this run: 232s vs 851s last sprint".
- uven, integration gaps: "workers mark stories 'passes: true' on typecheck alone; integration gaps surface only in local validation" (`uven 449980e:.takt/retro.md:14`).
- cs-agent: US-003 "large orchestration rewrite with no tests added" (`dua-cs-agent/cs-agent/.takt/retro.md`, What Didn't Go Well).
- kraken: "the agent implemented exactly what was specified" when VOLUME omitted `ml` (`kraken-wrapper 6f46aed:.takt/retro.md:20`). This is a spec problem, not a worker problem.

Positive worker evidence:
- kraken: US-005 worker "self-discovered and fixed the missing `base_unit_price` column" (`kraken-wrapper/.takt/retro.md`, What Went Well).
- cs-agent: US-001 "identified and fixed a pre-existing latent bug: ... 'BUSINESS' as the OnboardingStep default" (`dua-cs-agent/cs-agent/.takt/retro.md`).
- dikta parakeet: "10/10 stories delivered ... every blocker this sprint traced back to orchestration tooling, not implementation" (`R(dikta):26`).
- munin: "fifth clean sprint in a row" (`munin/.takt/retro.md`, What Went Well).

Worker time cost: dikta small 236s (n=34), medium 354s (n=20), large 674s (n=5) (`dikta/.takt/stats.json`).

Data missing: first-attempt success rate. CHANGELOG 2026-09-29 says "Record per-story `attempts` ... so the Sonnet first-attempt success rate becomes measurable before any builder-tier change" (`takt/CHANGELOG.md:5`), and commit 1196e2a says "Retro data had no retry statistics, so the Sonnet-first builder could not be evaluated". No `retries` block exists in any stats.json read.

### 2.2 Merge stage

All entries are failures or friction, none are catches:
- nettobrand: merge-stage agent "committed the story (`ebf325c`) but never called StructuredOutput ... workflow aborted and the orchestrator had to resume manually" (`nettobrand-wrapper/nettobrand/.takt/retro.md:38`). Status `potential`, first seen 2026-09-24 (line 20 alert table).
- nettobrand: "Workbook files committed to git by merge stage" (alert, `retro.md:19`); fixed by `.gitignore` and `cleanFiles()` in takt commit 98db385 ("never stage ephemeral or absolute paths in merge/commit stages"). Needs "1 more clean run to mark resolved".
- dikta: "each landed as two back-to-back commits ... identical trees"; workbook files for US-001 and US-005 missing (`R(dikta):35`).
- dikta, worktree base: "multi-story-wave Workflow worktrees were cut from the launch-time HEAD rather than the branch tip" blocked 4 of 10 stories (`R(dikta):33`, alert `:17`).
- dikta: `run.md` documents `waves` as `[{wave, stories}]`, code expects `[[ids]]` (`R(dikta):18`, `:34`).
- dua-erp (pre-v3): "Worktree dependency friction ... parallel stories in worktrees lack changes from earlier waves, requiring manual file porting" (`dua-erp/.takt/retro.md:13`, and What Didn't Go Well).
- Merge Strategist (Opus) added 2026-03-12 (`CHANGELOG.md:19`); "Verify Merge Strategist placeholder in run.md is filled correctly" carried 2x, never verified (`takt/.takt/retro.md`, action items). Replaced in v3 by an overlap-sorted merge stage (`CHANGELOG.md:6`).

### 2.3 Verifier (hidden BDD scenarios, verify-fix loop)

Rationale for adding: "Prevent workers from gaming verification by hiding test scenarios ... Add a verify-fix loop (max 3 cycles)" (`takt/tasks/archive/2026-03-07-scenario-verification/prd-scenario-verification.md:5-16`).

Catches:
- dikta Sparkle sprint, 2026-03-14: "SPUUpdaterDelegate wiring caught by scenario verification (SC-011)" and "Appcast history preservation caught by scenario verification (SC-014) ... build-release.sh overwrote appcast.xml entirely" (`dikta e0d1338:.takt/retro.md:16-17`). Both real bugs. Metrics: "Verification cycles: 1 (2 bugs found and fixed)" (line 52).
- dikta Shadow sprint, 2026-09-29, verify cycle 1 (`dikta/bugs.json`, commit be0aee7): BUG-001 fallback reason logged to OS log but not DiagnosticLogger, no test; BUG-002 Meet fixture never requests mic/camera, no test. Both are spec-conformance and test-coverage gaps, not user-visible defects. Classification: spec gap.
- dikta parakeet: "Verification cycles 1-2 re-opened BUG-001 on false positives (an unregistered test file, a stale doc line) before landing on the real regression — a Swift 6 strict-concurrency break" (`R(dikta):36`). One real catch, two wasted cycles.
- uven chat-v2-file-uploads: "42/42 verifier scenarios green on re-verify after 3 bug fixes (BUG-001 toast Esc-dismiss, BUG-002 health-poll infra polish, BUG-003 bucket-verify polish)" (`uven 6aa48e9:.takt/retro.md:27`). The retro's own labels are polish. Classification: style/polish.
- Clean passes with no catch: kraken "Scenario verification passed 14/14" (`kraken-wrapper ce7c891`), dikta "Verification cycles: 1 (all 7 scenarios passed static verification)" (`dikta f0c7b06`), uven "verifier 29/29, zero blocked" (`uven feb4cb3:.takt/retro.md:18`).

False positives and reliability:
- uven, chronic: "Scenario verifier / reviewer agent hallucinating findings (Chronic — carried 15x)" (`uven cec2070:.takt/retro.md:7`). Origin: "Scenario verifier hallucinated on first run: claimed DashboardPage.tsx still existed ... asserted a literal `/dashboard` Route entry at `main.tsx:28` — none of which were true. Second verifier run passed but also fabricated a line number" (`uven f75faa6:.takt/retro.md:26`). Also "structurally unreliable for 'file deleted' scenarios" (line 30).
- uven, reviewer: "Reviewer agent hallucinated a false positive: claimed an empty `catch` block existed in `handleAddMembers` — ... required must-fix override" (`uven feb4cb3:.takt/retro.md:28`); another reviewer must-fix "correctly overridden" (line 20).
- Action item "Add explicit 'verify file deleted / verify code present' tool call step to scenario verifier and reviewer prompts" carried 16x (`uven cec2070:.takt/retro.md:99`). `agents/verifier.md` last changed 2026-04-16 (d16c3db). A grep for read/confirm/evidence wording finds only "Actually run things" (`takt/agents/verifier.md:123`) and gate evidence rules (`takt/lib/final-gate.md:165-167`). No dedicated file-read-confirmation step found. Marked unverified whether it was fixed in substance.
- dua-erp: alert "Test failure slips through verify — 1 failing test in final build not caught by orchestrator" (`dua-erp 05c2605`, resolved in `72c1b5e`).
- Reduced-scope reality: several repos state verification was static only ("all code trace, no live browser test", `kraken-wrapper 6072dfa`; "validated by visual inspection only", `simplybrf-wrapper/.takt/retro.md`; dikta Windows "Fifth consecutive Windows sprint validated by code inspection only", `dikta f8debb3:.takt/retro.md:34`). In those runs the verifier could not run anything.

Time cost: not separable. Dikta overhead avg 2025s vs small story avg 236s.

### 2.4 Review gate (4-pass; formerly reviewer plus final gate)

Rationale:
- Reviewer added 2026-03-02: "convention violations, implicit dependencies, placeholder code, and naming mismatches all shipped uncaught because the scenario verifier only checks behavioral correctness" across 6 retros (`takt/tasks/archive/2026-03-02-code-review/prd-code-review.md:7`). Acceptance target "Review phase adds < 5 minutes" (line 93).
- Final Gate added 2026-04-08: "Three-pass review (SRE, Security, Adversary) ... Hard-blocks PR creation on must-fix" (commit fb18f5d).
- Merged 2026-04-16: "reviewer and final-gate overlapped significantly (both read the same diff, security scope duplicated) ... Net: ... -1 agent per run, -1 fix cycle" (commit d16c3db).
- Moved to Fable 2026-09-29: "the gate is the one bounded high-stakes call per cycle and has consistently caught what verification missed" (commit 1196e2a; `CHANGELOG.md:5`). The claim is stated by the author of the change, and the cost of Fable versus Opus is not measured in any retro.

Catches, classified (real = would break production, safety or release):
- dikta v1.0 Sparkle: EdDSA placeholder guard (real, release footgun) "would silently break all updates if shipped" (`dikta e0d1338:.takt/retro.md:18`, commit a85a357). Same commit removes an unused variable and import (style).
- dikta v0.5 to Windows: thread-safety data race on `audioConverter` (real, commit 72d65b7); silent hotkey re-registration failure in Release (real, f8d1640); duplicate onboarding window (real, effc15a); log rotation keeps 6 files not 5 (real, 311188c); settings window close path skips hotkey restore (real, c078399). Five real catches in dikta history from "fix: review" commits.
- dikta parakeet, cycle 1, three must-fix "that verification missed entirely": shared `TdtDecoderState` leaking across takes (real), appcast `minimumSystemVersion` 14.0 vs target 15.0 (real, "Sparkle would offer v1.5 to macOS 14 users whose app then refuses to launch", commit 37155f2), 12 bench result files force-added past `.gitignore` (hygiene) (`R(dikta):37`).
- dikta Shadow, cycle 1: four must-fix (MF-1 12h driver backstop, MF-2 muted tap, MF-3 willTerminate kills Chrome, MF-4 poller emits failed after 8 evaluate errors) (commit b759721, `review-comments.json` summary). Real reliability items.
- dikta Shadow, cycle 2: one must-fix, found by enumerating CoreAudio process objects on the machine: "Neither production host returns PIDs that resolve to CoreAudio process objects, so the shadow tap always falls back to the global unmuted tap. The cycle-1 MF-2 fix (mutedWhenTapped) never runs ... The whole 'targeted tap' feature ... is dead code in production" (`dikta/review-comments.json`, pass2_sre). Real, and it invalidates a fix the loop accepted one cycle earlier. Both the unit tests and the verifier had passed.
- nettobrand security-hardening: `sec-1` "Auth.js's `authorize()` callback bypassed `loginAction`'s rate limiting entirely via a direct POST" (real security) and `sre-1` "unbounded `Map` growth ... OOM vector" (real). "Required reading across files no single story had in scope" (`nettobrand-wrapper/nettobrand/.takt/retro.md:33`, `:46`).
- uven chat-v2-file-uploads, three cycles: cycle 1 FK cascade semantics, broken `start-rustfs.sh`, docstring mismatch; cycle 2 stored-XSS via inline Content-Type; cycle 3 tz-naive orphan GC silently never deleting in prod (all real) (`uven 6aa48e9:.takt/retro.md:33`, `:36`). Cost: "Overhead 7h ... ~25265s overhead (vs ~2822s running avg)" (line 40), and a user override of the 2-cycle limit.
- uven other sprints: "Opus review gate found 4 real, specific issues; none blocking. Good ROI." (`uven 47faecf:.takt/retro.md:12`, should-fix, perf/test-name/coercion class); "caught 3 real should-fix items (perf slice, inverted test name, 422 coercion gap)" (`uven 0d28b88:.takt/retro.md:14`); swap-state reset caught (`uven a8732aa`, real minor).
- kraken: "one must-fix (ml missing from VOLUME denominations)" (`kraken-wrapper 6f46aed:.takt/retro.md:17`). Real gap but the AC omitted `ml`, so classified spec gap.
- apisix-waf: review-fixes resolved "dead var removal, stable-source tokenisation, case-insensitive masking, cache eviction cap" plus 3 review-cycle stories (`apisix-waf/.takt/retro.md:17`). Mix of style and real, not split by the retro.
- dua-factory: "Opus adversarial gate caught the sprint-manifest drift ... surfaced something the 306-test suite could not see" (`dua-factory/.takt/retro.md:16`). Docs-level, not code.
- cs-agent-saas: review surfaced unused `Spinner` import (style), then went unfixed and became an alert (`dua-cs-agent/cs-agent-saas/.takt/retro.md`).
- oribium: "F-5 review (post-sprint) identified multiple race conditions ... flagged but not fixed during the sprint" (`oribium/sepanel_oribium/.takt/retro.md:25`). Caught, not acted on in-sprint.

Empty or low-yield gate runs: dikta f0c7b06 "0 must-fix, 1 suggestion"; kraken 9a83fe9 "approved first pass"; nettobrand 4ec5a12 "0 must-fix, 2 suggestions"; nettobrand 8260ff4 passed first cycle; dua-factory "1 suggestion, 0 must-fix"; uven 47faecf, 0d28b88, 51bf384 all "0 must-fix".

False positives and wasted cycles: reviewer hallucinated empty catch and a wrongly raised CLAUDE.md-block objection (uven feb4cb3, above); dikta Shadow cycle-1 fix loop produced code that production never reaches (see cycle 2). The gate is the only stage with a documented anti-false-positive rule: "No false positives on must-fix — if you're not certain it's a real bug with real production impact, classify as suggestion" (`takt/lib/final-gate.md` and PRD-era prompt, `tasks/.../prd-code-review.md` FR-7 caps at 2 cycles; `takt-run.js:22` `maxReviewCycles` default 2).

Tally of gate findings that the retros or commits describe as real bug, security or release-breaking: about 16 (dikta 5 + 3 + 1 + 4 + 1, nettobrand 2, uven 3+ in one sprint, plus uven should-fix sets). Style or hygiene: about 6. Spec gap: 1. Wrongly raised: 2.

### 2.5 Local validation (Phase 4b/4c)

Rationale: "Exists because two bugs (parameterized SET LOCAL, missing drizzle-orm in Docker) passed all static review phases but failed at runtime" (commit 063dc14).

Evidence:
- uven: "BUG-002 and BUG-003 (discovered in local validation) ... US-007 emitted `unread_update` but excluded recipients based on `_host_channels` ... no recipient ever received the event" (`uven 449980e:.takt/retro.md:27-33`). Both caught "only in local validation, not during story verification". Two real integration bugs.
- nettobrand: "Local VM validation passed 10/10 checks on the first run ... zero files required fixing" (`nettobrand-wrapper/nettobrand/.takt/retro.md:31`). No defect, 1 clean data point.
- Config coverage: `local-validation.md` exists in only 3 repos found (dikta, uven, nettobrand). dikta's version is "Run the full macOS unit test target" (`dikta/.takt/local-validation.md`), which repeats the test run workers and the gate already do. No dikta retro records a local-validation catch.
- run.md makes it toggleable and skippable (`takt/lib/run.md:131-135`).

### 2.6 Auto-retro

Rationale: "Add auto-retro phase — orchestrator spawns retro agent after PR creation" (`CHANGELOG.md:33`); PRD "Gap 4" (`tasks/archive/2026-03-07-baseline-completion/prd-baseline-completion.md`).

What it produced that helped:
- Cross-repo sweep drove the 2026-04-16 lean cleanup: "Cross-project retro sweep (17 retros, Feb-Apr) revealed: reviewer and final-gate overlapped ... Chronic tech debt items accumulated across 5+ projects without ever being promoted" (commit d16c3db).
- Surfaced orchestration bugs: worktree-HEAD and waves-shape (`R(dikta):33-34`), timing gaps ("fixes empty timing data across 7+ consecutive runs", `CHANGELOG.md:8`; "fixes 'timing stats unavailable' in 4 repos", `:9`).
- "Carried items eventually become stories ... The install.sh item carried 5x before becoming a dedicated US-002" (`takt/.takt/retro.md:27`), and in dikta the two 14-sprint items were finally done when a sprint was scoped to them (`R(dikta):27`).

What it did not deliver:
- Data holes in the retros themselves: kraken-wrapper "Phase overhead: unavailable — retro start time not captured" in about 9 consecutive versions (`kraken-wrapper c0a884b`, `e53afd7`, `d20ec9c`, `9a83fe9`, `faf2833`, `d6473dd`, `851945c`, `c73225e`, `465e579`); apisix-waf, simplybrf, munin, nettobrand "0 stories" (`nettobrand-wrapper/.takt/retro.md`, Metrics); missing workbooks: dikta US-001 and US-005, oribium US-004, kraken 4 of 9 (`kraken-wrapper/.takt/retro.md`, Metrics).
- Records without action, see section 3.
- Retention policy discards history ("alerts + last 1 entry only", `CHANGELOG.md:46`), so per-sprint stage data must be rebuilt from git.

### 2.7 Debug mode (`lib/debug.md`)

No retro, CHANGELOG entry or PRD mentions takt debug mode being used. `grep -rn -i 'takt debug|workbook-debug|debug mode|debug agent'` over every retro.md and CHANGELOG.md returned no hits. `lib/debug.md` git history shows it was last touched 2026-02-16 (cb5addf) after creation on 2026-02-15 (b389e3e). The only `debug-active.md` found is `/Users/sebastianstrandberg/work/git/oribium/debug-active.md`, which is the global `/debug` skill breadcrumb (repo oribium, session 2026-08-05), not takt's debug agent. Verdict basis: absence of evidence. Data missing: whether the user runs `takt debug` outside repos with committed retros.

### 2.8 PRD, feature and sprint scenario generation

`commands/sprint.md:331` and `:478` require 2-5 BDD scenarios per story, with `scenarios.json` "used exclusively by the verifier". No retro grades scenario quality directly. Indirect evidence: SC-011 and SC-014 were useful scenarios (2.3); kraken requirement gaps recur as chronic items "Enumerate all expected values in acceptance criteria for unit/enum lists" (carried 17x) and "Specify test data in acceptance criteria for price anomaly stories" (carried 15x) (`kraken-wrapper/.takt/retro.md:57-58` region), which point at AC and scenario authoring not being improved by the loop. Data missing: scenario count versus catches.

---

## 3. Chronic alerts and carry counts (ritual signal)

Counts are as printed in each retro, latest version unless noted.

| Repo | Item | Carried | Status at last retro |
|---|---|---|---|
| kraken-wrapper | Add `tsx` devDependency; shared eval tsconfig; add `eval/results/` to .gitignore | 23x each | open (`kraken-wrapper/.takt/retro.md:48-50`) |
| kraken-wrapper | Cron daily-brief `orgId` refactor | 21x | open |
| kraken-wrapper | Automate Supabase type generation; re-index jCodeMunch | 19x each | open |
| kraken-wrapper | Document Zod v4 differences; enumerate all values in AC | 17x each | open |
| kraken-wrapper | Specify test data in AC | 15x | open |
| kraken-wrapper | Unit abbreviation docs; wire invite email provider | 12x each | open |
| nettobrand-wrapper | Add Task spawning so waves run in parallel | 18x | open |
| nettobrand-wrapper | Post-deploy verification phase | 15x | open |
| nettobrand-wrapper | Railway company seed | 15x | open |
| nettobrand-wrapper | Railway migrations pending | 11x | open |
| nettobrand-wrapper | Two-step submodule+wrapper commit automation | 10x | open |
| nettobrand-wrapper | `[BLOCKER]` agent teardown, `[BLOCKER]` label | 4x on the action item, alert confirmed since 2026-03-22 | open (`nettobrand-wrapper/.takt/retro.md` alert table) |
| nettobrand | Bulk actions placeholders, next/image domains, DB integration tests | 13x each | open; cards #52, #53 in Backlog "unpicked" (`nettobrand/.takt/retro.md`) |
| nettobrand | SiteSetting table | 11x | open, card #54 |
| nettobrand | SearchInput client component | 10x | open, card #55 |
| nettobrand | createKorpenInvoice getConfig; Prisma CLI pin | 9x each | open, cards #56, #57 |
| nettobrand | dotenv-cli docs | 8x | open, no card |
| uven | Verifier/reviewer hallucination: add file-read confirmation to prompts | 16x | open in retro at 2026-04-18 (`uven cec2070:.takt/retro.md:99`); fix unverified |
| dikta | Swift/Apple platform-gotchas story template | 14x | open (`R(dikta):73`) |
| dikta | `swift test` never run end-to-end | 14x then mitigated | resolved by parakeet US-002 gate (`R(dikta):27`) |
| dikta | ConfigService dual atomic writes | ~14 sprints | resolved by US-001 (`R(dikta):27`) |
| dikta | Extract AudioRecorder subsystems | 12x | open (`R(dikta):76`) |
| dikta | CHANGELOG [0.6] entry missing noise-token fix | 11x | open (`R(dikta):79`) |
| dikta | Windows build verify; Windows release checklist; FormatterTests inline copy | 7x each | open |
| dikta | Verify `WithNoSpeechThreshold` name | 4x | open (`R(dikta):65`) |
| dikta | Zombie agent panes | alert confirmed since 2026-03-27 | open in alert table (`R(dikta):10`); v3 removes TeamCreate (`CHANGELOG.md:6`) |
| cs-agent | Delete stale `factories.ts` | 7x | closed as "file already removed" (`dua-cs-agent/.takt/retro.md`, alert resolved 2026-03-22). Carried 7 retros for a file that no longer existed. |
| oribium | `pyproject.toml` missing deps | 5x | open |
| oribium | Review browser-UI story sizing | 4x | open |
| munin | Migration bootstrap, dev setup doc, ctx_batch_execute args | 5x each | open |
| takt | Verify `start takt` end to end | 5x | alert resolved 2026-03-22 by real use |

Signals:
- The retro added a chronic tier at 5+ carries (`CHANGELOG.md:10`, 2026-03-29). Afterward counts kept growing: kraken to 23, nettobrand to 18, dikta to 14. The tier changed how items are printed, not whether they are done.
- Nettobrand states the mechanism: "The gap isn't 'nobody's tracking this' — it's tracked twice, in both `retro.md` and `TODO.md`, and picked up by neither" (`nettobrand-wrapper/nettobrand/.takt/retro.md:44` region).
- Items that were resolved were resolved by a human scoping a sprint to them, not by the retro loop (dikta US-001/US-002; takt US-002).
- A hardest-evidence ritual example: the `/sprint` command was changed to read chronic debt before story generation (commit d16c3db "Add chronic tech debt check to /sprint command"). Dikta's Shadow sprint began after that and its retro shows the 14x, 12x, 11x, 7x items still open at 2026-09-28.

---

## 4. Stage additions, removals and merges, with stated reasons

| Date | Change | Stated reason | Source |
|---|---|---|---|
| 2026-02-19 | Hidden-scenario verifier | Stop workers gaming visible tests | commit 3b0b17e; `prd-scenario-verification.md:5` |
| 2026-03-02 | Reviewer phase | Quality gap across 6 retros | `CHANGELOG.md:36`; `prd-code-review.md:7` |
| 2026-03-07 | Auto-retro, PR creation phase | Baseline autonomy (Gaps 3 and 4) | `CHANGELOG.md:32-33` |
| 2026-03-07 | TDD enforcement dropped from worker | "BDD scenarios are the verification layer" | `CHANGELOG.md:30` |
| 2026-03-12 | /tdd command removed | "BDD scenarios are the quality gate; TDD workflow redundant" | `CHANGELOG.md:17` |
| 2026-03-12 | Merge Strategist (Opus) | Optimal merge order in parallel mode | `CHANGELOG.md:19` |
| 2026-04-08 | Final Gate | Zero-defect review before PR | commit fb18f5d |
| 2026-04-08 | Local validation | Two bugs passed static review, failed at runtime | commit 063dc14 |
| 2026-04-16 | Reviewer merged into review gate | Overlap, "-1 agent per run, -1 fix cycle" | commit d16c3db |
| 2026-09-24 | v3 Workflow script replaces run.md mechanics | Determinism, resumability, shared roster | `CHANGELOG.md:6`; commit e169796 |
| 2026-09-29 | Gate model Opus to Fable; per-story `attempts` | Gate "consistently caught what verification missed"; builder tier unmeasurable | `CHANGELOG.md:5`; commit 1196e2a |

No stage has ever been removed on the basis of measured cost. The only removal-style change (reviewer merge) was justified by overlap between two stages that both read the same diff.

---

## 5. Verdict per stage (only from what was found)

**Worker: mixed, unmeasured.** Retros overwhelmingly report zero blocked stories, and workers show good local judgment (self-fixed schema and enum bugs). But the gate and local validation repeatedly find defects workers left: FK semantics twice, tz-naive datetimes, integration state missed by typecheck-only passes, and one external runner producing a broken infra script. First-attempt success cannot be computed because attempts tracking began 2026-09-29.

**Merge stage: mixed, net cost.** Every merge-stage entry is a failure or friction: leaked workbooks, a missing structured output that aborted a run, stale worktree bases that blocked 4 of 10 dikta stories, and duplicate commits. It catches nothing by design. It is the main source of tooling-caused blocked runs in the sample, and dikta's retro says orchestration tooling is now the primary blocker class (`R(dikta):41`).

**Verifier: mixed.** Real catches exist but are few: SC-011, SC-014 and one regression in dikta. Other catches are polish (uven), or spec and test-coverage gaps (dikta Shadow BUG-001/002). It burned two cycles on false positives in dikta parakeet and shows a 16-retro chronic hallucination problem in uven with no confirmed fix. In many repos it runs by code reading only, which removes its ability to catch runtime issues, and the gate and local validation found bugs it passed (dikta Shadow cycle 2, uven BUG-002/003).

**Review gate: helping.** It has the strongest catch record in the sample: dikta parakeet's three must-fix items that verification missed, nettobrand's auth bypass and OOM vector, uven's stored-XSS and silent GC failure, dikta Shadow's dead-code tap discovered by inspecting the live machine. Costs are visible: uven's 3 cycles and about 7 hours of overhead, one hallucinated finding, one wrongly raised must-fix, and a cycle-2 result that invalidated a cycle-1 fix. Many gate runs also return 0 must-fix (about 8 recorded). The Fable upgrade rationale rests on the change author's claim, and no retro compares Fable against Opus.

**Local validation: helping where a runtime exists, otherwise unproven.** Two real integration bugs in uven were caught only here, and it was created for two runtime-only bugs. Only 3 repos define it. Dikta's version re-runs the unit tests, and no dikta retro records a catch from it. Nettobrand's run passed with nothing to fix.

**Auto-retro: mixed leaning ritual.** It produced the useful cross-repo cleanup and exposed tooling bugs. It also carried 23, 18, 16, 14 and 13 times items that never changed, added a "chronic" tier that did not change outcomes, once tracked a stale item for 7 retros after the file was gone, and repeatedly reported missing timing and workbook data about itself. Resolution came from humans scoping sprints, not from the retro.

**Debug mode: no evidence.** No retro, CHANGELOG line or PRD records its use since 2026-02-16. Cannot be scored as helping or ritual on this data.

**Scenario generation: unmeasured.** Scenarios only matter through the verifier, whose catch record is above. No data on scenario count versus catches.

---

## 6. Open questions and missing data

- No per-stage wall-clock. "Phase overhead" mixes verify, fix loops, review, PR, retro start, and idle time. Recovering per-stage cost needs Workflow run logs (not read).
- No first-attempt or retry data for workers before 2026-09-29.
- Retro retention (last 1 entry) and missing timing mean older sprints are only visible through git history, and only in repos that commit `retro.md` (dua-cs-agent, korpen and two cs-agent repos have 0 commits for it).
- No side-by-side Opus vs Fable gate result. No retro yet from a Fable gate run except dikta's current Shadow sprint, which has no retro.
- Unverified: whether the uven hallucination item was ever fixed in `agents/verifier.md` or `lib/final-gate.md`.
- Unverified: whether findings labeled "real" by retros were confirmed by execution. Only dikta Shadow cycle 2 states an empirical check.

## 7. Out-of-scope observations

- `takt/lib/run.md` exposes `waves` shape and worktree HEAD limitation; commit 1196e2a says the installed `run.md` "had drifted ahead of the repo", so install and source can diverge silently. The dikta retro's waves and HEAD alerts (`R(dikta):17-18`) may be partly fixed at source; not checked.
- dikta `.takt/retro.md:35`: workbooks for finished stories can be missing, which weakens every downstream retro claim.
- `dua-factory` retro: external Codex worker "hung twice on `Reading additional input from stdin...`" (`dua-factory/.takt/retro.md`), and a separate uven note that external opencode workers stalled. External runners are a recurring reliability source.
- dua-cs-agent retro routes: "Session agent routes `takt retro` through `/takt` skill (PRD converter) instead of running retro directly — has happened 2+ times" (`dua-cs-agent/.takt/retro.md`, alert table).
- oribium `debug-active.md` (2026-08-05) is an open unfinished debug session (403 on mailbox/new), unrelated to takt.
- dikta working tree currently has uncommitted edits plus untracked `bugs.json`, `review-comments.json`, `sprint.json` from the in-flight Shadow sprint.
