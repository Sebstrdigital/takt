# Feature: Broader Feature Scope Guidelines

## 1. Introduction / Overview

The `/feature` skill currently encourages Features that are too small — 1-3 stories each — because the guidance doesn't distinguish between "what a Feature doc describes" and "what stories the orchestrator executes." Feature docs don't need to be small. Story decomposition is `/sprint`'s job. A Feature doc should describe initiative-level work: a meaningful chunk of value a user would notice. This Feature recalibrates the scope guidance in `commands/feature.md` so Features are appropriately broad, reducing the number of Feature docs per Epic and the planning ceremony that comes with them.

---

## 2. Goals

- Feature docs cover initiative-level scope: 4-8 stories when converted by /sprint, not 1-3
- The /feature skill explicitly tells the skill invoker (and the LLM) that story decomposition is /sprint's responsibility
- If a Feature would produce fewer than 3 stories, the guidance recommends rolling it into a sibling Feature
- The example in /feature reflects broad scope, not narrow sub-task scope

---

## 3. User Stories

### US-001: Update /feature scope guidance and example

**Description:** As a takt user, I want /feature to guide me toward initiative-level scope so that I produce fewer, more meaningful Feature docs instead of many tiny ones.

**Acceptance Criteria:**
- [ ] commands/feature.md includes explicit guidance: a Feature doc should produce 4-8 stories when converted by /sprint; if it would produce fewer than 3 stories, roll it into a sibling Feature
- [ ] commands/feature.md includes a note clarifying that story decomposition is /sprint's responsibility — Feature docs describe the initiative, not individual implementation tasks
- [ ] The example in commands/feature.md shows a Feature that covers multiple related user-visible outcomes (not a single sub-task like "add a column"), producing at least 4 stories when converted

---

## 4. Functional Requirements

- **FR-1:** The Story Scope section in `commands/feature.md` must add a scope target: "A Feature doc should produce 4-8 stories when converted by /sprint. If your Feature would produce fewer than 3 stories, consider rolling it into a sibling Feature instead."
- **FR-2:** The Story Scope section must include a note: "Story decomposition is /sprint's job, not the Feature doc's job. Feature docs describe what the user will experience — /sprint breaks that down into implementable stories."
- **FR-3:** The example Feature doc in `commands/feature.md` must be replaced or updated to show a Feature with broader scope — covering multiple related user-visible outcomes that would produce 4-6 stories in sprint.json.
- **FR-4:** The checklist at the end of `commands/feature.md` must include: "Feature produces 4-8 stories (if fewer than 3, consider merging with a sibling Feature)."

---

## 5. Non-Goals (Out of Scope)

- Changes to `/epic` — handled in F-1
- Changes to `/sprint` — handled in F-3
- The quick path — handled in F-4
- Changing the sprint.json story format or schema
- Changing acceptance criteria rules (max 3-4, behavioral outcomes — unchanged)
- Enforcing scope programmatically — guidance only, the LLM applies judgment

---

## 6. Technical Considerations

- `commands/feature.md` is the only file that changes
- The installed copy at `~/.claude/commands/feature.md` must also be updated — `install.sh` handles this on next run

---

## 7. Success Metrics

- A Feature doc created after this change produces 4-8 stories in sprint.json
- A takt Epic with a 3-initiative scope produces 2-3 Feature docs instead of 5-6

---

## 8. Open Questions

- None — scope is clear.
