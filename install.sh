#!/bin/bash
#
# takt Installer
# Installs everything into ~/.claude/ so the repo can be deleted after install.
#
# Installed layout:
#   ~/.claude/lib/takt/             # Agent prompts + supporting files
#   ~/.claude/commands/             # Slash commands (/feature, /sprint, /tdd)
#   ~/.claude/CLAUDE.md             # takt section appended
#
# Safe install logic for commands:
#   - If target file exists with source_id: takt -> overwrite (update)
#   - If target file exists WITHOUT that source_id -> install with prefix
#   - If target file doesn't exist -> install as-is
#   - Shows version changes on updates
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ID="takt"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
TAKT_DIR="$CLAUDE_DIR/lib/takt"
PREFIX="takt-"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

installed=0
updated=0
prefixed=0
skipped=0

get_version() {
    local file="$1"
    grep -m1 '^version:' "$file" 2>/dev/null | sed 's/version: *//' || echo "unknown"
}

check_and_install() {
    local src="$1"
    local target_dir="$2"
    local filename
    filename="$(basename "$src")"

    mkdir -p "$target_dir"

    local target="$target_dir/$filename"
    local src_version
    src_version="$(get_version "$src")"

    local prefixed_name="${PREFIX}${filename}"
    local prefixed_target="$target_dir/$prefixed_name"

    if [ -f "$target" ] && grep -q "source_id: $SOURCE_ID" "$target" 2>/dev/null; then
        if diff -q "$src" "$target" >/dev/null 2>&1; then
            echo -e "  ${GRAY}current${NC}  $filename ${GRAY}(v$src_version)${NC}"
            skipped=$((skipped + 1))
        else
            cp "$src" "$target"
            echo -e "  ${BLUE}updated${NC}  $filename ${GRAY}(v$src_version)${NC}"
            updated=$((updated + 1))
        fi
    elif [ -f "$prefixed_target" ] && grep -q "source_id: $SOURCE_ID" "$prefixed_target" 2>/dev/null; then
        if diff -q "$src" "$prefixed_target" >/dev/null 2>&1; then
            echo -e "  ${GRAY}current${NC}  $prefixed_name ${GRAY}(v$src_version)${NC}"
            skipped=$((skipped + 1))
        else
            cp "$src" "$prefixed_target"
            echo -e "  ${BLUE}updated${NC}  $prefixed_name ${GRAY}(v$src_version)${NC}"
            updated=$((updated + 1))
        fi
    elif [ -f "$target" ]; then
        cp "$src" "$prefixed_target"
        echo -e "  ${YELLOW}prefixed${NC} $filename -> $prefixed_name ${GRAY}(existing file preserved)${NC}"
        prefixed=$((prefixed + 1))
    else
        cp "$src" "$target"
        echo -e "  ${GREEN}added${NC}    $filename ${GRAY}(v$src_version)${NC}"
        installed=$((installed + 1))
    fi
}

echo ""
echo "========================================="
echo "  takt Installer"
echo "========================================="
echo ""

# --- Cleanup legacy artifacts (removed 2026-04-16, safe to delete this block after 2026-06-01) ---
for old_file in "$TAKT_DIR/reviewer.md"; do
    if [ -f "$old_file" ]; then
        rm -f "$old_file"
        echo -e "  ${YELLOW}removed${NC}  $(basename "$old_file") (merged into final-gate.md)"
    fi
done
echo ""

# --- takt core ---
echo "takt -> $TAKT_DIR/"
mkdir -p "$TAKT_DIR"
cp "$SCRIPT_DIR/lib/run.md" "$TAKT_DIR/run.md"
cp "$SCRIPT_DIR/agents/verifier.md" "$TAKT_DIR/verifier.md"
cp "$SCRIPT_DIR/lib/worker.md" "$TAKT_DIR/worker.md"
cp "$SCRIPT_DIR/lib/debug.md" "$TAKT_DIR/debug.md"
cp "$SCRIPT_DIR/lib/retro.md" "$TAKT_DIR/retro.md"
cp "$SCRIPT_DIR/lib/final-gate.md" "$TAKT_DIR/final-gate.md"
cp "$SCRIPT_DIR/lib/tooling.md" "$TAKT_DIR/tooling.md"
cp "$SCRIPT_DIR/lib/init.md" "$TAKT_DIR/init.md"
echo -e "  ${GREEN}copied${NC}   run.md"
echo -e "  ${GREEN}copied${NC}   verifier.md"
echo -e "  ${GREEN}copied${NC}   worker.md"
echo -e "  ${GREEN}copied${NC}   debug.md"
echo -e "  ${GREEN}copied${NC}   retro.md"
echo -e "  ${GREEN}copied${NC}   final-gate.md"
echo -e "  ${GREEN}copied${NC}   tooling.md"
echo -e "  ${GREEN}copied${NC}   init.md"
echo ""

# --- Commands ---
echo "Commands -> $CLAUDE_DIR/commands/"
for f in "$SCRIPT_DIR"/commands/*.md; do
    [ -f "$f" ] && check_and_install "$f" "$CLAUDE_DIR/commands"
done
echo ""

# --- CLAUDE.md section ---
echo "Config -> $CLAUDE_MD"
mkdir -p "$CLAUDE_DIR"
[ -f "$CLAUDE_MD" ] || touch "$CLAUDE_MD"

TAKT_SECTION_START="<!-- takt:start -->"
TAKT_SECTION_END="<!-- takt:end -->"

generate_takt_section() {
    cat << 'SECTION'

<!-- takt:start -->
## takt — Autonomous Agent Orchestrator

For non-trivial work (3+ stories), suggest takt: `/feature` → `/sprint` → `start takt`.
Before entering plan mode, ask: takt Feature or native plan?

**Agent Type Rule:** Read the prompt file first (`~/.claude/lib/takt/run.md`, etc.), use `subagent_type: "general-purpose"` and `model: "sonnet"` for all spawned Tasks. Never use custom/named agent types.
<!-- takt:end -->
SECTION
}

if grep -q "$TAKT_SECTION_START" "$CLAUDE_MD" 2>/dev/null; then
    # Existing tagged section — remove old, append new
    sed -n "/$TAKT_SECTION_START/,/$TAKT_SECTION_END/!p" "$CLAUDE_MD" > "$CLAUDE_MD.tmp"
    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    generate_takt_section >> "$CLAUDE_MD"
    echo -e "  ${BLUE}updated${NC}  takt section"
    updated=$((updated + 1))
elif grep -q "## takt" "$CLAUDE_MD" 2>/dev/null; then
    # Old untagged section — remove it and append tagged version
    # Remove from "## takt" to end of file (old format was always at the end)
    sed -i '' '/^## takt/,$d' "$CLAUDE_MD"
    generate_takt_section >> "$CLAUDE_MD"
    echo -e "  ${BLUE}updated${NC}  takt section (migrated to tagged format)"
    updated=$((updated + 1))
else
    # No section at all — append
    generate_takt_section >> "$CLAUDE_MD"
    echo -e "  ${GREEN}added${NC}    takt section"
    installed=$((installed + 1))
fi
echo ""

# --- Summary ---
echo "-----------------------------------------"
echo -e "  ${GREEN}Added:${NC}    $installed"
echo -e "  ${BLUE}Updated:${NC}  $updated"
echo -e "  ${GRAY}Current:${NC}  $skipped"
echo -e "  ${YELLOW}Prefixed:${NC} $prefixed"
echo ""
echo "Installed to ~/.claude/ (repo can be deleted)"
echo ""
