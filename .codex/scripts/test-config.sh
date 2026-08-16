#!/bin/bash
# Regression checks for repository Codex hooks and generated skills.

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
POST_EDIT_HOOK="$REPO_ROOT/.codex/hooks/post-edit-dart.sh"
BUILD_HOOK="$REPO_ROOT/.codex/hooks/pre-commit-build-runner.sh"
CODEX_GIT_HOOK="$REPO_ROOT/.codex/hooks/check-git-hooks.sh"
CLAUDE_GIT_HOOK="$REPO_ROOT/.claude/hooks/check-git-hooks.sh"
WORKTREE_GUARD_HOOK="$REPO_ROOT/.claude/hooks/session-start-worktree-guard.sh"

"$REPO_ROOT/.codex/scripts/sync-agent-skills.sh" --check

# shellcheck disable=SC2016
grep -Fq 'Read and apply ALL rules from `AGENTS.md`' \
  "$REPO_ROOT/.agents/skills/review-before-commit/SKILL.md"
if grep -Fq '/review-before-commit' \
  "$REPO_ROOT/.agents/skills/review-before-commit/SKILL.md"; then
  echo "Generated review skill still uses the Claude slash invocation." >&2
  exit 1
fi
if grep -Fq '.claude/AGENTS.md' \
  "$REPO_ROOT/.agents/skills/review-before-commit/SKILL.md"; then
  echo "Generated review skill points to a nonexistent .claude/AGENTS.md." >&2
  exit 1
fi
grep -Fq '**Published**: May 2023<br>' \
  "$REPO_ROOT/.agents/skills/claudeception/resources/research-references.md"
# shellcheck disable=SC2088
grep -Fq '~/.agents/skills/art-direct/styles/' \
  "$REPO_ROOT/.agents/skills/art-direct/docs/2026-01-28-art-direct-design.md"

SCRATCH_DIR=$(mktemp -d "${TMPDIR:-/tmp}/divine-codex-hooks.XXXXXX")
trap 'rm -rf "$SCRATCH_DIR"' EXIT
TEST_REPO="$SCRATCH_DIR/repo"
BIN_DIR="$SCRATCH_DIR/bin"
CALL_LOG="$SCRATCH_DIR/dart-calls.log"
mkdir -p "$TEST_REPO/mobile/lib" "$BIN_DIR"

git -C "$TEST_REPO" init -q

touch "$TEST_REPO/mobile/mise.toml"
cat > "$TEST_REPO/mobile/pubspec.yaml" <<'EOF'
name: codex_hook_test
environment:
  sdk: ^3.0.0
EOF
cat > "$TEST_REPO/mobile/lib/warning file.dart" <<'EOF'
// ANALYZER_WARNING
void main() {}
EOF
cat > "$TEST_REPO/mobile/lib/clean.dart" <<'EOF'
void main() {}
EOF
cat > "$TEST_REPO/mobile/lib/info only.dart" <<'EOF'
// ANALYZER_INFO
void main() {}
EOF
cat > "$TEST_REPO/mobile/lib/with space.dart" <<'EOF'
@freezed
class GeneratedInput {}
EOF

cat > "$BIN_DIR/mise" <<'EOF'
#!/bin/bash
if [ "$1" != "exec" ] || [ "$2" != "--" ] || [ "$3" != "dart" ]; then
  exit 99
fi
shift 3
exec "$TEST_DART" "$@"
EOF
cat > "$BIN_DIR/test-dart" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$DART_CALL_LOG"
case "$1" in
  --version)
    exit 0
    ;;
  format)
    exit 0
    ;;
  analyze)
    if grep -q 'ANALYZER_WARNING' "$2"; then
      # Mirror real `dart analyze`: a header and footer around the diagnostic,
      # severity right-padded to 7 characters so `warning` sits at column 1.
      echo "Analyzing $2..."
      echo
      echo "warning - $2:1:1 - Test warning. - test_warning"
      echo
      echo "1 issue found."
      exit 2
    fi
    # Info-level diagnostics are reported with exit 0, so the severity match is
    # the only thing that can surface them.
    if grep -q 'ANALYZER_INFO' "$2"; then
      echo "Analyzing $2..."
      echo
      echo "   info - $2:1:1 - Test info. - test_info"
      echo
      echo "1 issue found."
      exit 0
    fi
    echo "No issues found!"
    exit 0
    ;;
  run)
    if [ "${BUILD_FAIL:-0}" = "1" ]; then
      echo "BUILD FAILED: simulated builder error"
      exit 1
    fi
    exit 0
    ;;
  *)
    exit 98
    ;;
