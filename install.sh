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
# prompt.md removed in v2 — solo.md + worker.md replace it
if [ -f "$TAKT_DIR/prompt.md" ]; then
    rm -f "$TAKT_DIR/prompt.md"
fi
cp "$SCRIPT_DIR/agents/verifier.md" "$TAKT_DIR/verifier.md"
cp "$SCRIPT_DIR/lib/team-lead.md" "$TAKT_DIR/team-lead.md"
cp "$SCRIPT_DIR/lib/worker.md" "$TAKT_DIR/worker.md"
cp "$SCRIPT_DIR/lib/debug.md" "$TAKT_DIR/debug.md"
cp "$SCRIPT_DIR/lib/retro.md" "$TAKT_DIR/retro.md"
echo -e "  ${GREEN}copied${NC}   solo.md"
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
echo "Config -> $CLAUDE_MD"
mkdir -p "$CLAUDE_DIR"
[ -f "$CLAUDE_MD" ] || touch "$CLAUDE_MD"

TAKT_SECTION_START="<!-- takt:start -->"
TAKT_SECTION_END="<!-- takt:end -->"

generate_takt_section() {
    cat << 'SECTION'

<!-- takt:start -->
## takt - Autonomous Agent Orchestrator

**Proactive usage — IMPORTANT:**
When the user discusses a new feature, significant change, or enters plan mode for non-trivial work (likely 3+ stories), **suggest the takt workflow** instead of implementing inline:

1. "This sounds like it could be X stories — want me to create a PRD with `/takt-prd`?"
2. After PRD approval: convert to `stories.json` + `.takt/scenarios.json` with `/takt`
3. Execute with `takt solo` (≤5 stories) or `takt team` (6+ stories)

**Plan-mode interception — IMPORTANT:**
When the user wants to plan a feature (says "plan this", "I want to build X", or you're about to enter plan mode), use **AskUserQuestion** BEFORE entering native plan mode:
- **takt PRD** — Structured PRD with gated what/why/why-not flow, stories, acceptance criteria, autonomous execution (`/takt-prd`)
- **Native plan** — Vanilla Claude Code plan mode for simpler or non-story work

If the user picks takt PRD → run `/takt-prd` (which has its own gated flow).
If the user picks native plan → proceed with standard `EnterPlanMode`.

**When NOT to suggest takt:** Simple tasks (single file change, quick fix, one-liner), pure research/exploration, or when the user explicitly wants to implement directly.

**When the user says "use takt" (or similar) without prior context:**
If the user mentions takt outside of a planning session (no active PRD, no feature discussion in progress), present the available modes:

> Which takt mode do you want to run?
> - `takt solo` — Execute stories sequentially (needs `stories.json`)
> - `takt team` — Execute stories in parallel with multiple agents (needs `stories.json` with waves)
> - `takt debug` — Bug-fixing discipline (needs bug description or `bugs.json`)
> - `takt retro` — Retrospective from workbooks (needs `workbook-*.md` files)
> - `/takt-prd` — Start fresh: create a PRD for a new feature

**Commands:**
- `takt solo` — run stories sequentially (needs `stories.json`)
- `takt team` — run stories in parallel (multi-agent)
- `takt debug` — strict bug-fixing discipline
- `takt retro` — post-execution retrospective
- `/takt-prd` — generate PRD from feature description
- `/takt` — convert PRD to stories.json + .takt/scenarios.json
- `/tdd` — TDD workflow

**CRITICAL — Agent Type Rule:**
When launching any takt mode (`takt solo`, `takt team`, etc.), you MUST:
1. Read the corresponding prompt file FIRST (`~/.claude/lib/takt/solo.md`, `team-lead.md`, etc.)
2. Follow its "How to Launch" section exactly
3. Use `subagent_type: "general-purpose"` and `model: "sonnet"` for ALL spawned Tasks
4. NEVER use custom/named agent types (e.g. "Seb the boss", TDD agents, or any other named agent from the Task tool's agent list). The prompt files define the correct configuration — trust them.
<!-- takt:end -->
SECTION
}

if grep -q "$TAKT_SECTION_START" "$CLAUDE_MD" 2>/dev/null; then
    # Existing tagged section — replace it
    new_section="$(generate_takt_section)"
    # Use awk to replace between markers (inclusive)
    awk -v start="$TAKT_SECTION_START" -v end="$TAKT_SECTION_END" -v replacement="$new_section" '
        $0 ~ start { printing=0; printf "%s\n", replacement; next }
        $0 ~ end { printing=1; next }
        printing!=0 { print }
        BEGIN { printing=1 }
    ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp" && mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
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
