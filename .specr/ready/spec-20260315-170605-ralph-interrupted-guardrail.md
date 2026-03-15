# Spec: Ralph Loop INTERRUPTED Guardrail

**Status:** Draft

## Problem / Goal

The ralph loop (`specr ralph`) currently runs up to `MAX_ITER` iterations with no way for the LLM agent to signal that it has encountered an unrecoverable problem. If the agent hits a situation where retrying cannot succeed (e.g., a blocking error, risk of data corruption, or a critical ambiguity requiring human input), it will continue looping uselessly — or worse, cause harm by retrying a dangerous operation.

The goal is to give the LLM agent an escape hatch: output the bare word `INTERRUPTED` that the loop detects deterministically, causing it to break immediately and surface the issue to the user.

## Relevant Findings

- The ralph loop lives in `bin/specr`, function `specr_ralph()` (lines 47–149).
- The loop runs `claude --print` up to `MAX_ITER` (10) times.
- Completion is detected by checking the last 5 lines of output for a line ending in `COMPLETED` (with a length guard of < 200 chars on the tail block). This same pattern should be reused for `INTERRUPTED`.
- On completion: exits 0, moves spec to `completed/`.
- On max iterations: exits 1, spec stays in `in-progress/`.
- The LLM prompt (lines 98–119) instructs the agent on behavior but currently has no instruction for signaling failure.

## Technical Implementation

### 1. Ralph prompt update

Add a new numbered instruction to `RALPH_PROMPT` (after the existing item 8) telling the agent:

- If you encounter a situation where **retrying cannot succeed**, **continuing risks data corruption**, or **critical user input is required before you can proceed**, output the single word `INTERRUPTED` as the very last thing in your response. Do not attempt to continue or retry.
- Examples of when to use INTERRUPTED:
  - A required external dependency or service is missing and cannot be installed within the task.
  - A task requires a decision or credential that only a human can provide.
  - Continuing would overwrite or corrupt data in a way that cannot be undone.
  - A fundamental assumption in the spec is incorrect and the task cannot be implemented as written.

### 2. INTERRUPTED signal detection in the loop

Add a second check in the `while` loop body, directly after the existing `COMPLETED` check block (after line 145 in the current file). The detection logic mirrors `COMPLETED` exactly:

```bash
if echo "$TAIL" | grep -q 'INTERRUPTED$' && [[ ${#TAIL} -lt 200 ]]; then
  echo ""
  echo "━━━ Ralph INTERRUPTED after ${ITER} iteration(s). Review output above for details. ━━━"
  exit 2
fi
```

Key details:
- Uses the same `$TAIL` variable (last 5 lines of output) already captured for the `COMPLETED` check.
- Matches `INTERRUPTED` at end of line (`INTERRUPTED$`), same anchoring as `COMPLETED$`.
- Same length guard (`${#TAIL} -lt 200`) to avoid false positives from longer lines that happen to contain the word.
- The spec file stays in `in-progress/` — no `mv` is performed.
- The loop output has already been printed via `echo "$OUTPUT"` before this check runs, so the user can see what went wrong.

### 3. Exit codes

The three loop outcomes and their exit codes:

| Outcome | Exit code | Spec moved to |
|---|---|---|
| COMPLETED | 0 | `completed/` |
| Max iterations | 1 | stays in `in-progress/` |
| INTERRUPTED | 2 | stays in `in-progress/` |

Exit code 2 is distinct so that calling scripts or CI can differentiate between "ran out of retries" and "agent actively bailed out."

## Constraints and Assumptions

- The `INTERRUPTED` signal is a bare word only — no reason string appended. The user reads the full iteration output above it for context.
- Detection uses the same tail-scanning pattern as `COMPLETED` to keep behavior consistent and predictable.
- The change is confined to `bin/specr` — no other files need modification.
- The `INTERRUPTED` check must come after the `COMPLETED` check so that `COMPLETED` takes priority if both somehow appear.

## Acceptance Criteria

- [ ] Agent can output `INTERRUPTED` as a bare word to halt the ralph loop.
- [ ] Loop exits with exit code 2 on interruption, distinct from completion (0) and max iterations (1).
- [ ] Spec file remains in `in-progress/` on interruption (no move).
- [ ] A clear message is printed indicating the loop was interrupted by the agent.
- [ ] `RALPH_PROMPT` includes instructions telling the agent when and how to use `INTERRUPTED`.
- [ ] Detection is robust — uses end-of-line anchoring and tail length guard, matching the `COMPLETED` pattern.

## Task List

- [ ] Update `RALPH_PROMPT` in `bin/specr` to add INTERRUPTED signal instructions
  - [ ] Add a new numbered instruction (after item 8) describing when to output `INTERRUPTED`
  - [ ] Include concrete examples of valid interruption scenarios
- [ ] Add INTERRUPTED detection logic to the ralph `while` loop in `bin/specr`
  - [ ] Add `grep -q 'INTERRUPTED$'` check on `$TAIL` after the existing `COMPLETED` check
  - [ ] Apply the same `${#TAIL} -lt 200` length guard
  - [ ] Print a user-facing message indicating interruption
  - [ ] Exit with code 2
  - [ ] Ensure spec file is NOT moved (stays in `in-progress/`)