esac
EOF
chmod +x "$BIN_DIR/mise" "$BIN_DIR/test-dart"

POST_PAYLOAD=$(jq -n --arg command $'*** Begin Patch\n*** Update File: mobile/lib/warning file.dart\n*** End Patch' \
  '{tool_input: {command: $command}}')
POST_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    "$POST_EDIT_HOOK" <<< "$POST_PAYLOAD")

if ! printf '%s\n' "$POST_OUTPUT" | jq -e \
  '.decision == "block"
   and (.reason | startswith("Analyzer diagnostics in"))
   and (.reason | contains("Test warning"))' >/dev/null; then
  echo "Post-edit hook did not surface a column-1 warning via the severity match." >&2
  echo "It fell back to the analyzer exit code, whose message also contains the" >&2
  echo "diagnostic text, so this assertion pins the severity-match path." >&2
  echo "Reason was: $(printf '%s' "$POST_OUTPUT" | jq -r '.reason // "<none>"')" >&2
  exit 1
fi
FORMAT_LINE=$(grep -n '^format ' "$CALL_LOG" | cut -d: -f1)
ANALYZE_LINE=$(grep -n '^analyze ' "$CALL_LOG" | cut -d: -f1)
if [ -z "$FORMAT_LINE" ] || [ -z "$ANALYZE_LINE" ] || [ "$FORMAT_LINE" -ge "$ANALYZE_LINE" ]; then
  echo "Post-edit hook did not format before analyzing." >&2
  exit 1
fi

INFO_PAYLOAD=$(jq -n --arg command $'*** Begin Patch\n*** Update File: mobile/lib/info only.dart\n*** End Patch' \
  '{tool_input: {command: $command}}')
INFO_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    "$POST_EDIT_HOOK" <<< "$INFO_PAYLOAD")

if ! printf '%s\n' "$INFO_OUTPUT" | jq -e \
  '.decision == "block" and (.reason | contains("info -"))' >/dev/null; then
  echo "Post-edit hook did not block info-level diagnostics reported with exit 0." >&2
  exit 1
fi

# A file with no diagnostics must not block, or every edit stalls.
CLEAN_PAYLOAD=$(jq -n --arg command $'*** Begin Patch\n*** Update File: mobile/lib/clean.dart\n*** End Patch' \
  '{tool_input: {command: $command}}')
CLEAN_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    "$POST_EDIT_HOOK" <<< "$CLEAN_PAYLOAD")

if [ -n "$CLEAN_OUTPUT" ]; then
  echo "Post-edit hook blocked a file with no diagnostics: $CLEAN_OUTPUT" >&2
  exit 1
fi

NON_DART_PAYLOAD=$(jq -n --arg command $'*** Begin Patch\n*** Update File: README.md\n*** End Patch' \
  '{tool_input: {command: $command}}')
NON_DART_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="/usr/bin:/bin" "$POST_EDIT_HOOK" <<< "$NON_DART_PAYLOAD")
if [ -n "$NON_DART_OUTPUT" ]; then
  echo "Non-Dart edit unexpectedly required a Dart toolchain." >&2
  exit 1
fi

MISSING_DART_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="/usr/bin:/bin" "$POST_EDIT_HOOK" <<< "$POST_PAYLOAD")
printf '%s\n' "$MISSING_DART_OUTPUT" | jq -e \
  '.decision == "block" and (.reason | contains("Unable to run the repository Dart SDK"))' >/dev/null

CHAINED_COMMIT_PAYLOAD=$(jq -n --arg command '   git commit -m test && echo done' \
  '{tool_input: {command: $command}}')
CODEX_GIT_OUTPUT=$(cd "$TEST_REPO" && \
  "$CODEX_GIT_HOOK" <<< "$CHAINED_COMMIT_PAYLOAD")
CLAUDE_GIT_OUTPUT=$(cd "$TEST_REPO" && \
  env CLAUDE_PROJECT_DIR="$TEST_REPO" \
    "$CLAUDE_GIT_HOOK" <<< "$CHAINED_COMMIT_PAYLOAD")
printf '%s\n' "$CODEX_GIT_OUTPUT" | jq -e \
  '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null
printf '%s\n' "$CLAUDE_GIT_OUTPUT" | jq -e \
  '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null

git -C "$TEST_REPO" add "mobile/lib/with space.dart" mobile/pubspec.yaml
COMMIT_PAYLOAD=$(jq -n --arg command 'git commit -m test' \
  '{tool_input: {command: $command}}')
BUILD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    BUILD_FAIL=1 \
    "$BUILD_HOOK" <<< "$COMMIT_PAYLOAD" 2>"$SCRATCH_DIR/build-failure.stderr")

