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

```
Plan  ──>  Scope  ──>  Execute  ──>  Review
 PRD       prd.json    takt solo     takt retro
                        takt team
                        takt debug
```

1. **Plan** — Discuss the feature with Claude. Say "Create the PRD" and Claude generates a structured requirements document using `/takt-prd`.
2. **Scope** — Say "Convert to prd.json" and Claude converts the PRD into executable stories with priorities, sizes, model assignments, dependencies, and wave groupings using `/takt`.
3. **Execute** — Say "Start" and Claude picks the right mode: `takt solo` for small features, `takt team` for larger parallel work, or `takt debug` for bug fixing.
4. **Review** — After execution, `takt retro` analyzes workbooks from the run, identifies patterns, and tracks recurring issues across executions.

## Modes

### takt solo — Sprint Execution

Single agent, one story at a time. Each iteration spawns a fresh Claude instance that reads the PRD, picks the next incomplete story, implements it with TDD, verifies acceptance criteria, commits, and exits. The next iteration picks up where it left off.

```bash
takt solo              # Auto-calculated iterations
takt solo 10           # Max 10 iterations
```

Best for: small features (2-5 stories), linear dependencies, quick delivery.

### takt team — Parallel Delivery

Multi-agent team execution modeled on how real engineering teams work. A scrum master (Opus) orchestrates worker agents implementing stories in parallel, each in their own git worktree. Stories are grouped into waves based on their dependency graph — Wave N+1 doesn't start until Wave N is fully merged and tested.

```bash
takt team              # Launch team execution
```

The scrum master never writes code. It spawns workers, monitors progress, plans merge order by reading workbooks for file overlap, resolves conflicts by consulting the original author (still idle with context), and runs tests after every merge.

Best for: larger features (6+ stories), multiple independent chains, complex PRDs where parallelism pays off.

### takt debug — Incident Response

Strict bug-fixing discipline inspired by incident management: reproduce first, root cause second, minimal fix third, present evidence last. The agent must confirm the bug exists before touching any code. No unrelated changes allowed.

```bash
takt debug "Login fails on Safari"
```

Best for: bug fixing where discipline matters more than speed.

### takt retro — Continuous Improvement

Reads workbooks from a completed run and generates a retrospective entry in `retro.md`. Scans previous entries for recurring patterns and manages an alert lifecycle: `potential` → `confirmed` → `mitigated` → `resolved`.

```bash
takt retro
```

Suggested automatically after each `takt solo` or `takt team` run completes. The value of retros compounds over time — patterns that repeat across runs surface as confirmed alerts rather than rediscovered surprises.

## Artifacts

| File | Purpose | Created by |
|------|---------|------------|
| `prd.json` | Stories, waves, dependencies, model assignments | `/takt` command + human review |
| `workbook-US-XXX.md` | Per-story notes: decisions, files changed, blockers | Each agent during implementation |
| `retro.md` | Retrospective entries + active alerts | `takt retro` agent |
| `tasks/prd-*.md` | Source PRD documents | `/takt-prd` command |
| `tasks/archive/` | Completed PRDs, auto-archived on finish | `takt solo` / `takt team` |

## Team Mode — Roles & Models

| Role | Model | Responsibility |
|------|-------|---------------|
| Scrum master | Opus 4.6 | Orchestration, wave execution, merge planning. **Never writes code.** |
| Senior dev | Opus 4.5 | Complex stories: multi-file refactors, architectural changes |
| Dev | Sonnet 4.5 | Standard stories (~80-90% of work). Cost-effective, reliable. |

## Installation

```bash
git clone https://github.com/duadigital/dua-loop.git
cd dua-loop && ./install.sh
```

Everything installs into `~/.claude/`. The repo can be deleted after install.

### Updating

```bash
cd dua-loop && git pull && ./install.sh
```

### What Gets Installed

```
~/.claude/
├── lib/takt/
│   ├── takt.sh               # Core script (dispatch + solo mode)
│   ├── prompt.md              # Solo agent instructions
│   ├── verifier.md            # Deep verification agent
│   ├── team-lead.md           # Team mode scrum master prompt
│   ├── worker.md              # Team mode worker prompt
│   ├── debug.md               # Debug mode agent prompt
│   └── retro.md               # Retro mode agent prompt
├── commands/
│   ├── takt.md                # /takt — convert PRD to prd.json
│   ├── takt-prd.md            # /takt-prd — generate PRD
│   └── tdd.md                 # /tdd — TDD workflow
└── CLAUDE.md                  # takt section appended
```

## Prerequisites

- [Claude Code CLI](https://claude.com/claude-code) installed and authenticated
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project

## References

- [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/) — the original autonomous agent loop concept that takt builds upon
- [Claude Code documentation](https://claude.com/claude-code)

## License

[MIT](LICENSE)
