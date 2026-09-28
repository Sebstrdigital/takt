# takt process audit — 2026-09-29

**Question:** which takt stages catch real problems, which are ritual, and where would an existing Claude Code skill do the job better?

**Revision 2 (same day):** Sebastian clarified that takt's files exist to hand work between context windows, not for a human to read. Section 4 traces every handoff on that basis and proposal P10 follows from it. Earlier findings stand.

**Method:** four read-only scouts mined every `.takt/retro.md` and `stats.json` under `work/git/` (22 repos, 1,164 story commits), the takt CHANGELOG and archived PRDs, every prompt file in `lib/`, `agents/`, `commands/`, the git history of fix commits per stage, and the skill/agent inventory in `~/.claude/`. Evidence files are next to this README: `retro-evidence.md`, `git-evidence.md`, `stage-map.md`, `skill-overlap.md`. Numbers from git classification are roughly plus or minus 10 points.

Nothing in the pipeline was changed by this audit. Every item under "Proposals" is for Sebastian to accept, reject or reshape.

---

## 1. Verdict per stage

| Stage | Verdict | Evidence in one line | Proposal |
|---|---|---|---|
| Planning (`/epic`, `/feature`, `/sprint`) | Keep, consolidate | Works, but 22 human gates for a 4-feature epic, rules contradict each other, hidden scenarios are not independent | P7 |
| Worker | Keep, unmeasured | Rarely blocks; defects surface downstream; first-attempt rate measurable from next run (attempts field) | P2 |
| Merge / commit stage | Cut down | Zero recorded wins, 3 recorded failures, 6 of 16 spawns in a typical run doing `git add` + `jq` | P1 |
| Verifier (hidden BDD) | Keep, fix known failure | 50 fix commits, 80 % real bugs, but false-positive cycles from stale index and hallucinated findings carried 16 sprints | P3 |
| Review gate (4-pass) | Keep, sharpen | 109 fix commits, 66 % real; the best catches in the whole history (CSRF, stored XSS, cross-tenant FK, data race). Findings partly wasted: suggestions never surfaced | P4 |
| Local validation | Keep where it runs the app, cut where it re-runs tests | 2 real integration bugs in uven caught nowhere else; dikta's version repeats the unit tests | P5 |
| Artifact bus (files between context windows) | Half wired | 5 of 8 handoffs work as designed; `bugs.json` and `review-comments.json` are written but no next agent is told to read them, and the feature doc never boards | P10 |
| Auto-retro | Trim to what is read | Stats and tooling-bug reports are used; alert lifecycle and carry counts are not: 23x, 18x, 14x carries, resolved only when a human scoped a sprint | P6 |
| Debug mode (`lib/debug.md`) | Retire | No use recorded since 2026-02-16; `/diagnose` is a superset of the method | P8 |
| Doc and rule drift | Fix | 4 contradictions, 3 stale references, 1 wrong pass count | P9 |

---

## 2. What the numbers say

**Fix commits across all takt repos** (`git-evidence.md`):

| Stage | Fix commits | Real bug | Cosmetic / docs / test-only |
|---|---|---|---|
| Verify | 50 | 40 (80 %) | 10 |
| Review gate | 109 | 73 (66 %) | 36 |
| Local validation | 0 with that subject | unknown | unknown |
| Retro | 58 | 5 | 53 |

**Where the value concentrates.** uven, nettobrand, kraken, dikta, sepanel_oribium and munin account for nearly all real catches. In takt, cs-agent, cs-kb-agent, mcp-servers, dua-factory and mobile-app the gates produced only docs or import moves, or nothing. Gates pay off on runtime-heavy product code and not on prompt repos or thin wrappers.

**Cost.** Overhead (everything after the last story merged) averages 2,025 s in dikta against 236 to 674 s per story. That bucket is not split by stage anywhere, so the cost of verifier vs gate vs retro cannot be separated from existing data. The parakeet run spent 7,032 s in overhead, of which two verify cycles were false positives.

**Spawns.** A 6-story sequential run with clean verify and gate spawns about 16 agents: 6 workers, 6 merge agents, 1 verifier, 1 gate, 1 validation, 1 retro. The shadow-participant run reached roughly 26 after fixes.

---

## 3. Findings per stage

### 3.1 Merge / commit stage

