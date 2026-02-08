#!/bin/bash
# DuaLoop - Autonomous AI agent loop
# Usage: dualoop [init|install|max_iterations]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"

PRD_FILE="$PROJECT_ROOT/prd.json"
PROGRESS_FILE="$PROJECT_ROOT/progress.txt"
TASKS_DIR="$PROJECT_ROOT/tasks"
ARCHIVE_DIR="$TASKS_DIR/archive"
LAST_BRANCH_FILE="$PROJECT_ROOT/.last-branch"
STATS_FILE="$PROJECT_ROOT/.dualoop-stats.json"

# Default model when story doesn't specify one
DEFAULT_MODEL="sonnet"

# Size weights for progress calculation
get_size_weight() {
  case "$1" in
    small) echo 1 ;;
    medium) echo 2 ;;
    large) echo 3 ;;
    *) echo 1 ;;
  esac
}

# Get timeout in seconds based on story size
get_story_timeout() {
  case "$1" in
    small) echo 1200 ;;   # 20 minutes
    medium) echo 2400 ;;  # 40 minutes
    large) echo 3600 ;;   # 60 minutes
    *) echo 1800 ;;       # 30 minutes default
  esac
}

# Calculate max iterations from story count: stories + max(3, ceil(stories * 0.3))
calculate_max_iterations() {
  if [ ! -f "$PRD_FILE" ]; then
    echo 10; return
  fi
  local story_count
  story_count=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null || echo 0)
  if [ "$story_count" -eq 0 ]; then
    echo 10; return
  fi
  local buffer=$(( (story_count * 3 + 9) / 10 ))
  [ "$buffer" -lt 3 ] && buffer=3
  echo $(( story_count + buffer ))
}

# Run command with timeout (portable version for macOS/Linux)
# Usage: run_with_timeout <timeout_seconds> <output_var_name> <command...>
# Streams output to stderr in real-time, captures to variable
# Returns: 0 on success, 124 on timeout, or command's exit code
run_with_timeout() {
  local timeout_seconds=$1
  local output_var=$2
  shift 2
  local output_file=$(mktemp)
  local pid_file=$(mktemp)

  # Run command in background with output capture and real-time display
  ( "$@" 2>&1 | tee "$output_file" >&2; echo $? > "$pid_file.exit" ) &
  local wrapper_pid=$!

  # Monitor with timeout
  local elapsed=0
  local interval=5
  while [ $elapsed -lt $timeout_seconds ]; do
    if ! kill -0 $wrapper_pid 2>/dev/null; then
      # Process finished
      wait $wrapper_pid 2>/dev/null
      local exit_code=0
      if [ -f "$pid_file.exit" ]; then
        exit_code=$(cat "$pid_file.exit")
        rm -f "$pid_file.exit"
      fi
      # Export output to caller's variable
      eval "$output_var=\"\$(cat '$output_file')\""
      rm -f "$output_file" "$pid_file"
      return $exit_code
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  # Timeout reached - kill all related processes
  echo "" >&2
  echo "  ⚠️  TIMEOUT: Command exceeded ${timeout_seconds}s limit" >&2
  echo "  Killing stuck process..." >&2

  # Kill the wrapper and any child processes
  pkill -P $wrapper_pid 2>/dev/null
  kill $wrapper_pid 2>/dev/null
  sleep 2
  pkill -9 -P $wrapper_pid 2>/dev/null || true
  kill -9 $wrapper_pid 2>/dev/null || true

  # Export partial output
  eval "$output_var=\"\$(cat '$output_file' 2>/dev/null || echo '')\""
  rm -f "$output_file" "$pid_file" "$pid_file.exit"
  return 124  # Standard timeout exit code
}

# Calculate weighted progress percentage
calculate_progress() {
  if [ ! -f "$PRD_FILE" ]; then
    echo "0"
    return
  fi

  local completed_weight=0
  local total_weight=0

  while IFS= read -r line; do
    local size=$(echo "$line" | cut -d'|' -f1)
    local passes=$(echo "$line" | cut -d'|' -f2)
    local weight=$(get_size_weight "$size")
    total_weight=$((total_weight + weight))
    if [ "$passes" = "true" ]; then
      completed_weight=$((completed_weight + weight))
    fi
  done < <(jq -r '.userStories[] | "\(.size // "small")|\(.passes)"' "$PRD_FILE" 2>/dev/null)

  if [ "$total_weight" -eq 0 ]; then
    echo "0"
  else
    echo $((completed_weight * 100 / total_weight))
  fi
}

