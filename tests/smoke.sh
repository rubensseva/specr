#!/usr/bin/env bash
# tests/smoke.sh — shell-level smoke tests for specr agent routing and config precedence
#
# Usage: bash tests/smoke.sh
#
# Prepends fake codex/claude/agent stubs to PATH, runs specr commands in an
# isolated git repo, and verifies which provider binary is invoked for each
# command and config combination. No real provider calls are made.

PASS=0
FAIL=0

SPECR_BIN="$(cd "$(dirname "$0")/.." && pwd)/bin/specr"

# ── Assertion helpers ──────────────────────────────────────────────────────────
_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
_fail() { echo "  FAIL: $1"; echo "    expected: [$3]"; echo "    actual:   [$2]"; FAIL=$((FAIL + 1)); }

assert() {
  # assert "description" "$actual" "$expected"
  if [ "$2" = "$3" ]; then _pass "$1"; else _fail "$1" "$2" "$3"; fi
}

assert_file_contains() {
  # assert_file_contains "description" "/path/to/file" "needle"
  if grep -qF "$3" "$2" 2>/dev/null; then
    _pass "$1"
  else
    echo "  FAIL: $1"
    echo "    needle not found in $2: [$3]"
    FAIL=$((FAIL + 1))
  fi
}

# ── Temp environment ───────────────────────────────────────────────────────────
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

FAKE_BIN="$T/bin"
LOG="$T/log"
mkdir -p "$FAKE_BIN" "$LOG"

# Fake provider stubs: log their invocation, output "COMPLETED", exit 0.
# Using an unquoted heredoc so $_stub and $_log expand at write time;
# \$@ is escaped so it becomes literal $@ in the generated script.
for _stub in codex claude agent; do
  _log="$LOG/$_stub"
  cat > "$FAKE_BIN/$_stub" <<STUB_BODY
#!/usr/bin/env bash
echo "$_stub \$@" >> "$_log"
echo "COMPLETED"
exit 0
STUB_BODY
  chmod +x "$FAKE_BIN/$_stub"
done
unset _stub _log

# Minimal git repo for command tests
REPO="$T/repo"
git init -q "$REPO"
git -C "$REPO" config user.email test@test.com
git -C "$REPO" config user.name Test
touch "$REPO/.gitkeep"
git -C "$REPO" add .gitkeep
git -C "$REPO" commit -q -m "init"
# Ensure the branch is named "main" so ralph's branch-creation logic triggers
git -C "$REPO" branch -M main 2>/dev/null || git -C "$REPO" checkout -B main 2>/dev/null || true

# Controlled user config directory (empty — no user config by default)
USER_CFG="$T/user-config"
mkdir -p "$USER_CFG/specr"

# ── Helpers ────────────────────────────────────────────────────────────────────
clear_logs() { rm -f "$LOG/codex" "$LOG/claude" "$LOG/agent"; }

# Returns "yes" if the stub's log file is non-empty, "no" otherwise
was_invoked() { [ -s "$LOG/$1" ] && echo yes || echo no; }

# Place a minimal spec file in .specr/ready/ for ralph to consume
place_spec() {
  mkdir -p "$REPO/.specr/ready"
  printf '# Test spec\n## Task list\n- [ ] A task\n' > "$REPO/.specr/ready/spec-test.md"
}

clean_project_cfg() { rm -f "$REPO/.specr/config"; }
clean_user_cfg()    { rm -f "$USER_CFG/specr/config"; }

# Run specr inside the isolated repo.
# Any SPECR_* env vars exported by the caller are inherited by the child process.
run_specr() {
  (
    cd "$REPO"
    XDG_CONFIG_HOME="$USER_CFG" \
    HOME="$T/home" \
    PATH="$FAKE_BIN:$PATH" \
    bash "$SPECR_BIN" "$@"
  ) 2>&1 || true
}

# ── Tests ──────────────────────────────────────────────────────────────────────
echo "=== specr smoke tests ==="
echo ""

# ─── 1. Default routing ───────────────────────────────────────────────────────
echo "--- 1. Default routing (codex=major, claude=minor) ---"

# sync → minor → claude
clear_logs
run_specr sync
assert "sync default: claude invoked"    "$(was_invoked claude)" "yes"
assert "sync default: codex not invoked" "$(was_invoked codex)"  "no"

# preflight (no spec in ready/) → minor → claude
clear_logs
run_specr preflight
assert "preflight default: claude invoked"    "$(was_invoked claude)" "yes"
assert "preflight default: codex not invoked" "$(was_invoked codex)"  "no"

# ralph → minor → claude (ralph + ralph_cleanup both use minor)
clear_logs
place_spec
run_specr ralph
assert "ralph default: claude invoked"    "$(was_invoked claude)" "yes"
assert "ralph default: codex not invoked" "$(was_invoked codex)"  "no"

