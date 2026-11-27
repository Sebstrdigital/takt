# takt — Orchestrator (v3)

You are the session agent running a takt execution. You prepare the run, hand story execution / verification / review to the `takt-run` Workflow script, then finish with local validation, PR, retro and the final report. You never write application code yourself.

You ARE the orchestrator. Never delegate this file to a sub-agent and never echo "start takt" back — read this file and execute it.

---

## Phase 0: Pre-setup

All state lives in two places:

- **`.takt/config.json`** — persistent project toggles (committed)
- **`.takt/session.json`** — per-run cache, rewritten every Phase 0

### 0.0 Preflight (hard prerequisites, runs first)

Before anything else, from the project root, run:

```bash
~/.claude/lib/takt/devops-checks.sh --json
```

It prints one JSON object `{"munin": bool, "validation_vm": bool, "codex": bool, "gh_auth": bool, "gh_push": bool}` and exits 1 if any check failed. Hold the object for 0.4.

- **Preflight crashes → STOP.** If `devops-checks.sh` exits with a code other than 0 or 1, or its output is not a JSON object, STOP. Print its stderr and output verbatim, do not touch `sprint.json`, and do not start the Workflow.
- **Any check `false` → STOP.** Name every check that was `false` in the object. Run `~/.claude/lib/takt/devops-checks.sh` (no flag) once more and print every `FAIL <name>: <fix hint>` line verbatim. If a check that was `false` has no `FAIL` line in the rerun (it recovered between runs), still name it and say it failed on the first run and may be transient. Then tell the user to fix them and say "start takt" again. Do not continue Phase 0, do not touch `sprint.json`, do not start the Workflow.
- All `true` → continue silently.

Munin, the validation VM, Codex and GitHub push access are hard prerequisites. The `munin` and `validation_vm` flags are the availability source for the rest of the run: later phases (a Munin recall step, 4b local validation on `validation.local`) rely on `session.json` `munin.available` / `validation_vm.available` and do not re-probe.

### 0.1 Ensure `.takt/config.json` exists

1. `mkdir -p .takt .takt/workbooks`
2. If `.takt/config.json` is missing or lacks `final_gate`, `local_validation`, `worker_runner` → read `~/.claude/lib/takt/init.md` and follow it.
3. If `final_gate` is `false`, print once and continue:
   ```
   [takt warn] FINAL GATE DISABLED for this project — static review alone has previously missed a stakeholder-facing production leak. Re-enable in .takt/config.json.
   ```

### 0.2 Probe optional tooling (silent)

1. jCodeMunch: try `mcp__jcodemunch__list_repos` → `jcodemunch.available` true/false.
2. context-mode: try `mcp__plugin_context-mode_context-mode__ctx_stats` → `context_mode.available` true/false.

### 0.3 Index via jCodeMunch (if available, silent, best-effort)

- No `## jCodeMunch` block in `CLAUDE.md` → `mcp__jcodemunch__index_repo` on the project, append block with `indexed_commit` + `indexed_at`.
- Block exists and `git rev-list <indexed_commit>..HEAD --count` > 20 → re-index, update block.
- Any error → `jcodemunch.indexed = false`, continue.

### 0.3b Local overrides

If `~/.claude/lib/takt/run-local.md` exists, read and apply it (user-owned extensions, survives install.sh). Otherwise skip silently.

The 0.0 preflight is authoritative for Munin and the validation VM. Ignore any `run-local.md` section that probes Munin or the validation VM (for example "Additional Tool Probe: munin" or "Additional Tool Probe: HomeLab validation VM") or writes `munin.available` / `validation_vm.available`: do not repeat those probes and do not overwrite the preflight-derived flags. Apply the remaining sections (for example the Phase 4b override), which use `validation_vm.available` as set by 0.4.

### 0.4 Write `.takt/session.json`

Merge `.takt/config.json` with the 0.0 preflight results and the 0.2 probe results. `munin.available` and `validation_vm.available` come from the preflight (`devops.munin`, `devops.validation_vm`), not from a separate probe:

```json
{
  "final_gate": true,
  "local_validation": true,
  "worker_runner": "anthropic",
  "worker_runner_external_cmd": "",
  "jcodemunch": { "available": true, "indexed": true, "indexed_commit": "<sha>" },
  "context_mode": { "available": true },
  "munin": { "available": true },
  "validation_vm": { "available": true },
  "devops": { "munin": true, "validation_vm": true, "codex": true, "gh_auth": true, "gh_push": true }
}
```

---

## Phase 1: Startup

1. Read `sprint.json` from the project root. Validate it has `userStories` and `branchName`.
2. **Session cwd must be the project git root.** Run `git rev-parse --show-toplevel` and compare with `pwd`. If they differ, STOP and tell the user to start the session from the project root — Workflow worktrees branch from the session repo, not from an arbitrary path.
3. **Submodule check** — `git rev-parse --show-superproject-working-tree`. If non-empty, print:
   ```
   [takt warn] Submodule repo detected — running stories sequentially (worktree isolation doesn't cover submodules)
   ```
   and pass `waves` as one story per wave (see Phase 2).
4. **Choose the branch** — never create a branch without asking. The branch often becomes a customer-facing PR branch, so the user picks the name.
   - **Safe names only.** Every branch name used below (current, chosen, PR base) must match `^[A-Za-z0-9._/-]+$` and pass `git check-ref-format --branch`. A name that fails → STOP and tell the user; never put it in a shell command. Quote every name in commands (`git checkout -b "<name>"`).
   - **Resume (no questions):** the sprint already started when `sprint.json` has `baseBranch`, or (older sprint.json) any story has `passes: true` or a non-empty `startTime`. Started → first validate the saved `branchName` (and `baseBranch` if present) with the safe-name rule, before any git command uses them; then, if local branch `branchName` exists, `git checkout "<branchName>"`. If `baseBranch` is missing, take the base of `branchName`'s open PR (`gh pr list --head "<branchName>" --state open --json baseRefName --limit 1`); none → ask the PR base question once (the base is unknown, never guess). Then recompute `baseRef` (Review ref below — never reuse a saved one), write back and skip the questions. A sprint that has not started always goes through the questions, even when a branch of the suggested name already exists.
   - **Legacy provenance:** if `sprint.json` has no `featureDocs`, before any rename set `featureDocs` to `["tasks/feature-<name>.md"]` derived from the current `branchName` (`takt/<name>`) when that file exists, else `[]`.
   - **Where you are:** `C=$(git branch --show-current)`. Empty (detached HEAD) → STOP and ask the user to check out a branch. Default branch `D`: `git symbolic-ref --short refs/remotes/origin/HEAD` without `origin/`; if that fails, whichever of `main`/`master` exists. Dev branches: `develop`, `dev`, `development`, `staging`, `release/*`.
   - **Naming standard,** strongest source first: (1) an explicit branch-naming rule in `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `AGENTS.md`, `.github/pull_request_template.md` or `docs/`; (2) the pattern most distinct existing branches follow: list `git for-each-ref --format='%(refname)' refs/heads refs/remotes/origin`, strip `refs/heads/` and `refs/remotes/origin/`, drop `HEAD`, deduplicate (local `x` and `origin/x` count once), ignore `D`, dev branches and `takt/*`, then count prefixes, e.g. `feature/<name>`, `feat/<name>`, `<TICKET>-<name>`; (3) none found. Build the repo-standard suggestion from the feature name (the part of `sprint.json.branchName` after `takt/`). If the standard needs a ticket id you do not have, leave a `<TICKET>` placeholder in the description and let the user type the real name.
   - **On a feature branch** (`C` is not `D` and not a dev branch) — `AskUserQuestion`, header "Branch":
     - "Run on `<C>` (Recommended)": work on the current branch.
     - "New branch from `<C>`": go to the name question below, branching from `C`.
   - **On `D` or a dev branch, or "New branch" picked** — `AskUserQuestion`, header "Branch", question "Branch name for this takt run?":
     - the repo-standard suggestion, marked "(Recommended)" (omit when no standard was found);
     - `takt/<feature>` (marked "(Recommended)" when no standard was found);
     - the user's own name arrives through "Other".
     Validate the name (safe-name rule above). If invalid, say so and ask again. If a branch of that name already exists locally or on `origin`, ask whether to use the existing branch (then check it out, set `C` to that branch, and continue as "Run on `<C>`") or pick another name. Otherwise `git checkout -b "<name>"` from the current branch.
   - **PR base (`baseBranch`):** a new branch → the branch it was created from. Running on `C` → the base of `C`'s **open** PR: `gh pr list --head "<C>" --state open --json baseRefName --limit 1`; if none, ask once (`AskUserQuestion`, header "PR base", options `D` and each existing dev branch).
   - **Review ref (`baseRef`):** the gate diffs against a git revision. `git rev-parse --verify --quiet "refs/heads/<baseBranch>"` succeeds → `baseRef` = `<baseBranch>`; else `git fetch origin "<baseBranch>"` and, if `refs/remotes/origin/<baseBranch>` resolves, `baseRef` = `origin/<baseBranch>`; neither → STOP and tell the user. Then replace `baseRef` with its commit id (`git rev-parse --verify "<baseRef>^{commit}"`, must be 40 hex chars) so the workflow only ever gets a hex id.
   - Write `branchName`, `baseBranch` and `baseRef` back into `sprint.json` (`jq`, keep everything else). Every later phase uses these values.
5. **Detect mode** from `waves`: sequential if empty/missing or every wave has 1 story; parallel if any wave has 2+.
6. **Estimate duration** from `.takt/stats.json` (`stories.bySize.<size>.avg` per story + `overhead.avg`; defaults small=120s, medium=180s, large=300s, overhead=480s). Print as `estimate × 0.8` to `estimate × 1.3`, rounded to 5 min.
7. Print the start line and nothing else:
   ```
   takt started — <branchName> (<N> stories, <mode>, ~15-25 min)
   ```

---

## Phase 2-4: Run the workflow

One Workflow call covers stories, verification and the review gate. The script is deterministic JS; agents do all file and git work. Never read `.takt/scenarios.json` yourself — only the verifier inside the workflow reads it.

Build `args`:

| arg | value |
|-----|-------|
| `projectDir` | absolute project git root |
| `branch` | `sprint.json.branchName` |
| `baseBranch` | `sprint.json.baseRef` (resolvable git ref from Phase 1 step 4; the short `baseBranch` name is only for `gh`) |
| `taktLib` | absolute path of `~/.claude/lib/takt` (expand `~`) |
| `stories` | `jq '[.userStories[] | select(.passes == false)]' sprint.json` (full story objects) |
| `verifyOnly` | omit normally. For a verify-only rerun (every story already `passes: true`) pass `stories: []` plus `verifyOnly: true` — the script skips Phase 2 and goes straight to verification and the gate. `stories: []` without `verifyOnly: true` makes the script throw |
| `waves` | `sprint.json.waves` filtered to incomplete stories, **converted to an array of id arrays** — `[["US-001","US-002"],["US-003"]]`, not the `{wave, stories}` objects sprint.json stores (the script does `w.filter(...)` on each wave); omit if empty; one id per wave when the submodule check fired. Known limitation (2026-09-28): waves with 2+ stories run in Workflow worktrees cut from the HEAD at workflow launch, so a later multi-story wave does not see earlier waves' merges — keep dependent stories in single-story waves, or relaunch the remainder after wave 1 |
| `workerRunner` | `.takt/session.json.worker_runner` |
| `externalCmd` | `.takt/session.json.worker_runner_external_cmd` (or `""`) |
| `finalGate` | `.takt/session.json.final_gate` |
| `maxVerifyCycles` | `3` |
| `maxReviewCycles` | `2` |

Call:

```
Workflow({
  scriptPath: "<absolute ~/.claude/lib/takt>/takt-run.js",
  args: { ...as above... }
})
```

Wait for the task notification. The result is:

```json
{
  "stories": [{ "id": "US-001", "title": "...", "status": "done|blocked", "reason": "...", "files": [], "attempts": 1 }],
  "verification": { "ran": true, "verdict": "PASSED|FAILED", "cycles": 1, "openBugs": ["BUG-002"] },
  "gate": { "ran": true, "verdict": "PASSED|BLOCKED|SKIPPED", "cycles": 1, "openMustFix": ["MF-003"], "suggestionCount": 0 },
  "timing": { "verify": [], "gate": [], "fixes": [], "merges": [], "commits": [] },
  "blocked": []
}
```

`openBugs` and `openMustFix` are id arrays. Details live in `bugs.json` and `review-comments.json` in the project root.

**Resume:** if the workflow is interrupted, re-invoke with the same `scriptPath` + `args` and `resumeFromRunId: "<runId from the launch result>"` — completed stories replay from cache.

**Stop conditions** (no PR, no retro; print the final report with the reason):
- any story `blocked`
- `verification.verdict != "PASSED"` — list the `openBugs` ids, with each entry's description from `bugs.json`
- `gate.verdict == "BLOCKED"` — list the `openMustFix` ids, with each entry's finding from `review-comments.json`

The workflow already committed every story (feature commits), merged worktrees, removed them, and updated `passes` / `startTime` / `endTime` in `sprint.json`. Verify with `git status --short` that only ephemeral files are dirty; if a worktree or `worktree-*` branch is left behind, remove it (`git worktree remove --force <path>`; `git branch -D <name>`).

---

## Phase 4b: Local Validation (project-toggleable, interactive)

Skip silently if `.takt/session.json.local_validation` is `false`. If `true` but `.takt/local-validation.md` is missing, print once and continue:
```
[takt warn] local_validation enabled in .takt/config.json but .takt/local-validation.md is missing — skipping runtime checks.
```

1. Spawn one validation agent:
   ```
   # Local Validation
   ## Project Working Directory
   <absolute path>
   ## Instructions
   Read .takt/local-validation.md for the validation steps. Execute each step. Report pass/fail per step.
   If a step fails, investigate the root cause and attempt to fix it.
   Do NOT modify sprint.json. Do NOT run git commands. Write results to .takt/validation-report.md
   ```
   Config: `subagent_type: "builder"`, `mode: "bypassPermissions"`, `run_in_background: true`. `TaskStop` it when done.
2. Read `.takt/validation-report.md`. Unfixable failures → STOP, report, no PR. Fixes made → `git add` (never ephemeral files) + `git commit -m "fix: local validation"`.
3. Manual check via `AskUserQuestion`:
   - "All good — ship it" → Phase 5
   - "Found issues" → STOP, wait for the user's description, fix, re-validate.

---

## Phase 5: PR Creation

1. `command -v gh` missing → do step 6, then skip to Phase 6.
2. `git push -u origin <branchName>`
3. Body: summary, stories completed, verification result, gate summary, `suggestionCount`, duration. If `review-comments.json` exists, read it and append a section `## Review suggestions (should-fix)` with one line per `SF-*` entry: ``- SF-00n `file:line` — finding``. No `SF-*` entries → omit the section. If `review-comments.json` has a non-empty `follow_ups` list, append a section `## Follow-up ideas` with one line per entry: `- <follow-up>`. Empty or missing list → omit the section.
4. `--draft` if `gate.suggestionCount > 0`.
5. Write the assembled body to `.takt/pr-body.md` with the Write tool (literal data — never interpolate it into a shell command, heredoc or quoted argument), check for an open PR on this branch: `gh pr list --head "<branchName>" --state open --json url --limit 1`. One exists → do not create or comment; use its URL. None → `gh pr create --base "<baseBranch>" --head "<branchName>" --title "feat: <summary>" --body-file .takt/pr-body.md [--draft]` → capture URL. Then `rm -f .takt/pr-body.md` (ephemeral, never committed).
6. **No PR (`gh` missing)** — before Phase 6 cleanup deletes `review-comments.json`, append the same `SF-*` list to the project's TODO file: the first of `TODO.md` or `docs/TODO.md` that exists, else create `TODO.md` in the project root, under `## takt review suggestions — <branchName> — <YYYY-MM-DD>` (skip if there are no `SF-*` entries; also append any `follow_ups` as a `Follow-up ideas` list under the same heading). Not on a stop condition: a stop keeps the files for resume.

---

## Phase 6: Auto-Retro

1. `cp sprint.json .takt/sprint-snapshot.json`
2. Write the Workflow's returned JSON verbatim to `.takt/run-report.json` (you have it in context; a heredoc via Bash is fine).
3. Spawn the retro agent:
   ```
   # Auto-Retro
   ## Project Working Directory
   <absolute path>
   ## Branch
   <branchName>
   ## Instructions
   Read ~/.claude/lib/takt/retro.md for your instructions.
   Read .takt/run-report.json for per-stage timing and story attempts.
   Process workbooks from .takt/workbooks/, generate the retro entry, update CHANGELOG.md, clean up workbooks and .takt/review.diff, commit and push.
   Output a one-line summary.
   ```
   Config: `subagent_type: "general-purpose"`, `model: "sonnet"`, `mode: "bypassPermissions"`, `run_in_background: true`. `TaskStop` it when done; capture the one-line summary.

---

## Phase 7: Completion

1. Duration = earliest story `startTime` → now.
2. Print the final report — the ONLY output after the start line:
   ```
   takt complete — <branchName>
   - Stories: X/Y passed [Z blocked]
   - Verification: PASSED (1 cycle) | FAILED — <n> open bugs (ids)
   - Gate: PASSED (1 cycle) | BLOCKED — <n> open must-fix (ids) | SKIPPED
   - PR: <URL or "skipped">
   - Retro: <one-line summary>
   - Duration: N min
   ```
   On a stop condition, replace `takt complete` with `takt stopped` and add one line per open bug id / must-fix id / blocked story.
3. **Stale artifact safety net** — if the retro ran and any of these still exist, delete them:
   ```bash
   rm -f sprint.json .takt/sprint-snapshot.json .takt/scenarios.json .takt/review.diff .takt/review-base-* .takt/validation-report.md .takt/run-report.json bugs.json review-comments.json
   ```
   Do NOT delete them on a stop condition — the user needs them to resume.

---

## Rules

1. **Never write application code** — you orchestrate only.
2. **Session cwd = project git root** — Workflow worktrees are keyed to it.
3. **Never read `.takt/scenarios.json`** — only the verifier inside the workflow does.
4. **Agents from the roster** — workers `grunt` (simple) / `builder` (complex) / `heavy` (retry); `builder` for worktree merges (workers commit their own stories); verifier and retro `general-purpose` + `sonnet`; gate `skeptic` (Codex relay, Sonnet fallback). Defined in `~/.claude/agents/`, shared with the `/orchestrator` skill.
5. **Ephemeral files are never committed** — `sprint.json`, `bugs.json`, `review-comments.json`, `.takt/workbooks/`, `.takt/scenarios.json`, `.takt/session.json`, `.takt/review.diff`, `.takt/review-base-*`, `.takt/sprint-snapshot.json`, `.takt/validation-report.md`, `.takt/run-report.json`.
6. **Kill agents you spawn directly** — `TaskStop` the validation and retro agents as soon as you have their result. Workflow agents are managed by the Workflow tool.
7. **Never kill tmux panes.**
8. **Silent execution** — print only: any `[takt warn]` lines, the start line, the final report. No phase headers, no narration, no diff commentary.

You are a background process. Work silently. Report when done.
