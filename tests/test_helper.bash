# test_helper.bash — shared setup for takt.bats

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$TESTS_DIR/fixtures"

setup() {
  # Create a temp directory for each test
  TEST_TMPDIR="$(mktemp -d)"

  # cd to tmpdir so PROJECT_ROOT (= pwd) points to temp dir
  cd "$TEST_TMPDIR"

  # Set PRD_FILE to temp location (tests override as needed)
  PRD_FILE="$TEST_TMPDIR/prd.json"

  # Source takt.sh to get functions (source guard will return 0)
  source "$TESTS_DIR/../bin/takt.sh"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}
