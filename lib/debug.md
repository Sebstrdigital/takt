# takt debug — retired

Debug mode was replaced on 2026-09-29. It had no recorded use since 2026-02-16 and the `/diagnose` skill is a superset of its method.

When the user says `takt debug` or asks to debug a takt-produced bug:

1. Run the `/diagnose` skill for the method (build a feedback loop, reproduce, rank hypotheses, instrument, fix, regression test at the right seam).
2. Use the `/debug` skill if the session may be interrupted; it keeps a `debug-active.md` breadcrumb file.
3. If `bugs.json` or `review-comments.json` exist in the project root, read the entries with `status: "open"` first; they are the verifier's and review gate's findings from the last run.

Do not reintroduce a takt-specific debug agent here.