# Calculate ETA based on historical stats
calculate_eta() {
  if [ ! -f "$STATS_FILE" ] || [ ! -f "$PRD_FILE" ]; then
    echo ""
    return
  fi

  local remaining_minutes=0
  local has_stats=false

  while IFS= read -r line; do
    local size=$(echo "$line" | cut -d'|' -f1)
    local model=$(echo "$line" | cut -d'|' -f2)
    local passes=$(echo "$line" | cut -d'|' -f3)

    if [ "$passes" = "false" ]; then
      local key="${size}-${model}"
      local avg=$(jq -r --arg k "$key" '.[$k].avgMinutes // 0' "$STATS_FILE" 2>/dev/null)
      if [ -n "$avg" ] && [ "$avg" != "0" ] && [ "$avg" != "null" ]; then
        remaining_minutes=$((remaining_minutes + avg))
        has_stats=true
      fi
    fi
  done < <(jq -r '.userStories[] | "\(.size // "small")|\(.model // "sonnet")|\(.passes)"' "$PRD_FILE" 2>/dev/null)

  if [ "$has_stats" = "true" ] && [ "$remaining_minutes" -gt 0 ]; then
    if [ "$remaining_minutes" -lt 60 ]; then
      echo "~${remaining_minutes} min"
    else
      local hours=$((remaining_minutes / 60))
      local mins=$((remaining_minutes % 60))
      echo "~${hours}h ${mins}m"
    fi
  else
    echo ""
  fi
}

# Update stats file with completion data from current PRD
update_stats() {
  if [ ! -f "$PRD_FILE" ]; then
    return
  fi

  # Initialize stats file if it doesn't exist
  if [ ! -f "$STATS_FILE" ]; then
    echo '{}' > "$STATS_FILE"
  fi

  # Read current stats
  local stats=$(cat "$STATS_FILE")

  # Process each completed story with both startTime and endTime
  while IFS= read -r line; do
    local size=$(echo "$line" | cut -d'|' -f1)
    local model=$(echo "$line" | cut -d'|' -f2)
    local start=$(echo "$line" | cut -d'|' -f3)
    local end=$(echo "$line" | cut -d'|' -f4)

    # Skip if missing timestamps
    if [ -z "$start" ] || [ -z "$end" ] || [ "$start" = "null" ] || [ "$end" = "null" ]; then
      continue
    fi

    # Calculate duration in minutes (YYYY-MM-DD HH:MM format)
    local start_epoch=$(date -j -f "%Y-%m-%d %H:%M" "$start" "+%s" 2>/dev/null || date -d "$start" "+%s" 2>/dev/null)
    local end_epoch=$(date -j -f "%Y-%m-%d %H:%M" "$end" "+%s" 2>/dev/null || date -d "$end" "+%s" 2>/dev/null)

    if [ -z "$start_epoch" ] || [ -z "$end_epoch" ]; then
      continue
    fi

    local duration_seconds=$((end_epoch - start_epoch))
    local duration_minutes=$((duration_seconds / 60))

    # Skip if duration is negative or zero
    if [ "$duration_minutes" -le 0 ]; then
      continue
    fi

    local key="${size}-${model}"

    # Update stats for this key
    local current_count=$(echo "$stats" | jq -r --arg k "$key" '.[$k].count // 0')
    local current_avg=$(echo "$stats" | jq -r --arg k "$key" '.[$k].avgMinutes // 0')
    local current_min=$(echo "$stats" | jq -r --arg k "$key" '.[$k].minMinutes // 999999')
    local current_max=$(echo "$stats" | jq -r --arg k "$key" '.[$k].maxMinutes // 0')

    # Calculate new values
    local new_count=$((current_count + 1))
    local new_avg=$(( (current_avg * current_count + duration_minutes) / new_count ))
    local new_min=$duration_minutes
    local new_max=$duration_minutes

    if [ "$current_min" -lt "$new_min" ] && [ "$current_min" != "999999" ]; then
      new_min=$current_min
    fi
    if [ "$current_max" -gt "$new_max" ]; then
      new_max=$current_max
    fi

    # Update stats object
    stats=$(echo "$stats" | jq --arg k "$key" \
      --argjson count "$new_count" \
      --argjson avg "$new_avg" \
      --argjson min "$new_min" \
      --argjson max "$new_max" \
      '.[$k] = {count: $count, avgMinutes: $avg, minMinutes: $min, maxMinutes: $max}')

  done < <(jq -r '.userStories[] | select(.passes == true) | "\(.size // "small")|\(.model // "sonnet")|\(.startTime // "")|\(.endTime // "")"' "$PRD_FILE" 2>/dev/null)

  # Write updated stats
  echo "$stats" > "$STATS_FILE"
  echo "Updated completion stats in .dualoop-stats.json"
}

