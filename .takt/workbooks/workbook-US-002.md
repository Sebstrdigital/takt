# Workbook: US-002 - Add scenarios.json generation to /takt command

## Story
Add BDD scenario generation to the /takt slash command so that `.takt/scenarios.json` is created alongside `stories.json` when converting a PRD.

## Changes Made

### File: `/Users/sebastianstrandberg/Documents/git/takt/commands/takt.md`

Four additions were made:

1. **New "Scenario Generation" section** (inserted before "Checklist Before Saving")
   - Explains why scenarios exist (independent verification, not copy-paste of acceptance criteria)
   - Documents the `.takt/scenarios.json` format with a concrete JSON example
   - Lists 7 scenario rules: 2-5 per story, BDD format, observable outcomes, not AC copy-paste, type field values, globally unique IDs, hidden from workers
   - Includes a writing guide with good/bad examples to steer the LLM

2. **Conversion Rules — new rule 14**
   - "Scenario generation: After writing stories.json, generate `.takt/scenarios.json` with 2-5 BDD scenarios per story. Scenarios describe observable behavioral outcomes, not implementation details. Create `.takt/` directory if it does not exist."

3. **Checklist update**
   - Added: `- [ ] **scenarios.json** generated at `.takt/scenarios.json` with 2-5 BDD scenarios per story`

4. **"After Creating stories.json" section update**
   - Changed opener to mention both files: "Once you have saved `stories.json` and `.takt/scenarios.json`..."
   - Added second checkmark line in the summary block: `✅ .takt/scenarios.json generated (hidden from workers, used by verifier)`

## Acceptance Criteria Verification

- [x] The /takt command includes instructions to generate `.takt/scenarios.json` alongside `stories.json` (Conversion Rule 14 + Scenario Generation section)
- [x] Scenario format documented: each story gets 2-5 BDD scenarios with id, given, when, then, and type fields (JSON schema in Scenarios File Format sub-section)
- [x] Command instructions specify scenarios must describe observable behavioral outcomes, not copy-pasted acceptance criteria (Scenario Rules 3 and 4, Scenario Writing Guide)

## Notes
- The Scenario Generation section is placed before the Checklist so it reads naturally in document order (content, then checklist, then summary)
- Scenario type field supports three values: "behavioral", "contract", "edge" — giving the LLM vocabulary to classify scenarios accurately
- The "Hidden from workers" rule is explicit: `.takt/` is gitignored and only `verifier.md` reads this file
