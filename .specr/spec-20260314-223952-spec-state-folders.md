# Spec: State folders for spec lifecycle

## Problem / Goal

All specs currently land as flat files in `.specr/`. There is no way to track where a spec is in its lifecycle. Adding folder-based state management with `draft/`, `ready/`, `in-progress/`, and `completed/` subdirectories gives users a simple, filesystem-native way to see and manage spec progress.

The agent (Claude Code in Specr mode) is responsible for creating specs in the correct folder and moving them between states as part of the conversation. No manual file management is required from the user.

## Relevant findings about the current project

- `bin/specr` is the sole entry point — a bash script that launches Claude Code with `--append-system-prompt`.
- The script currently sets `SPEC_DIR=".specr"` and builds a path prefix `${SPEC_DIR}/spec-${STAMP}`.
- The system prompt instructs the agent to create the spec file at that prefix path.
- There are no subcommands today — `specr "idea"` is the only usage.
- Existing flat specs in `.specr/` root will be left as-is (not migrated).

## Technical implementation

### 1. Folder structure

The `.specr/` directory gains four state subdirectories:

```
.specr/
  draft/
  ready/
  in-progress/
  completed/
```

These represent the spec lifecycle. The normal flow is `draft → ready → in-progress → completed`, but the agent may skip states when appropriate (e.g., move directly from `draft` to `completed`).

### 2. Changes to `bin/specr`

#### Spec creation (`specr "idea"`)

- Change `SPEC_PATH_PREFIX` from `.specr/spec-${STAMP}` to `.specr/draft/spec-${STAMP}`.
- Run `mkdir -p` for all four state directories on every invocation (idempotent).
- Update the system prompt to describe the folder-based state system and the agent's responsibility for managing transitions.

#### New subcommand: `specr list`

Lists all spec files grouped by state folder. Output format:

```
draft
  spec-20260314-223952-spec-state-folders.md

in-progress
  spec-20260312-140000-billing-seats.md

completed
  spec-20260301-091500-dark-mode.md
```

Behavior:
- Iterates over the four state folders in lifecycle order: `draft`, `ready`, `in-progress`, `completed`.
- Lists `.md` files in each folder.
- Omits empty state groups entirely (no "ready" heading if there are no ready specs).
- If no specs exist in any folder, prints a short message like `No specs found.`

#### Argument routing

The script needs basic subcommand detection:
- `specr list` → run the list function.
- `specr "anything else"` → existing spec creation flow (unchanged behavior, new path).
- `specr` (no args) → existing usage message.

### 3. System prompt changes

The Specr system prompt in `bin/specr` must be updated to tell the agent:

- Specs are created in `.specr/draft/` (the path prefix already reflects this).
- Four states exist: `draft`, `ready`, `in-progress`, `completed`.
- The agent is responsible for moving spec files between state folders when appropriate during a session. For example, when the user indicates a spec is finalized and ready for implementation, the agent should move it to `ready/`.
- Moving a spec means using a shell command (e.g., `mv`) to relocate the file from one state folder to another, keeping the filename unchanged.
- The agent should confirm with the user before changing a spec's state.
- The normal flow is `draft → ready → in-progress → completed`, but states can be skipped.

### 4. No changes needed

- No migration of existing flat `.specr/*.md` files.
- No validation rules on state transitions.
- No changes to the spec file format itself.
- The `prompts/` directory is currently empty and not involved.

## Constraints and assumptions

- The agent (Claude Code) has access to shell tools and can run `mv` to relocate files between folders.
- State is purely filesystem-based — the folder a spec lives in *is* its state. No metadata, database, or config file.
- `specr list` is a pure bash operation, no Claude invocation needed.
- The four state names are fixed and not user-configurable in v1.

## Acceptance criteria

- Running `specr "idea"` creates the spec file in `.specr/draft/`.
- The agent's system prompt describes the state folders and the agent's responsibility for managing transitions.
- The agent can move a spec between state folders during a session.
- `specr list` displays specs grouped by state in lifecycle order, omitting empty groups.
- `specr list` with no specs prints a short empty-state message.
- All four state directories are created automatically on any `specr` invocation.
- Existing specs in `.specr/` root are unaffected.

## Task list

- [ ] Update `bin/specr` to create all four state directories (`draft/`, `ready/`, `in-progress/`, `completed/`) under `.specr/` on every invocation
- [ ] Change `SPEC_PATH_PREFIX` to use `.specr/draft/` instead of `.specr/`
- [ ] Add argument routing to `bin/specr` to detect `list` subcommand vs. spec creation
- [ ] Implement `specr list` function in `bin/specr`
  - [ ] Iterate state folders in lifecycle order
  - [ ] List `.md` files under each folder with a heading
  - [ ] Omit empty state groups
  - [ ] Handle the no-specs-at-all case
- [ ] Update the system prompt in `bin/specr` to describe the state folder system
  - [ ] Explain the four states and their meaning
  - [ ] Instruct the agent to move specs between folders when appropriate
  - [ ] Instruct the agent to confirm state changes with the user
- [ ] Update `README.md` to document `specr list` and the state folder structure