# Get progress summary string
get_progress_summary() {
  if [ ! -f "$PRD_FILE" ]; then
    echo ""
    return
  fi

  local completed=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null || echo "0")
  local total=$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null || echo "0")
  local pct=$(calculate_progress)
  local eta=$(calculate_eta)

  if [ -n "$eta" ]; then
    echo "$completed/$total stories ($pct%) | ETA: $eta"
  else
    echo "$completed/$total stories ($pct%)"
  fi
}

# Initialize per-project scaffolding
dualoop_init() {
  echo "Initializing DuaLoop in $(pwd)..."

  mkdir -p tasks/archive

  if [ ! -f prd.json ]; then
    echo '{"project":"","branchName":"","description":"","userStories":[]}' | jq . > prd.json
  fi

  if [ ! -f progress.txt ]; then
    printf "# DuaLoop Progress Log\nStarted: %s\n---\n" "$(date)" > progress.txt
  fi

  # .gitignore entries
  for entry in .last-branch .original-branch .dualoop-stats.json; do
    grep -qxF "$entry" .gitignore 2>/dev/null || echo "$entry" >> .gitignore
  done

  # Clean stale tracking files
  rm -f .last-branch .original-branch

  echo "Done. Project files: prd.json, progress.txt, tasks/"
}

# Global installation (symlinks)
dualoop_install() {
  local bin_dir="$HOME/.local/bin"
  local cmd_dir="$HOME/.claude/commands"

  mkdir -p "$bin_dir" "$cmd_dir"

  # Symlink dualoop binary
  ln -sf "$SCRIPT_DIR/dualoop.sh" "$bin_dir/dualoop"
  echo "Linked: $bin_dir/dualoop"

  # Symlink skills (dua-prd to avoid conflict with existing /prd)
  ln -sf "$SCRIPT_DIR/skills/prd/SKILL.md" "$cmd_dir/dua-prd.md"
  ln -sf "$SCRIPT_DIR/skills/dua/SKILL.md" "$cmd_dir/dua.md"
  ln -sf "$SCRIPT_DIR/skills/tdd/SKILL.md" "$cmd_dir/tdd.md"
  echo "Linked: /dua-prd, /dua, /tdd → ~/.claude/commands/"

  # Append to ~/.claude/CLAUDE.md if DuaLoop section doesn't exist
  local claude_md="$HOME/.claude/CLAUDE.md"
  if [ ! -f "$claude_md" ] || ! grep -q "DuaLoop" "$claude_md" 2>/dev/null; then
    cat >> "$claude_md" << 'SECTION'

## DuaLoop - Autonomous Agent Loop

Available globally. Use when a project has `prd.json`:
- `dualoop` — run the autonomous loop
- `dualoop init` — scaffold a new project
- `/dua-prd` — generate PRD from feature description
- `/dua` — convert PRD to prd.json
- `/tdd` — TDD workflow
SECTION
    echo "Updated: ~/.claude/CLAUDE.md"
  fi

  echo ""
  echo "Install complete. Usage:"
  echo "  cd ~/my-project && dualoop init"
  echo "  dualoop          # run the loop"
}

# Source guard: allow sourcing for tests without executing main logic
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0

# Subcommand routing
case "${1:-}" in
  init)
    dualoop_init
    exit 0
    ;;
  install)
    dualoop_install
    exit 0
    ;;
esac

# Parse remaining args for the loop
if [ -n "${1:-}" ] && [[ "${1:-}" =~ ^[0-9]+$ ]]; then
  MAX_ITERATIONS=$1
else
  MAX_ITERATIONS=""
fi

# Auto-calculate max iterations if not provided as argument
if [ -z "$MAX_ITERATIONS" ]; then
  MAX_ITERATIONS=$(calculate_max_iterations)
  _MAX_ITER_SOURCE="auto"
else
  _MAX_ITER_SOURCE="manual"
