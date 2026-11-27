#!/usr/bin/env bash
#
# devops-checks.sh - takt preflight: verify runtime prerequisites, fail fast with a fix hint.
#
# Usage: devops-checks.sh [--json]
#   default  one line per check: "PASS <name>" or "FAIL <name>: <fix hint>"
#   --json   a single JSON object {"<name>": true|false, ...}
# Exit code: 0 when every check passes, 1 when any fails.
#
# Plain bash, no LLM calls. Every network check is bounded by a timeout, and the
# checks run in parallel, so the whole script finishes in about TIMEOUT seconds
# worst case.

# shellcheck disable=SC2329  # check_* functions (and run_timeout) are invoked indirectly via "check_$name"
set -uo pipefail

TIMEOUT=10          # seconds per network check
SSH_CONNECT_TIMEOUT=5

JSON=0
for arg in "$@"; do
    case "$arg" in
        --json) JSON=1 ;;
        -h|--help)
            sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "devops-checks.sh: unknown argument: $arg" >&2
            exit 2
            ;;
    esac
done

# run_timeout <seconds> <cmd...> - bounded run; macOS has no timeout(1) by default.
run_timeout() {
    local secs="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$secs" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$secs" "$@"
    else
        "$@" &
        local pid=$!
        ( sleep "$secs"; kill "$pid" 2>/dev/null ) &
        local watchdog=$!
        wait "$pid" 2>/dev/null
        local rc=$?
        kill "$watchdog" 2>/dev/null
        wait "$watchdog" 2>/dev/null
        return "$rc"
    fi
}

# Each check_* prints nothing on success (return 0) or a fix hint on stdout (return 1).

check_munin() {
    local cfg="$HOME/.config/munin/config.toml"
    if [ ! -f "$cfg" ]; then
        echo "no $cfg - install munin or create its config (run-local.md: munin is optional memory)"
        return 1
    fi
    if ! command -v munin >/dev/null 2>&1; then
        echo "munin CLI not on PATH - install munin (config exists at $cfg)"
        return 1
    fi
    if ! run_timeout "$TIMEOUT" munin projects >/dev/null 2>&1; then
        echo "munin unreachable - check munin.local is up and db_url/embed_url in $cfg"
        return 1
    fi
}

check_validation_vm() {
    if ! command -v ssh >/dev/null 2>&1; then
        echo "ssh not on PATH"
        return 1
    fi
    if ! run_timeout "$TIMEOUT" ssh -o ConnectTimeout="$SSH_CONNECT_TIMEOUT" -o BatchMode=yes \
        validation 'podman --version' >/dev/null 2>&1; then
        echo "'ssh validation' failed or podman missing - check validation.local is up, ~/.ssh/config has Host validation, and podman is installed on the VM"
        return 1
    fi
}

check_codex() {
    if ! command -v codex >/dev/null 2>&1; then
        echo "codex not on PATH - install the Codex CLI (npm i -g @openai/codex); the review gate falls back to Sonnet without it"
        return 1
    fi
}

check_gh_auth() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "gh not on PATH - install GitHub CLI (brew install gh)"
        return 1
    fi
    if ! run_timeout "$TIMEOUT" gh auth status >/dev/null 2>&1; then
        echo "gh not authenticated - run: gh auth login"
        return 1
    fi
}

check_gh_push() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "gh not on PATH - install GitHub CLI (brew install gh)"
        return 1
    fi
    local url slug
    url="$(git remote get-url origin 2>/dev/null)" || {
        echo "no origin remote in $(pwd) - run from inside the project repo"
        return 1
    }
    # git@github.com:owner/repo.git | https://github.com/owner/repo(.git) | ssh://git@github.com/owner/repo
    slug="$(printf '%s' "$url" | sed -E 's#^(ssh://)?(git@|https?://)?([^/:]+)[:/]##; s#\.git$##; s#/+$##')"
    case "$slug" in
        */*) ;;
        *)
            echo "cannot parse owner/repo from origin '$url'"
            return 1
            ;;
    esac
    local push
    push="$(run_timeout "$TIMEOUT" gh api "repos/$slug" --jq '.permissions.push' 2>/dev/null)" || {
        echo "gh api repos/$slug failed - check gh auth and that the repo exists/is visible to the active account"
        return 1
    }
    if [ "$push" != "true" ]; then
        echo "active gh account cannot push to $slug - run: gh auth switch (or gh auth login with the right account)"
        return 1
    fi
}

CHECKS=(munin validation_vm codex gh_auth gh_push)

TMP="$(mktemp -d "${TMPDIR:-/tmp}/devops-checks.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# Run all checks in parallel; each writes its hint to $TMP/<name>.out and rc to $TMP/<name>.rc.
for name in "${CHECKS[@]}"; do
    (
        out="$("check_$name" 2>&1)"
        echo $? > "$TMP/$name.rc"
        printf '%s' "$out" > "$TMP/$name.out"
    ) &
done
wait

fail=0
json_body=""
for name in "${CHECKS[@]}"; do
    rc="$(cat "$TMP/$name.rc" 2>/dev/null || echo 1)"
    hint="$(cat "$TMP/$name.out" 2>/dev/null)"
    if [ "$rc" = "0" ]; then
        ok=true
        [ "$JSON" = 1 ] || echo "PASS $name"
    else
        ok=false
        fail=1
        [ "$JSON" = 1 ] || echo "FAIL $name: ${hint:-check failed}"
    fi
    json_body="${json_body:+$json_body, }\"$name\": $ok"
done

[ "$JSON" = 1 ] && echo "{$json_body}"

exit "$fail"
