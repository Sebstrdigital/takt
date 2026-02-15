# takt

An autonomous AI agent orchestrator for Claude Code. Four modes for different workflows: solo execution, parallel teams, structured debugging, and retrospectives.

Named after the Swedish/German word for "beat, pace, rhythm" — takt keeps your development in rhythm.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

## Installation

```bash
git clone https://github.com/duadigital/dua-loop.git
cd dua-loop && ./install.sh
```

Everything installs into `~/.claude/`. The repo can be deleted after install.

## Updating

```bash
cd dua-loop && git pull && ./install.sh
```

## Modes

### takt solo — Sequential Execution

Single agent, one story at a time. Best for small PRDs (2-5 stories) with linear dependencies.

```bash
takt solo              # Auto-calculated iterations
takt solo 10           # Max 10 iterations
```

### takt team — Parallel Execution

Multi-agent team with git worktrees for isolation. A scrum master orchestrates workers implementing stories in parallel, then merges results wave by wave.

```bash
takt team              # Launch team execution
```

Best for larger PRDs (6+ stories) with independent chains where parallelism pays off.

### takt debug — Structured Debugging

Strict bug-fixing discipline: reproduce → root cause → minimal fix → present evidence to human. No unrelated changes allowed.

```bash
takt debug "Login fails on Safari"
```

### takt retro — Retrospective

Reads workbooks from a completed run, generates a retrospective entry in `retro.md`, and scans for recurring patterns across previous entries.

```bash
takt retro
```

Suggested automatically after each `takt solo` or `takt team` run completes.

## Usage

1. Open Claude Code in your project
2. Discuss and plan the feature with Claude
3. Say "Create the PRD" — Claude uses `/takt-prd` to generate `tasks/prd-feature.md`
4. Say "Convert to prd.json" — Claude uses `/takt` to create `prd.json` with stories
5. Say "Start" — Claude runs `takt solo` or `takt team` depending on PRD complexity

## What Gets Installed

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

## Per-Project Files

```
my-project/
├── prd.json              # Active user stories (with waves for team mode)
├── workbook-US-XXX.md    # Per-story implementation notes
├── retro.md              # Retrospective entries + active alerts
└── tasks/
    └── archive/          # Completed PRDs
```

## Prerequisites

- [Claude Code CLI](https://claude.com/claude-code) installed and authenticated
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://claude.com/claude-code)

## License

[MIT](LICENSE)
