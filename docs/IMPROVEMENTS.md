# DuaLoop Improvements

Future enhancements for the DuaLoop autonomous agent system.

---

## 1. Auto-Initialize AGENTS.md on First Run

**Status:** ✅ Implemented (in init.sh)

### Problem

When DuaLoop runs on a new project for the first time, there's no AGENTS.md file to provide context about the codebase. This means:
- First iterations have no context about project conventions
- Patterns must be discovered from scratch
- Early iterations may make mistakes that could have been avoided

### Proposed Solution

Add a pre-step to `dualoop.sh` that checks for an AGENTS.md file at the project root before starting the main loop.

**Flow:**

```
./dualoop.sh
    │
    ▼
┌─────────────────────────────┐
│ Check for AGENTS.md in root │
└─────────────────────────────┘
    │
    ├── Found → Continue to main loop
    │
    └── Not found → Interactive setup
            │
            ▼
    ┌───────────────────────────────────┐
    │ "No AGENTS.md found. Would you    │
    │  like to create one?"             │
    │                                   │
    │  [A] Analyze project & generate   │
    │  [B] Create minimal template      │
    │  [C] Skip for now                 │
    └───────────────────────────────────┘
            │
            ▼
    (If A) Claude analyzes project structure,
           tech stack, existing patterns,
           and generates comprehensive AGENTS.md
            │
            ▼
    Continue to main DuaLoop loop
```

### Implementation Ideas

#### Option A: Analyze Project & Generate

Claude would:
1. Scan project structure (`find` or `tree`)
2. Identify tech stack (package.json, requirements.txt, Cargo.toml, etc.)
3. Read key config files (tsconfig, eslint, prettier, etc.)
4. Sample a few source files to understand patterns
5. Generate AGENTS.md with:
   - Project overview
   - Tech stack summary
   - Build/test commands
   - Directory structure explanation
   - Detected conventions

#### Option B: Create Minimal Template

Generate a basic AGENTS.md template:
```markdown
# Project Name

## Overview
[Brief description of the project]

## Tech Stack
- [List technologies]

## Commands
- `npm install` - Install dependencies
- `npm run dev` - Start development server
- `npm test` - Run tests

## Conventions
- [Add conventions as they are discovered]

## Gotchas
- [Add gotchas as they are discovered]
```

#### Option C: Skip

Continue without AGENTS.md. DuaLoop will still work, just without initial context.

### Technical Considerations

- Interactive prompts in bash script (read input)
- May need to run Claude once before the main loop
- Should commit the generated AGENTS.md before starting iterations
- Could use a flag to skip: `./dualoop.sh --skip-init`

### Questions to Resolve

- Should this run every time, or only when AGENTS.md is missing?
- How deep should the project analysis go?
- Should it also check for AGENTS.md in key subdirectories?
- Should the user be able to edit the generated file before proceeding?
- How to handle projects with multiple roots (monorepos)?

---

## Future Improvements (Backlog)

Add more improvement ideas here as they arise:

- [x] Auto-initialize AGENTS.md (implemented in init.sh)
- [x] Human checkpoints in workflow (PRD → prd.json → start loop)
- [x] Auto branch creation at loop start
- [x] Merge/PR prompt at end of successful run
- [ ] Better error recovery when iteration fails mid-story
- [ ] Parallel story execution (for independent stories)
- [ ] Cost tracking per story/run
- [ ] Integration with GitHub Issues/PRs
- [ ] Web dashboard for monitoring DuaLoop runs
- [ ] Slack/Discord notifications on completion
- [ ] Auto-improvement of skills - Project skills may evolve to be better than source skills; need a way to sync improvements back or handle divergence
- [ ] Bidirectional skill sync - upgrade.sh currently overwrites project skills with source; consider merging or preserving project-specific improvements
- [x] Story sizing and progress tracking (implemented in dualoop.sh):
  - Added `size` field to stories: `"small"`, `"medium"`, `"large"`
  - Added `startTime` and `endTime` fields for timing
  - Weighted progress percentage based on size
  - ETA calculation from `.dualoop-stats.json` keyed by size-model
  - Stats updated after successful loop completion
- [ ] Completion summary with verified metrics + qualitative analysis:
  - Generate summary when DuaLoop completes all stories
  - **Part 1: Verified metrics from git/tools** (not LLM-generated to avoid hallucination):
    - Story count from prd.json
    - Commit count: `git rev-list --count main..HEAD`
    - Lines changed: `git diff --stat main`
    - Files changed: `git diff --name-only main`
    - Test results: run test command and capture output
    - Total time spent (sum of story durations from prd.json)
  - **Part 2: Qualitative analysis from LLM** (valuable insights that require understanding):
    - Implementation quality observations (TDD followed? patterns used?)
    - Workflow notes (issues encountered, how resolved)
    - Key decisions made during implementation
    - Source: progress.txt + git commit messages + a summary agent
  - Example output:
    ```
    ═══════════════════════════════════════════════════════════
      DuaLoop Implementation Summary
    ═══════════════════════════════════════════════════════════

    Branch: dua/dark-mode-dashboard
    Stories: 7/7 completed
    Duration: 47 minutes

    Git stats:
    - 15 commits
    - 12 files changed
    - +2,634 / -124 lines

    Tests: 210 passing ✓

    Key files:
    - src/components/theme-provider.tsx (new)
    - src/components/theme-toggle.tsx (new)
    - src/app/layout.tsx (modified)

    Implementation quality:
    - Followed TDD workflow (tests written first)
    - Browser verification for each UI story
    - Proper dark mode patterns (dark:bg-*, dark:text-*)

    Workflow observations:
    - Deep verification caught edge case in US-007
    - Commit pattern: feat: US-XXX then chore: mark complete
    ```

- [ ] Lightweight roadmap + state files (optional, low overhead):
  - Add `ROADMAP.md` for near-term phases or milestones
  - Add `STATE.md` for decisions, blockers, and current focus
  - Keep them small and updated during iteration cadence
- [ ] Optional per-story PLAN artifact (execution blueprint):
  - Store a short task list per story in `plans/` or `PLAN.md`
  - Keep steps atomic to reduce variance across iterations
  - Use it as the reference when a story spans multiple files
- [ ] Phase wrapper (discuss → plan → execute → verify):
  - Lightweight phase folders (e.g., `phases/01/`)
  - Checklist template to enforce consistency across iterations
  - Allows batching stories while keeping context fresh
- [ ] Per-iteration SUMMARY artifact (audit + handoff):
  - Short `SUMMARY.md` with what changed and how verified
  - Useful for later review and restart points
- [ ] Per-story verification notes (traceable QA):
  - Minimal checklist or `verifications/` entry
  - Tie acceptance criteria to actual verification steps/outcomes
- [ ] Track deep verification status per story:
  - Add a `deepVerified` (or similar) field to user stories
  - Skip re-verifying stories that already passed deep verification
  - Reset `deepVerified` to false if the story changes after verification