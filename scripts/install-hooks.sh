#!/bin/bash
# Install git hooks for divine-mobile development
# Run this once after cloning the repo, or via: cd mobile && mise run setup_hooks

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
if [[ "$GIT_COMMON_DIR" != /* ]]; then
  GIT_COMMON_DIR="$REPO_ROOT/$GIT_COMMON_DIR"
fi
HOOKS_DIR="$GIT_COMMON_DIR/hooks"

if ! command -v mise >/dev/null 2>&1; then
  echo "mise is required but not found on PATH."
  echo "Install mise: https://mise.jdx.dev/getting-started.html"
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
cd "$REPO_ROOT/mobile"

# Unset git env vars that break Flutter/Dart in hooks (especially in worktrees)
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

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
    git status --porcelain -- "$REPO_ROOT/mobile" \
        | awk '{print $2}' \
        | grep -E '^mobile/.*(\.g\.dart|\.freezed\.dart|\.mocks\.dart|\.types\.temp\.dart)$' \
        | sort -u || true
}

echo "Running pre-commit checks..."

# Check if any Dart files are staged
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACM \
    | grep '^mobile/.*\.dart$' \
    | grep -v '\.g\.dart$' \
    | grep -v '\.freezed\.dart$' || true)

if [ -z "$STAGED_DART_FILES" ]; then
    echo "No Dart files staged, skipping checks"
    exit 0
fi

# Run dart format check (fast)
echo "[1/3] Checking format..."
if ! mise exec -- dart format --output=none --set-exit-if-changed lib test integration_test 2>/dev/null; then
    echo ""
    echo "Format check failed!"
    echo "Run: cd mobile && mise exec -- dart format lib test integration_test"
    exit 1
fi
echo "Format OK"

# Run flutter analyze (medium speed)
echo "[2/3] Running analyzer..."
if ! mise exec -- flutter analyze 2>/dev/null; then
    echo ""
    echo "Analysis failed!"
    echo "Fix the issues above before committing"
    exit 1
fi
echo "Analysis OK"

# Verify generated files when codegen inputs changed
CODEGEN_INPUTS=$(printf '%s\n' "$STAGED_DART_FILES" | list_codegen_inputs)
if [ -n "$CODEGEN_INPUTS" ]; then
    BEFORE_STATUS_FILE=$(mktemp)
    AFTER_STATUS_FILE=$(mktemp)
    trap 'rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"' EXIT

    capture_generated_status > "$BEFORE_STATUS_FILE"

    echo "[3/3] Verifying generated files..."
    mise exec -- dart run build_runner build --delete-conflicting-outputs >/dev/null

    capture_generated_status > "$AFTER_STATUS_FILE"
    NEW_GENERATED_CHANGES=$(comm -13 "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE" || true)

    rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"
    trap - EXIT

    if [ -n "$NEW_GENERATED_CHANGES" ]; then
        echo ""
        echo "Generated files changed during verification:"
        echo "$NEW_GENERATED_CHANGES"
        echo ""
        echo "Run: cd mobile && mise exec -- dart run build_runner build --delete-conflicting-outputs"
        echo "Then stage the generated files and commit again."
        exit 1
    fi

    echo "Generated files OK"
fi

echo ""
echo "All pre-commit checks passed!"
EOF

chmod +x "$HOOKS_DIR/pre-commit"

# Create pre-push hook
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Pre-push hook for divine-mobile
# Verifies generated files and runs tests related to changed files before pushing

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT/mobile"

# Unset git env vars that break Flutter/Dart in hooks (especially in worktrees)
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE

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
    git -C "$REPO_ROOT" status --porcelain -- mobile \
        | awk '{print $2}' \
        | grep -E '^mobile/.*(\.g\.dart|\.freezed\.dart|\.mocks\.dart|\.types\.temp\.dart)$' \
        | sort -u || true
}

echo "Running pre-push checks..."

# Get the remote and branch being pushed to
remote="$1"
url="$2"

# Always compare against origin/main to catch all changes that will affect CI
BASE_BRANCH="origin/main"

# Fetch latest main to ensure accurate comparison
git -C "$REPO_ROOT" fetch origin main --quiet 2>/dev/null || true

# Merge-conflict check
CURRENT_BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Checking for merge conflicts with main..."
    if ! git -C "$REPO_ROOT" merge-tree --write-tree "$BASE_BRANCH" HEAD >/dev/null 2>&1; then
        echo ""
        echo "Branch has merge conflicts with main!"
        echo ""
        echo "Resolve conflicts before pushing:"
        echo "  git fetch origin main"
        echo "  git merge origin/main   # or: git rebase origin/main"
        exit 1
    fi
    echo "No merge conflicts with main"
    echo ""
fi

# Get list of changed Dart files (excluding generated files)
CHANGED_FILES=$(git -C "$REPO_ROOT" diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null \
    | grep '^mobile/.*\.dart$' \
    | grep -v '\.g\.dart$' \
    | grep -v '\.freezed\.dart$' || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No Dart files changed, skipping checks"
    exit 0
fi

echo "Changed files:"
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

    echo "Verifying generated files..."
    mise exec -- dart run build_runner build --delete-conflicting-outputs >/dev/null

    capture_generated_status > "$AFTER_STATUS_FILE"
    NEW_GENERATED_CHANGES=$(comm -13 "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE" || true)

    rm -f "$BEFORE_STATUS_FILE" "$AFTER_STATUS_FILE"
    trap - EXIT

    if [ -n "$NEW_GENERATED_CHANGES" ]; then
        echo ""
        echo "Generated files are out of date."
        echo "Run: cd mobile && mise exec -- dart run build_runner build --delete-conflicting-outputs"
        echo "Then commit the generated files before pushing."
        echo ""
        echo "$NEW_GENERATED_CHANGES"
        exit 1
    fi

    echo "Generated files OK"
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
done

# Remove duplicates and mobile/ prefix for flutter test
TEST_FILES=$(echo "$TEST_FILES" | tr ' ' '\n' | sort -u | sed 's|^mobile/||' | grep -v '^$' || true)

if [ -z "$TEST_FILES" ]; then
    echo "No corresponding test files found for changed files"
    echo "Consider adding tests for your changes!"
    echo ""
    exit 0
fi

echo "Running tests for changed files:"
echo "$TEST_FILES" | head -5
TEST_COUNT=$(echo "$TEST_FILES" | wc -l | tr -d ' ')
if [ "$TEST_COUNT" -gt 5 ]; then
    echo "   ... and $((TEST_COUNT - 5)) more test files"
fi
echo ""

echo "Executing tests..."
if mise exec -- flutter test $TEST_FILES 2>&1; then
    echo ""
    echo "All tests passed!"
else
    echo ""
    echo "Tests failed!"
    echo "Fix the failing tests before pushing."
    echo ""
    echo "To skip this check (not recommended): git push --no-verify"
    exit 1
fi
EOF

chmod +x "$HOOKS_DIR/pre-push"

echo "Git hooks installed!"
echo ""
echo "Pre-commit: format check, flutter analyze, codegen verification"
echo "Pre-push:   merge conflict check, codegen verification, tests for changed files"
echo ""
echo "To bypass hooks (not recommended): --no-verify"
