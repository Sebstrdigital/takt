#!/bin/bash
# DuaLoop Migration Script
# Migrates projects from old "Ralph" workflow to new DuaLoop structure
# Usage: /path/to/DuaLoop/migrate.sh

set -e

# Get the directory where this script lives (the DuaLoop repo)
DUALOOP_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target is the current working directory
TARGET_DIR="$(pwd)"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              DuaLoop Migration Script                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Source: $DUALOOP_SOURCE"
echo "Target: $TARGET_DIR"
echo ""

# Check we're not running from inside the DuaLoop repo itself
if [ "$DUALOOP_SOURCE" = "$TARGET_DIR" ]; then
  echo "Error: You're running migrate.sh from inside the DuaLoop repository."
  echo "       Run this from your project directory instead:"
  echo ""
  echo "       cd /path/to/your/project"
  echo "       $DUALOOP_SOURCE/migrate.sh"
  echo ""
  exit 1
fi

# Check if this looks like an old Ralph project
RALPH_DETECTED=false
if [ -f "$TARGET_DIR/ralph.sh" ] || [ -d "$TARGET_DIR/skills/ralph" ] || [ -d "$TARGET_DIR/scripts/ralph" ] || grep -qi "ralph" "$TARGET_DIR/CLAUDE.md" 2>/dev/null; then
  RALPH_DETECTED=true
  echo "Old Ralph workflow detected."
else
  echo "No old Ralph workflow detected."
  echo "If this is a fresh project, use init.sh instead:"
  echo "  $DUALOOP_SOURCE/init.sh"
  echo ""
  read -p "Continue with migration anyway? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Step 1: Backup existing files"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Backup AGENTS.md if it exists
if [ -f "$TARGET_DIR/AGENTS.md" ]; then
  cp "$TARGET_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md.backup"
  echo "  ✓ AGENTS.md → AGENTS.md.backup"
else
  echo "  - No AGENTS.md found (will be created)"
fi

# Backup CLAUDE.md if it exists
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
  cp "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md.backup"
  echo "  ✓ CLAUDE.md → CLAUDE.md.backup"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Step 2: Move old archive to new location"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Move old archive/ to tasks/archive/
if [ -d "$TARGET_DIR/archive" ]; then
  mkdir -p "$TARGET_DIR/tasks"
  if [ -d "$TARGET_DIR/tasks/archive" ]; then
    # Merge contents
    cp -r "$TARGET_DIR/archive/"* "$TARGET_DIR/tasks/archive/" 2>/dev/null || true
    rm -rf "$TARGET_DIR/archive"
    echo "  ✓ Merged archive/ into tasks/archive/"
  else
    mv "$TARGET_DIR/archive" "$TARGET_DIR/tasks/archive"
    echo "  ✓ Moved archive/ → tasks/archive/"
  fi
else
  echo "  - No old archive/ folder found"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Step 3: Run init.sh to create new structure"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Run init.sh
"$DUALOOP_SOURCE/init.sh"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Step 4: Merge AGENTS.md with backup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Merge AGENTS.md if backup exists
if [ -f "$TARGET_DIR/AGENTS.md.backup" ]; then
  # Extract project-specific content from backup (everything before DuaLoop section if it exists)
  # and merge with new DuaLoop workflow section

  # Check if backup already had DuaLoop section
  if grep -q "## DuaLoop Workflow" "$TARGET_DIR/AGENTS.md.backup" 2>/dev/null; then
    # Old backup already has DuaLoop section, just restore it
    mv "$TARGET_DIR/AGENTS.md.backup" "$TARGET_DIR/AGENTS.md"
    echo "  ✓ Restored AGENTS.md (already had DuaLoop section)"
  else
    # Need to merge: keep old content + add new DuaLoop section
    # Get the DuaLoop section from the new AGENTS.md
    DUALOOP_SECTION=$(sed -n '/## DuaLoop Workflow/,$p' "$TARGET_DIR/AGENTS.md" 2>/dev/null || echo "")

    if [ -n "$DUALOOP_SECTION" ]; then
      # Append DuaLoop section to backup and use that
      echo "" >> "$TARGET_DIR/AGENTS.md.backup"
      echo "$DUALOOP_SECTION" >> "$TARGET_DIR/AGENTS.md.backup"
      mv "$TARGET_DIR/AGENTS.md.backup" "$TARGET_DIR/AGENTS.md"
      echo "  ✓ Merged: kept your project content + added DuaLoop Workflow section"
    else
      # No DuaLoop section found, just restore backup
      mv "$TARGET_DIR/AGENTS.md.backup" "$TARGET_DIR/AGENTS.md"
      echo "  ✓ Restored original AGENTS.md"
    fi
  fi
else
  echo "  - No backup to merge (new AGENTS.md created by init.sh)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Step 5: Clean up old files and reset state"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Remove .last-branch to prevent false branch-change detection
# This file from previous projects would cause dualoop.sh to archive
# the NEW prd.json before the agent can read it
if [ -f "$TARGET_DIR/.last-branch" ]; then
  rm -f "$TARGET_DIR/.last-branch"
  echo "  ✓ Removed .last-branch (prevents stale branch detection)"
fi

# Also remove .original-branch if present
if [ -f "$TARGET_DIR/.original-branch" ]; then
  rm -f "$TARGET_DIR/.original-branch"
  echo "  ✓ Removed .original-branch"
fi

# Ensure .dualoop-stats.json is in .gitignore (may have been skipped by init.sh)
if [ -f "$TARGET_DIR/.gitignore" ]; then
  if ! grep -q "^\.dualoop-stats\.json$" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    echo ".dualoop-stats.json" >> "$TARGET_DIR/.gitignore"
    echo "  ✓ Added .dualoop-stats.json to .gitignore"
  fi
