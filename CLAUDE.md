# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is takt?

takt is an autonomous AI agent orchestrator with four modes: solo (sequential), team (parallel), debug (bug-fixing), and retro (retrospective). Based on [Geoffrey Huntley's Ralph Wiggum pattern](https://ghuntley.com/ralph/).

Each mode spawns fresh Claude Code instances. Memory persists via:
- **Git history** - commits from previous iterations
- **prd.json** - tracks which stories are `passes: true/false`
- **workbook-US-XXX.md** - per-story implementation notes
- **retro.md** - retrospective entries and active alerts

## Commands

```bash
# Install globally (one-time, from repo)
./install.sh

# Initialize a project
takt init

# Solo mode — sequential execution
takt solo [max_iterations]

# Team mode — parallel execution
takt team

# Debug mode — structured bug fixing
takt debug "description"

# Retro mode — generate retrospective
takt retro

# Check story status
cat prd.json | jq '.userStories[] | {id, title, passes}'
```

## Architecture

### Core Script (`bin/takt.sh`)
Subcommand dispatch to four modes:
- `takt solo` — wraps original loop logic, one story per iteration
- `takt team` — launches Claude Code with team-lead prompt for parallel execution
- `takt debug` — launches Claude Code with debug prompt for structured bug fixing
- `takt retro` — launches Claude Code with retro prompt for retrospective generation

### Key Files (source → installed)
- `bin/takt.sh` → `~/.claude/lib/takt/takt.sh` - Core script
- `lib/prompt.md` → `~/.claude/lib/takt/prompt.md` - Solo agent instructions
- `agents/verifier.md` → `~/.claude/lib/takt/verifier.md` - Deep verification agent
- `lib/team-lead.md` → `~/.claude/lib/takt/team-lead.md` - Team scrum master prompt
- `lib/worker.md` → `~/.claude/lib/takt/worker.md` - Team worker prompt
- `lib/debug.md` → `~/.claude/lib/takt/debug.md` - Debug agent prompt
- `lib/retro.md` → `~/.claude/lib/takt/retro.md` - Retro agent prompt
- `commands/*.md` → `~/.claude/commands/` - Slash commands

### Slash Commands
- `/takt` - Convert PRD to `prd.json` format (with waves and dependsOn for team mode)
- `/takt-prd` - Generate PRDs from feature descriptions
- `/tdd` - Test-Driven Development workflow

### Story Fields in prd.json
- `model`: `"sonnet"` (default) or `"opus"` (for complex multi-file work)
- `verify`: `"inline"` (self-verified) or `"deep"` (independent verification agent)
- `passes`: `false` → `true` when story complete
- `dependsOn`: array of story IDs this story depends on (for team mode wave computation)

### Team Mode: Waves
- `waves` top-level field in prd.json groups stories by dependency
- Wave N+1 doesn't start until Wave N is fully merged
- Workers use git worktrees in `.worktrees/` for isolation

## Running Tests

```bash
bats tests/
```
