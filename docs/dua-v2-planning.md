# Takt — Planning Notes

## Context

Planning session for evolving dua-loop into **takt** — a broader system with multiple execution modes. Based on real-world experience from orchestrating 50+ person programs across 10+ teams at Wireless Car.

---

## Rename: dua-loop → takt

The system is no longer just a loop. New name: **takt** (Swedish/German for "beat, pace, rhythm") with modes underneath.

```bash
takt solo    # Single agent, sequential story execution
takt team    # Parallel team execution with agent roles
takt debug   # Strict bug-fixing discipline
takt retro   # Post-execution review and trend analysis
```

---

## Four Modes

### takt solo (was: dua loop)
- Single agent, sequential story execution
- Bash script spawns fresh Claude instance per story
- One story at a time, linear git history
- Best for: small PRDs (2-5 stories), linear dependencies, simple features

### takt team (new)
- Parallel team execution using Claude Code's native agent system (TeamCreate, Task, SendMessage)
- Git worktrees for isolation — each agent works in its own worktree/branch
- Agents stay idle after completing their story (context preserved for merge conflict resolution)
- Best for: larger PRDs (6+ stories), multiple independent chains, parallelism pays off

### takt debug (new)
- Strict bug-fixing discipline with fresh context per attempt
- Flow: reproduce → root cause → minimal fix → present evidence to human
- Agent MUST confirm bug exists before touching code
- Human-in-the-loop verification at the end — agent proves the fix, human confirms
- No unrelated changes allowed
- If fix fails → fresh iteration with learnings documented

### takt retro (new)
- Runs after each `takt solo` or `takt team` execution
- Reads workbooks from the run, produces an entry in `retro.md`
- Scans previous entries for recurring patterns
- Flags alerts when known risks are triggered
- Suggested automatically after each run completes

---

## Artifacts

| File | Purpose | Written by |
|------|---------|------------|
| `prd.json` | Stories, waves, dependencies | `/takt-prd`, human review |
| `workbook-US-XXX.md` | Per-story notes: decisions, files changed, blockers, agent ID | Each agent during implementation |
| `retro.md` | Run entries + active alerts section at top | `takt retro` agent |

`retro.md` replaces the old `progress.txt`. Active alerts live at the top of the file with a simple lifecycle: `potential` → `confirmed` → `mitigated` → `resolved`. If the alerts section outgrows the file, split into `risks.md` then.

---

## Team Mode — Agent Roles & Model Assignments

| Role | Model | Responsibility |
|------|-------|---------------|
| Scrum master / orchestrator | Opus 4.6 | Executes wave plan, assigns stories, resolves merge conflicts, coordinates. **Never writes code.** |
| Senior dev (complex stories) | Opus 4.5 | Implements complex stories, communicates changes to peers |
| Dev (standard stories) | Sonnet 4.5 | Implements standard stories, communicates changes to peers |
| Intern / assistant (support) | Haiku 4.5 | Pre-merge recon, codebase lookups, post-merge verification, build/test runs |

### Model philosophy
- **Opus 4.6**: Reasoning, orchestration, coordination only. No code implementation.
- **Opus 4.5**: Complex implementation. Multi-file refactors, architectural changes.
- **Sonnet 4.5**: Workhorse for ~80-90% of stories. Cost-effective, reliable.
- **Haiku 4.5**: Support tasks only. Not for story implementation.

---

## Team Mode — Wave Planning

Waves are **pre-computed in prd.json** by `/takt-prd`. The scrum master executes the plan — it does not create it.

```json
{
  "waves": [
    { "wave": 1, "stories": ["US-001", "US-003", "US-005"] },
    { "wave": 2, "stories": ["US-002", "US-004"] }
  ]
}
```

- `/takt-prd` analyzes `dependsOn` fields and computes wave groupings
- Human reviews wave plan before execution
- Wave N+1 doesn't start until Wave N is fully merged

---

## Team Mode — Git Worktree Strategy

Each parallel worker gets its own git worktree inside `.worktrees/`:

```
main (or feature branch)
  ├── .worktrees/us-001/  →  branch: takt/us-001  →  Agent A (sonnet)
  ├── .worktrees/us-003/  →  branch: takt/us-003  →  Agent B (sonnet)
  └── .worktrees/us-005/  →  branch: takt/us-005  →  Agent C (opus 4.5)
```

- `.worktrees/` is gitignored, lives inside the project
- Worktrees auto-cleaned after successful merge

---

## Team Mode — Agent Lifecycle

1. **Spawned** → implements story in its worktree, writes workbook
2. **Story done** → reports `done`, goes idle (context preserved)
3. **Merge planning** → scrum master reads workbooks, identifies file overlaps, plans merge order
4. **Merge execution** → merges one by one, tests after each
5. **If conflict** → scrum master consults original agent (still idle with context)
6. **Merge successful** → scrum master sends shutdown request
7. **Agent shuts down** → resources freed

Rule: Keep agents from current wave alive. Shut down after successful merge.

---

## Team Mode — Communication

Agents communicate via SendMessage. **Structured flags + free-form descriptions.**

**Required flags:** `started`, `blocked` (with reason), `done`

**Free-form:** agents share discoveries as needed. Scrum master uses broadcast sparingly for team-wide concerns.

---

## Team Mode — Failure Handling

- **Max 2 retries per story** — scrum master chooses: retry, escalate model, or reassign
- **After 2 failures** → story flagged as `blocked` with documented analysis
- Dependent stories in later waves also flagged
- Human reviews before next execution

---

## Mode Selection in /takt-prd

Decision guide:
- **takt solo** — ≤5 stories, mostly linear dependencies, simple feature
- **takt team** — 6+ stories, 2+ independent chains, parallelism pays off
- **takt debug** — bug fixing, strict verification discipline

---

## Decisions Log

| # | Question | Decision |
|---|----------|----------|
| Q1 | Where should team mode live? | One `takt` CLI with subcommands dispatching to separate implementations |
| Q2 | Wave planning? | Rules-based, pre-computed in prd.json. Scrum master executes, doesn't plan. |
| Q3 | Git worktree location? | `.worktrees/` inside project, auto-cleaned after merge |
| Q4 | Communication protocol? | Structured flags required + free-form encouraged |
| Q5 | Failure handling? | Scrum master decides within retry cap (max 2), then blocked + human review |

---

## Next Steps

1. ~~Answer the 5 open questions~~ Done
2. Generate PRD with `/takt-prd` (covering all three modes or team mode first)
3. Convert to prd.json with `/takt`
4. Implement (dogfooding: use takt solo to build takt team?)
