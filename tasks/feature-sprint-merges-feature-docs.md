# Feature: /sprint Merges Multiple Feature Docs

## 1. Introduction / Overview

After `/epic` loops through all Features (F-1), the user has multiple Feature docs in `tasks/`. But `/sprint` currently handles one Feature doc at a time — the user would need to run it separately for each doc and manually combine the results. This Feature makes `/sprint` detect all `tasks/feature-*.md` files and combine them into one `sprint.json` with a single coherent wave plan. The full Epic converts in one step. Single-doc invocation continues to work unchanged.

---

## 2. Goals

- `/sprint` invoked without arguments detects all Feature docs and offers to merge them
- Story IDs are auto-renumbered across Feature docs to avoid collisions
- Wave computation runs across all stories from all docs combined
- Single-doc invocation is backward-compatible and unchanged

---

## 3. User Stories

### US-001: /sprint detects and merges all Feature docs

**Description:** As a takt user, I want /sprint to find all my Feature docs and combine them into one sprint.json so that I don't have to merge them manually.

**Acceptance Criteria:**
- [ ] When /sprint is invoked without a specific Feature doc argument, it scans tasks/ for all feature-*.md files and presents a list, offering to merge them all into one sprint.json
- [ ] The resulting sprint.json contains all stories from all Feature docs, with auto-renumbered IDs (US-001 onwards, globally unique across all docs), and a single wave plan computed across all stories

### US-002: Story ID collision resolution and wave computation

**Description:** As a takt user, I want story IDs to be unique and waves to be computed correctly across all Feature docs so that the combined sprint.json runs without conflicts.

**Acceptance Criteria:**
- [ ] When two Feature docs both have a US-001, the first doc keeps US-001 and the second doc's stories are renumbered starting from the next available ID — the renaming is noted in the /sprint summary
- [ ] dependsOn references within each Feature doc are updated to reflect the renumbered IDs
- [ ] Waves are computed from the combined dependsOn graph across all stories, not per-Feature-doc

---

## 4. Functional Requirements

- **FR-1:** When `commands/sprint.md` is invoked without a Feature doc argument (or when invoked from `/epic`'s hand-off), it scans `tasks/` for all `feature-*.md` files and presents them to the user with a "merge all" offer.
- **FR-2:** If the user confirms merge, all stories from all Feature docs are combined into a single `userStories` array. Story IDs are globally renumbered US-001, US-002, … in the order they appear (Feature docs processed in filename alphabetical order, then story priority order within each doc).
- **FR-3:** All `dependsOn` references in each story are updated to the renumbered IDs before insertion into the combined array.
- **FR-4:** Wave computation runs on the combined `dependsOn` graph across all stories. The `waves` field reflects the full parallel execution plan, not per-Feature-doc waves.
- **FR-5:** The /sprint summary lists each Feature doc merged, the original story counts, and any ID renames (e.g. "feature-foo.md: US-001–US-003 → US-001–US-003 (unchanged); feature-bar.md: US-001–US-002 → US-004–US-005 (renumbered)").
- **FR-6:** Single-doc invocation (e.g. `/sprint tasks/feature-foo.md`) continues to work exactly as before — no change to single-doc behaviour.
- **FR-7:** `.takt/scenarios.json` is generated from all stories across all merged Feature docs.

---

## 5. Non-Goals (Out of Scope)

- Merging existing sprint.json files — only Feature docs are merged
- Changing the sprint.json schema or story format
- Conflict resolution beyond ID auto-renumbering (e.g. duplicate story titles are left as-is)
- Changes to `/epic` (F-1) or `/feature` (F-2)
- The quick path (F-4)

---

## 6. Technical Considerations

- `commands/sprint.md` is the only file that changes
- The installed copy at `~/.claude/commands/sprint.md` must also be updated — `install.sh` handles this on next run
- Feature doc processing order: alphabetical by filename. This is deterministic and predictable.

---

## 7. Success Metrics

- A user with 3 Feature docs in tasks/ can run /sprint once and get a single sprint.json with all stories, correct IDs, and a valid wave plan
- No manual story ID editing required after merge

---

## 8. Open Questions

- **Merge order:** Alphabetical by filename is the default. Should /sprint let the user reorder Feature docs before merging? Recommend: no — alphabetical is deterministic. Users can rename files if they care about order.
- **Story count warning:** If the combined sprint.json would have more than 15 stories, should /sprint warn the user? Recommend: yes — flag it and suggest splitting into multiple sprints (run subset of Feature docs at a time).
