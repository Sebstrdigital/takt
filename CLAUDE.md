# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is takt?

takt is an autonomous AI agent orchestrator that runs natively inside Claude Code. Four modes: solo (sequential), team (parallel), debug (bug-fixing), and retro (retrospective). Based on [Geoffrey Huntley's Ralph Wiggum pattern](https://ghuntley.com/ralph/).

There is no bash script or CLI binary. The user says "takt solo" or "takt team" in Claude Code, which reads the appropriate prompt file and spawns autonomous agents using Claude Code's native Task and TeamCreate tools.

Each mode spawns fresh Claude Code agent instances. Memory persists via:
- **Git history** - commits from previous iterations
- **prd.json** - tracks which stories are `passes: true/false`
- **.takt/workbooks/workbook-US-XXX.md** - per-story implementation notes (ephemeral)
- **.takt/retro.md** - retrospective entries and active alerts

## Usage

Say these phrases in Claude Code (they are not terminal commands):

- **takt solo** — run stories sequentially (reads `~/.claude/lib/takt/solo.md`)
- **takt team** — run stories in parallel with multiple agents (reads `~/.claude/lib/takt/team-lead.md`)
- **takt debug** — structured bug-fixing discipline (reads `~/.claude/lib/takt/debug.md`)
- **takt retro** — generate retrospective from workbooks (reads `~/.claude/lib/takt/retro.md`)

Slash commands (also in Claude Code):
- `/takt-prd` — generate a PRD from a feature description
- `/takt` — convert a PRD into executable `prd.json`
- `/tdd` — TDD workflow

Install: `./install.sh` (one-time, copies prompts to `~/.claude/`)

## Architecture

### How It Works

1. User says "takt solo" (or team/debug/retro) in Claude Code
2. Claude Code reads the corresponding prompt from `~/.claude/lib/takt/`
3. The prompt instructs Claude Code to read `prd.json` and spawn worker agents via Task/TeamCreate
4. Each worker gets a fresh context (Ralph Wiggum pattern) and implements one story
5. The orchestrator updates `prd.json` as stories complete

### Key Files (source -> installed)
- `lib/solo.md` -> `~/.claude/lib/takt/solo.md` - Solo orchestrator prompt
- `lib/prompt.md` -> `~/.claude/lib/takt/prompt.md` - Solo worker instructions
- `agents/verifier.md` -> `~/.claude/lib/takt/verifier.md` - Deep verification agent
- `lib/team-lead.md` -> `~/.claude/lib/takt/team-lead.md` - Team scrum master prompt
- `lib/worker.md` -> `~/.claude/lib/takt/worker.md` - Team worker prompt
- `lib/debug.md` -> `~/.claude/lib/takt/debug.md` - Debug agent prompt
- `lib/retro.md` -> `~/.claude/lib/takt/retro.md` - Retro agent prompt
- `commands/*.md` -> `~/.claude/commands/` - Slash commands

### Artifacts
- `prd.json` — project root, tracks stories and their status
- `.takt/workbooks/workbook-US-XXX.md` — ephemeral per-story notes, deleted after retro
- `.takt/retro.md` — persistent retrospective entries and alerts

### Slash Commands
- `/takt` - Convert PRD to `prd.json` format (with waves and dependsOn for team mode)
- `/takt-prd` - Generate PRDs from feature descriptions
- `/tdd` - Test-Driven Development workflow

### Story Fields in prd.json
- `model`: `"sonnet"` (default) or `"opus"` (for complex multi-file work)
- `verify`: `"inline"` (self-verified) or `"deep"` (independent verification agent)
- `passes`: `false` -> `true` when story complete
- `dependsOn`: array of story IDs this story depends on (for team mode wave computation)

### Team Mode: Waves
- `waves` top-level field in prd.json groups stories by dependency
- Wave N+1 doesn't start until Wave N is fully merged
- Workers use git worktrees in `.worktrees/` for isolation