One Haiku (or Sonnet, for worktrees) agent per wave whose entire job is `git add <files>`, `git commit`, and one `jq` line into `sprint.json`. It exists because `takt-run.js` never touches the filesystem by design. Every retro mention is a failure: workbooks committed to git (nettobrand), a run aborted because the agent skipped the structured output (nettobrand), stories landing as duplicate back-to-back commits (dikta), worktree bases cut from launch-time HEAD blocking 4 of 10 stories (dikta). No retro records the stage doing anything a worker could not have done.

### 3.2 Verifier

Verify fixes are the highest-quality fixes in the history (80 % real), so the stage is not ritual. Its failure mode is specific and known: it asserts things about files without reading them. uven carried "verifier hallucinates findings" for 16 sprints and the action item "add explicit verify-file-exists step to verifier prompt" for as long. dikta parakeet burned two cycles on an unregistered test file and a stale doc line. Windows sprint 4 failed 14 of 15 scenarios on a stale jCodeMunch index and passed 15 of 15 once told not to use it. `agents/verifier.md` has not changed since 2026-04-16.

A second weakness: the "hidden, independent" scenarios are written by `/sprint` in the same context, immediately after the acceptance criteria they are supposed to be independent from (`sprint.md:482` vs `:490-535`). That is why verification finds spec-conformance and test-coverage gaps (shadow BUG-001/002) rather than design bugs.

### 3.3 Review gate

The strongest stage. Real catches that no other stage saw: OIDC CSRF state (uven), stored XSS via content type (uven), cross-tenant FK guard (sepanel), rate-limit bypass in Auth.js authorize (nettobrand), unbounded Map growth (nettobrand), audioConverter data race (dikta), orphaned Chrome process on quit (dikta), shadow tap always falling back to global unmuted (dikta, cycle 2). It also restored a heavy-freight shipping fallback that a verify fix had broken the same day.

Three things waste part of its output:

1. `review-comments.json` is written for the next agents but no next agent is told to read it (section 4). Fix workers get a four-field subset through the structured output, cycle 2 reviews cold, and the should-fix suggestions (11 in the shadow run) reach nobody before Phase 7 deletes the file.
2. The checklist is web-centric: SQL injection, `NODE_ENV`, DB transactions, load simulation against a Swift menu-bar app. `.takt/final-gate-checklist.md` already exists as a per-project hook but no repo uses it for stack-specific passes.
3. Cycle 2 sometimes invalidates cycle 1's fix (dikta shadow MF-1). `/deep-review` has a triage and convergence rule for exactly this; the gate has none.

Fable vs Opus at the gate has no data yet. Two runs will tell.

### 3.4 Local validation

Defined in 3 repos only. In uven it runs the service and caught two real integration bugs (unread events never reaching recipients) that tests, verifier and gate all passed. In dikta it re-runs the unit test target the worker and gate already ran; no dikta retro records a catch. The stage also contains the only blocking `AskUserQuestion` inside an otherwise unattended run.

### 3.5 Auto-retro

What gets read: `stats.json` for the ETA, tooling-bug notes that led to real takt fixes (worktree HEAD, waves shape, timing gaps), and the CHANGELOG line. What does not: the alert lifecycle (potential, confirmed, mitigated, resolved), carry counts, and chronic-debt promotion. kraken carried an item 23 times, nettobrand-wrapper 18, dikta 14. The "chronic after 5 carries" tier added on 2026-03-29 did not change the growth rate. Items got done only when Sebastian scoped a sprint to them. About 25 lines of `retro.md` exist to maintain data with no consumer, and the retention policy (last entry only) throws away the history a process audit needs.

### 3.6 Debug mode

`lib/debug.md` (86 lines) has no spawn instructions, no retro mention, no CHANGELOG line and no PRD since 2026-02-16. `/diagnose` covers the method (feedback loop, reproduce, ranked hypotheses, regression test at the right seam) and adds discipline debug.md lacks. `/debug` covers the breadcrumb file.

### 3.7 Planning

`/epic` to `/feature` to `/sprint` works, and `/spec` now produces `sprint.json` plus `.takt/scenarios.json` with an adversarial "would a lazy implementation pass this" check that `/sprint` lacks. Two canonical paths to the same artifacts, and their rules disagree: `feature.md:127` says never list typecheck as a criterion, `sprint.md:299` makes it mandatory; `feature.md:118` wants fewer broader stories, `sprint.md:239` wants small ones.

---

## 4. The artifact bus: files as the handoff between context windows

takt's files are not for a human. They are how one context window hands work to the next, so the question is whether each intended reader is actually pointed at the file, and what survives the hop. Traced through every prompt builder in `takt-run.js` and every `lib/*.md`:

