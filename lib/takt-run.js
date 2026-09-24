// takt-run.js — takt sprint execution as a Claude Code Workflow script.
//
// Invoked by the takt orchestrator (run.md Phase 2) via:
//   Workflow({ scriptPath: "<abs>/.claude/lib/takt/takt-run.js", args: { ... } })
//
// The script owns Phases 2-4 (stories → verify → review gate) with deterministic
// JS control flow. Agents do all file and git work; the script never touches the
// filesystem. The session agent keeps Phase 0/1 (setup) and 4b-7 (local
// validation, PR, retro, report).
//
// args (all paths absolute):
//   projectDir        string   git root of the project (must equal the session cwd — worktrees branch from it)
//   branch            string   feature branch name (already checked out)
//   baseBranch        string   branch the PR diff is measured against (default "main")
//   taktLib           string   directory holding worker.md / verifier.md / final-gate.md / tooling.md
//   stories           array    sprint.json userStories with passes:false (full story objects)
//   waves             array    array of arrays of story ids; omitted/empty → one story per wave
//   workerRunner      string   "anthropic" (default) | "external"
//   externalCmd       string   external CLI template with {STORY_ID} placeholder (workerRunner=external)
//   finalGate         boolean  run the Opus review gate (default true)
//   maxVerifyCycles   number   default 3
//   maxReviewCycles   number   default 2
//
// Returns { stories, verification, gate, blocked } — see bottom of file.

export const meta = {
  name: 'takt-run',
  description: 'takt sprint: story waves in worktrees, merge, hidden-scenario verification, Opus review gate',
  whenToUse: 'Started by the takt orchestrator after Phase 1. Not meant to be run by hand.',
  phases: [
    { title: 'Stories', detail: 'one fresh worker per story; waves run in parallel worktrees' },
    { title: 'Verify', detail: 'independent verifier against hidden BDD scenarios; verify-fix loop' },
    { title: 'Gate', detail: 'unified 4-pass review; review-fix loop', model: 'opus' },
  ],
}

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------

const A = args || {}
const projectDir = A.projectDir
const branch = A.branch
const baseBranch = A.baseBranch || 'main'
const taktLib = A.taktLib
const stories = Array.isArray(A.stories) ? A.stories : []
const workerRunner = A.workerRunner || 'anthropic'
const externalCmd = A.externalCmd || ''
const finalGate = A.finalGate !== false
const maxVerify = typeof A.maxVerifyCycles === 'number' ? A.maxVerifyCycles : 3
const maxReview = typeof A.maxReviewCycles === 'number' ? A.maxReviewCycles : 2

if (!projectDir || !branch || !taktLib) {
  throw new Error('takt-run: args.projectDir, args.branch and args.taktLib are required (absolute paths)')
}
if (!stories.length) {
  throw new Error('takt-run: args.stories is empty — nothing to run')
}

const byId = {}
for (const s of stories) byId[s.id] = s

const waves = (Array.isArray(A.waves) && A.waves.length)
  ? A.waves.map(w => w.filter(id => byId[id]))
  : stories.slice().sort((a, b) => (a.priority || 0) - (b.priority || 0)).map(s => [s.id])

const EPHEMERAL = 'sprint.json bugs.json review-comments.json .takt/workbooks .takt/scenarios.json .takt/session.json .takt/review.diff .takt/sprint-snapshot.json .takt/validation-report.md'

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const WORKBOOK = {
  type: 'object',
  properties: {
    storyId: { type: 'string' },
    status: { type: 'string', enum: ['done', 'blocked'] },
    workDir: { type: 'string', description: 'absolute path the worker edited in (output of pwd)' },
    branch: { type: 'string', description: 'output of git rev-parse --abbrev-ref HEAD in workDir' },
    startedAt: { type: 'number', description: 'unix seconds, from date -u +%s at start' },
    finishedAt: { type: 'number', description: 'unix seconds, from date -u +%s at end' },
    filesChanged: { type: 'array', items: { type: 'string' } },
    workbookPath: { type: 'string' },
    blockers: { type: 'string' },
    summary: { type: 'string' },
  },
  required: ['storyId', 'status', 'workDir', 'branch', 'startedAt', 'finishedAt', 'filesChanged', 'workbookPath'],
}

