# Shared Optional Tooling — takt agents

Read `.takt/session.json` if it exists. Use the availability flags to select tools.

## jCodeMunch (when `jcodemunch.available` is `true`)

Prefer jCodeMunch MCP tools over Grep/Glob/Read for code navigation:
- `mcp__jcodemunch__search_symbols` to locate symbols
- `mcp__jcodemunch__get_file_outline` to understand file structure without reading it whole
- `mcp__jcodemunch__get_symbol_source` to fetch a single symbol's source
- `mcp__jcodemunch__find_references` to locate all usages or trace blast radius
- `mcp__jcodemunch__get_call_hierarchy` to follow execution paths across the codebase

## context-mode (when `context_mode.available` is `true`)

Prefer context-mode for long-output commands:
- `mcp__plugin_context-mode_context-mode__ctx_execute` for CLI producing >20 lines
- `mcp__plugin_context-mode_context-mode__ctx_execute_file` for analyzing logs, CSV, JSON

## Fallback

Both are optional. If `.takt/session.json` is missing or any MCP call errors, silently fall back to Grep / Read / Bash. Do not warn the user — the session agent already recorded availability during Phase 0. These tools are accelerators — they never replace your obligation to read the code.
