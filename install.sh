#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.specr-cli"
BIN_DIR="${HOME}/.local/bin"
REPO_URL="https://github.com/rubensaldanha/specr.git"

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
if ! command -v claude >/dev/null 2>&1; then
  warn "claude CLI not found — specr requires it at runtime"
  warn "Install it before using specr: https://docs.anthropic.com/en/docs/claude-code"
else
  ok "claude CLI found"
fi

if [[ ${#missing[@]} -gt 0 ]]; then
  err "Missing required tools: ${missing[*]}"
  exit 1
fi
ok "git found"

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
echo "Tip: before your first 'specr ralph', run 'specr preflight' in your project"
echo "     to verify Claude has the tools and environment access it needs."
