# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is takt?

takt is an autonomous AI agent orchestrator that runs natively inside Claude Code. Primary command: `start takt` (auto-detects sequential vs parallel from stories.json). Also supports debug and retro modes. Based on [Geoffrey Huntley's Ralph Wiggum pattern](https://ghuntley.com/ralph/).

There is no bash script or CLI binary. The user says "start takt" in Claude Code, which reads the unified prompt file and spawns autonomous agents using Claude Code's native Task tool.

Each mode spawns fresh Claude Code agent instances. Memory persists via:
- **Git history** - commits from previous iterations
- **stories.json** - tracks which stories are `passes: true/false`
- **.takt/workbooks/workbook-US-XXX.md** - per-story implementation notes (ephemeral)
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

The `/takt` slash command is ONLY for converting PRDs to stories.json. Never route mode commands through it.

**CRITICAL — Agent Type Rule:** When launching any takt mode, the session agent MUST read the corresponding prompt file FIRST (`~/.claude/lib/takt/run.md`, `debug.md`, etc.) and follow its instructions exactly. The prompt file specifies `subagent_type: "general-purpose"` and `model: "sonnet"` for all spawned Tasks. NEVER use custom agent types (e.g. "Seb the boss", TDD agents, or any other named agent). Always `"general-purpose"`.

Slash commands (also in Claude Code):
- `/takt-prd` — generate a PRD from a feature description
- `/takt` — convert a PRD into executable `stories.json`
- `/tdd` — TDD workflow

Install: `./install.sh` (one-time, copies prompts to `~/.claude/`)

## Architecture

### How It Works

1. User says "start takt" in Claude Code
2. The **session agent** reads `~/.claude/lib/takt/run.md`
3. The session agent reads `stories.json`, detects mode (sequential vs parallel from waves), prints a story matrix
4. The session agent orchestrates directly — spawning fresh worker Tasks for each story (Ralph Wiggum pattern)
5. Workers run autonomously with `mode: "bypassPermissions"` and `run_in_background: true`
6. The session agent monitors progress via `TaskOutput` + reading `stories.json`, printing one-liner status updates
7. Stories are updated in `stories.json` as they complete

### Key Files (source -> installed)
- `lib/run.md` -> `~/.claude/lib/takt/run.md` - Unified orchestrator prompt (replaces solo.md + team-lead.md)
- `agents/verifier.md` -> `~/.claude/lib/takt/verifier.md` - Deep verification agent
- `lib/worker.md` -> `~/.claude/lib/takt/worker.md` - Worker prompt
- `lib/debug.md` -> `~/.claude/lib/takt/debug.md` - Debug agent prompt
- `lib/retro.md` -> `~/.claude/lib/takt/retro.md` - Retro agent prompt
- `commands/*.md` -> `~/.claude/commands/` - Slash commands

### Artifacts
- `stories.json` — project root, tracks stories and their status
- `.takt/workbooks/workbook-US-XXX.md` — ephemeral per-story notes, deleted after retro
- `.takt/retro.md` — persistent retrospective entries and alerts

### Slash Commands
- `/takt` - Convert PRD to `stories.json` format (with waves and dependsOn for team mode)
- `/takt-prd` - Generate PRDs from feature descriptions
- `/tdd` - Test-Driven Development workflow

### Story Fields in stories.json
- `verify`: `"inline"` (self-verified) or `"deep"` (independent verification agent)
- `passes`: `false` -> `true` when story complete
- `dependsOn`: array of story IDs this story depends on (for team mode wave computation)

## Markdown File Hygiene

Keep the repo lean. Every markdown file must justify its presence. When creating or encountering `.md` files, apply this rule:

- **Completed PRDs, roadmaps, TODOs, planning docs** — archive or delete once implemented. Git history is the permanent record.
- **Keep only what's active**: prompt files (`lib/`, `commands/`, `agents/`), `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `future-improvements.md`, and `.takt/retro.md`.

If an `.md` file has served its purpose, remove it. Don't let stale docs accumulate.

### Team Mode: Waves
- `waves` top-level field in stories.json groups stories by dependency
- Wave N+1 doesn't start until Wave N is fully merged
- Workers use Claude Code's native `isolation: "worktree"` feature for isolation (platform-managed, no manual worktree commands needed)
