# specr

AI agents write better code when they have a spec. The problem is that writing specs is the boring part, so nobody does it, and the agent wings it. specr writes the spec for you.

`specr "rough feature idea"` researches your codebase, asks clarifying questions, and writes a spec with implementation details, constraints, acceptance criteria, and a task list. You stay in control of scope; specr does the grunt work.

A skill can do planning too, but it's a prompt loaded into a session already full of other context. specr runs as its own process with a clean context window, fully dedicated to getting the spec right.

Once a spec is ready, `specr ralph` implements it. It picks up the spec, creates a feature branch, and works through the task list one item at a time, committing and checking off tasks as it goes.

There's also `specr list`, `specr preflight`, `specr sync`, and `specr auto`. Run `specr --help` for details.

## Requirements

- macOS
- `git`
- At least one supported agent provider:
  - `codex` — default for spec creation (`major` tier)
  - `claude` — default for implementation loops, preflight, sync (`minor` tier)
  - `agent` (Cursor headless CLI) — optional alternative for either tier

## Configuration

specr uses a two-tier agent model:

- **major** — spec authoring: `specr "idea"`, `specr auto` speccer
- **minor** — everything else: `specr ralph`, `specr preflight`, `specr auto` reviewer, `specr sync`

Built-in defaults: `major` uses `codex` + `gpt-5.4` with high reasoning; `minor` uses `claude` + `claude-sonnet-4-6`.

Override via environment variables:

```bash
export SPECR_MAJOR_PROVIDER=claude   # codex | claude | cursor
export SPECR_MAJOR_MODEL=claude-opus-4-5
export SPECR_MINOR_PROVIDER=claude
export SPECR_MINOR_MODEL=claude-sonnet-4-6
```

Or via config file at `~/.config/specr/config` (user-wide) or `.specr/config` (per-project):

```
major.provider=claude
major.model=claude-opus-4-5
minor.provider=claude
minor.model=claude-sonnet-4-6
```

Config precedence (lowest to highest): built-in defaults → user config → project config → environment variables → CLI overrides.

### Using Cursor

Cursor's headless `agent` CLI is supported as a provider for both spec creation and implementation. Note: the Cursor Agent CLI is currently in beta.

```bash
# Use Cursor for spec creation only
export SPECR_MAJOR_PROVIDER=cursor
export SPECR_MAJOR_MODEL=claude-sonnet-4-6

# Use Cursor with GPT 5.4 for spec creation
export SPECR_MAJOR_PROVIDER=cursor
export SPECR_MAJOR_MODEL=gpt-5.4

# Same but with fast mode (faster output, same model)
export SPECR_MAJOR_PROVIDER=cursor
export SPECR_MAJOR_MODEL=gpt-5.4-fast

# Use Cursor for everything
export SPECR_MAJOR_PROVIDER=cursor
export SPECR_MINOR_PROVIDER=cursor
```

To override the command used (e.g. non-standard install path):

```bash
export SPECR_CURSOR_CMD=/path/to/agent
export SPECR_CODEX_CMD=/path/to/codex
export SPECR_CLAUDE_CMD=/path/to/claude
```

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

To update later: `specr update`.
