# specr

`specr` helps you spec features before you implement them.

The main workflow is `specr "rough idea"`: it researches the codebase, asks clarifying questions, and writes a concrete spec under `.specr/`. When that spec is ready, `specr ralph` is the convenience layer that implements it one top-level task at a time.

Everything else is secondary support around that flow.

## Requirements

- macOS
- `git`
- `codex` for the default speccing flow, or `claude` if you use `specr --claude`
- `claude` for `specr ralph`, `specr preflight`, `specr auto`, and `specr sync`

## Install

```bash
git clone https://github.com/rubensseva/specr.git ~/.specr-cli
mkdir -p ~/.local/bin
ln -sf ~/.specr-cli/bin/specr ~/.local/bin/specr
```

If `~/.local/bin` is not on your `PATH`, add this to `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

To update later:

```bash
specr update
```

## Quick start

```bash
cd your-project

# 1. Create a spec
specr "add team billing with seat management"

# 2. See what state it is in
specr list

# 3. Optional: run a readiness check before implementation
specr preflight

# 4. Implement the latest ready spec
specr ralph
```

## Main commands

### `specr "rough feature idea"`

The primary feature. Starts an interactive speccing session and writes the spec to `.specr/draft/`. When the spec is solid, it moves to `.specr/ready/`.

By default this uses Codex. Use `specr --claude "idea"` to force Claude instead.

### `specr ralph [-n N] [spec-file]`

The secondary feature. Implements a ready spec in an automated loop, one top-level task per iteration.

`ralph` will:

1. Pick the latest spec from `.specr/ready/` unless you pass a filename.
2. Move it to `.specr/in-progress/`.
3. Create a feature branch if you are on `main` or `master`.
4. Implement one top-level task per iteration, update the checkboxes in the spec, and commit the code changes.
5. Move the spec to `.specr/completed/` when everything is done.

Use `-n` to set the max iteration count. The default is `20`.

## Supporting commands

| Command | What it does |
|---|---|
| `specr list` | Show specs grouped by state. |
| `specr preflight [spec-file]` | Check whether the environment is ready for `ralph`. |
| `specr auto [-n N] [--model M] "idea"` | Experimental autonomous spec creation. |
| `specr sync [--dry-run]` | Reconcile spec state folders with actual codebase progress. |
| `specr update` | Update the local install. |
| `specr --version` | Show the current version. |

## Spec states

Specs live under `.specr/` and move through:

```text
draft/ -> ready/ -> in-progress/ -> completed/
```

Each spec is a markdown file with:

- What we are solving
- Technical implementation
- Relevant findings
- Constraints and assumptions
- Acceptance criteria
- Task list with markdown checkboxes

That task list is what `ralph` executes and checks off over time.
