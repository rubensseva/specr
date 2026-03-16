# Spec: Ralph Preflight Check

## Problem / Goal

Before running `specr ralph`, there is no way to verify that Claude Code has the permissions, tools, and environment access it will need to implement a spec. If a permissions issue or missing dependency surfaces mid-loop (e.g., on iteration 5 of 20), the user has wasted time and may have a half-implemented spec stuck in `in-progress/`.

The goal is to add a `specr preflight` command that invokes Claude Code in `--print` mode with a prompt instructing it to read the spec, analyze what it would need to implement it, and produce a structured report covering:

- **Required:** permissions and tools that are essential for implementation.
- **Recommended:** permissions, tools, or environment improvements that would help produce a better result.
- **Environment:** git access, file system access, external dependencies or services mentioned in the spec.

The preflight does not block or gate anything programmatically — it outputs Claude's report and the user reads it.

## Relevant Findings

- The ralph loop lives in `bin/specr`, function `specr_ralph()` (lines 47–181).
- Ralph invokes Claude Code as: `claude --print --model sonnet --append-system-prompt "${RALPH_PROMPT}" "Implement the next task in the spec: ${SPEC_PATH}"`
- Spec selection in ralph supports: explicit filename (looks in `ready/` then `in-progress/`), or defaults to most recently modified `.md` in `ready/`.
- Claude Code permissions are configured in `.claude/settings.local.json` under `permissions.allow`. Currently only `WebSearch` is allowed.
- Claude Code's `--print` mode runs non-interactively: it executes, prints output, and exits. This is the correct mode for preflight since the report is the output.
- The `RALPH_PROMPT` (lines 110–138) describes what ralph does — the preflight prompt needs to reference the same working context so it can accurately predict what ralph will need.

## Technical Implementation

### 1. New `specr_preflight()` function in `bin/specr`

Add a new function `specr_preflight()` that:

1. Checks `claude` is on PATH (same guard as `specr_ralph` and `specr_create`).
2. Calls `ensure_state_dirs`.
3. Selects a spec file using the same logic as `specr_ralph`:
   - If an argument is provided, look for it in `ready/` then `in-progress/`.
   - If no argument, pick the most recently modified `.md` from `ready/`.
   - Error if no spec is found.
4. Does **not** move the spec between state folders — this is read-only.
5. Builds a `PREFLIGHT_PROMPT` (see below).
6. Invokes Claude Code: `claude --print --model sonnet --append-system-prompt "${PREFLIGHT_PROMPT}" "Check implementation readiness for the spec: ${SPEC_PATH}"`
7. Prints Claude's output directly (it already goes to stdout via `--print`).

### 2. The `PREFLIGHT_PROMPT`

The prompt should instruct Claude to:

1. Read the spec file at the path provided in the user prompt.
2. Analyze every task and subtask to determine what tools, permissions, shell commands, file access, git operations, and external dependencies would be needed to implement the spec fully.
3. Attempt to verify its current environment by checking what it can actually do (e.g., run a test command, check git status, verify a CLI tool is installed, read relevant config files).
4. Produce a structured report with these sections:

   **Required** — Things that are essential. Implementation will fail or stall without these.
   - Permissions and tools (e.g., `Bash`, `Edit`, `Write`, file read access)
   - External CLIs or dependencies (e.g., `npm`, `cargo`, `docker`)
   - Environment requirements (e.g., environment variables, running services)

   **Recommended** — Things that aren't strictly blocking but would meaningfully improve the implementation quality or speed.
   - Additional tools or permissions that would help (e.g., `WebSearch` for looking up API docs)
   - Nice-to-have dependencies or configurations

   **Environment Status** — Current state of the working environment.
   - Git status (clean working tree? correct branch?)
   - Relevant project state (are dependencies installed? does the project build?)

   **Issues** — Any problems found, with suggested fixes where possible.

5. Be thorough but concise. Do not implement anything. Do not modify any files. This is a read-only analysis.

The prompt should also include the `RALPH_PROMPT` content (or a summary of it) so Claude understands the context in which the spec will be implemented — i.e., one task at a time, committing after each, using `--print` mode.

### 3. Command routing

Add a `preflight` case to the argument routing block at the bottom of `bin/specr`:

```bash
case "$1" in
  list)
    specr_list
    ;;
  preflight)
    shift
    specr_preflight "$@"
    ;;
  ralph)
    shift
    specr_ralph "$@"
    ;;
  *)
    specr_create "$@"
    ;;
esac
```

### 4. Usage text update

Add preflight to the `usage()` function:

```
specr preflight [spec-file]   Run a readiness check before implementing a spec
```

## Constraints and Assumptions

- The preflight is entirely read-only — it does not move specs between state folders, does not modify files, and does not create branches.
- The preflight uses `--print` mode (non-interactive). The user reads Claude's stdout output as the report.
- No exit code logic is needed beyond the default. If `claude` fails to run, the shell will propagate the error naturally.
- The spec selection logic should be extracted into a shared helper or duplicated from ralph — either approach is acceptable, but duplication is simpler and consistent with the current style of the script.
- The preflight prompt should give Claude enough context about ralph's execution model (one task at a time, commits after each, `--print` mode) so it can make accurate predictions about what will be needed.
- Uses `--model sonnet` to match ralph's model, ensuring the preflight check reflects the same capabilities as the actual implementation run.

## Acceptance Criteria

- `specr preflight` selects the most recent ready spec and runs a preflight check.
- `specr preflight <spec-file>` runs a preflight check on a specific spec (from `ready/` or `in-progress/`).
- The output is a structured report from Claude Code covering required permissions/tools, recommended improvements, environment status, and any issues found.
- No files are modified, no specs are moved, no branches are created.
- The `usage()` text includes the preflight command.
- The preflight prompt gives Claude enough context about ralph's execution model to make accurate assessments.

## Task List

- [ ] Add `specr_preflight()` function to `bin/specr`
  - [ ] Add `claude` PATH check (same pattern as other functions)
  - [ ] Add `ensure_state_dirs` call
  - [ ] Implement spec selection logic mirroring `specr_ralph` (argument or most-recent from `ready/`, also check `in-progress/`)
  - [ ] Build the `PREFLIGHT_PROMPT` heredoc with structured report instructions and ralph context
  - [ ] Invoke `claude --print --model sonnet --append-system-prompt "${PREFLIGHT_PROMPT}"` with the spec path as user prompt
- [ ] Update command routing and usage text
  - [ ] Add `preflight)` case to the `case` block in argument routing
  - [ ] Add preflight line to `usage()` output