| Artifact | Producer, intended reader | Reader told to read it? | What actually crosses the hop | Lost |
|---|---|---|---|---|
| `.takt/scenarios.json` | `/sprint`, verifier | Yes (`verifier.md:8,23`) | The file | Nothing. Hidden from workers as designed |
| workbooks | worker, merge agent and retro | Yes (`takt-run.js:246`, `retro.md:7`) | The file | Nothing. Heavy retry is given a one-line `why`, not attempt 1's workbook path |
| `.takt/validation-report.md` | validation agent, session | Yes (`run.md:147`) | The file | Nothing |
| `.takt/session.json`, `stats.json`, `retro.md`, `sprint.json` | orchestrator and retro, next run | Yes | The file | Nothing |
| `bugs.json` | verifier, fix workers and verifier cycle N+1 | No | Fix workers get the same four fields inline from the VERDICT schema. Cycle N+1's prompt never mentions cycle N's file, so it re-verifies everything cold | Cycle memory. Parakeet re-opened BUG-001 twice on new false positives because cycle 2 had no record of cycle 1 |
| `review-comments.json` | gate, fix workers and gate cycle N+1 | No | Fix workers get `id, pass, file, description` from the GATE schema. `line`, `evidence`, `impact` stay in the file. Cycle 2's prompt never mentions cycle 1's file. Suggestions are in neither the schema nor any reader's prompt, and Phase 7 deletes the file | Evidence and impact for the fixer; all should-fix suggestions; cycle memory. Shadow MF-1 cycle 2 invalidated cycle 1's fix because cycle 2 reviewed cold |
| `.takt/review.diff` | gate, gate | Same context | Not a hop | Nothing |
| `tasks/feature-*.md` | `/feature`, `/sprint` only | No | Worker gets the story JSON. Gate gets the diff and `CLAUDE.md`. Retro archives the doc | The why, the scope edges and "what we are not building" never reach anyone who writes or reviews code. The gate cannot check spec compliance because it is never given the spec |

**The pattern.** Every hop that has exactly one channel works. The two loop hops have two channels, file and structured output, and the prompts wire only the narrower one. The result is a bus where the producer writes the full record to disk and the consumer receives a summary in its prompt.

**The rule to adopt:** one channel per hop. For the two loops the file should be the channel, because it can carry history across cycles and full evidence without growing the orchestrator's context; the structured output then carries only the verdict, the counts and the path. That is proposal P10.

---

## 5. Skills: where they fit

| takt stage | Skill or agent | Fit | Why |
|---|---|---|---|
| Review gate | `/deep-review` | Adopt parts | SRE and security passes near-identical; triage (block / followup / dismiss) and re-run convergence are the parts worth lifting. Checklists are Next.js/Drizzle/Supabase-specific, output shape differs, and spawning sub-reviewers from inside a Workflow agent is unverified |
| Review gate | `skeptic` agent | Add as pass | The gate never checks "does the diff satisfy the story". Skeptic's refute-against-spec stance fills that hole |
| Review gate | plugin `/code-review` | No | Needs a GitHub PR, posts comments, drops findings under 80 confidence |
| Review gate | `/code-review`, `/security-audit` (skills) | No, as gate | Whole-repo audits writing to `docs/audits/`; right as periodic project audits, wrong per sprint |
| Verifier | `/tdd` | No | Writes visible tests with user plan approval; the verifier's value is hidden scenarios |
| Scenario authoring | `/spec` | Drop-in, pre-run | Already emits `scenarios.json`; adversarial check is stronger than `sprint.md` |
| Verify-fix loop | `/diagnose` phases 1-2 | Adapt | Feedback loop first, reproduce before fix, with interactive pauses turned into "record and continue" |
| Debug mode | `/diagnose` + `/debug` | Replace | Superset of `lib/debug.md` |
| Merge, retro, local validation | none | Gap | Bespoke; nothing on disk covers them |
| Native-app review checklist | none | Gap | Every pass doc found is web or serverless oriented |

Not verifiable: built-in `simplify`, `security-review`, `run`, `workflow-authoring` have no file on disk to read.

---

## 6. Proposals, ranked by value over effort

