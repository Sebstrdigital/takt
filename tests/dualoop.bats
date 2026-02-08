#!/usr/bin/env bats

load test_helper

# --- Story selection ---

@test "selects lowest-priority incomplete story" {
  PRD_FILE="$FIXTURES_DIR/prd-simple.json"
  local result
  result=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0].id' "$PRD_FILE")
  [ "$result" = "US-001" ]
}

@test "returns empty when all stories complete" {
  PRD_FILE="$FIXTURES_DIR/prd-complete.json"
  local result
  result=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0].id // empty' "$PRD_FILE")
  [ -z "$result" ]
}

# --- Dynamic iteration calculation ---

@test "4 stories -> 7 iterations" {
  # 4 stories: buffer = ceil(4*0.3) = 2, min 3 => 4+3=7
  cat > "$PRD_FILE" << 'EOF'
{"userStories":[
  {"passes":false},{"passes":false},{"passes":false},{"passes":false}
]}
EOF
  local result
  result=$(calculate_max_iterations)
  [ "$result" -eq 7 ]
}

@test "13 stories -> 17 iterations" {
  # 13 stories: buffer = ceil(13*0.3) = 4 => 13+4=17
  local stories=""
  for i in $(seq 1 13); do
    [ -n "$stories" ] && stories="$stories,"
    stories="$stories{\"passes\":false}"
  done
  echo "{\"userStories\":[$stories]}" > "$PRD_FILE"
  local result
  result=$(calculate_max_iterations)
  [ "$result" -eq 17 ]
}

@test "20 stories -> 26 iterations" {
  # 20 stories: buffer = ceil(20*0.3) = 6 => 20+6=26
  local stories=""
  for i in $(seq 1 20); do
    [ -n "$stories" ] && stories="$stories,"
    stories="$stories{\"passes\":false}"
  done
  echo "{\"userStories\":[$stories]}" > "$PRD_FILE"
  local result
  result=$(calculate_max_iterations)
  [ "$result" -eq 26 ]
}

@test "no prd.json -> defaults to 10" {
  PRD_FILE="$TEST_TMPDIR/nonexistent.json"
  local result
  result=$(calculate_max_iterations)
  [ "$result" -eq 10 ]
}

@test "all stories complete -> defaults to 10" {
  PRD_FILE="$FIXTURES_DIR/prd-complete.json"
  local result
  result=$(calculate_max_iterations)
  [ "$result" -eq 10 ]
}

# --- Timeout mapping ---

@test "small timeout = 1200s" {
  [ "$(get_story_timeout small)" -eq 1200 ]
}

@test "medium timeout = 2400s" {
  [ "$(get_story_timeout medium)" -eq 2400 ]
}

@test "large timeout = 3600s" {
  [ "$(get_story_timeout large)" -eq 3600 ]
}

@test "unknown size = 1800s default" {
  [ "$(get_story_timeout unknown)" -eq 1800 ]
}

# --- Weighted progress ---

@test "weighted progress with mixed sizes" {
  # 1 complete small(1), 1 incomplete medium(2), 1 incomplete small(1)
  # total=4, completed=1, pct=25
  PRD_FILE="$FIXTURES_DIR/prd-mixed.json"
  local result
  result=$(calculate_progress)
  [ "$result" -eq 14 ]
  # small(1)=complete + medium(2)+large(3)+small(1)=incomplete = 1/7 = 14%
}

@test "0% when nothing complete" {
  PRD_FILE="$FIXTURES_DIR/prd-simple.json"
  local result
  result=$(calculate_progress)
  [ "$result" -eq 0 ]
}

@test "100% when all complete" {
  PRD_FILE="$FIXTURES_DIR/prd-complete.json"
  local result
  result=$(calculate_progress)
  [ "$result" -eq 100 ]
}

# --- Size weights ---

@test "size weight: small=1" {
  [ "$(get_size_weight small)" -eq 1 ]
}

@test "size weight: medium=2" {
  [ "$(get_size_weight medium)" -eq 2 ]
}

@test "size weight: large=3" {
  [ "$(get_size_weight large)" -eq 3 ]
}

@test "size weight: unknown defaults to 1" {
  [ "$(get_size_weight foo)" -eq 1 ]
}

# --- Model selection ---

@test "reads model from story" {
  PRD_FILE="$FIXTURES_DIR/prd-simple.json"
  local result
  result=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0].model' "$PRD_FILE")
  [ "$result" = "sonnet" ]
}

@test "defaults to sonnet when model not set" {
  cat > "$PRD_FILE" << 'EOF'
{"userStories":[{"passes":false,"priority":1}]}
EOF
  local result
  result=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0].model // "sonnet"' "$PRD_FILE")
  [ "$result" = "sonnet" ]
}

# --- Deep verification filter ---

@test "only verify:deep stories selected for deep verification" {
  PRD_FILE="$FIXTURES_DIR/prd-simple.json"
  local result
  result=$(jq -r '[.userStories[] | select(.verify == "deep")] | length' "$PRD_FILE")
  [ "$result" -eq 1 ]
}

@test "mixed prd has correct deep verify count" {
  PRD_FILE="$FIXTURES_DIR/prd-mixed.json"
  local result
  result=$(jq -r '[.userStories[] | select(.verify == "deep")] | length' "$PRD_FILE")
  [ "$result" -eq 2 ]
}

# --- Init scaffolding ---

@test "dualoop_init creates project scaffolding" {
  cd "$TEST_TMPDIR"
  dualoop_init > /dev/null
  [ -f prd.json ]
  [ -f progress.txt ]
  [ -d tasks/archive ]
}

@test "dualoop_init does not overwrite existing prd.json" {
  cd "$TEST_TMPDIR"
  echo '{"existing":true}' > prd.json
  dualoop_init > /dev/null
  local result
  result=$(jq -r '.existing' prd.json)
  [ "$result" = "true" ]
}

@test "dualoop_init adds gitignore entries" {
  cd "$TEST_TMPDIR"
  dualoop_init > /dev/null
  grep -qxF ".last-branch" .gitignore
  grep -qxF ".original-branch" .gitignore
  grep -qxF ".dualoop-stats.json" .gitignore
}
