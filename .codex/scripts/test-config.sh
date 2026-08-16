#!/bin/bash
# Regression checks for repository Codex hooks and generated skills.

set -e
trap 'echo "test-config.sh failed at line $LINENO: $BASH_COMMAND" >&2' ERR

REPO_ROOT=$(git rev-parse --show-toplevel)
POST_EDIT_HOOK="$REPO_ROOT/.codex/hooks/post-edit-dart.sh"
BUILD_HOOK="$REPO_ROOT/.codex/hooks/pre-commit-build-runner.sh"
CODEX_GIT_HOOK="$REPO_ROOT/.codex/hooks/check-git-hooks.sh"
CLAUDE_GIT_HOOK="$REPO_ROOT/.claude/hooks/check-git-hooks.sh"
WORKTREE_GUARD_HOOK="$REPO_ROOT/.claude/hooks/session-start-worktree-guard.sh"
CLAUDE_PURGE_HOOK="$REPO_ROOT/.claude/hooks/session-end-purge-build-artifacts.sh"
CLAUDE_ANALYZE_HOOK="$REPO_ROOT/.claude/hooks/post-edit-analyze.sh"

"$REPO_ROOT/.codex/scripts/sync-agent-skills.sh" --check

# Every registered Claude hook command must resolve to an executable file in
# this repository — a registration pointing at a missing file must fail loudly
# here, not silently at session end. Every hook timeout must be whole seconds
# (a millisecond-scale value like 5000 exceeds the 600s ceiling this suite
# pins). The SessionEnd matcher is asserted exactly because it deliberately
# excludes non-terminal reasons such as `other`.
while IFS= read -r hook_cmd; do
  case "$hook_cmd" in
    '"$CLAUDE_PROJECT_DIR"'/*)
      hook_path=${hook_cmd#'"$CLAUDE_PROJECT_DIR"'}
      if [ ! -x "$REPO_ROOT$hook_path" ]; then
        echo "Registered Claude hook is missing or not executable: $hook_cmd" >&2
        exit 1
      fi
      ;;
    *)
      echo "Unrecognized Claude hook command shape: $hook_cmd" >&2
      exit 1
      ;;
  esac
done < <(jq -r '.hooks | .[] | .[] | .hooks[].command' "$REPO_ROOT/.claude/settings.json")

missing_timeouts=$(jq -r '.hooks | .[] | .[] | .hooks[]
  | select(.timeout == null)
  | .command' "$REPO_ROOT/.claude/settings.json")
if [ -n "$missing_timeouts" ]; then
  echo "Every Claude hook must declare an explicit whole-second timeout; missing on: $missing_timeouts" >&2
  exit 1
fi

bad_timeouts=$(jq -r '.hooks | .[] | .[] | .hooks[].timeout' "$REPO_ROOT/.claude/settings.json" \
  | awk '$1 !~ /^[0-9]+$/ || $1 > 600 { print }')
if [ -n "$bad_timeouts" ]; then
  echo "Claude hook timeouts must be whole seconds and at most 600: got $bad_timeouts" >&2
  exit 1
fi

jq -e '.hooks.SessionEnd[]
  | select(.matcher == "logout|prompt_input_exit|bypass_permissions_disabled")
  | .hooks[]
  | select(.command | endswith("session-end-purge-build-artifacts.sh"))' \
  "$REPO_ROOT/.claude/settings.json" >/dev/null || {
  echo "SessionEnd purge hook registration is missing or its matcher changed." >&2
  exit 1
}

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
mkdir -p "$TEST_REPO/mobile/.dart_tool"
touch "$TEST_REPO/mobile/.dart_tool/package_config.json"
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
ln -sf "$BIN_DIR/test-dart" "$BIN_DIR/dart"

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

# The no-toolchain path must be exercised with mise and dart both hidden:
# dev machines commonly install mise system-wide (e.g. /usr/bin/mise), and
# then it resolves a real dart, analyzes the fixture, and emits no block —
# failing this test before the purge-hook tests below ever run. Pin the PATH
# to a scratch bin holding only the tools the hook needs when no SDK resolves.
NO_TOOLCHAIN_BIN="$SCRATCH_DIR/no-toolchain-bin"
mkdir -p "$NO_TOOLCHAIN_BIN"
for tool in jq git sed grep cat dirname basename; do
  ln -s "$(command -v "$tool")" "$NO_TOOLCHAIN_BIN/$tool"
done
MISSING_DART_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$NO_TOOLCHAIN_BIN" "$POST_EDIT_HOOK" <<< "$POST_PAYLOAD")
printf '%s\n' "$MISSING_DART_OUTPUT" | jq -e \
  '.decision == "block" and (.reason | contains("Unable to run the repository Dart SDK"))' >/dev/null

rm -f "$TEST_REPO/mobile/.dart_tool/package_config.json"
: > "$CALL_LOG"
CODEX_PURGED_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    TEST_DART="$BIN_DIR/test-dart" \
    DART_CALL_LOG="$CALL_LOG" \
    "$POST_EDIT_HOOK" <<< "$POST_PAYLOAD")
if ! printf '%s\n' "$CODEX_PURGED_OUTPUT" | jq -e \
  '.systemMessage
   | contains("Skipped Dart format/analyze")
     and contains("flutter pub get")' >/dev/null; then
  echo "Codex post-edit hook did not explain the missing package_config.json skip." >&2
  echo "Output was: $CODEX_PURGED_OUTPUT" >&2
  exit 1
fi
if grep -q '^format \|^analyze ' "$CALL_LOG"; then
  echo "Codex post-edit hook invoked dart without package_config.json." >&2
  exit 1
fi
touch "$TEST_REPO/mobile/.dart_tool/package_config.json"

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

CLAUDE_ANALYZE_PAYLOAD=$(jq -n --arg path "$TEST_REPO/mobile/lib/clean.dart" \
  '{tool_input: {file_path: $path}}')
: > "$CALL_LOG"
rm -f "$TEST_REPO/mobile/.dart_tool/package_config.json"
CLAUDE_ANALYZE_OUTPUT=$(cd "$TEST_REPO" && \
  env PATH="$BIN_DIR:/usr/bin:/bin" \
    DART_CALL_LOG="$CALL_LOG" \
    "$CLAUDE_ANALYZE_HOOK" <<< "$CLAUDE_ANALYZE_PAYLOAD")
if ! printf '%s\n' "$CLAUDE_ANALYZE_OUTPUT" | jq -e \
  '.systemMessage
   | contains("Skipped Dart analysis")
     and contains("flutter pub get")' >/dev/null; then
  echo "Claude post-edit analyze hook did not explain the missing package_config.json skip." >&2
  echo "Output was: $CLAUDE_ANALYZE_OUTPUT" >&2
  exit 1
fi
if grep -q '^analyze ' "$CALL_LOG"; then
  echo "Claude post-edit analyze hook invoked dart without package_config.json." >&2
  exit 1
fi

NON_DIVINE_MAIN="$SCRATCH_DIR/non-divine-main"
NON_DIVINE_LINK="$SCRATCH_DIR/non-divine-linked"
mkdir -p "$NON_DIVINE_MAIN/mobile/build"
git -C "$NON_DIVINE_MAIN" init -q
touch "$NON_DIVINE_MAIN/mobile/build/output.o"
git -C "$NON_DIVINE_MAIN" add mobile/build/output.o
git -C "$NON_DIVINE_MAIN" \
  -c user.email=test@example.com \
  -c user.name=Test \
  commit -q -m init
git -C "$NON_DIVINE_MAIN" worktree add -q "$NON_DIVINE_LINK"
NON_DIVINE_OUTPUT=$(cd "$NON_DIVINE_LINK" && \
  env CLAUDE_PROJECT_DIR="$NON_DIVINE_LINK" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
if [ -n "$NON_DIVINE_OUTPUT" ] || [ ! -d "$NON_DIVINE_LINK/mobile/build" ]; then
  echo "Purge hook ran outside a divine-mobile checkout." >&2
  exit 1
fi

MAIN_PURGE_REPO="$SCRATCH_DIR/main-purge"
mkdir -p "$MAIN_PURGE_REPO/mobile/build" "$MAIN_PURGE_REPO/mobile/.dart_tool"
git -C "$MAIN_PURGE_REPO" init -q
cat > "$MAIN_PURGE_REPO/mobile/pubspec.yaml" <<'EOF'
name: main_purge_test
EOF
touch "$MAIN_PURGE_REPO/mobile/build/output.o"
MAIN_PURGE_OUTPUT=$(cd "$MAIN_PURGE_REPO" && \
  env CLAUDE_PROJECT_DIR="$MAIN_PURGE_REPO" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
if [ -n "$MAIN_PURGE_OUTPUT" ] || [ ! -d "$MAIN_PURGE_REPO/mobile/build" ]; then
  echo "Purge hook did not skip the main checkout." >&2
  exit 1
fi

WT_MAIN="$SCRATCH_DIR/purge-main"
WT_LINK="$SCRATCH_DIR/purge-linked"
mkdir -p "$WT_MAIN/mobile/packages/bar"
git -C "$WT_MAIN" init -q
cat > "$WT_MAIN/mobile/pubspec.yaml" <<'EOF'
name: linked_purge_test
EOF
touch "$WT_MAIN/mobile/packages/bar/.keep"
git -C "$WT_MAIN" add mobile/pubspec.yaml mobile/packages/bar/.keep
git -C "$WT_MAIN" \
  -c user.email=test@example.com \
  -c user.name=Test \
  commit -q -m init
git -C "$WT_MAIN" worktree add -q "$WT_LINK"

mkdir -p "$WT_LINK/mobile/build" \
  "$WT_LINK/mobile/.dart_tool" \
  "$WT_LINK/mobile/packages/bar/build"
touch "$WT_LINK/mobile/build/output.o" \
  "$WT_LINK/mobile/.dart_tool/package_config.json" \
  "$WT_LINK/mobile/packages/bar/build/output.o"

CLEAR_OUTPUT=$(cd "$WT_LINK" && \
  env CLAUDE_PROJECT_DIR="$WT_LINK" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"clear"}')
RESUME_OUTPUT=$(cd "$WT_LINK" && \
  env CLAUDE_PROJECT_DIR="$WT_LINK" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"resume"}')
if [ -n "$CLEAR_OUTPUT$RESUME_OUTPUT" ] || [ ! -d "$WT_LINK/mobile/build" ] || [ ! -d "$WT_LINK/mobile/.dart_tool" ]; then
  echo "Purge hook did not skip clear/resume SessionEnd reasons." >&2
  exit 1
fi

PURGE_PEER_BIN="$SCRATCH_DIR/purge-peer-bin"
mkdir -p "$PURGE_PEER_BIN"
for tool in bash cat jq git find stat mv rm mkdir rmdir basename nohup sed head tr; do
  ln -s "$(command -v "$tool")" "$PURGE_PEER_BIN/$tool"
done
cat > "$PURGE_PEER_BIN/ps" <<'EOF'
#!/bin/bash
if [ "$1" = "-eo" ] && [ "$2" = "pid=,comm=" ]; then
  echo "4242 zsh"
  exit 0
fi
if [ "$1" = "-o" ] && [ "$2" = "ppid=" ] && [ "$3" = "-p" ]; then
  exit 0
fi
exit 1
EOF
cat > "$PURGE_PEER_BIN/lsof" <<'EOF'
#!/bin/bash
pid=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-p" ]; then
    pid="$2"
    break
  fi
  shift
done
[ "$pid" = "4242" ] || exit 1
printf 'n%s\n' "$PURGE_PEER_CWD"
EOF
chmod +x "$PURGE_PEER_BIN/ps" "$PURGE_PEER_BIN/lsof"
PEER_OUTPUT=$(cd "$WT_LINK" && \
  env PATH="$PURGE_PEER_BIN" \
    CLAUDE_PROJECT_DIR="$WT_LINK" \
    PURGE_PEER_CWD="$WT_LINK/mobile" \
    "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
if ! printf '%s\n' "$PEER_OUTPUT" | jq -e \
  '.systemMessage
   | contains("Skipped build-artifact purge")
     and contains("pid 4242")
     and contains("other live process")' >/dev/null; then
  echo "Purge hook did not explain the shared-worktree skip." >&2
  echo "Output was: $PEER_OUTPUT" >&2
  exit 1
fi
if [ ! -d "$WT_LINK/mobile/build" ] || [ ! -d "$WT_LINK/mobile/.dart_tool" ]; then
  echo "Purge hook deleted artifacts while another process was active in the worktree." >&2
  exit 1
fi

PURGE_OUTPUT=$(cd "$WT_LINK" && \
  env CLAUDE_PROJECT_DIR="$WT_LINK" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
printf '%s\n' "$PURGE_OUTPUT" | jq -e \
  '.systemMessage == "Purged 3 build/.dart_tool dirs from purge-linked"' >/dev/null
if [ -d "$WT_LINK/mobile/build" ] || [ -d "$WT_LINK/mobile/.dart_tool" ] || [ -d "$WT_LINK/mobile/packages/bar/build" ]; then
  echo "Purge hook did not remove linked worktree build artifacts." >&2
  exit 1
fi
if [ -n "$(git -C "$WT_LINK" status --short)" ]; then
  echo "Purge hook left the linked worktree dirty." >&2
  exit 1
fi

gitdir=$(git -C "$WT_LINK" rev-parse --absolute-git-dir)

# Staging is only the visible half: the background rm must actually reclaim
# the staged artifacts, or every session-end just moves the disk bill around.
for _ in $(seq 1 100); do
  [ ! -e "$gitdir/claude-purge" ] && break
  sleep 0.1
done
if [ -e "$gitdir/claude-purge" ]; then
  echo "Purge hook staged artifacts but never deleted them." >&2
  exit 1
fi

mkdir -p "$gitdir/claude-purge/old"
touch "$gitdir/claude-purge/old/artifact"
NOOP_OUTPUT=$(cd "$WT_LINK" && \
  env CLAUDE_PROJECT_DIR="$WT_LINK" "$CLAUDE_PURGE_HOOK" \
    <<< '{"reason":"prompt_input_exit"}')
if [ -n "$NOOP_OUTPUT" ] || [ -d "$gitdir/claude-purge" ]; then
  echo "Purge hook did not clean leftover staging on a no-op run." >&2
  exit 1
fi

# A linked worktree on a different filesystem from the main checkout must
# still purge: the hook detects the cross-device gitdir and deletes in place
# instead of staging (mv would degrade to a synchronous copy that can blow
# the hook timeout). /dev/shm supplies a second filesystem where one exists;
# the probe guards the fixture itself, since `git worktree add` into a missing
# or read-only /dev/shm (macOS, hardened containers) would abort the suite
# before any skip logic could run.
if [ -d /dev/shm ] && [ -w /dev/shm ]; then
  XDEV_MAIN="$SCRATCH_DIR/xdev-main"
  XDEV_LINK="/dev/shm/divine-purge-xdev-$$"
  # Failing runs re-run the most; clean the tmpfs worktree from the EXIT trap
  # so a red assertion does not leak it into RAM.
  trap 'rm -rf "$SCRATCH_DIR" "$XDEV_LINK"' EXIT
  mkdir -p "$XDEV_MAIN/mobile/packages/bar"
  git -C "$XDEV_MAIN" init -q
  cat > "$XDEV_MAIN/mobile/pubspec.yaml" <<'EOF'
name: xdev_purge_test
EOF
  touch "$XDEV_MAIN/mobile/packages/bar/.keep"
  git -C "$XDEV_MAIN" add mobile/pubspec.yaml mobile/packages/bar/.keep
  git -C "$XDEV_MAIN" \
    -c user.email=test@example.com \
    -c user.name=Test \
    commit -q -m init
  git -C "$XDEV_MAIN" worktree add -q "$XDEV_LINK"
  mkdir -p "$XDEV_LINK/mobile/build" "$XDEV_LINK/mobile/.dart_tool"
  touch "$XDEV_LINK/mobile/build/output.o" \
    "$XDEV_LINK/mobile/.dart_tool/package_config.json"
  XDEV_WORKTREE_DEV=$(stat -c %d "$XDEV_LINK/mobile" 2>/dev/null || echo no-dev-1)
  XDEV_GITDIR=$(git -C "$XDEV_LINK" rev-parse --absolute-git-dir)
  XDEV_GITDIR_DEV=$(stat -c %d "$XDEV_GITDIR" 2>/dev/null || echo no-dev-2)
  if [ "$XDEV_WORKTREE_DEV" != "$XDEV_GITDIR_DEV" ]; then
    # A regular file at the staging path makes any staging attempt fail loudly
    # (mkdir -p cannot succeed), so this test discriminates the in-place path
    # from a cross-device mv even though both eventually delete the artifacts.
    touch "$XDEV_GITDIR/claude-purge"
    XDEV_NAME=$(basename "$XDEV_LINK")
    XDEV_OUTPUT=$(cd "$XDEV_LINK" && \
      env CLAUDE_PROJECT_DIR="$XDEV_LINK" "$CLAUDE_PURGE_HOOK" \
        <<< '{"reason":"prompt_input_exit"}' || true)
    printf '%s\n' "$XDEV_OUTPUT" | jq -e --arg name "$XDEV_NAME" \
      '.systemMessage == ("Purged 2 build/.dart_tool dirs from " + $name)' >/dev/null || {
      echo "Cross-device purge did not report removing both artifact dirs." >&2
      exit 1
    }
    if [ ! -f "$XDEV_GITDIR/claude-purge" ]; then
      echo "Cross-device purge touched the gitdir staging path instead of deleting in place." >&2
      exit 1
    fi
    for _ in $(seq 1 100); do
      [ ! -d "$XDEV_LINK/mobile/build" ] && [ ! -d "$XDEV_LINK/mobile/.dart_tool" ] && break
      sleep 0.1
    done
    if [ -d "$XDEV_LINK/mobile/build" ] || [ -d "$XDEV_LINK/mobile/.dart_tool" ]; then
      echo "Cross-device purge did not delete the artifact dirs." >&2
      exit 1
    fi
  else
    echo "skip: /dev/shm shares a filesystem with the scratch dir; cross-device purge path not exercised."
  fi
else
  echo "skip: no writable /dev/shm; cross-device purge path not exercised."
fi

echo "Codex configuration checks passed."
