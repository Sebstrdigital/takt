# Feature: Epic Loops All Features

## 1. Introduction / Overview

After a user runs `/epic` and confirms the Feature breakdown, they currently have to manually invoke `/feature` for each subsequent Feature. The skill hands off after the first Feature and leaves the user as the coordinator between `/epic` and each `/feature` invocation. This Feature fixes that: `/epic` automatically runs the full `/feature` interview for every Feature in the confirmed breakdown — in sequence — before presenting the `/sprint` hand-off. The user still goes through each Feature's why/what/what-not gates (those live in `/feature`), but they don't need to manually trigger each one.

---

## 2. Goals

- `/epic` drives the full planning session from Feature breakdown confirmation through to all Feature docs written — no manual re-invocation between Features
- After all Feature docs are written, `/epic` presents a summary of all docs created and offers to hand off to `/sprint`
- The user's why/what/what-not gates in `/feature` are preserved for every Feature

---

## 3. User Stories

### US-001: /epic iterates through all Features after breakdown confirmation

**Description:** As a takt user, I want /epic to loop through all Features automatically so that I can complete the full planning session in one go without manually triggering /feature for each Feature.

**Acceptance Criteria:**
- [ ] After the Feature breakdown is confirmed in /epic, the skill invokes /feature for F-1, waits for the Feature doc to be written, then invokes /feature for F-2, and so on through all Features in the confirmed list
- [ ] Each Feature's full why/what/what-not interview runs as normal — the user still goes through the gates for each Feature
- [ ] After all Feature docs are written, /epic presents a summary: "N Feature docs created: feature-X.md, feature-Y.md, feature-Z.md" and offers to hand off to /sprint

---

## 4. Functional Requirements

- **FR-1:** After the Feature breakdown gate is confirmed in `commands/epic.md`, the Step 6 review gate must be replaced with a loop: invoke `/feature` for each Feature in the confirmed list, in order (F-1 first, F-N last). Each invocation passes the Feature's name and scope from the Epic doc as context.
- **FR-2:** The loop must be sequential — F-2 does not start until F-1's Feature doc is written and confirmed.
- **FR-3:** After all Features in the loop are complete, `/epic` presents a completion summary listing all Feature doc filenames created.
- **FR-4:** The completion summary offers a single next step: "Run /sprint to convert all Feature docs to sprint.json."
- **FR-5:** If the user abandons mid-loop (e.g. says "stop" or "done for now"), the already-written Feature docs are preserved and the user is told which Features remain unplanned.

---

## 5. Non-Goals (Out of Scope)

- Changes to the `/feature` skill itself — F-1 only changes `/epic`'s behaviour after breakdown confirmation
- Changes to `/sprint` — handled in F-3
- The quick path for small changes — handled in F-4
- Parallel Feature planning — Features are always planned in sequence
- Skipping any Feature's why/what/what-not gates — every Feature still gets the full interview

---

## 6. Technical Considerations

- `commands/epic.md` is the only file that changes — it's a prompt file (markdown), not code
- The loop is implemented as prose instructions in the skill prompt: "for each Feature in the confirmed breakdown, invoke /feature with the Feature's name and scope as context, then proceed to the next Feature"
- The installed copy at `~/.claude/commands/epic.md` must also be updated — `install.sh` handles this on next run

---

## 7. Success Metrics

- A user running `/epic` for a 3-Feature initiative completes all 3 Feature docs in one session without manually re-invoking `/feature`
- No Feature in the confirmed breakdown is skipped

---

## 8. Open Questions

- Should /epic ask "continue to F-2?" between Features, or proceed automatically? Recommend: proceed automatically — the user can always say "stop" if they want to pause. Adding a confirmation gate between each Feature re-introduces the overhead this Feature is meant to remove.
