# specr

AI agents write better code when they have a spec. The problem is that writing specs is the boring part, so nobody does it, and the agent wings it. specr writes the spec for you.

`specr "rough feature idea"` researches your codebase, asks clarifying questions, and writes a spec with implementation details, constraints, acceptance criteria, and a task list. You stay in control of scope; specr does the grunt work.

A skill can do planning too, but it's a prompt loaded into a session already full of other context. specr runs as its own process with a clean context window, fully dedicated to getting the spec right.

Once a spec is ready, `specr ralph` implements it. It picks up the spec, creates a feature branch, and works through the task list one item at a time, committing and checking off tasks as it goes.

There's also `specr list`, `specr preflight`, `specr sync`, and `specr auto`. Run `specr --help` for details.

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

To update later: `specr update`.
