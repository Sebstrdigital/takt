# DuaLoop

An autonomous AI agent loop that runs [Claude Code](https://claude.com/claude-code) repeatedly until all PRD items are complete. Each iteration is a fresh Claude Code instance with clean context.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

## How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                           PLANNING PHASE                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  You + Claude: Discuss feature, analyze codebase, plan architecture │
│                                                                      │
│  You: "Create the PRD"                                              │
│       ↓                                                              │
│  Claude: Creates tasks/prd-feature-name.md                          │
│       ↓                                                              │
│  ⏸️ "Convert to prd.json?" ──────────────────────── Review PRD       │
│       ↓ Yes                                                          │
│  Claude: Creates prd.json (includes branchName: dua/feature-name)   │
│       ↓                                                              │
│  ⏸️ "Start the loop?" ───────────────────────────── Review stories   │
│       ↓ Yes                                                          │
└───────┼─────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      AUTONOMOUS LOOP                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ CREATE BRANCH: dua/feature-name (once, from prd.json)          │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                              │                                       │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    STORY ITERATION                              │ │
│  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐           │ │
│  │  │ Pick next   │──▶│ Implement   │──▶│ Run checks  │           │ │
│  │  │ story from  │   │ with TDD    │   │ (typecheck, │           │ │
│  │  │ prd.json    │   │             │   │ lint, test) │           │ │
│  │  └─────────────┘   └─────────────┘   └──────┬──────┘           │ │
│  │                                             │                   │ │
│  │                                             ▼                   │ │
│  │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐           │ │
│  │  │ Log to      │◀──│ Mark story  │◀──│ Commit      │           │ │
│  │  │ progress.txt│   │ passes:true │   │ changes     │           │ │
│  │  └──────┬──────┘   └─────────────┘   └─────────────┘           │ │
│  │         │                                                       │ │
│  │         ▼                                                       │ │
│  │  ┌─────────────┐  Yes                                          │ │
│  │  │More stories?│────────────────────────────────────┐          │ │
│  │  │passes:false │                                    │          │ │
│  │  └──────┬──────┘                                    │          │ │
│  │         │ No                                   Back to Pick     │ │
│  └─────────┼──────────────────────────────────────────┼───────────┘ │
│            │                                          │             │
│            ▼                                          │             │
│  ┌─────────────────┐                                  │             │
│  │ Deep verify?    │ (for stories with verify: deep)  │             │
│  │ Run verifier    │                                  │             │
│  │ agent           │                                  │             │
│  └────────┬────────┘                                  │             │
│           │                                           │             │
│           ▼                                           │             │
│  ┌─────────────────┐  No                              │             │
│  │ All verified?   │──────────────────────────────────┘             │
│  └────────┬────────┘  (mark failed stories passes:false)            │
│           │ Yes                                                      │
│           ▼                                                          │
│  ┌─────────────────┐                                                │
│  │ Archive PRD     │──▶ tasks/archive/YYYY-MM-DD-feature/           │
│  └────────┬────────┘                                                │
│           │                                                          │
└───────────┼──────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  ⏸️ COMPLETE - What would you like to do?                            │
│                                                                      │
│     1) Merge to main                                                │
│     2) Create Pull Request                                          │
│     3) Stay on branch                                               │
└─────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [Claude Code CLI](https://claude.com/claude-code) installed and authenticated
- `jq` installed (`brew install jq` on macOS)
- `bats-core` for running tests (`brew install bats-core` on macOS)
- A git repository for your project
- (For UI testing) Google Chrome with "Claude in Chrome" extension v1.0.36+

## Quick Start

```bash
# 1. Clone DuaLoop (one-time)
git clone https://github.com/duadigital/DuaLoop.git ~/tools/dualoop

# 2. Install globally (one-time)
cd ~/tools/dualoop && ./install.sh

# 3. Initialize a project
cd ~/my-project
dualoop init

# 4. Start Claude Code
claude
```

Then in Claude Code:
```
You: "I want to add a user settings page with dark mode toggle"
Claude: [discusses, asks clarifying questions, plans architecture]

You: "Create the PRD"
Claude: [creates tasks/prd-user-settings.md]
       "PRD created! Convert to prd.json?"

You: "Yes"
Claude: [creates prd.json with stories]
       "prd.json ready with 4 stories. Start the loop?"

You: "Yes"
Claude: [runs dualoop]
       - Creates branch: dua/user-settings
       - Implements all stories autonomously
       - "Complete! Merge to main, create PR, or stay on branch?"

You: "Create PR"
Claude: [pushes and creates PR]
```

## What Gets Installed

```
~/.local/bin/dualoop            # Symlink → dualoop.sh
~/.claude/commands/dua-prd.md   # Symlink → /dua-prd skill
~/.claude/commands/dua.md       # Symlink → /dua skill
~/.claude/commands/tdd.md       # Symlink → /tdd skill
```

## Per-Project Files

After `dualoop init`, your project gets:

```
my-project/
├── prd.json           # Active user stories
├── progress.txt       # Iteration learnings
└── tasks/
    └── archive/       # Completed PRDs
```

## prd.json Structure

```json
{
  "project": "MyApp",
  "branchName": "dua/feature-name",
  "description": "Feature description",
  "userStories": [
    {
      "id": "US-001",
      "title": "Story title",
      "description": "As a user, I want...",
      "acceptanceCriteria": ["Criterion 1", "Typecheck passes"],
      "priority": 1,
      "passes": false,
      "model": "sonnet",
      "verify": "inline"
    }
  ]
}
```

### Story Fields

| Field | Values | Description |
|-------|--------|-------------|
| `model` | `"sonnet"` (default), `"opus"` | Which model implements this story. Use opus for complex multi-file work. |
| `verify` | `"inline"` (default), `"deep"` | Inline = self-verified. Deep = independent verification agent after completion. |
| `passes` | `false` → `true` | Updated by DuaLoop when story is complete |

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new Claude Code instance** with clean context. Memory persists via:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Stories

Stories must fit in a single context window. If a story is too big, the iteration will fail mid-implementation.

**Right-sized:**
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic

**Too big (split these):**
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### TDD Workflow

Every story is implemented using Test-Driven Development:
1. **RED** - Write a failing test
2. **GREEN** - Write minimal code to pass
3. **REFACTOR** - Clean up while tests stay green

### Completion & Archiving

When DuaLoop completes all stories:
1. Moves the source PRD file (`tasks/prd-feature-name.md`) to `tasks/archive/YYYY-MM-DD-feature-name/`
2. Resets `prd.json` for the next feature (ready for conversion from a new PRD)
3. Prompts you to:
   - **Merge to main** - merges the feature branch and optionally deletes it
   - **Create PR** - pushes and creates a pull request (requires `gh` CLI)
   - **Stay on branch** - do nothing, merge/PR later manually

Note: `progress.txt` is cumulative learnings that persist across features - it is never reset or archived.

## Debugging

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
```

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://claude.com/claude-code)
