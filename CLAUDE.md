# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is takt?

takt is an autonomous AI agent orchestrator that runs natively inside Claude Code. Primary command: `start takt` (auto-detects sequential vs parallel from sprint.json). Also supports debug and retro modes. Based on [Geoffrey Huntley's Ralph Wiggum pattern](https://ghuntley.com/ralph/).

There is no bash script or CLI binary. The user says "start takt" in Claude Code, which reads the unified prompt file and spawns autonomous agents using Claude Code's native Task tool.

Each mode spawns fresh Claude Code agent instances. Memory persists via:
- **Git history** - commits from previous iterations
- **sprint.json** - tracks which stories are `passes: true/false` (ephemeral, never committed)
- **.takt/workbooks/workbook-US-XXX.md** - per-story implementation notes (ephemeral)
- **.takt/stats.json** - per-project timing stats for ETA estimation (persistent)
- **.takt/retro.md** - retrospective entries and active alerts

## Usage

Say these phrases in Claude Code (they are not terminal commands):

- **start takt** — run stories (reads `~/.claude/lib/takt/run.md`, auto-detects sequential vs parallel from waves)
- **takt debug** — structured bug-fixing discipline (reads `~/.claude/lib/takt/debug.md`)
- **takt retro** — generate retrospective from workbooks (reads `~/.claude/lib/takt/retro.md`)

Deprecated aliases (also read `run.md`):
- `takt solo` — same as `start takt`
- `takt team` — same as `start takt`

### Command Routing (IMPORTANT)

These phrases trigger prompt file reads, NOT slash commands:

| User says | Session agent reads | NOT |
|-----------|-------------------|-----|
| `start takt` | `~/.claude/lib/takt/run.md` | /takt |
| `takt solo` (deprecated) | `~/.claude/lib/takt/run.md` | /takt |
| `takt team` (deprecated) | `~/.claude/lib/takt/run.md` | /takt |
| `takt debug` | `~/.claude/lib/takt/debug.md` | /takt |
| `takt retro` | `~/.claude/lib/takt/retro.md` | /takt |

The `/sprint` slash command is ONLY for converting Feature docs to sprint.json. Never route mode commands through it.

**CRITICAL — Agent Type Rule:** When launching any takt mode, the session agent MUST read the corresponding prompt file FIRST (`~/.claude/lib/takt/run.md`, `debug.md`, etc.) and follow its instructions exactly. The prompt file specifies `subagent_type: "general-purpose"` for all spawned Tasks. Workers use `model: "haiku"` or `model: "sonnet"` depending on the story's `complexity` field; all other agents (verifier, reviewer, etc.) use `model: "sonnet"`. NEVER use custom agent types (e.g. "Seb the boss", TDD agents, or any other named agent). Always `"general-purpose"`.

Slash commands (also in Claude Code):
- `/feature` — generate a Feature doc from a feature description
- `/sprint` — convert a Feature doc into executable `sprint.json`

Install: `./install.sh` (one-time, copies prompts to `~/.claude/`)

## Architecture

### How It Works

1. User says "start takt" in Claude Code
2. The **session agent** reads `~/.claude/lib/takt/run.md`
3. The session agent reads `sprint.json`, detects mode (sequential vs parallel from waves), estimates duration from `.takt/stats.json`, prints a single start line with ETA
4. The session agent orchestrates silently — spawning fresh worker Tasks for each story (Ralph Wiggum pattern)
5. Workers run autonomously with `mode: "bypassPermissions"` and `run_in_background: true`
6. No intermediate output — the orchestrator works silently until all phases complete
7. Final report: stories passed, PR URL, retro summary, total duration

### Key Files (source -> installed)
- `lib/run.md` -> `~/.claude/lib/takt/run.md` - Unified orchestrator prompt (replaces solo.md + team-lead.md)
- `agents/verifier.md` -> `~/.claude/lib/takt/verifier.md` - Deep verification agent
- `lib/worker.md` -> `~/.claude/lib/takt/worker.md` - Worker prompt
- `lib/debug.md` -> `~/.claude/lib/takt/debug.md` - Debug agent prompt
- `lib/retro.md` -> `~/.claude/lib/takt/retro.md` - Retro agent prompt
- `commands/*.md` -> `~/.claude/commands/` - Slash commands

### Artifacts
- `sprint.json` — project root, tracks stories and their status (ephemeral, never committed, deleted by retro)
- `.takt/workbooks/workbook-US-XXX.md` — ephemeral per-story notes, deleted after retro
- `.takt/stats.json` — per-project timing stats for ETA estimation (persistent across runs)
- `.takt/retro.md` — persistent retrospective entries and alerts

### Slash Commands
- `/sprint` - Convert Feature doc to `sprint.json` format (with waves and dependsOn for team mode)
- `/feature` - Generate Feature docs from feature descriptions

### Story Fields in sprint.json
- `passes`: `false` -> `true` when story complete
- `dependsOn`: array of story IDs this story depends on (for team mode wave computation)
- `complexity`: `"simple"` or `"complex"` — controls worker model selection. Simple stories use Haiku; complex stories use Sonnet. All other agents (verifier, reviewer, retro, debug, bug-fix workers) use Sonnet.

## Development Workflow

### install.sh Sync Rule

`install.sh` copies source files from this repo to `~/.claude/`. If you modify any file under `lib/`, `commands/`, or `agents/`, the installed prompts will drift from source until you re-run it.

**HARD RULE:** When you (or Claude Code) modify any file in `lib/`, `commands/`, or `agents/`, Claude Code MUST ask the user before committing or pushing:

> "You've modified prompt source files. Should I run `./install.sh` to sync the installed prompts before committing?"

Do not skip this prompt. Stale installed prompts are silent bugs.

### Shipping Checklist

Before tagging a release or merging a significant change to `main`:

- [ ] Run `./install.sh` — verify it completes without errors
- [ ] Test in a real project: say "start takt" with a valid `sprint.json`
- [ ] Verify all phases complete: workers finish, verifier runs, reviewer runs, PR is created
- [ ] Check `.takt/retro.md` for any active alerts that block release
- [ ] Update `CHANGELOG.md` with the change summary

## Markdown File Hygiene

Keep the repo lean. Every markdown file must justify its presence. When creating or encountering `.md` files, apply this rule:

- **Completed PRDs, roadmaps, TODOs, planning docs** — archive or delete once implemented. Git history is the permanent record.
- **Keep only what's active**: prompt files (`lib/`, `commands/`, `agents/`), `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `future-improvements.md`, and `.takt/retro.md`.

If an `.md` file has served its purpose, remove it. Don't let stale docs accumulate.

### Model Matrix

| Role | Model | When |
|------|-------|------|
| Orchestrator (session agent) | sonnet | Always |
| Worker (complex) | sonnet | Per story |
| Worker (simple) | haiku | Per story, complexity: "simple" |
| Verifier | sonnet | Per run, after all stories pass |
| Reviewer | sonnet | Per run, after verification |
| Bug-fix worker | sonnet | Per bug, in verify-fix loop |
| Retro agent | sonnet | Per run, end of sprint |

### Team Mode: Waves
- `waves` top-level field in sprint.json groups stories by dependency
- Wave N+1 doesn't start until Wave N is fully merged
- Workers use Claude Code's native `isolation: "worktree"` feature for isolation (platform-managed, no manual worktree commands needed)