fi

# Clean up old Ralph files
CLEANED_SOMETHING=false

if [ -f "$TARGET_DIR/ralph.sh" ]; then
  rm "$TARGET_DIR/ralph.sh"
  echo "  ✓ Removed ralph.sh"
  CLEANED_SOMETHING=true
fi

if [ -d "$TARGET_DIR/skills/ralph" ]; then
  rm -rf "$TARGET_DIR/skills/ralph"
  echo "  ✓ Removed skills/ralph/"
  CLEANED_SOMETHING=true
fi

if [ -d "$TARGET_DIR/scripts/ralph" ]; then
  rm -rf "$TARGET_DIR/scripts/ralph"
  echo "  ✓ Removed scripts/ralph/"
  CLEANED_SOMETHING=true
  # Check if scripts folder is now empty
  if [ -d "$TARGET_DIR/scripts" ] && [ -z "$(ls -A "$TARGET_DIR/scripts" 2>/dev/null)" ]; then
    rm -rf "$TARGET_DIR/scripts"
    echo "  ✓ Removed empty scripts/ folder"
  fi
fi

# Check for old prompt.md in root (new one is in dualoop/)
if [ -f "$TARGET_DIR/prompt.md" ] && [ -f "$TARGET_DIR/dualoop/prompt.md" ]; then
  rm "$TARGET_DIR/prompt.md"
  echo "  ✓ Removed old prompt.md (new one in dualoop/)"
  CLEANED_SOMETHING=true
fi

# Clean up empty skills folder if ralph was the only thing in it
if [ -d "$TARGET_DIR/skills" ] && [ -z "$(ls -A "$TARGET_DIR/skills" 2>/dev/null)" ]; then
  rm -rf "$TARGET_DIR/skills"
  echo "  ✓ Removed empty skills/ folder"
  CLEANED_SOMETHING=true
fi

if [ "$CLEANED_SOMETHING" = "false" ]; then
  echo "  - No old Ralph files found to clean up"
fi

# Warn about old skills/prd if it exists alongside new one
if [ -d "$TARGET_DIR/skills/prd" ] && [ -d "$TARGET_DIR/dualoop/skills/prd" ]; then
  echo ""
  echo "  Note: Old skills/prd/ folder still exists."
  echo "        New PRD skill is in dualoop/skills/prd/"
  echo "        You may want to remove skills/prd/ if not customized."
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Step 6: Clean Ralph references from CLAUDE.md and AGENTS.md"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Clean Ralph references from AGENTS.md
if [ -f "$TARGET_DIR/AGENTS.md" ]; then
  if grep -qi "ralph" "$TARGET_DIR/AGENTS.md" 2>/dev/null; then
    # Remove Ralph-specific sections
    # Remove lines containing "ralph" (case insensitive)
    sed -i.tmp '/[Rr]alph/d' "$TARGET_DIR/AGENTS.md"
    rm -f "$TARGET_DIR/AGENTS.md.tmp"

    # Replace any remaining ralph references with dualoop
    sed -i.tmp 's|scripts/ralph|dualoop|g' "$TARGET_DIR/AGENTS.md"
    rm -f "$TARGET_DIR/AGENTS.md.tmp"

    echo "  ✓ Cleaned Ralph references from AGENTS.md"
  else
    echo "  - No Ralph references found in AGENTS.md"
  fi
fi

if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
  # Check for Ralph references
  if grep -qi "ralph" "$TARGET_DIR/CLAUDE.md" 2>/dev/null; then
    # Remove lines containing "ralph" (case insensitive) and clean up
    # But preserve the rest of the file
    sed -i.tmp '/[Rr]alph/d' "$TARGET_DIR/CLAUDE.md"
    rm -f "$TARGET_DIR/CLAUDE.md.tmp"

    # Also remove any "skills/ralph" references
    sed -i.tmp 's|skills/ralph|dualoop/skills/dua|g' "$TARGET_DIR/CLAUDE.md"
    rm -f "$TARGET_DIR/CLAUDE.md.tmp"

    # Remove ralph.sh references
    sed -i.tmp 's|ralph\.sh|dualoop/dualoop.sh|g' "$TARGET_DIR/CLAUDE.md"
    rm -f "$TARGET_DIR/CLAUDE.md.tmp"

    echo "  ✓ Cleaned Ralph references from CLAUDE.md"
  else
    echo "  - No Ralph references found in CLAUDE.md"
  fi
fi

# Clean up CLAUDE.md backup if migration was successful
if [ -f "$TARGET_DIR/CLAUDE.md.backup" ]; then
  rm -f "$TARGET_DIR/CLAUDE.md.backup"
  echo "  ✓ Removed CLAUDE.md.backup"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              Migration Complete!                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "What was done:"
echo "  - Created dualoop/ folder with scripts and skills"
echo "  - Preserved your progress.txt"
echo "  - Merged your AGENTS.md with DuaLoop workflow section"
echo "  - Moved archive/ to tasks/archive/"
echo "  - Cleaned up old Ralph files"
echo "  - Updated CLAUDE.md references"
echo ""
echo "New workflow:"
echo "  1. Describe a feature to Claude"
echo "  2. Say 'Create the PRD'"
echo "  3. Claude will ask to convert to prd.json"
echo "  4. Claude will ask to start the loop"
echo "  5. DuaLoop runs autonomously"
echo "  6. Choose to merge or create PR when done"
echo ""
echo "Run: ./dualoop/dualoop.sh"
echo ""
