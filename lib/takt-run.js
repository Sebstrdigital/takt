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
//   finalGate         boolean  run the Fable review gate (default true)
//   maxVerifyCycles   number   default 3
//   maxReviewCycles   number   default 2
//
// Returns { stories, verification, gate, blocked } — see bottom of file.

export const meta = {
  name: 'takt-run',
  description: 'takt sprint: story waves in worktrees, merge, hidden-scenario verification, Fable review gate',
  whenToUse: 'Started by the takt orchestrator after Phase 1. Not meant to be run by hand.',
  phases: [
    { title: 'Stories', detail: 'one fresh worker per story; waves run in parallel worktrees' },
    { title: 'Verify', detail: 'independent verifier against hidden BDD scenarios; verify-fix loop' },
    { title: 'Gate', detail: 'unified 4-pass review; review-fix loop', model: 'fable' },
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

const EPHEMERAL = 'sprint.json bugs.json review-comments.json .takt/workbooks .takt/scenarios.json .takt/session.json .takt/review.diff .takt/sprint-snapshot.json .takt/validation-report.md .takt/run-report.json'
const EPHEMERAL_LIST = EPHEMERAL.split(' ')

// Per-stage timing, reported by agents from `date -u +%s` (the script has no clock).
const timing = { verify: [], gate: [], fixes: [], merges: [], commits: [] }
function stamp(list, meta, r) {
  if (r && typeof r.startedAt === 'number' && typeof r.finishedAt === 'number') {
    list.push({ ...meta, startedAt: r.startedAt, finishedAt: r.finishedAt })
  }
}

// Workers report filesChanged as they see them — sometimes absolute, sometimes including the
// workbook they were told to write. Normalise to paths relative to `base` (the worktree or
// projectDir) and drop every ephemeral path so the merge/commit stages can never stage them.
function cleanFiles(files, base) {
  const bases = [base, projectDir].filter(Boolean).map(b => b.replace(/\/+$/, '') + '/')
  const out = []
  for (const raw of files || []) {
    if (!raw || typeof raw !== 'string') continue
    let f = raw.trim()
    for (const b of bases) if (f.startsWith(b)) f = f.slice(b.length)
    f = f.replace(/^\.\//, '')
    if (!f || f.startsWith('/')) continue
    if (EPHEMERAL_LIST.some(e => f === e || f.startsWith(e + '/'))) continue
    if (!out.includes(f)) out.push(f)
  }
  return out
}

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
    committed: { type: 'boolean' },
    sha: { type: 'string' },
  },
  required: ['storyId', 'status', 'workDir', 'branch', 'startedAt', 'finishedAt', 'filesChanged', 'workbookPath', 'committed'],
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
    startedAt: { type: 'number', description: 'unix seconds from date -u +%s' },
    finishedAt: { type: 'number', description: 'unix seconds from date -u +%s' },
  },
  required: ['merged', 'failed'],
}

const VERDICT = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASSED', 'FAILED'] },
    bugsPath: { type: 'string', description: 'absolute path of the bugs.json the verifier wrote' },
    openBugIds: { type: 'array', items: { type: 'string' }, description: 'ids of bugs.json entries with status open after this cycle' },
    newBugCount: { type: 'number' },
    fixedBugCount: { type: 'number' },
    notes: { type: 'string' },
    startedAt: { type: 'number', description: 'unix seconds from date -u +%s' },
    finishedAt: { type: 'number', description: 'unix seconds from date -u +%s' },
  },
  required: ['verdict', 'openBugIds'],
}

const GATE = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASSED', 'BLOCKED'] },
    reviewPath: { type: 'string', description: 'absolute path of the review-comments.json the gate wrote' },
    openMustFixIds: { type: 'array', items: { type: 'string' }, description: 'ids of must-fix entries with status open after this cycle' },
    newMustFixCount: { type: 'number' },
    suggestionCount: { type: 'number' },
    summary: { type: 'string' },
    startedAt: { type: 'number', description: 'unix seconds from date -u +%s' },
    finishedAt: { type: 'number', description: 'unix seconds from date -u +%s' },
  },
  required: ['verdict', 'openMustFixIds'],
}

