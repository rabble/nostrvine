#!/bin/bash
# Install git hooks for divine-mobile development
# Run this once after cloning the repo

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
if [[ "$GIT_COMMON_DIR" != /* ]]; then
  GIT_COMMON_DIR="$REPO_ROOT/$GIT_COMMON_DIR"
fi
HOOKS_DIR="$GIT_COMMON_DIR/hooks"
DART_BIN="$(command -v dart)"
FLUTTER_BIN="$(command -v flutter)"

if [ -z "$DART_BIN" ] || [ -z "$FLUTTER_BIN" ]; then
  echo "❌ Could not find both 'dart' and 'flutter' on PATH."
  echo "Open a shell with the project toolchain loaded, then rerun scripts/install-hooks.sh."
  exit 1
fi

echo "Installing git hooks..."

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook for divine-mobile
# Runs format check, analyze, and codegen verification to catch CI failures early

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
DART_BIN="__DART_BIN__"
FLUTTER_BIN="__FLUTTER_BIN__"
cd "$REPO_ROOT/mobile"

list_codegen_inputs() {
    while IFS= read -r file; do
        [ -z "$file" ] && continue

        local abs_path="$REPO_ROOT/$file"
        [ -f "$abs_path" ] || continue

        local base_path="${abs_path%.dart}"
        if grep -Eq '@Riverpod|@riverpod|@freezed|@Freezed|@JsonSerializable|@GenerateMocks|@DriftDatabase|@UseRowClass|@DataClassName|@UseMoor|@HiveType' "$abs_path" \
            || grep -Eq "part '.*\\.(g|freezed)\\.dart';" "$abs_path" \
            || [ -f "${base_path}.g.dart" ] \
            || [ -f "${base_path}.freezed.dart" ] \
            || [ -f "${base_path}.mocks.dart" ]; then
            echo "$file"
        fi
    done
}

capture_generated_status() {
    git status --porcelain -- mobile \
        | awk '{print $2}' \
        | grep -E '^mobile/.*(\.g\.dart|\.freezed\.dart|\.mocks\.dart|\.types\.temp\.dart)$' \
        | sort -u || true
}

echo "🔍 Running pre-commit checks..."

# Check if any Dart files are staged
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACM \
    | grep '^mobile/.*\.dart$' \
    | grep -v '\.g\.dart$' \
    | grep -v '\.freezed\.dart$' || true)

if [ -z "$STAGED_DART_FILES" ]; then
    echo "✅ No Dart files staged, skipping checks"
    exit 0
fi

# Run dart format check (fast)
echo "📝 Checking format..."
if ! "$DART_BIN" format --output=none --set-exit-if-changed lib test 2>/dev/null; then
    echo ""
    echo "❌ Format check failed!"
    echo "Run: cd mobile && dart format lib test"
    exit 1
fi
echo "✅ Format OK"

# Run flutter analyze (medium speed)
echo "🔬 Running analyzer..."
if ! "$FLUTTER_BIN" analyze --no-fatal-infos 2>/dev/null; then
    echo ""
    echo "❌ Analysis failed!"
    echo "Fix the issues above before committing"
    exit 1
fi
echo "✅ Analysis OK"

# Verify generated files when codegen inputs changed
CODEGEN_INPUTS=$(printf '%s\n' "$STAGED_DART_FILES" | list_codegen_inputs)
if [ -n "$CODEGEN_INPUTS" ]; then
    BEFORE_STATUS_FILE=$(mktemp)
    AFTER_STATUS_FILE=$(mktemp)
    trap 'rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"' EXIT

    capture_generated_status > "$BEFORE_STATUS_FILE"

    echo "🧬 Verifying generated files..."
    "$DART_BIN" run build_runner build --delete-conflicting-outputs >/dev/null

    capture_generated_status > "$AFTER_STATUS_FILE"
    NEW_GENERATED_CHANGES=$(comm -13 "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE" || true)

    rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"
    trap - EXIT

    if [ -n "$NEW_GENERATED_CHANGES" ]; then
        echo ""
        echo "❌ Generated files changed during verification:"
        echo "$NEW_GENERATED_CHANGES"
        echo ""
        echo "Run: cd mobile && dart run build_runner build --delete-conflicting-outputs"
        echo "Then stage the generated files and commit again."
        exit 1
    fi

    echo ""
    echo "✅ Generated files OK"
fi

echo ""
echo "✅ All pre-commit checks passed!"
EOF

sed -i.bak \
  -e "s|__DART_BIN__|$DART_BIN|g" \
  -e "s|__FLUTTER_BIN__|$FLUTTER_BIN|g" \
  "$HOOKS_DIR/pre-commit"
rm -f "$HOOKS_DIR/pre-commit.bak"
chmod +x "$HOOKS_DIR/pre-commit"

# Create pre-push hook
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Pre-push hook for divine-mobile
# Verifies generated files and runs tests related to changed files before pushing

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
DART_BIN="__DART_BIN__"
FLUTTER_BIN="__FLUTTER_BIN__"
cd "$REPO_ROOT/mobile"

list_codegen_inputs() {
    while IFS= read -r file; do
        [ -z "$file" ] && continue

        local abs_path="$REPO_ROOT/$file"
        [ -f "$abs_path" ] || continue

        local base_path="${abs_path%.dart}"
        if grep -Eq '@Riverpod|@riverpod|@freezed|@Freezed|@JsonSerializable|@GenerateMocks|@DriftDatabase|@UseRowClass|@DataClassName|@UseMoor|@HiveType' "$abs_path" \
            || grep -Eq "part '.*\\.(g|freezed)\\.dart';" "$abs_path" \
            || [ -f "${base_path}.g.dart" ] \
            || [ -f "${base_path}.freezed.dart" ] \
            || [ -f "${base_path}.mocks.dart" ]; then
            echo "$file"
        fi
    done
}

run_without_git_env() {
    (
        while IFS= read -r git_var; do
            unset "$git_var"
        done < <(git rev-parse --local-env-vars)

        "$@"
    )
}

git_repo() {
    run_without_git_env git -C "$REPO_ROOT" "$@"
}

capture_generated_status() {
    git_repo status --porcelain -- mobile \
        | awk '{print $2}' \
        | grep -E '^mobile/.*(\.g\.dart|\.freezed\.dart|\.mocks\.dart|\.types\.temp\.dart)$' \
        | sort -u || true
}

echo "🚀 Running pre-push checks..."

# Get the remote and branch being pushed to
remote="$1"
url="$2"

# Always compare against origin/main to catch all changes that will affect CI
# (CI runs against main branch, so we want to test everything that differs from main)
BASE_BRANCH="origin/main"

# Fetch latest main to ensure accurate comparison
git_repo fetch origin main --quiet 2>/dev/null || true

# ── Merge-conflict check ──────────────────────────────────────────
# Trial-merge the branch into origin/main. If there are conflicts the
# PR cannot be merged cleanly, so fail early instead of wasting CI time.
CURRENT_BRANCH=$(git_repo rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "🔀 Checking for merge conflicts with main..."
    # Create a temporary merge in-memory (no worktree changes)
    if ! git_repo merge-tree --write-tree "$BASE_BRANCH" HEAD >/dev/null 2>&1; then
        echo ""
        echo "❌ Branch has merge conflicts with main!"
        echo ""
        echo "Resolve conflicts before pushing:"
        echo "  git fetch origin main"
        echo "  git merge origin/main   # or: git rebase origin/main"
        echo "  # resolve conflicts, then commit and push"
        echo ""
        # Show which files conflict
        git_repo merge-tree --write-tree --name-only "$BASE_BRANCH" HEAD 2>&1 | grep -E '^\S' | head -20 || true
        exit 1
    fi
    echo "✅ No merge conflicts with main"
    echo ""
fi

# Get list of changed Dart files (excluding generated files)
CHANGED_FILES=$(git_repo diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep '^mobile/.*\.dart$' \
    | grep -v '\.g\.dart$' \
    | grep -v '\.freezed\.dart$' || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ No Dart files changed, skipping tests"
    exit 0
fi

echo "📁 Changed files:"
echo "$CHANGED_FILES" | head -10
TOTAL_CHANGED=$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')
if [ "$TOTAL_CHANGED" -gt 10 ]; then
    echo "   ... and $((TOTAL_CHANGED - 10)) more"
fi
echo ""

# Mirror CI's generated-file check for codegen inputs
CODEGEN_INPUTS=$(printf '%s\n' "$CHANGED_FILES" | list_codegen_inputs)
if [ -n "$CODEGEN_INPUTS" ]; then
    BEFORE_STATUS_FILE=$(mktemp)
    AFTER_STATUS_FILE=$(mktemp)
    trap 'rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"' EXIT

    capture_generated_status > "$BEFORE_STATUS_FILE"

    echo "🧬 Verifying generated files..."
    run_without_git_env "$DART_BIN" run build_runner build --delete-conflicting-outputs >/dev/null

    capture_generated_status > "$AFTER_STATUS_FILE"
    NEW_GENERATED_CHANGES=$(comm -13 "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE" || true)

    rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"
    trap - EXIT

    if [ -n "$NEW_GENERATED_CHANGES" ]; then
        echo ""
        echo "❌ Generated files are out of date."
        echo "Run: cd mobile && dart run build_runner build --delete-conflicting-outputs"
        echo "Then commit the generated files before pushing."
        echo ""
        echo "$NEW_GENERATED_CHANGES"
        exit 1
    fi

    echo "✅ Generated files OK"
    echo ""
fi

# Find corresponding test files
TEST_FILES=""

for file in $CHANGED_FILES; do
    # If it's already a test file, add it directly
    if [[ "$file" == *"_test.dart" ]]; then
        if [ -f "$REPO_ROOT/$file" ]; then
            TEST_FILES="$TEST_FILES $file"
        fi
        continue
    fi

    # Skip non-lib files
    if [[ "$file" != mobile/lib/* ]]; then
        continue
    fi

    # Try standard test path: lib/foo.dart -> test/foo_test.dart
    test_file=$(echo "$file" | sed 's|mobile/lib/|mobile/test/|' | sed 's|\.dart$|_test.dart|')
    if [ -f "$REPO_ROOT/$test_file" ]; then
        TEST_FILES="$TEST_FILES $test_file"
        continue
    fi

    # Try unit test path: lib/foo.dart -> test/unit/foo_test.dart
    test_file=$(echo "$file" | sed 's|mobile/lib/|mobile/test/unit/|' | sed 's|\.dart$|_test.dart|')
    if [ -f "$REPO_ROOT/$test_file" ]; then
        TEST_FILES="$TEST_FILES $test_file"
        continue
    fi

    # Try widgets test path: lib/widgets/foo.dart -> test/widgets/foo_test.dart
    test_file=$(echo "$file" | sed 's|mobile/lib/|mobile/test/|' | sed 's|\.dart$|_test.dart|')
    if [ -f "$REPO_ROOT/$test_file" ]; then
        TEST_FILES="$TEST_FILES $test_file"
    fi
done

# Remove duplicates and mobile/ prefix for flutter test
TEST_FILES=$(echo "$TEST_FILES" | tr ' ' '\n' | sort -u | sed 's|^mobile/||' | grep -v '^$' || true)

if [ -z "$TEST_FILES" ]; then
    echo "⚠️  No corresponding test files found for changed files"
    echo "   Consider adding tests for your changes!"
    echo ""
    echo "✅ Skipping tests (none found)"
    exit 0
fi

echo "🧪 Running tests for changed files:"
echo "$TEST_FILES" | head -5
TEST_COUNT=$(echo "$TEST_FILES" | wc -l | tr -d ' ')
if [ "$TEST_COUNT" -gt 5 ]; then
    echo "   ... and $((TEST_COUNT - 5)) more test files"
fi
echo ""

# Run the specific tests
echo "🏃 Executing tests..."
if run_without_git_env "$FLUTTER_BIN" test $TEST_FILES 2>&1; then
    echo ""
    echo "✅ All tests passed!"
else
    echo ""
    echo "❌ Tests failed!"
    echo "Fix the failing tests before pushing."
    echo ""
    echo "To skip this check (not recommended): git push --no-verify"
    exit 1
fi
EOF

sed -i.bak \
  -e "s|__DART_BIN__|$DART_BIN|g" \
  -e "s|__FLUTTER_BIN__|$FLUTTER_BIN|g" \
  "$HOOKS_DIR/pre-push"
rm -f "$HOOKS_DIR/pre-push.bak"
chmod +x "$HOOKS_DIR/pre-push"

echo "✅ Git hooks installed!"
echo ""
echo "Pre-commit: Runs 'dart format', 'flutter analyze', and codegen verification"
echo "Pre-push:   Verifies generated files and runs tests for changed files"
echo ""
echo "To bypass hooks (not recommended): --no-verify"
