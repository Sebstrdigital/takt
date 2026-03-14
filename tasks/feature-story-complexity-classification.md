# Feature: Story Complexity Classification

## 1. Introduction / Overview

takt currently has no way to distinguish simple mechanical stories from complex reasoning-heavy ones. This Feature adds a `complexity` field (`"simple"` | `"complex"`) to the sprint.json schema and updates the `/sprint` converter to auto-classify each story during conversion. This is the data foundation for F-2 (Orchestrator Model Routing), which will use the field to spawn the appropriate model per worker.

---

## 2. Goals

- Add `complexity` field to sprint.json schema with values `"simple"` or `"complex"`
- Auto-classify stories during `/sprint` conversion based on story scope
- Default missing `complexity` to `"complex"` — safe fallback, no regression for existing sprint.json files
- Document the field so users understand when to override it manually

---

## 3. User Stories

### US-001: Add complexity field to sprint.json schema and converter

**Description:** As a takt user, I want each story in sprint.json to carry a complexity classification so that the orchestrator can route it to the appropriate model tier.

**Acceptance Criteria:**
- [ ] The sprint.json output format in commands/sprint.md includes a `complexity` field with values `"simple"` or `"complex"` on every story
- [ ] The /sprint converter auto-classifies each story: simple = single file, deterministic output, no cross-file reasoning; complex = multiple files, logic decisions, integration points
- [ ] Stories without a complexity field are treated as `"complex"` by default (documented in the schema section)

---

### US-002: Update documentation to reflect the new field

**Description:** As a takt user, I want CLAUDE.md and README.md to document the complexity field so I know when and how to override it manually.

**Acceptance Criteria:**
- [ ] CLAUDE.md sprint.json fields section lists `complexity` with a one-line description of each value
- [ ] README.md sprint.json schema reference includes the complexity field with its classification rules

---

## 4. Functional Requirements

- **FR-1:** The `complexity` field must appear in the sprint.json output format schema in `commands/sprint.md`, alongside existing fields (`verify`, `passes`, `dependsOn`, etc.).
- **FR-2:** The auto-classification rule in `commands/sprint.md` must define: **simple** = single file, deterministic output, clear template to follow, no branching logic; **complex** = touches multiple files, requires understanding existing patterns, logic decisions, integration points, semantic refactoring.
- **FR-3:** If a story cannot be confidently classified as simple, it must default to `"complex"`.
- **FR-4:** The sprint.json output example in `commands/sprint.md` must be updated to show the `complexity` field on every story.
- **FR-5:** The checklist at the end of `commands/sprint.md` must include a step: "complexity assigned to each story (`simple` or `complex`)".
- **FR-6:** `CLAUDE.md` Story Fields section must list `complexity` with: `"simple"` (Haiku-tier, mechanical work) and `"complex"` (Sonnet-tier, reasoning required).
- **FR-7:** `README.md` sprint.json schema table must include the `complexity` field row.

---

## 5. Non-Goals (Out of Scope)

- Orchestrator model routing based on the field (F-2)
- Merge Strategist agent (F-3)
- Changes to `lib/run.md` or `lib/worker.md`
- Interactive or UI-based classification — auto-classification only; users override by editing sprint.json manually
- Per-project config file for classification rules

---

## 6. Technical Considerations

- `commands/sprint.md` is the only prompt file that needs substantive changes — it defines the schema and conversion rules.
- `CLAUDE.md` and `README.md` need small doc additions only.
- The field sits alongside `verify`, `size`, `type` in the story JSON object — same pattern, same placement.
- Classification happens at sprint.json generation time (in `/sprint`), not at run time. Workers never read their own complexity field — only the orchestrator uses it (in F-2).

---

## 7. Success Metrics

- Every story in a newly generated sprint.json has a `complexity` field set to `"simple"` or `"complex"`
- Running `/sprint` on a Feature doc with both simple (rename, scaffold) and complex (multi-file logic) stories produces correctly classified output
- An existing sprint.json without `complexity` fields still runs without error (orchestrator defaults to `"complex"`)

---

## 8. Open Questions

- Should the `/sprint` converter prompt include examples of borderline stories to help users understand the boundary? (e.g., "adding a constant to a config file = simple; adding a config file that multiple modules import = complex") Recommend yes — include 2-3 examples in the classification rule.
