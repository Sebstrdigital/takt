# Feature: Quick Path — Why/What/What-Not to Sprint

## 1. Introduction / Overview

For small or clear changes, the full Epic → Feature → Sprint ceremony is overkill. A user who wants to "add a sorting toggle to the list" doesn't need an Epic doc or a Feature doc — they need `sprint.json` + `.takt/scenarios.json` and a running takt. This Feature adds a quick path to `/takt`: always run a lean why/what/what-not interview (3 questions), then convert the answers directly to `sprint.json` + `.takt/scenarios.json`. No Feature doc artifact is created. The quality gate (scenarios.json) is always preserved. Business-driven development at conversation speed.

---

## 2. Goals

- A user can go from plain-language description to running takt in one short interview session
- The why/what/what-not interview is always run — no conditional "if clear enough, skip" logic
- scenarios.json is always generated — the quality gate is never skipped
- If the interview produces more than 5 stories, the user is warned and offered a Feature doc path instead

---

## 3. User Stories

### US-001: /takt offers a quick path option

**Description:** As a takt user, I want to be able to start a sprint from a plain-language description without writing a Feature doc so that small changes have proportionally small planning overhead.

**Acceptance Criteria:**
- [ ] When /takt is invoked (and no sprint.json or Feature docs exist), it presents a "Quick path" option alongside the standard "Full flow" option
- [ ] When the user selects Quick path, /takt runs a 3-question why/what/what-not interview (not a gated multi-round flow — just 3 focused questions in one prompt)
- [ ] After the interview, /takt generates sprint.json and .takt/scenarios.json directly from the answers — no Feature doc artifact is created

### US-002: Story count guard and quality gate

**Description:** As a takt user, I want the quick path to warn me if my change is too large for a quick sprint so that I don't accidentally underplan a complex initiative.

**Acceptance Criteria:**
- [ ] If the why/what/what-not answers would produce more than 5 stories, /takt warns the user and offers to save the answers as a Feature doc instead of proceeding to sprint.json
- [ ] .takt/scenarios.json is always generated — the quick path never skips scenario generation

---

## 4. Functional Requirements

- **FR-1:** In `commands/takt.md`, the "Case D: No artifacts found" path must add a third option: "Quick path — describe a change and go straight to sprint.json" alongside the existing "Full flow" and "Skip Epic" options.
- **FR-2:** When the user selects Quick path, `/takt` asks 3 questions in a single AskUserQuestion prompt:
  - Why: What problem does this solve or what goal does it achieve?
  - What: What should be built or changed? (be specific — list the key behaviours)
  - What not: What is explicitly out of scope?
- **FR-3:** `/takt` converts the why/what/what-not answers directly into `sprint.json` using the same story format, field rules, and complexity classification as `/sprint`. No Feature doc is created or saved.
- **FR-4:** `/takt` generates `.takt/scenarios.json` from the sprint.json stories using the same BDD scenario rules as `/sprint`. This step is mandatory — it cannot be skipped.
- **FR-5:** If the generated sprint.json would contain more than 5 stories, `/takt` pauses before saving and warns the user: "This looks like more than a quick change (N stories). Would you like to save this as a Feature doc instead, or proceed with the quick sprint?" If the user proceeds, sprint.json is saved as-is.
- **FR-6:** After sprint.json and scenarios.json are saved, `/takt` presents the standard summary (branch, story count, story list) and offers to `start takt`.

---

## 5. Non-Goals (Out of Scope)

- Saving a Feature doc artifact — the quick path never creates a Feature doc
- Skipping scenarios.json — always generated, no exceptions
- The full Epic/Feature/Sprint flow — unchanged
- Changes to `/epic`, `/feature`, or `/sprint` (F-1, F-2, F-3)
- Persisting the why/what/what-not answers anywhere beyond sprint.json and scenarios.json

---

## 6. Technical Considerations

- `commands/takt.md` is the only file that changes
- The quick path reuses the same story format, complexity classification, and scenario generation rules already defined in `commands/sprint.md` — no new rules needed
- The installed copy at `~/.claude/commands/takt.md` must also be updated — `install.sh` handles this on next run

---

## 7. Success Metrics

- A user can go from "I want to add X" to `start takt` in under 5 minutes via the quick path
- scenarios.json is generated on every quick path run (zero exceptions)

---

## 8. Open Questions

- Should the quick path's why/what/what-not be a single 3-question AskUserQuestion prompt, or 3 sequential prompts? Recommend: single prompt with 3 questions — minimises round trips and keeps the "quick" feel.
- Should the quick path support waves/parallel mode? Recommend: no — quick path is for small changes that fit in one sequential sprint. If the user needs parallel execution, they're in Feature doc territory.