fi

# Handle branch changes - just log and continue
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    TOTAL_STORIES=$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null || echo "0")
    echo "Branch changed: $LAST_BRANCH → $CURRENT_BRANCH"
    echo "Continuing with current prd.json ($TOTAL_STORIES stories)"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# DuaLoop Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

if [ "$_MAX_ITER_SOURCE" = "auto" ]; then
  _STORY_COUNT=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null || echo 0)
  _BUFFER=$(( MAX_ITERATIONS - _STORY_COUNT ))
  echo "Starting DuaLoop - Max iterations: $MAX_ITERATIONS (auto: $_STORY_COUNT stories + $_BUFFER buffer)"
else
  echo "Starting DuaLoop - Max iterations: $MAX_ITERATIONS"
fi
echo "Project root: $PROJECT_ROOT"

# Chrome browser integration (disabled by default for faster iteration)
# To enable: ./dualoop/dualoop.sh 10 --chrome
CHROME_FLAG=""
if [[ "$*" == *"--chrome"* ]]; then
  CHROME_FLAG="--chrome"
  echo "Chrome browser integration enabled (manual flag)"
else
  echo "Running without browser (add --chrome to enable)"
fi

# Save original branch and switch to feature branch
ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
TARGET_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")

if [ -n "$TARGET_BRANCH" ] && [ "$TARGET_BRANCH" != "null" ]; then
  CURRENT_GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  if [ "$CURRENT_GIT_BRANCH" != "$TARGET_BRANCH" ]; then
    echo ""
    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH" 2>/dev/null; then
      echo "Switching to existing branch: $TARGET_BRANCH"
      git checkout "$TARGET_BRANCH"
    else
      echo "Creating feature branch: $TARGET_BRANCH (from $ORIGINAL_BRANCH)"
      git checkout -b "$TARGET_BRANCH"
    fi
  else
    echo "Already on feature branch: $TARGET_BRANCH"
  fi

  # Save original branch for later merge/PR prompt
  echo "$ORIGINAL_BRANCH" > "$PROJECT_ROOT/.original-branch"
