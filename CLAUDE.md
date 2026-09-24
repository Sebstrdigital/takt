# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is takt?

takt is a sprint discipline layer for Claude Code: stories with acceptance criteria, hidden BDD scenarios verified by an independent agent, an Opus review gate, and compounding retros. Primary command: `start takt`. Also supports debug and retro modes. Based on [Geoffrey Huntley's Ralph Wiggum pattern](https://ghuntley.com/ralph/).

There is no bash script or CLI binary. The user says "start takt" in Claude Code. The session agent reads `run.md`, prepares the run, and hands stories / verification / review gate to the `takt-run` Workflow script (`lib/takt-run.js`). Claude Code's native Agent and Workflow tools provide the orchestration mechanics; takt provides the process and state model.

Memory persists via:
- **Git history** - commits from previous iterations
- **sprint.json** - tracks which stories are `passes: true/false` (ephemeral, never committed)
- **.takt/workbooks/workbook-US-XXX.md** - per-story implementation notes (ephemeral)
- **.takt/stats.json** - per-project timing stats for ETA estimation (persistent)
- **.takt/retro.md** - retrospective entries and active alerts

## Usage

Say these phrases in Claude Code (they are not terminal commands):

- **start takt** — run stories (reads `~/.claude/lib/takt/run.md`)
- **takt debug** — structured bug-fixing discipline (reads `~/.claude/lib/takt/debug.md`)
- **takt retro** — generate retrospective from workbooks (reads `~/.claude/lib/takt/retro.md`)

Deprecated aliases (also read `run.md`): `takt solo`, `takt team`.

### Command Routing (IMPORTANT)

These phrases trigger prompt file reads, NOT slash commands:

| User says | Session agent reads | NOT |
|-----------|-------------------|-----|
| `start takt` | `~/.claude/lib/takt/run.md` | /takt |
| `takt debug` | `~/.claude/lib/takt/debug.md` | /takt |
| `takt retro` | `~/.claude/lib/takt/retro.md` | /takt |

The `/sprint` slash command is ONLY for converting Feature docs to sprint.json. Never route mode commands through it.

**CRITICAL — Execution Rule:** On `start takt` the session agent MUST read `~/.claude/lib/takt/run.md` first and execute it itself. Never spawn the orchestrator as a sub-agent, never echo the phrase back, never ask for confirmation. Story execution happens inside the Workflow tool (`scriptPath: ~/.claude/lib/takt/takt-run.js`), which is an approved use of Workflow — no separate opt-in is needed.

**Agent roster:** takt uses the shared named agents in `~/.claude/agents/` (source: `claude-tools/agents/`): `grunt` (haiku) for `complexity: "simple"` stories, `builder` (sonnet) for complex, `heavy` (opus) for the single retry, `grunt`/`builder` for the merge and commit stages. Verifier and retro use `general-purpose` + `sonnet`; the review gate uses `general-purpose` + `opus`. Never invent other agent types.

Slash commands: `/takt`, `/epic`, `/feature`, `/sprint`. Install: `./install.sh`.

## Architecture

### How It Works

1. User says "start takt"
2. Session agent reads `~/.claude/lib/takt/run.md`
3. Phase 0-1: config, tool probes, feature branch, ETA from `.takt/stats.json`, retro alerts, one start line
4. Phase 2-4: one `Workflow` call running `takt-run.js` — waves of fresh workers (parallel waves in per-story worktrees), a merge stage that commits/merges/removes worktrees and updates `sprint.json`, the hidden-scenario verifier with a verify-fix loop, the 4-pass Opus gate with a review-fix loop. Deterministic JS control flow, resumable via `resumeFromRunId`.
5. Phase 4b-7: local validation (interactive), PR, auto-retro, final report — session agent
6. Output: start line + final report only

### Key Files (source -> installed)
- `lib/run.md` -> `~/.claude/lib/takt/run.md` - Orchestrator prompt (session agent)
- `lib/takt-run.js` -> `~/.claude/lib/takt/takt-run.js` - Workflow script: stories, verify, gate
- `lib/worker.md` -> `~/.claude/lib/takt/worker.md` - Worker prompt
- `agents/verifier.md` -> `~/.claude/lib/takt/verifier.md` - Scenario verification agent
- `lib/final-gate.md` -> `~/.claude/lib/takt/final-gate.md` - Review gate (conventions + SRE + security + adversary)
- `lib/tooling.md` -> `~/.claude/lib/takt/tooling.md` - Optional tooling config (jCodeMunch + context-mode)
- `lib/init.md` -> `~/.claude/lib/takt/init.md` - First-run config prompts
- `lib/debug.md` -> `~/.claude/lib/takt/debug.md` - Debug agent prompt
- `lib/retro.md` -> `~/.claude/lib/takt/retro.md` - Retro agent prompt
- `commands/*.md` -> `~/.claude/commands/` - Slash commands

### Artifacts
- `sprint.json` — project root, stories and status (ephemeral, never committed, deleted by retro)
- `.takt/workbooks/workbook-US-XXX.md` — ephemeral per-story notes, deleted after retro
- `.takt/stats.json` — per-project timing stats (persistent)
- `.takt/retro.md` — retrospective entries and alerts (persistent)
- `.takt/config.json` — project toggles (persistent, committed)

### Story Fields in sprint.json
- `passes`: `false` -> `true` when story merged
- `dependsOn`: story IDs this story depends on; a blocked dependency blocks the story
- `complexity`: `"simple"` (grunt/haiku) or `"complex"` (builder/sonnet)
- `size`: `small|medium|large` for ETA stats
- `waves`: top-level; each wave with 2+ stories runs in parallel worktrees, one story per wave runs in place

## Development Workflow

### install.sh Sync Rule

`install.sh` copies source files from this repo to `~/.claude/`. If you modify any file under `lib/`, `commands/`, or `agents/`, the installed prompts drift from source until you re-run it.

**HARD RULE:** When you (or Claude Code) modify any file in `lib/`, `commands/`, or `agents/`, Claude Code MUST ask the user before committing or pushing:

> "You've modified prompt source files. Should I run `./install.sh` to sync the installed prompts before committing?"

Do not skip this prompt. Stale installed prompts are silent bugs.

### Checking the workflow script

`lib/takt-run.js` is a Workflow script: top-level `await`/`return`, no Node APIs, no `Date.now()`. Syntax-check it as an async function body:

```bash
node -e 'const s=require("fs").readFileSync("lib/takt-run.js","utf8").replace(/^export const meta/m,"const meta");new (Object.getPrototypeOf(async function(){}).constructor)("args","agent","parallel","pipeline","phase","log","budget","workflow",s);console.log("ok")'
```

### Shipping Checklist

Before tagging a release or merging a significant change to `main`:

- [ ] Run `./install.sh` — verify it completes without errors
- [ ] Syntax-check `lib/takt-run.js` (above)
- [ ] Test in a real project: say "start takt" with a valid `sprint.json`
- [ ] Verify all phases complete: workflow returns, PR is created, retro runs
- [ ] Check `.takt/retro.md` for any active alerts that block release
- [ ] Update `CHANGELOG.md` with the change summary

## Markdown File Hygiene

Keep the repo lean. Every markdown file must justify its presence.

- **Completed PRDs, roadmaps, TODOs, planning docs** — archive or delete once implemented. Git history is the permanent record.
- **Keep only what's active**: prompt files (`lib/`, `commands/`, `agents/`), `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `docs/future-improvements.md`, and `.takt/retro.md`.

### Model Matrix

| Role | Agent | Model | When |
|------|-------|-------|------|
| Orchestrator (session agent) | self | session model | Always |
| Worker (simple) | `grunt` | haiku | Per story, `complexity: "simple"` |
| Worker (complex) | `builder` | sonnet | Per story |
| Worker retry | `heavy` | opus | Once per failed story |
| Merge / commit stage | `builder` (worktrees) / `grunt` (in place) | sonnet / haiku | Per wave, per fix cycle |
| Verifier | `general-purpose` | sonnet | Per verify cycle (max 3) |
| Bug-fix / review-fix worker | `builder` | sonnet | Per bug / must-fix |
| Review gate | `general-purpose` | opus | Per review cycle (max 2) |
| Local validation | `builder` | sonnet | Per run, if enabled |
| Retro agent | `general-purpose` | sonnet | Per run |

### Worktrees

- Workflow worktrees are created under `<repo>/.claude/worktrees/` on branches `worktree-<runId>-<n>`, from the session repo's HEAD.
- They are NOT merged back automatically. The merge stage inside `takt-run.js` commits, merges (`--no-ff`, fewest-overlap-first), removes the worktree and deletes the branch.
- The session must run from the project git root. Submodule repos and cross-repo work fall back to one story per wave (in-place edits).