| # | Proposal | Cuts / adds | Effort | Risk |
|---|---|---|---|---|
| P1 | Workers commit their own story. In-place worker: `git add <its files>`, `git commit -m "feat: <id>"`, `jq` update, at the end of `worker.md`. Worktree worker: same on its branch. Merge agent spawned only for waves with 2+ stories, to merge and clean up. | About 6 Haiku spawns per sequential run | Small: `worker.md` + `takt-run.js` merge call site | Worker stages junk. Mitigation: `cleanFiles` list moves into the worker prompt, `EPHEMERAL` unchanged |
| P2 | Read attempts data from the next 2-3 runs before touching builder tier. Already wired. | Nothing yet | None | None |
| P3 | Harden the verifier: (a) mandatory "read the file before asserting anything about it" step, (b) skip jCodeMunch unless `session.json.indexed_commit == HEAD`, (c) generate scenarios in a fresh agent from the feature doc, not in the `/sprint` context, or route scenario authoring through `/spec` | Expected: fewer false-positive cycles | Small for (a)(b), medium for (c) | (c) changes `/sprint`; two paths already exist, pick one |
| P10 | Wire the bus, one channel per hop. (a) `bugs.json` and `review-comments.json` become cycle-aware: each entry carries `cycle` and `status` (open, fixed, dismissed); cycle N+1's prompt points at the file and says "confirm each open item before raising new ones, never re-litigate a fixed one". (b) Fix-worker prompts point at the file entry instead of inlining a subset, so `evidence`, `impact` and `line` arrive. (c) VERDICT and GATE schemas shrink to verdict, counts and file path. (d) Should-fix suggestions are copied to the PR body by the session agent, or to the project `TODO.md` when there is no PR, before Phase 7 deletes the file. (e) Gate and worker prompts get the feature doc path from `sprint.json.branchName` so the spec boards the bus; the gate uses it for spec compliance | Cycle memory, full evidence to fixers, suggestions survive, spec reaches reviewers | Small to medium: prompt text, two schemas, one session step | Larger prompts for fixers; the deep-review convergence rule in P4 becomes unnecessary |
| P4 | Add a per-stack checklist mechanism: `lib/final-gate.md` core plus `final-gate-swift.md` / `-web.md` selected from `.takt/config.json`. With P10e in place, add a spec-compliance pass (skeptic stance) as pass 5 | Drops irrelevant web checks on native repos; the gate finally checks the diff against the story | Medium | Longer gate on Fable; measure per-stage time first (P6b) |
| P5 | Local validation: config gains `manual_check: false` so `AskUserQuestion` is opt-in; dikta's `local-validation.md` either drives the built app (`run` skill or a smoke script) or is removed | One blocking prompt per run | Small | None |
| P6 | Retro trim: (a) drop alert lifecycle and carry counts; chronic debt written once to the project's `TODO.md` (Sebastian's backlog convention) and never carried; (b) split overhead by adding `startedAt`/`finishedAt` to the VERDICT, GATE and COMMIT schemas so retro can report verify vs gate vs fix time; (c) keep the last 3 entries, not 1 | About 25 lines of ritual; adds the one metric this audit could not compute | Small | None |
| P7 | Planning: make `/spec` the canonical producer of `sprint.json` + `scenarios.json`; `/feature` keeps the doc; `/sprint` becomes a thin converter or is folded into `/spec`. Resolve typecheck and story-size contradictions in the surviving file | Two paths become one | Medium | Sebastian's muscle memory for `/sprint` |
| P8 | Retire `lib/debug.md`; `takt debug` prints "use /diagnose, breadcrumbs via /debug" | 86 lines | Trivial | None |
| P9 | Drift fixes: `final-gate.md:140` "three" to "four"; `CLAUDE.md:42` gate opus to fable; `takt.md:169` and `README:197` drop the `type` and `verify` fields; README:200 stop claiming `bugs.json` is read; `tooling.md:3` vs `worker.md:67` `.takt/` read ban; duplicate cleanup list in `retro.md:181` and `run.md:201` | Confusion | Trivial | None |

**Suggested order:** P9 and P8 today (no risk). P10a-d next, it is the largest value for the least code and it removes the cause of both documented cycle-2 regressions. P6b before P4 so the gate change can be measured. P1 and P3a/b after that. P4, P7, P3c, P10e after two runs of data.

**Not proposed:** merging verifier into the gate. Verify fixes are 80 % real; the two stages find different classes of defect (spec conformance vs runtime and security). Fixing the verifier's read-before-assert gap is cheaper than losing it.

---

## 7. What remains unmeasured

- First-attempt worker success rate (data starts with the next run).
- Fable vs Opus at the gate (no comparison exists; the change landed today).
- Per-stage overhead (P6b).
- Whether gate findings are folded into story commits in repos with stories but no fix commits (cs-kb-agent, mcp-servers, dua-factory).
- Whether a Workflow agent can spawn sub-agents, which `/deep-review` needs.
