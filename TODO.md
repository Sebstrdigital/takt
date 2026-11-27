## takt follow-ups — takt/review-lenses-devops — 2026-11-27
- Treat a Workflow gate result as PASSED only when no must-fix findings remain open (lib/takt-run.js:635, MF-016).
- Update CLAUDE.md lines 42 and 134 to describe the Codex relay gate with Sonnet fallback (MF-015).
- Add a stop and report branch in run.md Phase 0 for a preflight that exits before producing check results (MF-012).
- Reject malformed sprint data in run.md's normal start path instead of treating it as a verify-and-review rerun (MF-014).

## takt follow-ups — takt/review-scope — 2026-11-27
- Fix MF-002 and MF-003: edge cases in the fix-only re-review diff in lib/takt-run.js, left open by the review gate.
- Let the takt-run commit stage and story workers commit prompt-source changes despite the install.sh ask-before-commit rule in CLAUDE.md (US-002 needed a heavy retry; review-1 commit was refused).
