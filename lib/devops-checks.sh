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

# run_timeout <seconds> <cmd...> - bounded run; returns 124 when the deadline fired.
# The deadline is hard: TERM, then KILL one second later, to the command's whole process group, so a
# TERM-ignoring command or a child holding stdout open cannot outlive it (or stall a $(...) capture).
# Not timeout(1)/gtimeout: they cannot reap a straggler that outlives the command, and macOS has neither by default.
run_timeout() {
    local secs="$1"
    shift
    (
        set -m   # job control: each background job leads its own process group
        local mark rc pid watchdog
        mark="$(mktemp "${TMPDIR:-/tmp}/run-timeout.XXXXXX")" || exit 1
        "$@" </dev/null &
        pid=$!
        # Watchdog stdio is detached so its sleep cannot hold the caller's stdout open.
        ( sleep "$secs"; echo fired > "$mark"; kill -TERM -- "-$pid" 2>/dev/null
          sleep 1; kill -KILL -- "-$pid" 2>/dev/null ) >/dev/null 2>&1 &
        watchdog=$!
        wait "$pid" 2>/dev/null
        rc=$?
        kill -KILL -- "-$watchdog" 2>/dev/null   # stop the watchdog and its sleep
        kill -KILL -- "-$pid" 2>/dev/null        # reap stragglers still holding stdout
        [ -s "$mark" ] && rc=124
        rm -f "$mark"
        exit "$rc"
    )
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

# resolve_push_target - set REMOTE_HOST and REMOTE_SLUG from origin's PUSH url
# (the URL Phase 5 pushes to; it can differ from the fetch url). Returns 1 with a hint on stdout.
# Handles git@host:owner/repo.git | https://[user[:pass]@]host[:port]/owner/repo(.git) | ssh://git@host[:port]/owner/repo
# The raw url can embed credentials: userinfo is dropped before host/slug are derived and the raw url
# is never echoed, so no hint or request path can carry it.
resolve_push_target() {
    local url rest authority hostport
    url="$(git remote get-url --push origin 2>/dev/null)" || {
        echo "no origin remote in $(pwd) - run from inside the project repo"
        return 1
    }
    REMOTE_HOST=""
    REMOTE_SLUG=""
    case "$url" in
        *://*)
            rest="${url#*://}"
            authority="${rest%%/*}"
            [ "$authority" = "$rest" ] && rest="" || rest="${rest#*/}"
            hostport="${authority##*@}"
            REMOTE_HOST="${hostport%%:*}"
            REMOTE_SLUG="$rest"
            ;;
        *:*)
            authority="${url%%:*}"
            REMOTE_HOST="${authority##*@}"
            REMOTE_SLUG="${url#*:}"
            ;;
    esac
    url=""
    REMOTE_SLUG="${REMOTE_SLUG%.git}"
    REMOTE_SLUG="${REMOTE_SLUG%/}"
    case "$REMOTE_SLUG" in
        */*) ;;
        *)
            echo "cannot parse owner/repo from origin push url (value withheld)"
            return 1
            ;;
    esac
    if [ -z "$REMOTE_HOST" ]; then
        echo "cannot parse host from origin push url (value withheld)"
        return 1
    fi
}

check_gh_auth() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "gh not on PATH - install GitHub CLI (brew install gh)"
        return 1
    fi
    # Test only the active account on the host Phase 5 pushes to; a stale login for another
    # account or host must not block the run. No origin yet -> fall back to the active account on any host.
    local args=(auth status --active)
    REMOTE_HOST=""
    if resolve_push_target >/dev/null; then
        args+=(--hostname "$REMOTE_HOST")
    else
        REMOTE_HOST=""
    fi
    if ! run_timeout "$TIMEOUT" gh "${args[@]}" >/dev/null 2>&1; then
        echo "gh not authenticated${REMOTE_HOST:+ for $REMOTE_HOST} - run: gh auth login${REMOTE_HOST:+ --hostname $REMOTE_HOST}"
        return 1
    fi
}

check_gh_push() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "gh not on PATH - install GitHub CLI (brew install gh)"
        return 1
    fi
    resolve_push_target || return 1
    local push
    push="$(run_timeout "$TIMEOUT" gh api --hostname "$REMOTE_HOST" "repos/$REMOTE_SLUG" --jq '.permissions.push' 2>/dev/null)" || {
        echo "gh api repos/$REMOTE_SLUG on $REMOTE_HOST failed - check gh auth for $REMOTE_HOST and that the repo exists/is visible to the active account"
        return 1
    }
    if [ "$push" != "true" ]; then
        echo "active gh account on $REMOTE_HOST cannot push to $REMOTE_SLUG - run: gh auth switch --hostname $REMOTE_HOST (or gh auth login with the right account)"
        return 1
    fi
}

CHECKS=(munin validation_vm codex gh_auth gh_push)

# Without a scratch dir the result files below would land in filesystem-root paths and every
# check would read back as failed, so stop here with the real cause instead.
if ! TMP="$(mktemp -d "${TMPDIR:-/tmp}/devops-checks.XXXXXX")" || [ -z "$TMP" ] || [ ! -d "$TMP" ]; then
    echo "devops-checks.sh: cannot create temporary directory under ${TMPDIR:-/tmp} - free space or fix permissions" >&2
    exit 2
fi
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
