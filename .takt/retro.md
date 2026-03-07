# Active Alerts

| Status | Alert | First Seen | Last Seen |
|--------|-------|------------|-----------|
| confirmed | Spawned agents cannot use Bash or spawn sub-agents — intermediary orchestrator pattern is non-functional | 2026-03-07 | 2026-03-07 |
| confirmed | Prompt bloat — solo.md/team-lead.md embed ~9KB of instructions that agents can read from disk | 2026-03-07 | 2026-03-07 |
| potential | Workers cannot git commit — bypassPermissions mode only grants file edit access, not Bash | 2026-03-07 | 2026-03-07 |

---

## Retro: 2026-03-07 — takt/baseline-completion

### What Went Well
- **4/4 stories completed, all acceptance criteria met.** Retro routing fix, stale action escalation, automated PR creation, and auto-retro all delivered.
- **US-004 auto-retro used the correct pattern**: told the retro agent to "Read `~/.claude/lib/takt/retro.md` for instructions" instead of embedding the full file. This is the lean prompt pattern that should be standard.
- **Parallel execution of independent stories worked**: US-001, US-002, US-003 ran concurrently with no file conflicts (each touches different files).
- **All workers produced clean edits and workbooks** despite permission constraints — file operations via Edit/Write worked reliably with bypassPermissions mode.
- **Cross-project retro analysis provided strong signal**: reading 6 retro files across 3 projects (dua-cs-agent, dua-erp, mcp-servers) surfaced the confirmed routing bug and stale action item pattern that drove this PRD.

### What Didn't Go Well
- **Orchestrator stall (6 minutes wasted)**: The first attempt spawned an intermediary orchestrator Agent (Sonnet) with a ~20KB embedded prompt. The orchestrator could not find the Task tool and could not run Bash — it sat idle for 6 minutes before being killed. Root cause: spawned agents don't inherit the session agent's full tool access.
- **Workers could not git commit**: All 4 workers completed file edits but failed to run `git commit` — Bash was denied despite `mode: "bypassPermissions"`. The session agent had to commit all 4 stories manually. This means the current worker.md commit instructions are impossible for workers to follow.
- **Prompt bloat undetected until failure**: solo.md embeds worker.md (~3KB) + verifier.md (~3KB) + reviewer.md (~3KB) into every orchestrator prompt. These files exist on disk at `~/.claude/lib/takt/` and agents can read them. The embedding was never questioned because it worked when prompts were smaller.
- **Previous action items carry forward (2x)**: "Make cleanup spec conditional" and "Run install.sh for reviewer.md" — neither addressed in this run.

### Patterns Observed
- **Session-agent-as-orchestrator is the working pattern**: When the session agent orchestrated directly (spawning workers, committing, updating stories.json), everything worked smoothly. The intermediary orchestrator layer added latency and failure with no benefit.
- **File edits work, Bash doesn't, for spawned agents**: This is a hard boundary in Claude Code's agent spawning. `bypassPermissions` grants Edit/Write/Read/Glob but NOT Bash or Agent-spawning. This means workers should be scoped to file operations only.
- **Pointer prompts > embedded prompts**: US-004's retro agent used a 100-byte pointer to retro.md. The orchestrator prompt used 9KB of embedded copies. The pointer pattern should be standard for all agent spawns.
- **Prompt-only repos remain fast**: 5th consecutive retro confirming this. All stories were markdown edits, all completed quickly.

### Action Items
- [ ] [carried 2x] Make cleanup spec explicit that artifact deletion is conditional ("delete if exists")
- [ ] [carried 2x] Run `./install.sh` to deploy updated prompts to `~/.claude/lib/takt/`
- [ ] Rewrite solo.md: session agent IS the orchestrator, no intermediary layer
- [ ] Rewrite team-lead.md: same session-level orchestration pattern
- [ ] Implement prompt diet: all agent spawns use file-path pointers instead of embedded copies
- [ ] Update worker.md: remove git commit instructions, clarify workers do file edits only

### Metrics
- Stories completed: 4/4
- Stories blocked: 0
- Total workbooks: 4
- Orchestrator stall: 1 (killed after 6 min, restarted with direct-spawn pattern)
- Worker commit failures: 4 (all committed manually by session agent)