fi

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""

  # Determine model and verify mode for this iteration by reading next story from prd.json
  STORY_MODEL="$DEFAULT_MODEL"
  STORY_VERIFY="inline"
  STORY_ID=""
  STORY_TITLE=""
  STORY_SIZE="small"
  if [ -f "$PRD_FILE" ]; then
    # Find the highest priority story where passes: false
    NEXT_STORY=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0] // empty' "$PRD_FILE" 2>/dev/null)
    if [ -n "$NEXT_STORY" ] && [ "$NEXT_STORY" != "null" ]; then
      STORY_ID=$(echo "$NEXT_STORY" | jq -r '.id // empty')
      STORY_TITLE=$(echo "$NEXT_STORY" | jq -r '.title // empty')
      STORY_SIZE=$(echo "$NEXT_STORY" | jq -r '.size // "small"')
      STORY_MODEL_FROM_JSON=$(echo "$NEXT_STORY" | jq -r '.model // empty')
      STORY_VERIFY_FROM_JSON=$(echo "$NEXT_STORY" | jq -r '.verify // empty')
      if [ -n "$STORY_MODEL_FROM_JSON" ] && [ "$STORY_MODEL_FROM_JSON" != "null" ]; then
        STORY_MODEL="$STORY_MODEL_FROM_JSON"
      fi
      if [ -n "$STORY_VERIFY_FROM_JSON" ] && [ "$STORY_VERIFY_FROM_JSON" != "null" ]; then
        STORY_VERIFY="$STORY_VERIFY_FROM_JSON"
      fi
    fi
  fi

  # Get progress summary
  PROGRESS_SUMMARY=$(get_progress_summary)

  echo "═══════════════════════════════════════════════════════════"
  echo "  DuaLoop Iteration $i of $MAX_ITERATIONS"
  if [ -n "$PROGRESS_SUMMARY" ]; then
    echo "  Progress: $PROGRESS_SUMMARY"
  fi
  if [ -n "$STORY_ID" ]; then
    echo "  Story: $STORY_ID - $STORY_TITLE"
    echo "  Config: $STORY_SIZE | $STORY_MODEL | $STORY_VERIFY"
  fi
  echo "═══════════════════════════════════════════════════════════"

  # Record start time for this story (YYYY-MM-DD HH:MM)
  if [ -n "$STORY_ID" ]; then
    START_TIME=$(date +"%Y-%m-%d %H:%M")
    jq --arg id "$STORY_ID" --arg time "$START_TIME" \
      '(.userStories[] | select(.id == $id) | .startTime) = $time' \
      "$PRD_FILE" > "$PRD_FILE.tmp" && mv "$PRD_FILE.tmp" "$PRD_FILE"
  fi

  # Run claude with the prompt and determined model (with timeout)
  STORY_TIMEOUT=$(get_story_timeout "$STORY_SIZE")
  echo "  Timeout: ${STORY_TIMEOUT}s ($(( STORY_TIMEOUT / 60 )) min)"
  echo ""

  OUTPUT=""
  PROMPT_CONTENT=$(cat "$SCRIPT_DIR/prompt.md")
  run_with_timeout "$STORY_TIMEOUT" OUTPUT claude -p "$PROMPT_CONTENT" --model "$STORY_MODEL" --dangerously-skip-permissions $CHROME_FLAG
  CLAUDE_EXIT_CODE=$?

  if [ $CLAUDE_EXIT_CODE -eq 124 ]; then
    echo ""
    echo "  ⚠️  Story iteration timed out - continuing to next iteration"
    echo "  (The story may have been partially completed)"
  fi

  # Check if story was completed and record end time
  if [ -n "$STORY_ID" ]; then
    STORY_NOW_PASSES=$(jq -r --arg id "$STORY_ID" '.userStories[] | select(.id == $id) | .passes' "$PRD_FILE" 2>/dev/null)
    if [ "$STORY_NOW_PASSES" = "true" ]; then
      END_TIME=$(date +"%Y-%m-%d %H:%M")
      jq --arg id "$STORY_ID" --arg time "$END_TIME" \
        '(.userStories[] | select(.id == $id) | .endTime) = $time' \
        "$PRD_FILE" > "$PRD_FILE.tmp" && mv "$PRD_FILE.tmp" "$PRD_FILE"
      echo ""
      echo "  ✓ Completed: $STORY_ID - $STORY_TITLE"
    fi
  fi

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "All stories marked complete. Running final deep verification..."

    # Run deep verification on ALL stories with verify: deep
    DEEP_VERIFY_STORIES=$(jq -r '.userStories[] | select(.verify == "deep") | .id' "$PRD_FILE" 2>/dev/null)
    VERIFICATION_FAILED=false

    for VERIFY_STORY_ID in $DEEP_VERIFY_STORIES; do
      VERIFY_STORY=$(jq -r --arg id "$VERIFY_STORY_ID" '.userStories[] | select(.id == $id)' "$PRD_FILE")
      VERIFY_TITLE=$(echo "$VERIFY_STORY" | jq -r '.title')
      VERIFY_CRITERIA=$(echo "$VERIFY_STORY" | jq -r '.acceptanceCriteria | join("\n- ")')

      echo ""
      echo "───────────────────────────────────────────────────────"
      echo "  Deep Verification: $VERIFY_STORY_ID - $VERIFY_TITLE"
      echo "───────────────────────────────────────────────────────"

      VERIFIER_PROMPT=$(cat <<EOF
# Deep Verification Task

Verify that story $VERIFY_STORY_ID - "$VERIFY_TITLE" actually achieved its goals.

## Acceptance Criteria to Verify:
- $VERIFY_CRITERIA

## Instructions
$(cat "$SCRIPT_DIR/agents/verifier.md")

## Recent Changes
Run \`git log --oneline -5\` and \`git diff HEAD~3\` to see recent changes.

Perform verification now and output your report.
EOF
)

      VERIFY_OUTPUT=""
      run_with_timeout 900 VERIFY_OUTPUT claude -p "$VERIFIER_PROMPT" --model sonnet --dangerously-skip-permissions $CHROME_FLAG || true

      if echo "$VERIFY_OUTPUT" | grep -qi "VERIFICATION: FAILED"; then
        echo ""
        echo "  Deep verification FAILED for $VERIFY_STORY_ID"
        VERIFICATION_FAILED=true
        jq --arg id "$VERIFY_STORY_ID" '(.userStories[] | select(.id == $id) | .passes) = false' "$PRD_FILE" > "$PRD_FILE.tmp" && mv "$PRD_FILE.tmp" "$PRD_FILE"
      else
        echo ""
        echo "  Deep verification PASSED for $VERIFY_STORY_ID"
      fi
    done

    if [ "$VERIFICATION_FAILED" = "true" ]; then
      echo ""
      echo "Some stories failed deep verification. Continuing iterations..."
    else
      echo ""
      echo "╔═══════════════════════════════════════════════════════════╗"
      echo "║              DuaLoop completed all tasks!                 ║"
      echo "╚═══════════════════════════════════════════════════════════╝"
      echo ""
      echo "Completed at iteration $i of $MAX_ITERATIONS"

      # Archive the source PRD file (derived from branchName)
      COMPLETED_BRANCH=$(jq -r '.branchName // "unknown"' "$PRD_FILE")
      PR_DESCRIPTION=$(jq -r '.description // "Feature complete"' "$PRD_FILE")
      DATE=$(date +%Y-%m-%d)
      FOLDER_NAME=$(echo "$COMPLETED_BRANCH" | sed 's|^dua/||')
      ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

      # Derive PRD filename from branchName: dua/dark-mode → tasks/prd-dark-mode.md
      PRD_SOURCE_FILE="$TASKS_DIR/prd-$FOLDER_NAME.md"

      mkdir -p "$ARCHIVE_FOLDER"

      if [ -f "$PRD_SOURCE_FILE" ]; then
        echo "Archiving source PRD: $PRD_SOURCE_FILE"
        mv "$PRD_SOURCE_FILE" "$ARCHIVE_FOLDER/"
        echo "   Moved to: $ARCHIVE_FOLDER/"
      else
        echo "No source PRD file found at: $PRD_SOURCE_FILE"
      fi

      # Update stats with completion data (before resetting prd.json)
      update_stats

      # Reset prd.json for next feature
      cat > "$PRD_FILE" << 'EOF'
{
  "project": "",
  "branchName": "",
  "description": "",
  "userStories": []
}
EOF
      echo "Reset prd.json for next feature"

      # Prompt for merge or PR
      ORIGINAL_BRANCH_FILE="$PROJECT_ROOT/.original-branch"
      if [ -f "$ORIGINAL_BRANCH_FILE" ]; then
        RETURN_BRANCH=$(cat "$ORIGINAL_BRANCH_FILE")
        rm -f "$ORIGINAL_BRANCH_FILE"

        echo ""
        echo "───────────────────────────────────────────────────────────"
        echo "  Feature complete on branch: $COMPLETED_BRANCH"
        echo "───────────────────────────────────────────────────────────"
        echo ""
        echo "What would you like to do?"
        echo ""
        echo "  1) Merge to $RETURN_BRANCH"
        echo "  2) Create a Pull Request"
        echo "  3) Stay on this branch (do nothing)"
        echo ""
        read -p "Enter choice [1/2/3]: " MERGE_CHOICE

        case "$MERGE_CHOICE" in
          1)
            echo ""
            echo "Merging $COMPLETED_BRANCH into $RETURN_BRANCH..."
            git checkout "$RETURN_BRANCH"
            git merge "$COMPLETED_BRANCH" -m "Merge $COMPLETED_BRANCH into $RETURN_BRANCH"
            echo "✓ Merged successfully!"
            echo ""
            read -p "Delete the feature branch '$COMPLETED_BRANCH'? [y/N]: " DELETE_BRANCH
            if [[ "$DELETE_BRANCH" =~ ^[Yy]$ ]]; then
              git branch -d "$COMPLETED_BRANCH"
              echo "✓ Branch deleted"
            fi
            ;;
          2)
            echo ""
            echo "Creating Pull Request..."
            # Push the branch first
            git push -u origin "$COMPLETED_BRANCH" 2>/dev/null || git push --set-upstream origin "$COMPLETED_BRANCH"
            # Create PR using gh CLI if available
            if command -v gh &> /dev/null; then
              gh pr create --base "$RETURN_BRANCH" --head "$COMPLETED_BRANCH" --title "$PR_DESCRIPTION" --body "Implemented via DuaLoop autonomous agent."
            else
              echo ""
              echo "GitHub CLI (gh) not installed. Create PR manually:"
              echo "  https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/compare/$RETURN_BRANCH...$COMPLETED_BRANCH"
            fi
            ;;
          3|*)
            echo ""
            echo "Staying on branch: $COMPLETED_BRANCH"
            echo "You can merge or create a PR later."
            ;;
        esac
      fi

      exit 0
    fi
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "DuaLoop reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