const COMMIT = {
  type: 'object',
  properties: {
    committed: { type: 'boolean' },
    sha: { type: 'string' },
    notes: { type: 'string' },
    startedAt: { type: 'number', description: 'unix seconds from date -u +%s' },
    finishedAt: { type: 'number', description: 'unix seconds from date -u +%s' },
  },
  required: ['committed'],
}

// ---------------------------------------------------------------------------
// Prompt builders (lean — instructions live on disk in taktLib)
// ---------------------------------------------------------------------------

function commitBlock(story, isolate, attempt) {
  const mode = isolate ? 'worktree' : 'in place'
  return `## Commit your story
Mode: ${mode}
Project root: ${projectDir}
Ephemeral paths (never stage): ${EPHEMERAL}
${isolate
    ? `You are in a worktree (workDir != project root). After validation: \`git add -A && git reset -q -- ${EPHEMERAL}\`, then \`git commit -m "feat: ${story.id} - ${story.title}"\` on the worktree's branch. Do NOT touch sprint.json — the merge stage updates it.`
    : `You are working in place (workDir == project root; the checkout may hold unrelated dirty files). After validation: \`git add -- <each file you changed>\` (skip anything in the ephemeral list, never \`add -A\`), then \`git commit -m "feat: ${story.id} - ${story.title}"\`. Then update sprint.json with the jq in worker.md (attempts = ${attempt}).`}
Nothing to commit → status "blocked", blockers "no changes". Report committed (boolean) and sha. (an external runner that made its own commits counts as committed when \`git rev-list --count <sha at start>..HEAD\` is >= 1; record \`git rev-parse HEAD\` at start to compare)
Follow the git allow-list in worker.md. Never push, merge, rebase, stash, branch, or checkout (except \`git checkout -- <path>\` on an in-place retry).`
}

function workerPrompt(story, attempt, priorFailure, isolate) {
  const workbookPath = `${projectDir}/.takt/workbooks/workbook-${story.id}.md`
  const retry = priorFailure
    ? `\n## Previous attempt failed\n${priorFailure}\nAttempt 1's workbook: ${workbookPath} — read it before changing anything.\nUnderstand why before changing anything.\n${isolate ? '' : `You own the first attempt's uncommitted edits. Read its workbook's Files Changed list and either finish and stage those files too, or revert them with \`git checkout -- <path>\` before you commit, and delete any new untracked files attempt 1 created that you do not finish. Nothing from attempt 1 may be left uncommitted.\n`}`
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
Write your workbook to ${workbookPath} (absolute path, main checkout — NOT the worktree).

${commitBlock(story, isolate, attempt)}
Return status "done" only if every acceptance criterion is met and the commit succeeded; otherwise "blocked" with the reason in blockers.
Attempt ${attempt}.`
}

