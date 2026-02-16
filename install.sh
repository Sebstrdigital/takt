#!/bin/bash
#
# takt Installer
# Installs everything into ~/.claude/ so the repo can be deleted after install.
#
# Installed layout:
#   ~/.claude/lib/takt/             # Agent prompts + supporting files
#   ~/.claude/commands/             # Slash commands (/takt, /takt-prd, /tdd)
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
        local target_version
        target_version="$(get_version "$target")"

        if [ "$src_version" = "$target_version" ]; then
            echo -e "  ${GRAY}current${NC}  $filename ${GRAY}(v$target_version)${NC}"
            skipped=$((skipped + 1))
        else
            cp "$src" "$target"
            echo -e "  ${BLUE}updated${NC}  $filename ${GRAY}v$target_version -> v$src_version${NC}"
            updated=$((updated + 1))
        fi
    elif [ -f "$prefixed_target" ] && grep -q "source_id: $SOURCE_ID" "$prefixed_target" 2>/dev/null; then
        local target_version
        target_version="$(get_version "$prefixed_target")"

        if [ "$src_version" = "$target_version" ]; then
            echo -e "  ${GRAY}current${NC}  $prefixed_name ${GRAY}(v$target_version)${NC}"
            skipped=$((skipped + 1))
        else
            cp "$src" "$prefixed_target"
            echo -e "  ${BLUE}updated${NC}  $prefixed_name ${GRAY}v$target_version -> v$src_version${NC}"
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

# --- Cleanup old dua-loop artifacts ---
OLD_DUALOOP_DIR="$CLAUDE_DIR/lib/dualoop"
if [ -d "$OLD_DUALOOP_DIR" ]; then
    rm -rf "$OLD_DUALOOP_DIR"
    echo -e "  ${YELLOW}removed${NC}  lib/dualoop/ (replaced by lib/takt/)"
fi
for old_cmd in dua.md dua-prd.md; do
    if [ -f "$CLAUDE_DIR/commands/$old_cmd" ]; then
        rm -f "$CLAUDE_DIR/commands/$old_cmd"
        echo -e "  ${YELLOW}removed${NC}  commands/$old_cmd"
    fi
done
# Replace prefixed tdd if old version exists alongside takt version
if [ -f "$CLAUDE_DIR/commands/takt-tdd.md" ] && [ -f "$CLAUDE_DIR/commands/tdd.md" ]; then
    if grep -q "source_id: dua-loop" "$CLAUDE_DIR/commands/tdd.md" 2>/dev/null; then
        rm -f "$CLAUDE_DIR/commands/tdd.md"
        mv "$CLAUDE_DIR/commands/takt-tdd.md" "$CLAUDE_DIR/commands/tdd.md"
        echo -e "  ${YELLOW}replaced${NC} tdd.md (old dua-loop version)"
    fi
fi
# Remove old dua-loop section from CLAUDE.md if takt section also present
if [ -f "$CLAUDE_MD" ] && grep -q "dua-loop - Autonomous Agent Loop" "$CLAUDE_MD" 2>/dev/null; then
    sed -i '' '/## dua-loop - Autonomous Agent Loop/,/## takt/{ /## takt/!d; }' "$CLAUDE_MD"
    echo -e "  ${YELLOW}cleaned${NC}  CLAUDE.md (removed old dua-loop section)"
fi
# Remove old takt.sh (replaced by native Claude Code execution)
if [ -f "$TAKT_DIR/takt.sh" ]; then
    rm -f "$TAKT_DIR/takt.sh"
    echo -e "  ${YELLOW}removed${NC}  lib/takt/takt.sh (replaced by native execution)"
fi
echo ""

# --- takt core ---
echo "takt -> $TAKT_DIR/"
mkdir -p "$TAKT_DIR"
cp "$SCRIPT_DIR/lib/solo.md" "$TAKT_DIR/solo.md"
cp "$SCRIPT_DIR/lib/prompt.md" "$TAKT_DIR/prompt.md"
cp "$SCRIPT_DIR/agents/verifier.md" "$TAKT_DIR/verifier.md"
cp "$SCRIPT_DIR/lib/team-lead.md" "$TAKT_DIR/team-lead.md"
cp "$SCRIPT_DIR/lib/worker.md" "$TAKT_DIR/worker.md"
cp "$SCRIPT_DIR/lib/debug.md" "$TAKT_DIR/debug.md"
cp "$SCRIPT_DIR/lib/retro.md" "$TAKT_DIR/retro.md"
echo -e "  ${GREEN}copied${NC}   solo.md"
echo -e "  ${GREEN}copied${NC}   prompt.md"
echo -e "  ${GREEN}copied${NC}   verifier.md"
echo -e "  ${GREEN}copied${NC}   team-lead.md"
echo -e "  ${GREEN}copied${NC}   worker.md"
echo -e "  ${GREEN}copied${NC}   debug.md"
echo -e "  ${GREEN}copied${NC}   retro.md"
echo ""

# --- Commands ---
echo "Commands -> $CLAUDE_DIR/commands/"
for f in "$SCRIPT_DIR"/commands/*.md; do
    [ -f "$f" ] && check_and_install "$f" "$CLAUDE_DIR/commands"
done
echo ""

# --- CLAUDE.md section ---
echo "Config -> $CLAUDE_DIR/CLAUDE.md"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
if [ ! -f "$CLAUDE_MD" ] || ! grep -q "takt" "$CLAUDE_MD" 2>/dev/null; then
    mkdir -p "$CLAUDE_DIR"
    cat >> "$CLAUDE_MD" << 'SECTION'

## takt - Autonomous Agent Orchestrator

Available globally. Use when a project has `prd.json`. Say these in Claude Code:
- `takt solo` — run stories sequentially (reads `~/.claude/lib/takt/solo.md`)
- `takt team` — run stories in parallel (reads `~/.claude/lib/takt/team-lead.md`)
- `takt debug` — strict bug-fixing discipline
- `takt retro` — post-execution retrospective
- `/takt-prd` — generate PRD from feature description
- `/takt` — convert PRD to prd.json
- `/tdd` — TDD workflow
SECTION
    echo -e "  ${GREEN}added${NC}    takt section"
    installed=$((installed + 1))
else
    echo -e "  ${GRAY}current${NC}  takt section already present"
    skipped=$((skipped + 1))
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
