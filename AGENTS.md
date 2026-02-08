# DuaLoop Agent Instructions

## Overview

DuaLoop is an autonomous AI agent loop that runs Claude Code repeatedly until all PRD items are complete. Each iteration is a fresh Claude Code instance with clean context.

## Commands

```bash
# Run DuaLoop (from your project that has prd.json)
./dualoop.sh [max_iterations]
```

## Key Files

- `dualoop.sh` - The bash loop that spawns fresh Claude Code instances
- `prompt.md` - Instructions given to each Claude Code instance
- `prd.json.example` - Example PRD format
- `agents/verifier.md` - Deep verification agent instructions
- `skills/` - PRD generation, conversion, and TDD workflow skills

## Patterns

- Each iteration spawns a fresh Claude Code instance with clean context
- Memory persists via git history, `progress.txt`, and `prd.json`
- Stories should be small enough to complete in one context window
- Always update AGENTS.md with discovered patterns for future iterations