const MERGE = {
  type: 'object',
  properties: {
    merged: { type: 'array', items: { type: 'string' } },
    failed: {
      type: 'array',
      items: { type: 'object', properties: { id: { type: 'string' }, reason: { type: 'string' } }, required: ['id', 'reason'] },
    },
    notes: { type: 'string' },
  },
  required: ['merged', 'failed'],
}

const VERDICT = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASSED', 'FAILED'] },
    bugs: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          description: { type: 'string' },
          expected: { type: 'string' },
          actual: { type: 'string' },
        },
        required: ['id', 'description', 'expected', 'actual'],
      },
    },
    notes: { type: 'string' },
  },
  required: ['verdict', 'bugs'],
}

const GATE = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASSED', 'BLOCKED'] },
    mustFix: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          pass: { type: 'string' },
          file: { type: 'string' },
          description: { type: 'string' },
        },
        required: ['id', 'description'],
      },
    },
    suggestionCount: { type: 'number' },
    summary: { type: 'string' },
  },
  required: ['verdict', 'mustFix'],
}

const COMMIT = {
  type: 'object',
  properties: {
    committed: { type: 'boolean' },
    sha: { type: 'string' },
    notes: { type: 'string' },
  },
  required: ['committed'],
}

// ---------------------------------------------------------------------------
// Prompt builders (lean — instructions live on disk in taktLib)
// ---------------------------------------------------------------------------

function workerPrompt(story, attempt, priorFailure) {
  const retry = priorFailure
    ? `\n## Previous attempt failed\n${priorFailure}\nUnderstand why before changing anything.\n`
    : ''
  return `# Story Assignment: ${story.id} - ${story.title}

## Working directory
Run \`pwd\` first. That directory is your working directory (it may be a git worktree of ${projectDir}).
Use absolute paths under it for every file operation. Never \`cd\`.
Also run \`git rev-parse --abbrev-ref HEAD\` once and report it as \`branch\`.
Run \`date -u +%s\` at the start and at the end; report as startedAt / finishedAt.

## Story
${JSON.stringify(story, null, 2)}
${retry}
## Instructions
Read ${taktLib}/worker.md for your instructions.
Write your workbook to ${projectDir}/.takt/workbooks/workbook-${story.id}.md (absolute path, main checkout — NOT the worktree).
Do NOT run git commands other than the single rev-parse above. Do NOT modify sprint.json.
Return status "done" only if every acceptance criterion is met; otherwise "blocked" with the reason in blockers.
Attempt ${attempt}.`
}

function externalWorkerPrompt(story) {
  const cmd = externalCmd.split('{STORY_ID}').join(story.id)
  return `# External worker dispatch: ${story.id} - ${story.title}

Run \`pwd\` and report it as workDir; run \`git rev-parse --abbrev-ref HEAD\` and report it as branch.
Run \`date -u +%s\` before and after the command; report as startedAt / finishedAt.

Run this command from the working directory (use a subshell, do not cd the session):
\`\`\`
( cd "$(pwd)" && ${cmd} )
\`\`\`
Wait for it to exit. Then run \`git status --short\` and report every changed path as filesChanged.
If ${projectDir}/.takt/workbooks/workbook-${story.id}.md does not exist afterwards, create it with the sections
Decisions / Files Changed / Blockers Encountered / Notes for Merge from what you observed.
status = "done" if the command exited 0 and changed files, else "blocked" with stderr tail in blockers.
Do NOT run any other git command. Do NOT modify sprint.json.`
}