function externalWorkerPrompt(story, attempt, isolate) {
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
Also report workbookPath. Read ${taktLib}/worker.md (Git and step 5) for the commit rules.

${commitBlock(story, isolate, attempt)}
Return status "done" only if the command succeeded and the commit succeeded; report committed and sha.
Do NOT run git commands other than status, rev-parse, add, reset and commit.`
}

function mergePrompt(waveIndex, entries) {
  const items = entries.map((e, i) => `${i + 1}. ${e.story.id} — "${e.story.title}"
   workDir: ${e.result.workDir}
   branch: ${e.result.branch}
   startedAt: ${e.result.startedAt}  finishedAt: ${e.result.finishedAt}  attempts: ${e.attempts || 1}
   workbook: ${e.result.workbookPath} (ephemeral — never stage it)
   files: ${cleanFiles(e.result.filesChanged, e.result.workDir).join(', ') || '(none reported)'}`).join('\n')

  return `# takt merge stage — wave ${waveIndex + 1}

Project: ${projectDir}
Feature branch: ${branch} (checked out in ${projectDir})
Ephemeral paths that must NEVER be staged: ${EPHEMERAL}

Each worker already committed its story on its own worktree branch. Do not commit story work yourself.
Process the entries below IN THE GIVEN ORDER (already sorted to minimise conflicts). For each entry (workDir is a worktree):

A. Before merging: \`git -C <workDir> status --short\` must be empty apart from paths in the ephemeral list and \`git -C ${projectDir} rev-list --count HEAD..<branch>\` must be >= 1. Otherwise do NOT merge: record the entry in failed with reason "nothing committed on branch", then do step C for it.
B. \`git -C ${projectDir} merge --no-ff <branch> -m "feat: <id> - <title>"\`
   On conflict: read the workbook (Decisions, Files Changed, Notes for Merge) and resolve so BOTH stories' behaviour survives. Run the project's test command if CLAUDE.md names one. Commit the resolution. If you cannot resolve safely: \`git -C ${projectDir} merge --abort\`, record in failed with the conflicting files as reason, and continue with the next entry.
C. Cleanup, always: \`git -C ${projectDir} worktree remove --force <workDir>\` then \`git -C ${projectDir} branch -D <branch>\` (never for a worktree whose merge is still unresolved).

D. After a successful merge, update sprint.json (mechanical, exact):
   \`\`\`
   jq --arg id "<id>" --argjson s <startedAt> --argjson e <finishedAt> --argjson a <attempts> \\
     '(.userStories[] | select(.id == $id)) |= (.passes = true | .startTime = $s | .endTime = $e | .attempts = $a)' \\
     ${projectDir}/sprint.json > ${projectDir}/sprint.json.tmp && mv ${projectDir}/sprint.json.tmp ${projectDir}/sprint.json
   \`\`\`
   For a failed entry set only startTime/endTime/attempts, leave passes false.

Never \`git push\`. Never touch ${baseBranch}. Never delete a worktree whose merge is still unresolved.

## Entries
${items}

Run \`date -u +%s\` at start and at end; report as startedAt / finishedAt.
Return merged (ids), failed ([{id, reason}]) and short notes.`
}

function verifierPrompt(cycle) {
  return `# Scenario Verification (cycle ${cycle})

## Project Working Directory
${projectDir}

## Scenarios File
${projectDir}/.takt/scenarios.json

## Bug File
${projectDir}/bugs.json
${cycle === 1
  ? 'Cycle 1: overwrite any existing bugs.json (it is stale from an aborted run). If the verdict is PASSED, delete it with `rm -f` so no stale file remains.'
  : `Cycle ${cycle}: read the existing bugs.json FIRST. Re-check every entry with status "open" (set "fixed" or leave open, same id, no duplicates), never delete entries, append new defects with cycle ${cycle} and continuing ids.`}

## Instructions
Read ${taktLib}/verifier.md for your instructions.
Read the scenarios file and verify each scenario against the codebase in ${projectDir}.
Write bugs.json as verifier.md describes (behavioral descriptions only — never scenario ids or Given/When/Then text).
Run \`date -u +%s\` at start and at end; report as startedAt / finishedAt.
Return verdict PASSED only if 100% of scenarios pass and no entry is open; otherwise FAILED with
bugsPath, openBugIds (every entry with status open), newBugCount and fixedBugCount for this cycle.`
}

function bugFixPrompt(id, kind, filePath) {
  const detail = kind === 'Bug Fix'
    ? 'description / expected / actual'
    : 'file, line, finding, evidence, impact'
  return `# ${kind}: ${id}

## Project Working Directory
${projectDir}

## Entry
Read ${filePath} and locate the entry with id "${id}". Fix exactly that entry (${detail}).
Do NOT edit ${filePath} — the next cycle sets the entry's status.

## Instructions
Read ${taktLib}/tooling.md for optional tooling.
Fix it with the smallest change that makes the expected behaviour true. No unrelated changes.
Run the project's typecheck/lint/tests if CLAUDE.md names them and include real output in summary.
Run \`pwd\` → workDir, \`git rev-parse --abbrev-ref HEAD\` → branch, \`date -u +%s\` at start/end.
Write a short workbook to ${projectDir}/.takt/workbooks/workbook-${id}.md.
Do NOT run any git command; a separate commit stage commits your fix. Return committed: false and no sha. Do NOT modify sprint.json. Do NOT read ${projectDir}/.takt/scenarios.json.`
}

