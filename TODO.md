## takt follow-ups — takt/review-scope — 2026-11-27
- Let the takt-run commit stage and story workers commit prompt-source changes despite the install.sh ask-before-commit rule in CLAUDE.md (US-002 needed a heavy retry; review-1 commit was refused).
- Verifier: read sprint.json scope and drop failing scenarios outside it (PR #11 review; low value, since scenarios come from the spec).
- takt-run.js: reject story entries without an id instead of dispatching story:undefined (PR #11 review).
- Archive sprint.json next to the Feature doc at retro, so a later PR review can see the story acceptance criteria.
- Review-gate snapshots: exclude run files before `git add` so they never reach the object database (PR #11 review, local only).
- Small fixes from PR #11 review: Feature example uses **Scope:** instead of ## Scope (commands/feature.md:294); verify-only run still emits a Stories phase event (lib/takt-run.js); commands/sprint.md:83 says the verifier applies sprint scope; quote the checkout path in the gate shell commands.

## takt follow-ups — branch choice — 2026-11-27

- Pass the PR title to `gh pr create` as literal data (run.md Phase 5), not interpolated into the shell command.
- Align the `/takt` wrapper's existing-sprint and quick-path start instructions (commands/takt.md) with "read run.md and execute directly".