function mergePrompt(waveIndex, entries) {
  const items = entries.map((e, i) => `${i + 1}. ${e.story.id} — "${e.story.title}"
   workDir: ${e.result.workDir}
   branch: ${e.result.branch}
   startedAt: ${e.result.startedAt}  finishedAt: ${e.result.finishedAt}
   workbook: ${e.result.workbookPath}
   files: ${e.result.filesChanged.join(', ') || '(none reported)'}`).join('\n')

  return `# takt merge stage — wave ${waveIndex + 1}

Project: ${projectDir}
Feature branch: ${branch} (checked out in ${projectDir})
Ephemeral paths that must NEVER be staged: ${EPHEMERAL}

Process the entries below IN THE GIVEN ORDER (already sorted to minimise conflicts). For each entry:

A. If workDir == ${projectDir} (worker edited in place — the checkout may hold unrelated dirty files, so stage ONLY the story's files):
   1. \`git -C ${projectDir} add -- <each path in files>\` (paths relative to ${projectDir}; skip any path in the ephemeral list). Never \`add -A\` here.
   2. \`git -C ${projectDir} commit -m "feat: <id> - <title>"\`. If nothing to commit → record in failed with reason "no changes".

B. Else (workDir is a worktree):
   1. \`git -C <workDir> add -A\` then \`git -C <workDir> reset -q -- ${EPHEMERAL}\`
   2. \`git -C <workDir> commit -m "feat: <id> - <title>"\`. If nothing to commit → failed "no changes", then still clean up (step 5).
   3. \`git -C ${projectDir} merge --no-ff <branch> -m "feat: <id> - <title>"\`
   4. On conflict: read the workbook (Decisions, Files Changed, Notes for Merge) and resolve so BOTH stories' behaviour survives. Run the project's test command if CLAUDE.md names one. Commit the resolution. If you cannot resolve safely: \`git -C ${projectDir} merge --abort\`, record in failed with the conflicting files as reason, and continue with the next entry.
   5. Cleanup, always: \`git -C ${projectDir} worktree remove --force <workDir>\` then \`git -C ${projectDir} branch -D <branch>\`.

C. After a successful commit/merge, update sprint.json (mechanical, exact):
   \`\`\`
   jq --arg id "<id>" --argjson s <startedAt> --argjson e <finishedAt> \\
     '(.userStories[] | select(.id == $id)) |= (.passes = true | .startTime = $s | .endTime = $e)' \\
     ${projectDir}/sprint.json > ${projectDir}/sprint.json.tmp && mv ${projectDir}/sprint.json.tmp ${projectDir}/sprint.json
   \`\`\`
   For a failed entry set only startTime/endTime, leave passes false.

Never \`git push\`. Never touch ${baseBranch}. Never delete a worktree whose merge is still unresolved.

## Entries
${items}

Return merged (ids), failed ([{id, reason}]) and short notes.`
}

function verifierPrompt(cycle) {
  return `# Scenario Verification (cycle ${cycle})

## Project Working Directory
${projectDir}

## Scenarios File
${projectDir}/.takt/scenarios.json

## Instructions
Read ${taktLib}/verifier.md for your instructions.
Read the scenarios file and verify each scenario against the codebase in ${projectDir}.
Write bugs.json to ${projectDir} as verifier.md describes when any scenario fails.
Return verdict PASSED only if 100% of scenarios pass; otherwise FAILED with the bugs array
(behavioral descriptions only — never scenario ids or Given/When/Then text).`
}

function bugFixPrompt(bug, kind) {
  return `# ${kind}: ${bug.id}

## Project Working Directory
${projectDir}

## ${kind === 'Bug Fix' ? 'Bug' : 'Finding'}
${bug.description}
${bug.expected ? `Expected: ${bug.expected}\nActual: ${bug.actual}` : ''}${bug.file ? `File: ${bug.file}` : ''}

## Instructions
Read ${taktLib}/tooling.md for optional tooling.
Fix it with the smallest change that makes the expected behaviour true. No unrelated changes.
Run the project's typecheck/lint/tests if CLAUDE.md names them and include real output in summary.
Run \`pwd\` → workDir, \`git rev-parse --abbrev-ref HEAD\` → branch, \`date -u +%s\` at start/end.
Write a short workbook to ${projectDir}/.takt/workbooks/workbook-${bug.id}.md.
Do NOT run other git commands. Do NOT modify sprint.json. Do NOT read ${projectDir}/.takt/scenarios.json.`
}