function commitPrompt(message, files) {
  const list = cleanFiles(files, projectDir)
  const stage = list.length
    ? `\`git -C ${projectDir} add -- ${list.join(' ')}\` (paths relative to ${projectDir}; skip any that do not exist)`
    : `\`git -C ${projectDir} status --short\`, then \`git -C ${projectDir} add -- <only the modified/new source files, never: ${EPHEMERAL}>\``
  return `# takt commit stage

In ${projectDir}: ${stage}, then \`git -C ${projectDir} commit -m "${message}"\`.
Never \`git add -A\` — the checkout may hold unrelated dirty files. If nothing to commit, return committed=false.
Run \`date -u +%s\` at start and at end; report as startedAt / finishedAt.
Return the new commit sha. Never push. No other git commands.`
}

function gatePrompt(cycle) {
  return `# Review Gate (cycle ${cycle})

## Project Working Directory
${projectDir}

## Review File
${projectDir}/review-comments.json
${cycle === 1
  ? 'Cycle 1: overwrite any existing review-comments.json (it is stale from an aborted run).'
  : `Cycle ${cycle}: read the existing review-comments.json FIRST. For each must-fix with status "open", verify the fix in the current diff and set "fixed" or leave open with a note. Do not re-litigate fixed entries; a defect introduced by a fix is a new entry with cycle ${cycle}. Suggestions persist unchanged; append new findings with continuing ids.`}

## Instructions
First write the diff: \`git -C ${projectDir} diff ${baseBranch}...HEAD > ${projectDir}/.takt/review.diff\`
Then read ${taktLib}/final-gate.md for your instructions and run all four passes against ${projectDir}/.takt/review.diff.
Read ${projectDir}/CLAUDE.md for project conventions. If ${projectDir}/.takt/final-gate-checklist.md exists, enforce it too.
Write review-comments.json exactly as final-gate.md describes.
Run \`date -u +%s\` at start and at end; report as startedAt / finishedAt.
Return verdict PASSED (zero open must-fix) or BLOCKED with reviewPath, openMustFixIds (every must-fix with status open),
newMustFixCount and suggestionCount.`
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
  const prompt = workerRunner === 'external' ? externalWorkerPrompt(story, attempt, isolate) : workerPrompt(story, attempt, priorFailure, isolate)
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
    let attempts = 1
    let r = await runWorker(story, isolate, 1, null)
    if (!r || r.status !== 'done') {
      const why = r ? (r.blockers || r.summary || 'worker returned blocked') : 'worker returned no result'
      log(`${id}: attempt 1 failed (${why.slice(0, 120)}) — retrying on heavy`)
      // A failed isolated attempt may have left a worktree behind; the merge stage cleans it up
      // only if we hand it over, so keep the first result for cleanup.
      const first = r
      attempts = 2
      r = await runWorker(story, isolate, 2, why)
      if (first && first.workDir && first.workDir !== projectDir) {
        r = r || {}
        r.staleWorkDir = first.workDir
        r.staleBranch = first.branch
      }
    }
    // attempts is recorded into sprint.json by the worker (in place) or merge stage (worktrees) and surfaced in the story report,
    // so the retro can compute the first-attempt (Sonnet builder) success rate over time.
    return { story, result: r, attempts }
  }))

  const entries = []
  for (const e of results.filter(Boolean)) {
    const { story, result, attempts } = e
    if (!result || result.status !== 'done') {
      blocked.add(story.id)
      outcome[story.id] = { status: 'blocked', reason: result ? (result.blockers || 'blocked after retry') : 'no result after retry', files: [], attempts }
      if (isolate && result && (result.workDir || result.staleWorkDir)) entries.push({ story, result, attempts, cleanupOnly: true })
      continue
    }
    if (isolate && result.committed !== true) {
      blocked.add(story.id)
      outcome[story.id] = { status: 'blocked', reason: 'worker did not commit', files: [], attempts }
      if (result.workDir || result.staleWorkDir) entries.push({ story, result, attempts, cleanupOnly: true })
      continue
    }
    entries.push({ story, result, attempts })
  }

  if (!entries.length) continue

  // In place: the worker already committed its own story and updated sprint.json — no merge agent.
  if (!isolate) {
    let committedCount = 0
    for (const e of entries) {
      const r = e.result
      if (r.status === 'done' && r.committed) {
        committedCount++
        outcome[e.story.id] = { status: 'done', files: r.filesChanged, attempts: e.attempts }
      } else {
        blocked.add(e.story.id)
        outcome[e.story.id] = { status: 'blocked', reason: r.committed === false ? 'worker did not commit' : (r.blockers || 'blocked after retry'), files: r.filesChanged, attempts: e.attempts }
      }
    }
    log(`wave ${w + 1}: committed ${committedCount}/${runnable.length}`)
    continue
  }

  const ordered = overlapOrder(entries.filter(e => !e.cleanupOnly))
  const cleanup = entries.filter(e => e.cleanupOnly)

  let prompt = mergePrompt(w, ordered)
  if (cleanup.length) {
    prompt += `\n\n## Cleanup only (story blocked — do NOT merge, just remove)\n` + cleanup.map(e => {
      const dirs = [e.result.workDir, e.result.staleWorkDir].filter(d => d && d !== projectDir)
      const brs = [e.result.branch, e.result.staleBranch].filter(Boolean)
      return `- ${e.story.id}: worktrees ${dirs.join(', ') || '(none)'}; branches ${brs.join(', ') || '(none)'} — \`git -C ${projectDir} worktree remove --force <dir>\` then \`git -C ${projectDir} branch -D <branch>\`. Set startTime/endTime/attempts in sprint.json (${e.result.startedAt || 0}/${e.result.finishedAt || 0}/${e.attempts || 1}), leave passes false.`
    }).join('\n')
  }
  // Retried stories may also have a stale worktree from attempt 1.
  const stale = ordered.filter(e => e.result.staleWorkDir)
  if (stale.length) {
    prompt += `\n\n## Stale worktrees from failed first attempts (remove after the merge above, never merge them)\n` +
      stale.map(e => `- ${e.story.id}: ${e.result.staleWorkDir} / ${e.result.staleBranch || '(branch unknown — derive as worktree-<basename>)'}`).join('\n')
  }

  const merge = await agent(prompt, { label: `merge:wave-${w + 1}`, phase: 'Stories', schema: MERGE, agentType: 'builder' })
  stamp(timing.merges, { wave: w + 1 }, merge)

  const mergedIds = new Set(merge ? merge.merged : [])
  for (const e of ordered) {
    if (mergedIds.has(e.story.id)) {
      outcome[e.story.id] = { status: 'done', files: e.result.filesChanged, attempts: e.attempts }
    } else {
      const f = merge && merge.failed.find(x => x.id === e.story.id)
      blocked.add(e.story.id)
      outcome[e.story.id] = { status: 'blocked', reason: f ? `merge: ${f.reason}` : 'merge stage returned no result', files: e.result.filesChanged, attempts: e.attempts }
    }
  }
  log(`wave ${w + 1}: merged ${mergedIds.size}/${ordered.length}`)
}

