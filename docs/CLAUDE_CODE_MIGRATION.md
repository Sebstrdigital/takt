# DuaLoop Migration to Claude Code - COMPLETE

**Migration Status:** ✅ COMPLETE (January 11, 2026)
**Confidence Level:** 100% - Fully tested and verified

---

## Summary

DuaLoop has been successfully migrated from Ampcode to Claude Code. All core functionality works:

- ✅ Autonomous loop execution
- ✅ Git commits and PRD updates
- ✅ progress.txt logging
- ✅ Chrome browser integration for UI testing
- ✅ Completion signal detection (`<promise>COMPLETE</promise>`)

---

## What is DuaLoop?

**DuaLoop** is an autonomous AI agent loop system that implements features from a PRD (Product Requirements Document) without human intervention between iterations. It's based on [Geoffrey Huntley's Ralph Wiggum pattern](https://ghuntley.com/ralph/).

### Core Concept

```
PRD → User Stories (prd.json) → DuaLoop Loop → Completed Feature
```

Each iteration:
1. Spawns a **fresh Claude Code instance** with clean context
2. Picks the highest-priority incomplete story
3. Implements it, runs quality checks
4. Commits if passing, updates `prd.json` to mark complete
5. Logs learnings to `progress.txt`
6. Repeats until all stories pass

### Memory Persistence Between Iterations

Since each iteration has no memory, state persists via:
- **Git history** - commits from previous iterations
- **prd.json** - tracks which stories are `passes: true/false`
- **progress.txt** - append-only log of learnings (CRITICAL - be thorough!)
- **AGENTS.md** - reusable patterns for future iterations

---

## Migration Changes Made

### 1. dualoop.sh (formerly ralph.sh)

```bash
# Command changed from:
OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true

# To:
OUTPUT=$(claude -p "$(cat "$SCRIPT_DIR/prompt.md")" --dangerously-skip-permissions --chrome 2>&1 | tee /dev/stderr) || true
```

Key changes:
- `amp` → `claude`
- Added `-p` flag for print mode (non-interactive)
- `--dangerously-allow-all` → `--dangerously-skip-permissions`
- Added `--chrome` flag for browser testing

### 2. prompt.md

- Removed `$AMP_CURRENT_THREAD_ID` thread URL reference
- Removed `read_thread` tool reference
- Updated `dev-browser` skill → Chrome integration instructions

### 3. Documentation

- README.md - Updated all Amp references to Claude Code
- AGENTS.md - Updated terminology
- flowchart/src/App.tsx - Updated UI labels

---

## Chrome Browser Integration

Claude Code has official Chrome integration that replaces Ampcode's `dev-browser` skill.

### Prerequisites

| Component | Requirement |
|-----------|-------------|
| Claude Code CLI | v2.0.73 or higher |
| Chrome Extension | "Claude in Chrome" v1.0.36+ |
| Browser | Google Chrome only |
| Claude Plan | Pro, Team, or Enterprise |

### Setup

```bash
# Ensure Chrome is open with extension installed
# Run DuaLoop - Chrome flag is already included
./dualoop.sh
```

### Capabilities

- Navigate pages, click, type, fill forms
- Read console logs and network requests
- Record GIFs of interactions
- Access authenticated sites

---

## Key Differences from Ampcode

| Feature | Ampcode | Claude Code |
|---------|---------|-------------|
| CLI command | `amp` | `claude -p` |
| Permissions flag | `--dangerously-allow-all` | `--dangerously-skip-permissions` |
| Browser testing | `dev-browser` skill | `--chrome` flag + extension |
| Thread memory | `read_thread` tool | None (use progress.txt) |
| Auto-handoff | Yes (context: 90) | No - keep stories small |

---

## Important: Story Sizing

**Claude Code has no auto-handoff.** If a story exceeds the context window, it will fail mid-implementation.

Keep stories small:
- ✅ Add a database column and migration
- ✅ Add a UI component to an existing page
- ✅ Update a server action with new logic
- ❌ "Build the entire dashboard"
- ❌ "Add authentication"

---

## Important: progress.txt Quality

Since there's no `read_thread` fallback, progress.txt entries must be comprehensive.

**Good entry:**
```markdown
## 2026-01-11 14:30 - US-002
- Added PriorityBadge component to src/components/tasks/TaskCard.tsx
- Used existing Badge component with color variants
- **Learnings:**
  - TaskCard expects non-null props; added default priority='medium'
  - Badge uses `variant` prop, not `color`
```

**Bad entry:**
```markdown
## 2026-01-11 - US-002
- Added the component
- Works now
```

---

## Test Results

### Basic Loop Test (January 11, 2026)
- 3 stories completed in 3 iterations
- Git commits created correctly
- PRD updates working
- progress.txt logging working

### Chrome Integration Test (January 11, 2026)
- 3 stories completed in 2 iterations
- HTML page created and verified in Chrome
- Button click interaction tested
- DOM state changes verified

---

## Optional: claude-mem (Future Enhancement)

claude-mem is a memory plugin that can provide semantic search across iterations.

**Current Status:** Installed but not active in DuaLoop

**Limitation:** claude-mem hooks are optimized for interactive sessions. In print mode (`-p`), observation capture is limited.

**To enable in future:**
1. Ensure bun is installed: `curl -fsSL https://bun.sh/install | bash`
2. Install plugin: `claude plugin install claude-mem`
3. Add to dualoop.sh before the loop:
```bash
export PATH="$HOME/.bun/bin:$PATH"
CLAUDE_MEM_PLUGIN="$HOME/.claude/plugins/cache/thedotmack/claude-mem"
if [ -d "$CLAUDE_MEM_PLUGIN" ]; then
  CLAUDE_MEM_VERSION=$(ls "$CLAUDE_MEM_PLUGIN" | head -1)
  bun "$CLAUDE_MEM_PLUGIN/$CLAUDE_MEM_VERSION/scripts/worker-service.cjs" start
fi
```

For now, progress.txt + git history provide sufficient memory between iterations.

---

## Quick Reference

### Run DuaLoop
```bash
./dualoop.sh [max_iterations]  # default: 10
```

### Check Story Status
```bash
cat prd.json | jq '.userStories[] | {id, title, passes}'
```

### View Progress
```bash
cat progress.txt
```

### View Git History
```bash
git log --oneline -10
```

---

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://claude.com/claude-code)
- [Claude Code Chrome integration](https://code.claude.com/docs/en/chrome)
