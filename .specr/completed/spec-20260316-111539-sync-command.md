# Spec: `specr sync` — AI-verified spec state sync

## Problem / Goal

Spec files can drift out of sync with reality. A spec might sit in `in-progress/` long after its feature has been fully implemented, or linger in `ready/` when work has already begun. Today, the only way to fix this is manual inspection and `mv` commands.

The goal is a new `specr sync` subcommand that invokes Claude Code once in non-interactive mode (`--print`) to analyze all spec files against the actual codebase and move each to the correct state folder based on real implementation status.

A `--dry-run` flag lets users preview what would change without moving anything.

## Relevant findings about the current project

- `bin/specr` is the sole entry point — a bash script with subcommand routing (`list`, `ralph`, `preflight`, plus default spec creation).
- Existing non-interactive Claude invocations use `claude --print --model sonnet --append-system-prompt`.
- State folders: `draft/`, `ready/`, `in-progress/`, `completed/` under `.specr/`.
- Spec files contain Markdown checkbox task lists (`- [ ]` / `- [x]`) and structured sections (Problem, Technical implementation, Task list, etc.).
- The `ensure_state_dirs` helper already exists and is reused across subcommands.
- Ralph already moves specs between folders (`ready/ → in-progress/` on start, `in-progress/ → completed/` on finish).

## Technical implementation

### 1. New subcommand: `specr sync [--dry-run]`

Add a `sync` subcommand to the argument routing in `bin/specr`.

- `specr sync` — run sync, move files as needed.
- `specr sync --dry-run` — run sync, report recommendations only, do not move files.

Update the `usage()` function to include the new subcommand.

### 2. Single Claude invocation

The entire sync is one `claude --print --model sonnet` call. The bash wrapper does minimal work — it just builds the prompt and hands everything to Claude.

```bash
claude --print --model sonnet --append-system-prompt "${SYNC_PROMPT}" \
  "Sync the spec files in .specr/ to their correct state folders."
```

Claude handles everything: reading the specs, exploring the codebase, deciding the correct state, and moving files (or just reporting in dry-run mode).

### 3. System prompt (`SYNC_PROMPT`)

The system prompt instructs Claude to:

1. Discover all `.md` spec files across all four state folders (`draft/`, `ready/`, `in-progress/`, `completed/`) and the `.specr/` root (legacy orphans).
2. For each spec:
   - Read the spec content, especially the task list.
   - Explore the codebase to verify whether the described changes actually exist — check for the files, functions, configs, or behaviors the spec describes.
   - Determine the correct state:
     - `draft` — spec is incomplete, missing sections, or not yet actionable.
     - `ready` — spec is complete and well-formed, but no implementation work has started in the codebase.
     - `in-progress` — some but not all described work exists in the codebase.
     - `completed` — all described work is fully implemented in the codebase.
3. Report findings for each spec: current folder, recommended folder, and a one-line reason.
4. Move files that need to change (using `mv`) — or, if dry-run mode is indicated in the prompt, only report what would change without moving anything.

The dry-run vs. normal distinction is communicated to Claude via the user prompt, not the system prompt. In dry-run mode, the user prompt includes an instruction like "This is a dry run — report recommendations only, do NOT move any files."

### 4. Bash wrapper (`specr_sync`)

The bash function is intentionally minimal — just argument parsing and a single Claude call. No output parsing, no result codes, no structured format. Claude's output *is* the output.

### 5. Changes to `bin/specr`

1. **`usage()`** — add `specr sync [--dry-run]` line.
2. **New function `specr_sync()`** — thin wrapper as described above.
3. **Argument routing `case` block** — add `sync)` case.
4. **`SYNC_PROMPT`** — defined inside `specr_sync()`, consistent with how other prompts are scoped.

## Constraints and assumptions

- Claude Code (`claude` CLI) must be installed and on PATH.
- `--print` runs Claude non-interactively (no user input possible).
- `--model sonnet` is used for cost/speed efficiency, consistent with other non-interactive commands in the project.
- Claude has access to file read/write and bash tools via `--print` mode, so it can both explore the codebase and execute `mv` commands.
- Sync is a point-in-time operation — reflects current codebase state when run.
- Should not be run while ralph is actively implementing a spec.

## Acceptance criteria

- `specr sync` invokes Claude once in non-interactive mode to analyze all specs against the codebase.
- Claude reads each spec, verifies implementation status against actual code, and moves specs to the correct state folder.
- `specr sync --dry-run` reports recommendations without moving any files.
- Output clearly shows each spec's current state, recommended state, and reasoning.
- `specr sync` is documented in the `usage()` output.

## Task list

- [ ] Add `specr_sync` function to `bin/specr`
  - [ ] Parse `--dry-run` flag
  - [ ] Define `SYNC_PROMPT` instructing Claude to discover, analyze, and move/report spec files
  - [ ] Build user prompt (with dry-run variation)
  - [ ] Invoke `claude --print --model sonnet --append-system-prompt` and print output
- [ ] Add argument routing for `sync` subcommand in the `case` block
- [ ] Update `usage()` to document `specr sync [--dry-run]`