const storyReport = stories.map(s => ({ id: s.id, title: s.title, ...(outcome[s.id] || { status: 'blocked', reason: 'not scheduled', files: [] }) }))
const anyBlocked = storyReport.some(s => s.status !== 'done')

if (anyBlocked) {
  log(`stopping before verification — blocked: ${storyReport.filter(s => s.status !== 'done').map(s => s.id).join(', ')}`)
  return { stories: storyReport, verification: { ran: false }, gate: { ran: false }, blocked: storyReport.filter(s => s.status !== 'done').map(s => s.id), timing }
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
  stamp(timing.verify, { cycle }, v)
  if (!v) { verification.openBugs = ['VERIFIER: no result']; break }
  if (v.verdict === 'PASSED') { verification.verdict = 'PASSED'; verification.openBugs = []; break }
  if (!v.openBugIds || v.openBugIds.length === 0) { verification.openBugs = ['VERIFIER: FAILED with no open ids']; break }
  verification.openBugs = v.openBugIds
  if (cycle === maxVerify) break
  const bugsPath = v.bugsPath || `${projectDir}/bugs.json`
  log(`verify ${cycle}: ${v.openBugIds.length} open bug(s) — fixing`)
  const fixedFiles = []
  for (const id of v.openBugIds) {
    const fx = await agent(bugFixPrompt(id, 'Bug Fix', bugsPath), { label: `fix:${id}`, phase: 'Verify', schema: WORKBOOK, agentType: 'builder' })
    stamp(timing.fixes, { id, phase: 'verify' }, fx)
    if (fx && fx.filesChanged) fixedFiles.push(...fx.filesChanged)
  }
  if (fixedFiles.length === 0) { log(`verify ${cycle}: no fix reported changed files — skipping commit stage — fix edits, if any, remain uncommitted`); continue }
  const cm = await agent(commitPrompt(`fix: verify cycle ${cycle} - ${v.openBugIds.join(', ')}`, fixedFiles), {
    label: `commit:verify-${cycle}`, phase: 'Verify', schema: COMMIT, agentType: 'grunt',
  })
  stamp(timing.commits, { label: `verify-${cycle}` }, cm)
}

