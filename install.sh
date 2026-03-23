#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.specr-cli"
BIN_DIR="${HOME}/.local/bin"
REPO_URL="https://github.com/rubensseva/specr.git"

info()  { printf '  %s\n' "$*"; }
ok()    { printf '  ✓ %s\n' "$*"; }
warn()  { printf '  ! %s\n' "$*"; }
err()   { printf '  ✗ %s\n' "$*" >&2; }

echo "specr installer"
echo ""

# Check prerequisites
missing=()
if ! command -v git >/dev/null 2>&1; then
  missing+=("git")
fi

if [[ ${#missing[@]} -gt 0 ]]; then
  err "Missing required tools: ${missing[*]}"
  exit 1
fi
ok "git found"

# Check provider availability — at least one supported provider should be present
providers_found=()
if command -v codex  >/dev/null 2>&1; then providers_found+=("codex");  ok "codex found (major-tier default)"; fi
if command -v claude >/dev/null 2>&1; then providers_found+=("claude"); ok "claude found (minor-tier default)"; fi
if command -v agent  >/dev/null 2>&1; then providers_found+=("cursor"); ok "agent found (Cursor provider)"; fi

if [[ ${#providers_found[@]} -eq 0 ]]; then
  warn "No supported agent provider found."
  warn "Install at least one of: codex, claude, or the Cursor agent CLI."
  warn "  codex:  https://github.com/openai/codex"
  warn "  claude: https://docs.anthropic.com/en/docs/claude-code"
  warn "  cursor: https://cursor.com/blog/cli"
else
  if ! command -v codex  >/dev/null 2>&1; then
    warn "codex not found — default major-tier provider unavailable"
    warn "Set SPECR_MAJOR_PROVIDER=claude or SPECR_MAJOR_PROVIDER=cursor to override"
  fi
  if ! command -v claude >/dev/null 2>&1; then
    warn "claude not found — default minor-tier provider unavailable"
    warn "Set SPECR_MINOR_PROVIDER=codex or SPECR_MINOR_PROVIDER=cursor to override"
  fi
fi

# Clone or update
if [[ -d "$INSTALL_DIR" ]]; then
  info "Updating existing installation at ${INSTALL_DIR}..."
  git -C "$INSTALL_DIR" pull --ff-only --quiet
  ok "Updated"
else
  info "Cloning specr to ${INSTALL_DIR}..."
  git clone --quiet "$REPO_URL" "$INSTALL_DIR"
  ok "Cloned"
fi

# Symlink
mkdir -p "$BIN_DIR"
ln -sf "${INSTALL_DIR}/bin/specr" "${BIN_DIR}/specr"
ok "Linked specr → ${BIN_DIR}/specr"

# Check PATH
if [[ ":${PATH}:" != *":${BIN_DIR}:"* ]]; then
  echo ""
  warn "${BIN_DIR} is not on your PATH"

  # Detect shell config file
  shell_name="$(basename "${SHELL:-/bin/zsh}")"
  case "$shell_name" in
    zsh)  rc_file="${HOME}/.zshrc" ;;
    bash) rc_file="${HOME}/.bashrc" ;;
    *)    rc_file="${HOME}/.profile" ;;
  esac

  read -r -p "  Add it to ${rc_file}? [Y/n] " answer
  answer="${answer:-Y}"
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    printf '\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >> "$rc_file"
    ok "Added to ${rc_file}"
    info "Run: source ${rc_file}  (or open a new terminal)"
  else
    info "Add this to your shell config manually:"
    info "  export PATH=\"${BIN_DIR}:\$PATH\""
  fi
else
  ok "${BIN_DIR} is on PATH"
fi

echo ""
echo "Done. Run 'specr --help' to get started."
echo ""
echo "Tip: add .specr to your global gitignore so it's ignored in every project:"
echo '     echo ".specr" >> "$(git config --global core.excludesfile || echo ~/.gitignore)" && git config --global core.excludesfile "$(git config --global core.excludesfile || echo ~/.gitignore)"'
echo ""
echo "Tip: before your first 'specr ralph', run 'specr preflight' in your project"
echo "     to verify the configured agent has the tools and environment access it needs."