function commitPrompt(message, files) {
  const list = (files || []).filter(f => f && !EPHEMERAL.split(' ').some(e => f === e || f.startsWith(e + '/')))
  const stage = list.length
    ? `\`git -C ${projectDir} add -- ${list.join(' ')}\` (paths relative to ${projectDir}; skip any that do not exist)`
    : `\`git -C ${projectDir} status --short\`, then \`git -C ${projectDir} add -- <only the modified/new source files, never: ${EPHEMERAL}>\``
  return `# takt commit stage

In ${projectDir}: ${stage}, then \`git -C ${projectDir} commit -m "${message}"\`.
Never \`git add -A\` — the checkout may hold unrelated dirty files. If nothing to commit, return committed=false.
Return the new commit sha. Never push. No other git commands.`
}

function gatePrompt(cycle) {
  return `# Review Gate (cycle ${cycle})

## Project Working Directory
${projectDir}

## Instructions
First write the diff: \`git -C ${projectDir} diff ${baseBranch}...HEAD > ${projectDir}/.takt/review.diff\`
Then read ${taktLib}/final-gate.md for your instructions and run all four passes against ${projectDir}/.takt/review.diff.
Read ${projectDir}/CLAUDE.md for project conventions. If ${projectDir}/.takt/final-gate-checklist.md exists, enforce it too.
Write review-comments.json to ${projectDir} exactly as final-gate.md describes.
Return verdict PASSED (zero must-fix) or BLOCKED with every must-fix finding listed in mustFix.`
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function overlapOrder(entries) {
  // Fewest shared files with the already-merged set first; priority breaks ties.
  const merged = new Set()
  const remaining = entries.slice()
  const ordered = []
  while (remaining.length) {
    remaining.sort((a, b) => {
      const oa = a.result.filesChanged.filter(f => merged.has(f)).length
      const ob = b.result.filesChanged.filter(f => merged.has(f)).length
      if (oa !== ob) return oa - ob
      return (a.story.priority || 0) - (b.story.priority || 0)
    })
    const next = remaining.shift()
    ordered.push(next)
    next.result.filesChanged.forEach(f => merged.add(f))
  }
  return ordered
}

function workerType(story) {
  return story.complexity === 'simple' ? 'grunt' : 'builder'
}

async function runWorker(story, isolate, attempt, priorFailure) {
  const opts = {
    label: `story:${story.id}${attempt > 1 ? ':retry' : ''}`,
    phase: 'Stories',
    schema: WORKBOOK,
    agentType: attempt > 1 ? 'heavy' : (workerRunner === 'external' ? 'grunt' : workerType(story)),
  }
  if (isolate) opts.isolation = 'worktree'
  const prompt = workerRunner === 'external' ? externalWorkerPrompt(story) : workerPrompt(story, attempt, priorFailure)
  return agent(prompt, opts)
}

// ---------------------------------------------------------------------------
// Phase 2 — Stories
// ---------------------------------------------------------------------------

phase('Stories')

const outcome = {}          // id → { status: 'done'|'blocked', reason?, files }
const blocked = new Set()

function depsBlocked(story) {
  return (story.dependsOn || []).some(d => blocked.has(d))
}

for (let w = 0; w < waves.length; w++) {
  const ids = waves[w]
  const runnable = ids.filter(id => !depsBlocked(byId[id]))
  ids.filter(id => depsBlocked(byId[id])).forEach(id => {
    blocked.add(id)
    outcome[id] = { status: 'blocked', reason: 'dependency blocked', files: [] }
  })
  if (!runnable.length) continue

  const isolate = runnable.length > 1
  log(`wave ${w + 1}/${waves.length}: ${runnable.join(', ')}${isolate ? ' (worktrees)' : ''}`)

  // One attempt, then one retry on a higher tier with the failure context.
  const results = await parallel(runnable.map(id => async () => {
    const story = byId[id]
    let r = await runWorker(story, isolate, 1, null)
    if (!r || r.status !== 'done') {
      const why = r ? (r.blockers || r.summary || 'worker returned blocked') : 'worker returned no result'
      log(`${id}: attempt 1 failed (${why.slice(0, 120)}) — retrying on heavy`)
      // A failed isolated attempt may have left a worktree behind; the merge stage cleans it up
      // only if we hand it over, so keep the first result for cleanup.
      const first = r
      r = await runWorker(story, isolate, 2, why)
      if (first && first.workDir && first.workDir !== projectDir) {
        r = r || {}
        r.staleWorkDir = first.workDir
        r.staleBranch = first.branch
      }
    }
    return { story, result: r }
  }))

  const entries = []
  for (const e of results.filter(Boolean)) {
    const { story, result } = e
    if (!result || result.status !== 'done') {
      blocked.add(story.id)
      outcome[story.id] = { status: 'blocked', reason: result ? (result.blockers || 'blocked after retry') : 'no result after retry', files: [] }
      if (result && (result.workDir || result.staleWorkDir)) entries.push({ story, result, cleanupOnly: true })
      continue
    }
    entries.push({ story, result })
  }

  if (!entries.length) continue

  const ordered = overlapOrder(entries.filter(e => !e.cleanupOnly))
  const cleanup = entries.filter(e => e.cleanupOnly)
  const mergeType = isolate ? 'builder' : 'grunt'

  let prompt = mergePrompt(w, ordered)
  if (cleanup.length) {
    prompt += `\n\n## Cleanup only (story blocked — do NOT merge, just remove)\n` + cleanup.map(e => {
      const dirs = [e.result.workDir, e.result.staleWorkDir].filter(d => d && d !== projectDir)
      const brs = [e.result.branch, e.result.staleBranch].filter(Boolean)
      return `- ${e.story.id}: worktrees ${dirs.join(', ') || '(none)'}; branches ${brs.join(', ') || '(none)'} — \`git -C ${projectDir} worktree remove --force <dir>\` then \`git -C ${projectDir} branch -D <branch>\`. Set startTime/endTime in sprint.json (${e.result.startedAt || 0}/${e.result.finishedAt || 0}), leave passes false.`
    }).join('\n')
  }
  // Retried stories may also have a stale worktree from attempt 1.
  const stale = ordered.filter(e => e.result.staleWorkDir)
  if (stale.length) {
    prompt += `\n\n## Stale worktrees from failed first attempts (remove after the merge above, never merge them)\n` +
      stale.map(e => `- ${e.story.id}: ${e.result.staleWorkDir} / ${e.result.staleBranch || '(branch unknown — derive as worktree-<basename>)'}`).join('\n')
  }

  const merge = await agent(prompt, { label: `merge:wave-${w + 1}`, phase: 'Stories', schema: MERGE, agentType: mergeType })

  const mergedIds = new Set(merge ? merge.merged : [])
  for (const e of ordered) {
    if (mergedIds.has(e.story.id)) {
      outcome[e.story.id] = { status: 'done', files: e.result.filesChanged }
    } else {
      const f = merge && merge.failed.find(x => x.id === e.story.id)
      blocked.add(e.story.id)
      outcome[e.story.id] = { status: 'blocked', reason: f ? `merge: ${f.reason}` : 'merge stage returned no result', files: e.result.filesChanged }
    }
  }
  log(`wave ${w + 1}: merged ${mergedIds.size}/${ordered.length}`)
}

const storyReport = stories.map(s => ({ id: s.id, title: s.title, ...(outcome[s.id] || { status: 'blocked', reason: 'not scheduled', files: [] }) }))
const anyBlocked = storyReport.some(s => s.status !== 'done')

if (anyBlocked) {
  log(`stopping before verification — blocked: ${storyReport.filter(s => s.status !== 'done').map(s => s.id).join(', ')}`)
  return { stories: storyReport, verification: { ran: false }, gate: { ran: false }, blocked: storyReport.filter(s => s.status !== 'done').map(s => s.id) }
}

// ---------------------------------------------------------------------------
// Phase 3 — Verify (hidden scenarios; the script never sees scenarios.json)
// ---------------------------------------------------------------------------

phase('Verify')

let verification = { ran: true, verdict: 'FAILED', cycles: 0, openBugs: [] }
for (let cycle = 1; cycle <= maxVerify; cycle++) {
  verification.cycles = cycle
  const v = await agent(verifierPrompt(cycle), {
    label: `verify:${cycle}`, phase: 'Verify', schema: VERDICT, agentType: 'general-purpose', model: 'sonnet',
  })
  if (!v) { verification.openBugs = [{ id: 'VERIFIER', description: 'verifier returned no result' }]; break }
  if (v.verdict === 'PASSED') { verification.verdict = 'PASSED'; verification.openBugs = []; break }
  verification.openBugs = v.bugs
  if (cycle === maxVerify) break
  log(`verify ${cycle}: ${v.bugs.length} bug(s) — fixing`)
  const fixedFiles = []
  for (const bug of v.bugs) {
    const fx = await agent(bugFixPrompt(bug, 'Bug Fix'), { label: `fix:${bug.id}`, phase: 'Verify', schema: WORKBOOK, agentType: 'builder' })
    if (fx && fx.filesChanged) fixedFiles.push(...fx.filesChanged)
  }
  await agent(commitPrompt(`fix: verify cycle ${cycle} - ${v.bugs.map(b => b.id).join(', ')}`, fixedFiles), {
    label: `commit:verify-${cycle}`, phase: 'Verify', schema: COMMIT, agentType: 'grunt',
  })
}

if (verification.verdict !== 'PASSED') {
  return { stories: storyReport, verification, gate: { ran: false }, blocked: [] }
}

// ---------------------------------------------------------------------------
// Phase 4 — Review gate (Opus, mandatory unless finalGate=false)
// ---------------------------------------------------------------------------

let gate = { ran: false, verdict: 'SKIPPED', cycles: 0, openMustFix: [], suggestionCount: 0 }
if (finalGate) {
  phase('Gate')
  gate = { ran: true, verdict: 'BLOCKED', cycles: 0, openMustFix: [], suggestionCount: 0 }
  for (let cycle = 1; cycle <= maxReview; cycle++) {
    gate.cycles = cycle
    const g = await agent(gatePrompt(cycle), {
      label: `gate:${cycle}`, phase: 'Gate', schema: GATE, agentType: 'general-purpose', model: 'opus',
    })
    if (!g) { gate.openMustFix = [{ id: 'GATE', description: 'review gate returned no result' }]; break }
    gate.suggestionCount = g.suggestionCount || 0
    if (g.verdict === 'PASSED') { gate.verdict = 'PASSED'; gate.openMustFix = []; break }
    gate.openMustFix = g.mustFix
    if (cycle === maxReview) break
    log(`gate ${cycle}: ${g.mustFix.length} must-fix — fixing`)
    const fixedFiles = []
    for (const f of g.mustFix) {
      const fx = await agent(bugFixPrompt(f, 'Review Fix'), { label: `fix:${f.id}`, phase: 'Gate', schema: WORKBOOK, agentType: 'builder' })
      if (fx && fx.filesChanged) fixedFiles.push(...fx.filesChanged)
    }
    await agent(commitPrompt(`fix: review cycle ${cycle} - ${g.mustFix.map(f => f.id).join(', ')}`, fixedFiles), {
      label: `commit:review-${cycle}`, phase: 'Gate', schema: COMMIT, agentType: 'grunt',
    })
  }
}

return { stories: storyReport, verification, gate, blocked: [] }