if (verification.verdict !== 'PASSED') {
  return { stories: storyReport, verification, gate: { ran: false }, blocked: [], timing }
}

// ---------------------------------------------------------------------------
// Phase 4 — Review gate (Fable, mandatory unless finalGate=false)
// ---------------------------------------------------------------------------

let gate = { ran: false, verdict: 'SKIPPED', cycles: 0, openMustFix: [], suggestionCount: 0 }
if (finalGate) {
  phase('Gate')
  gate = { ran: true, verdict: 'BLOCKED', cycles: 0, openMustFix: [], suggestionCount: 0 }
  for (let cycle = 1; cycle <= maxReview; cycle++) {
    gate.cycles = cycle
    const g = await agent(gatePrompt(cycle), {
      label: `gate:${cycle}`, phase: 'Gate', schema: GATE, agentType: 'general-purpose', model: 'fable',
    })
    stamp(timing.gate, { cycle }, g)
    if (!g) { gate.openMustFix = ['GATE: no result']; break }
    gate.suggestionCount = g.suggestionCount || 0
    if (g.verdict === 'PASSED') { gate.verdict = 'PASSED'; gate.openMustFix = []; break }
    if (!g.openMustFixIds || g.openMustFixIds.length === 0) { gate.openMustFix = ['GATE: BLOCKED with no open ids']; break }
    gate.openMustFix = g.openMustFixIds
    if (cycle === maxReview) break
    const reviewPath = g.reviewPath || `${projectDir}/review-comments.json`
    log(`gate ${cycle}: ${g.openMustFixIds.length} open must-fix — fixing`)
    const fixedFiles = []
    for (const id of g.openMustFixIds) {
      const fx = await agent(bugFixPrompt(id, 'Review Fix', reviewPath), { label: `fix:${id}`, phase: 'Gate', schema: WORKBOOK, agentType: 'builder' })
      stamp(timing.fixes, { id, phase: 'gate' }, fx)
      if (fx && fx.filesChanged) fixedFiles.push(...fx.filesChanged)
    }
    if (fixedFiles.length === 0) { log(`gate ${cycle}: no fix reported changed files — skipping commit stage — fix edits, if any, remain uncommitted`); continue }
    const cm = await agent(commitPrompt(`fix: review cycle ${cycle} - ${g.openMustFixIds.join(', ')}`, fixedFiles), {
      label: `commit:review-${cycle}`, phase: 'Gate', schema: COMMIT, agentType: 'grunt',
    })
    stamp(timing.commits, { label: `review-${cycle}` }, cm)
  }
}

return { stories: storyReport, verification, gate, blocked: [], timing }
