# TODO: DuaLoop

## Repository Cleanup ✅

- [x] Rename from "ralph-claude" to "dualoop" on GitHub
- [x] Update remote URL
- [x] Rename ralph.sh to dualoop.sh
- [x] Rename skills/ralph/ to skills/dua/
- [x] Update all documentation references
- [x] Remove test artifacts (test-output/, test-prds/, archive/)
- [x] Remove flowchart React app (replaced with ASCII diagram in README)
- [x] Remove ralph image files
- [x] Move supplementary docs to docs/ folder
- [x] Remove unused GitHub workflow (deploy.yml)

---

## Documentation ✅

- [x] Add flow diagram to README (ASCII art)
- [x] Add quick start guide
- [x] Document the full workflow (PRD -> prd.json -> run loop)
- [x] Add debugging section

---

## Installation Script ✅

- [x] Create `init.sh` for easy project setup

Usage:
```bash
# Clone DuaLoop once
git clone https://github.com/duadigital/DuaLoop.git ~/tools/dualoop

# In any project, run init
cd ~/my-project
~/tools/dualoop/init.sh
```

---

## Future Enhancements

From IMPROVEMENTS.md and session learnings:
- [x] Auto-initialize AGENTS.md on first run (init.sh runs Claude to analyze project)
- [x] Human checkpoints in workflow (PRD → prd.json → start loop)
- [x] Auto branch creation at loop start (from prd.json branchName)
- [x] Merge/PR prompt at end of successful run
- [ ] Wave-based parallelization (for independent stories)
- [ ] Cost tracking per story/run
- [ ] Lightweight roadmap + state files (`ROADMAP.md`, `STATE.md`)
- [ ] Optional per-story plan artifacts (`plans/` or `PLAN.md`)
- [ ] Phase wrapper checklist (discuss → plan → execute → verify)
- [ ] Per-iteration summary artifact (`SUMMARY.md`)
- [ ] Per-story verification notes (traceable QA)
- [ ] Track deep verification status per story

---

*Created: 2026-01-16*
*Updated: 2026-01-17*
*Status: Core complete, workflow automation done, enhancements pending*
