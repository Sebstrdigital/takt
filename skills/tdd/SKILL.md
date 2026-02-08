---
name: tdd
description: "Test-Driven Development workflow for implementing user stories. Use when implementing features with DuaLoop. Ensures code quality through red-green-refactor cycle. Triggers on: implement with tdd, test-driven development, tdd workflow."
source_id: seb-claude-tools
version: 1.0.0
---

# Test-Driven Development (TDD) Skill

Implement user stories using the TDD red-green-refactor cycle.

## The TDD Cycle

For each piece of functionality:

1. **RED** — Write a failing test first
2. **GREEN** — Write minimal code to make the test pass
3. **REFACTOR** — Clean up while keeping tests green

Never skip a step. Never write production code without a failing test.

## Workflow

### 1. Analyze the Story
- Read the user story and acceptance criteria
- Break down criteria into testable behaviors
- Identify test files needed and plan test cases

### 2. Write Failing Tests (RED)
- Write test(s) for ONE behavior at a time
- Run tests — they MUST fail. If they pass, the feature already exists or the test is wrong
- Verify the test fails for the RIGHT reason

### 3. Write Minimal Code (GREEN)
- Write the simplest code to make the test pass
- Do NOT add extra functionality, handle untested edge cases, or optimize prematurely

### 4. Refactor (REFACTOR)
- Improve code while keeping tests green
- Run tests after EVERY change

### 5. Repeat
- Add next test case (must fail), implement, refactor
- Continue until all acceptance criteria are covered

## Test Types by Story Type

| Story Type | What to Test |
|-----------|-------------|
| Database/Schema | Migration runs, schema matches, constraints work, defaults set correctly |
| Backend/API | Happy path, error status codes, validation, authorization |
| UI Component | Renders correctly, interactions work, loading/error states, accessibility |
| Integration | End-to-end flow, components integrate, data flows through system |

## Integration with DuaLoop

1. Read the story and check existing tests
2. Plan test cases for each acceptance criterion
3. TDD loop: red-green-refactor for each behavior
4. Final check: all tests pass, typecheck passes, lint passes
5. Commit with test files included
