# takt First-Run Config — .takt/config.json

This file is read by the orchestrator (run.md Phase 0.1) only when `.takt/config.json` is missing or incomplete. It is not read on subsequent runs.

---

## Steps

1. `mkdir -p .takt`
2. Check if `.takt/config.json` exists and contains `final_gate`, `local_validation`, and `worker_runner` keys.
3. **If the file is missing or keys are absent**, prompt the user once via `AskUserQuestion` for each missing setting, then write `.takt/config.json` with the answers:

   ```
   AskUserQuestion:
     questions:
       - question: "Phase 4b — Final Gate (Opus reviewer). Previously caught a stakeholder-facing production leak that two review cycles missed. Strongly recommended. Run for this project?"
         header: "final_gate"
         multiSelect: false
         options:
           - label: "Yes"
             description: "Run the final-gate agent on every takt run"
           - label: "No"
             description: "Skip the final-gate phase for this project"
       - question: "Phase 4b — Local Validation (runtime checks via .takt/local-validation.md). Run for this project?"
         header: "local_validation"
         multiSelect: false
         options:
           - label: "Yes"
             description: "Run the local-validation agent when .takt/local-validation.md exists"
           - label: "No"
             description: "Skip the local-validation phase for this project"
       - question: "Worker runner — who executes story implementations?"
         header: "worker_runner"
         multiSelect: false
         options:
           - label: "Anthropic"
             description: "Use Claude Agent tool (Sonnet/Haiku) — best quality, uses Anthropic token budget"
           - label: "External"
             description: "Use an external CLI (e.g. OpenCode) — saves Anthropic tokens"
   ```

4. **If `worker_runner` is `"external"`**, prompt for the external command:
   ```
   AskUserQuestion:
     question: "External worker command. Use {STORY_ID} as placeholder for the story ID."
     header: "worker_runner_external_cmd"
     default: "opencode run --dangerously-skip-permissions \"Implement user story {STORY_ID} found in sprint.json. Do this running /worker skill.\""
   ```
   If the user confirms the default or provides a custom command, store it in `worker_runner_external_cmd`.

5. Write `.takt/config.json` (using the user's answers, lowercased booleans):
   ```json
   {
     "final_gate": true,
     "local_validation": true,
     "worker_runner": "anthropic"
   }
   ```
   Or when external:
   ```json
   {
     "final_gate": true,
     "local_validation": true,
     "worker_runner": "external",
     "worker_runner_external_cmd": "opencode run --dangerously-skip-permissions \"Implement user story {STORY_ID} found in sprint.json. Do this running /worker skill.\""
   }
   ```

6. **If `final_gate` is `false`** (either freshly chosen or already in the file), print a loud warning once and continue:
   ```
   [takt warn] FINAL GATE DISABLED for this project — static review alone has previously missed a stakeholder-facing production leak. Re-enable in .takt/config.json.
   ```
