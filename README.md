# takt

Enterprise-grade development workflows for AI agents. Four modes that mirror real agile delivery: sprint execution, parallel teams, structured debugging, and retrospectives.

Named after the Swedish/German word for "beat, pace, rhythm" — the same concept used in lean manufacturing and agile planning to set a sustainable delivery cadence. takt brings that discipline to autonomous AI development.

## Why takt?

Most AI coding tools treat development as a single prompt-response cycle. Real software delivery doesn't work that way. takt is built on patterns from orchestrating 50+ person programs across 10+ teams:

- **Stories, not prompts.** Work is scoped into user stories with acceptance criteria — the same artifact that drives human sprint planning.
- **Wave-based parallelism.** Dependencies are analyzed upfront, stories grouped into waves, and parallel agents execute within each wave — just like a real team coordinating across workstreams.
- **Fresh context per story.** Each story gets a clean agent instance, avoiding the context pollution that derails long sessions. Memory persists through git history, workbooks, and the PRD itself.
- **Built-in verification.** Stories can be self-verified or independently deep-verified by a separate agent — mirroring code review in human teams.
- **Retrospectives that compound.** After each run, patterns are extracted from workbooks and tracked across executions. Recurring issues surface as alerts, not surprises.

## How It Works

takt runs natively inside Claude Code. There is no CLI binary or bash script — you interact with it by typing phrases in Claude Code.

```
Plan  ──>  Scope  ──>  Execute  ──>  Review
 PRD       prd.json    takt solo     takt retro
                        takt team
                        takt debug
```

1. **Plan** — Discuss the feature with Claude. Say "Create the PRD" and Claude generates a structured requirements document using `/takt-prd`.
2. **Scope** — Say "Convert to prd.json" and Claude converts the PRD into executable stories with priorities, sizes, model assignments, dependencies, and wave groupings using `/takt`.
3. **Execute** — Say "takt solo" or "takt team" in Claude Code. Claude reads the orchestrator prompt, loads `prd.json`, and spawns autonomous worker agents for each story.
4. **Review** — Say "takt retro" and Claude analyzes workbooks from the run, identifies patterns, and tracks recurring issues across executions.

## Modes

### takt solo — Sprint Execution

Single orchestrator, one story at a time. The orchestrator reads `prd.json`, picks the next incomplete story, spawns a fresh worker agent to implement it with TDD, verifies acceptance criteria, updates `prd.json`, and moves to the next story.

Say in Claude Code:
```
takt solo
```

Best for: small features (2-5 stories), linear dependencies, quick delivery.

### takt team — Parallel Delivery

Multi-agent team execution modeled on how real engineering teams work.

Say in Claude Code:
```
takt team
```

**How it works:**

1. **Wave planning** — The scrum master reads `prd.json`, groups stories into waves based on `dependsOn`. Wave N+1 doesn't start until Wave N is fully merged and tested.
2. **Worktree isolation** — Each worker gets its own git worktree (`.worktrees/<story-id>/`), so agents work in parallel without stepping on each other's files.
3. **Parallel implementation** — Workers implement their stories with TDD, each writing a workbook with decisions, files changed, and blockers.
4. **Merge planning** — When a wave's workers finish, the scrum master reads their workbooks to identify file overlaps and plans the merge order to minimize conflicts.
5. **Sequential merge** — Stories are merged into main one by one. Tests run after each merge. If a conflict arises, the scrum master consults the original author (still idle with full context) to resolve it.
6. **Cleanup** — Worktrees are removed after successful merge. Next wave begins.

The scrum master never writes code. It orchestrates, monitors, plans merges, and resolves conflicts.

Best for: larger features (6+ stories), multiple independent chains, complex PRDs where parallelism pays off.

### takt debug — Incident Response

Strict bug-fixing discipline inspired by incident management: reproduce first, root cause second, minimal fix third, present evidence last. The agent must confirm the bug exists before touching any code. No unrelated changes allowed.

Say in Claude Code:
```
takt debug "Login fails on Safari"
```

Best for: bug fixing where discipline matters more than speed.

### takt retro — Continuous Improvement

Reads workbooks from a completed run and generates a retrospective entry in `.takt/retro.md`. Scans previous entries for recurring patterns and manages an alert lifecycle: `potential` -> `confirmed` -> `mitigated` -> `resolved`.

Say in Claude Code:
```
takt retro
```

Suggested automatically after each solo or team run completes. The value of retros compounds over time — patterns that repeat across runs surface as confirmed alerts rather than rediscovered surprises.

## Artifacts

| File | Purpose | Created by |
|------|---------|------------|
| `prd.json` | Stories, waves, dependencies, model assignments | `/takt` command + human review |
| `.takt/workbooks/workbook-US-XXX.md` | Per-story notes: decisions, files changed, blockers (ephemeral) | Each worker agent during implementation |
| `.takt/retro.md` | Retrospective entries + active alerts | `takt retro` agent |
| `tasks/prd-*.md` | Source PRD documents | `/takt-prd` command |
| `tasks/archive/` | Completed PRDs, auto-archived on finish | Solo/team orchestrator |

## Team Mode — Roles & Models

| Role | Model | Responsibility |
|------|-------|---------------|
| Scrum master | Opus 4.6 | Orchestration, wave execution, merge planning. **Never writes code.** |
| Senior dev | Opus 4.5 | Complex stories: multi-file refactors, architectural changes |
| Dev | Sonnet 4.5 | Standard stories (~80-90% of work). Cost-effective, reliable. |

## Installation

```bash
git clone https://github.com/duadigital/takt.git
cd takt && ./install.sh
```

Everything installs into `~/.claude/`. The repo can be deleted after install.

### Updating

```bash
cd takt && git pull && ./install.sh
```

### What Gets Installed

```
~/.claude/
├── lib/takt/
│   ├── solo.md               # Solo orchestrator prompt
│   ├── prompt.md             # Solo worker instructions
│   ├── verifier.md           # Deep verification agent
│   ├── team-lead.md          # Team mode scrum master prompt
│   ├── worker.md             # Team mode worker prompt
│   ├── debug.md              # Debug mode agent prompt
│   └── retro.md              # Retro mode agent prompt
├── commands/
│   ├── takt.md               # /takt — convert PRD to prd.json
│   ├── takt-prd.md           # /takt-prd — generate PRD
│   └── tdd.md                # /tdd — TDD workflow
└── CLAUDE.md                 # takt section appended
```

## Prerequisites

- [Claude Code CLI](https://claude.com/claude-code) installed and authenticated
- A git repository for your project

## References

- [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/) — the original autonomous agent loop concept that takt builds upon
- [Claude Code documentation](https://claude.com/claude-code)

## License

[MIT](LICENSE)