printf '%s\n' "$BUILD_OUTPUT" | jq -e '
  .hookSpecificOutput.hookEventName == "PreToolUse" and
  .hookSpecificOutput.permissionDecision == "deny" and
  (.hookSpecificOutput.permissionDecisionReason | contains("simulated builder error"))
' >/dev/null

cat > "$TEST_REPO/mobile/lib/with space.g.dart" <<'EOF'
// generated
EOF
SUCCESS_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    BUILD_FAIL=0 \
    "$BUILD_HOOK" <<< "$COMMIT_PAYLOAD" 2>"$SCRATCH_DIR/build-success.stderr")
if [ -n "$SUCCESS_OUTPUT" ]; then
  echo "Successful build hook wrote unexpected stdout: $SUCCESS_OUTPUT" >&2
  exit 1
fi
if ! git -C "$TEST_REPO" diff --cached --name-only \
  | grep -Fxq 'mobile/lib/with space.g.dart'; then
  echo "Generated file with a spaced path was not staged." >&2
  exit 1
fi

GUARD_SOCKET_DIR="$SCRATCH_DIR/cc-socks-test"
GUARD_BIN_DIR="$SCRATCH_DIR/guard-bin"
OTHER_REPO="$SCRATCH_DIR/other-repo"
mkdir -p "$GUARD_SOCKET_DIR" "$GUARD_BIN_DIR" "$OTHER_REPO"
git -C "$OTHER_REPO" init -q
python3 - "$GUARD_SOCKET_DIR" <<'PY'
import os
import socket
import sys

socket_dir = sys.argv[1]
for pid in ("111", "222", "333", "444", "777"):
    path = os.path.join(socket_dir, f"{pid}.sock")
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.bind(path)
    finally:
        sock.close()
PY

cat > "$GUARD_BIN_DIR/ps" <<'EOF'
#!/bin/bash
case "$*" in
  "-eo pid=,comm=")
    cat <<'PSOUT'
111 /opt/homebrew/bin/claude
222 sleep
333 claude
444 claude
555 claude
777 claude
PSOUT
    exit 0
    ;;
esac

if [ "$1" = "-o" ] && [ "$2" = "comm=" ] && [ "$3" = "-p" ]; then
  case "$4" in
    111) echo "/opt/homebrew/bin/claude"; exit 0 ;;
    222) echo "sleep"; exit 0 ;;
    333) echo "claude"; exit 0 ;;
    444) echo "claude"; exit 0 ;;
    555) echo "claude"; exit 0 ;;
    777) echo "claude"; exit 0 ;;
    *) echo "bash"; exit 0 ;;
  esac
fi

if [ "$1" = "-o" ] && [ "$2" = "ppid=" ] && [ "$3" = "-p" ]; then
  case "$4" in
    777) echo "1"; exit 0 ;;
    *) echo "777"; exit 0 ;;
  esac
fi

exit 1
EOF

cat > "$GUARD_BIN_DIR/lsof" <<'EOF'
#!/bin/bash
pid=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-p" ]; then
    pid="$2"
    break
  fi
  shift
done

case "$pid" in
  111) printf 'n%s\n' "$TEST_REPO" ;;
  222) printf 'n%s\n' "$TEST_REPO" ;;
  333) printf 'n%s\n' "$TEST_REPO/mobile" ;;
  444) printf 'n%s\n' "$OTHER_REPO" ;;
  555) printf 'n%s\n' "$TEST_REPO" ;;
  777) printf 'n%s\n' "$TEST_REPO" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$GUARD_BIN_DIR/ps" "$GUARD_BIN_DIR/lsof"

GUARD_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$GUARD_BIN_DIR:$PATH" \
    TEST_REPO="$TEST_REPO" \
    OTHER_REPO="$OTHER_REPO" \
    CLAUDE_PROJECT_DIR="$TEST_REPO" \
    CC_SOCK_DIR="$GUARD_SOCKET_DIR" \
    "$WORKTREE_GUARD_HOOK")

if ! printf '%s\n' "$GUARD_OUTPUT" | jq -e '
  .systemMessage
  | contains("2 other Claude sessions already have a matching launch-directory worktree")
    and contains("pid 111")
    and contains("pid 333")
    and (contains("pid 222") | not)
    and (contains("pid 444") | not)
    and (contains("pid 555") | not)
    and (contains("pid 777") | not)
' >/dev/null; then
  echo "Session worktree guard did not report only live Claude sessions in the same canonical worktree." >&2
  echo "Output was: $GUARD_OUTPUT" >&2
  exit 1
fi

echo "Codex configuration checks passed."
