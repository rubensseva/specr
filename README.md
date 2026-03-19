# specr

Spec-driven feature development for any codebase. Write the spec first, implement second.

`specr` launches Claude Code in a specification-only mode. You describe a rough feature idea, Claude researches the codebase, interviews you to flesh it out, and writes a structured spec. When the spec is ready, `specr ralph` implements it task by task in an automated loop.

## Requirements

- macOS
- `claude` CLI installed and on `PATH`

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/rubensaldanha/specr/main/install.sh | bash
```

The installer clones to `~/.specr-cli`, symlinks the binary to `~/.local/bin`, and offers to add it to your `PATH` if needed.

Or manually:

```bash
git clone https://github.com/rubensaldanha/specr.git ~/.specr-cli
mkdir -p ~/.local/bin
ln -sf ~/.specr-cli/bin/specr ~/.local/bin/specr
```

If `~/.local/bin` is not on your PATH, add this to your `~/.zshrc` (or `~/.bashrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

To update: `specr update`

## Quick start

```bash
cd your-project

# 1. Create a spec — Claude researches the codebase and interviews you
specr "add team billing with seat management"

# 2. Review what you have
specr list

# 3. Run a readiness check (recommended before first run)
specr preflight

# 4. Implement the spec — automated loop, one task at a time
specr ralph
```

## Commands

### `specr "rough feature idea"`

Starts an interactive spec session. Claude researches the codebase, asks clarifying questions, and writes a spec to `.specr/draft/`. When you're both happy with it, Claude moves the spec to `.specr/ready/` — at which point it's ready for implementation.

Use `--claude` to use Claude directly (default is Codex).

### `specr list`

Shows all specs grouped by lifecycle state (draft, ready, in-progress, completed). Empty states are omitted.

### `specr ralph [-n N] [spec-file]`

Implements a spec. Picks the most recent spec from `ready/`, or accepts a specific filename.

Ralph is an automated loop — it invokes Claude in non-interactive mode (`--print`), one top-level task per iteration, with a fresh context window each time. State persists through the spec file (markdown checkboxes) and git commits.

The loop:
1. Moves the spec from `ready/` to `in-progress/`.
2. Creates a feature branch if on main/master.
3. Each iteration: reads the spec, implements the next unchecked task, checks it off, adds a brief implementation note, and commits.
4. When all tasks are done, moves the spec to `completed/`.

Use `-n` to set the max number of iterations (default 20).

### Other commands

| Command | Description |
|---|---|
| `specr auto [-n N] [--model M] "idea"` | Autonomous spec creation — two-agent loop (writer + reviewer), no user interaction. Experimental. |
| `specr preflight [spec-file]` | Read-only readiness check before running ralph. Tests tool access, analyzes the spec for blockers. |
| `specr sync [--dry-run]` | AI-verified sync — reads all specs, checks the codebase, and moves specs to their correct state folder. |
| `specr update` | Update specr to the latest version. |
| `specr --version` | Show version. |

## Spec lifecycle

Specs move through four state folders under `.specr/`:

```
draft/  →  ready/  →  in-progress/  →  completed/
```

| Folder | Meaning |
|---|---|
| `draft/` | Spec is being written or refined |
| `ready/` | Finalized and ready for implementation |
| `in-progress/` | Currently being implemented by ralph |
| `completed/` | All tasks done |

During an interactive session, Claude manages state transitions (with your confirmation). During `specr ralph`, the loop handles transitions automatically.

## How specs are structured

Specs are markdown files with these sections:

- **What we are solving** — the problem and goal
- **Technical implementation** — the bulk of the spec; concrete implementation details
- **Relevant findings** — what was discovered about the current codebase
- **Constraints and assumptions**
- **Acceptance criteria** — observable, testable conditions
- **Task list** — markdown checklists (`- [ ]`) with 4-10 top-level tasks and subtasks

The task list drives implementation: ralph checks off tasks as it completes them and adds brief notes about what was done.

## Notes

- The tool installs to `~/.specr-cli` (distinct from the per-project `.specr/` spec directory).
- The entire tool is a single bash script at `bin/specr` — all prompts are embedded directly in it.
- Ralph uses Sonnet by default for non-interactive commands.
- Specs are named `spec-<YYYYMMDD>-<HHMMSS>-<short-name>.md`.
