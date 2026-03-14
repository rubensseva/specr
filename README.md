# specr

`specr` is a minimal single-file launcher that starts Claude Code in a strict specification-only workflow.

Run it inside any project directory with a rough feature idea:

```bash
specr "add team billing with seat management"
```

Claude starts in `Specr mode`, inspects the project, aligns on its understanding, interviews you to flesh out the feature, and writes the resulting spec to `.specr/draft/spec-<timestamp>-<short-name>.md`.

## Requirements

- macOS
- `claude` installed and available on `PATH`

## Install

```bash
git clone https://github.com/your-org/specr.git ~/.specr && mkdir -p ~/.local/bin && ln -sf ~/.specr/bin/specr ~/.local/bin/specr
```

Make sure `~/.local/bin` is on your `PATH`.

## Usage

From the project you want to spec in:

```bash
specr "rough outline of the feature"
```

That will:

1. Create state directories under `.specr/` (if they don't exist).
2. Launch Claude Code with the Specr startup prompt.
3. Keep the session focused on spec creation only.
4. Have Claude create a single spec file named `.specr/draft/spec-<timestamp>-<short-name>.md` once it understands the feature well enough to name it clearly.

### Implement a spec (ralph loop)

```bash
specr ralph                    # implements the most recent ready spec
specr ralph spec-20260314-*.md # implements a specific spec
```

This runs the ralph loop — a `while` loop that repeatedly invokes Claude Code in non-interactive mode (`--print`), one task at a time, with a fresh context window each iteration. State persists through the filesystem and git between iterations.

The loop:
1. Moves the spec from `ready/` to `in-progress/`.
2. Creates a feature branch if on main/master.
3. Each iteration: Claude reads the spec, implements the next unchecked task, checks it off, adds a brief implementation note, and commits.
4. When all tasks are done, the spec moves to `completed/`.
5. Stops after 10 iterations if not complete (re-run `specr ralph` to resume).

### List specs

```bash
specr list
```

Shows all specs grouped by lifecycle state:

```
draft
  spec-20260314-223952-spec-state-folders.md

in-progress
  spec-20260312-140000-billing-seats.md

completed
  spec-20260301-091500-dark-mode.md
```

Empty states are omitted from the output.

## Spec lifecycle

Specs move through four state folders under `.specr/`:

| Folder | Meaning |
|---|---|
| `draft/` | Spec is being written or refined (initial state) |
| `ready/` | Spec is finalized and ready for implementation |
| `in-progress/` | Spec is currently being implemented |
| `completed/` | Implementation is done |

The agent manages state transitions during a session by moving spec files between folders.

## Notes

- The full Specr prompt is embedded directly in `bin/specr`.
- Existing specs in `.specr/` root are not migrated automatically.