# specr "idea" (interactive create) → major → codex (via exec)
clear_logs
run_specr "test idea"
assert "create default: codex invoked"     "$(was_invoked codex)"  "yes"
assert "create default: claude not invoked" "$(was_invoked claude)" "no"

# auto -n 2: speccer → major (codex), reviewer → minor (claude)
clear_logs
run_specr auto -n 2 "test idea"
assert "auto default: codex invoked for speccer (major)" "$(was_invoked codex)"  "yes"
assert "auto default: claude invoked for reviewer (minor)" "$(was_invoked claude)" "yes"

echo ""

# ─── 2. Cursor routing ────────────────────────────────────────────────────────
echo "--- 2. Cursor routing (minor=cursor → agent, major=cursor → agent) ---"

# sync with minor=cursor → agent
clear_logs
(export SPECR_MINOR_PROVIDER=cursor SPECR_MINOR_MODEL=claude-sonnet-4-6; run_specr sync)
assert "sync cursor: agent invoked"      "$(was_invoked agent)"  "yes"
assert "sync cursor: claude not invoked" "$(was_invoked claude)" "no"

# preflight with minor=cursor → agent
clear_logs
(export SPECR_MINOR_PROVIDER=cursor SPECR_MINOR_MODEL=claude-sonnet-4-6; run_specr preflight)
assert "preflight cursor: agent invoked"      "$(was_invoked agent)"  "yes"
assert "preflight cursor: claude not invoked" "$(was_invoked claude)" "no"

# ralph with minor=cursor → agent
clear_logs
place_spec
(export SPECR_MINOR_PROVIDER=cursor SPECR_MINOR_MODEL=claude-sonnet-4-6; run_specr ralph)
assert "ralph cursor: agent invoked"      "$(was_invoked agent)"  "yes"
assert "ralph cursor: claude not invoked" "$(was_invoked claude)" "no"

# create with major=cursor → agent (interactive, via exec)
clear_logs
(export SPECR_MAJOR_PROVIDER=cursor SPECR_MAJOR_MODEL=claude-sonnet-4-6; run_specr "test idea")
assert "create cursor: agent invoked"     "$(was_invoked agent)"  "yes"
assert "create cursor: codex not invoked" "$(was_invoked codex)"  "no"

echo ""

# ─── 3. --claude compatibility override ──────────────────────────────────────
echo "--- 3. --claude compatibility override ---"

clear_logs
run_specr --claude "test idea"
assert "--claude create: claude invoked"    "$(was_invoked claude)" "yes"
assert "--claude create: codex not invoked" "$(was_invoked codex)"  "no"

echo ""

# ─── 4. Config file precedence ────────────────────────────────────────────────
echo "--- 4. Config precedence ---"

# Environment variable beats project config
clear_logs
clean_project_cfg
clean_user_cfg
mkdir -p "$REPO/.specr"
printf 'minor.provider=cursor\nminor.model=claude-sonnet-4-6\n' > "$REPO/.specr/config"
(export SPECR_MINOR_PROVIDER=claude; run_specr sync)
assert "env var beats project config: claude invoked" "$(was_invoked claude)" "yes"
assert "env var beats project config: agent not used" "$(was_invoked agent)"  "no"
clean_project_cfg

# Project config beats user config
clear_logs
printf 'minor.provider=cursor\nminor.model=claude-sonnet-4-6\n' > "$USER_CFG/specr/config"
mkdir -p "$REPO/.specr"
printf 'minor.provider=claude\nminor.model=claude-sonnet-4-6\n' > "$REPO/.specr/config"
run_specr sync
assert "project config beats user config: claude invoked" "$(was_invoked claude)" "yes"
assert "project config beats user config: agent not used" "$(was_invoked agent)"  "no"
clean_project_cfg
clean_user_cfg

echo ""

# ─── 5. Docs reflect implementation ──────────────────────────────────────────
echo "--- 5. Docs and help reflect the config model ---"

SPECR_DIR="$(cd "$(dirname "$0")/.." && pwd)"
assert_file_contains "README: mentions major tier"       "$SPECR_DIR/README.md"   "major"
assert_file_contains "README: mentions Cursor provider"  "$SPECR_DIR/README.md"   "cursor"
assert_file_contains "README: config file documented"    "$SPECR_DIR/README.md"   ".specr/config"
assert_file_contains "install.sh: checks codex"          "$SPECR_DIR/install.sh"  "codex"
assert_file_contains "install.sh: checks claude"         "$SPECR_DIR/install.sh"  "claude"
assert_file_contains "bin/specr --help: major/minor"     "$SPECR_DIR/bin/specr"   "major"
assert_file_contains "bin/specr --help: cursor listed"   "$SPECR_DIR/bin/specr"   "cursor"
assert_file_contains "bin/specr --help: env vars shown"  "$SPECR_DIR/bin/specr"   "SPECR_MAJOR_PROVIDER"

echo ""
echo "──────────────────────────────────────────────────"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo ""
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "All smoke tests passed."
