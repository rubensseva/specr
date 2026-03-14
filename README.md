# specr

`specr` is a minimal single-file launcher that starts Claude Code in a strict specification-only workflow.

Run it inside any project directory with a rough feature idea:

```bash
specr "add team billing with seat management"
```

Claude starts in `Specr mode`, inspects the project, aligns on its understanding, interviews you to flesh out the feature, and writes the resulting spec to `.specr/spec-<timestamp>-<short-name>.md`.

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

1. Reserve a timestamped spec path under `.specr/`.
2. Launch Claude Code with the Specr startup prompt.
3. Keep the session focused on spec creation only.
4. Have Claude create a single spec file named `.specr/spec-<timestamp>-<short-name>.md` once it understands the feature well enough to name it clearly.

## Notes

- v1 is intentionally narrow. It only launches Claude Code.
- `specr` does not manage sessions, resumes, or implementation.
- The full Specr prompt is embedded directly in `bin/specr`.
