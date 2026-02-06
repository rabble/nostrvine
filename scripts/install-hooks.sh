#!/bin/bash
# Install git hooks for divine-mobile development
# Run this once after cloning the repo

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks..."

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook for divine-mobile
# Runs format check and analyze to catch CI failures early

set -e

cd "$(git rev-parse --show-toplevel)/mobile"

echo "🔍 Running pre-commit checks..."

# Check if any Dart files are staged
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.dart$' || true)

if [ -z "$STAGED_DART_FILES" ]; then
    echo "✅ No Dart files staged, skipping checks"
    exit 0
fi

# Run dart format check (fast)
echo "📝 Checking format..."
if ! dart format --output=none --set-exit-if-changed lib test 2>/dev/null; then
    echo ""
    echo "❌ Format check failed!"
    echo "Run: cd mobile && dart format lib test"
    exit 1
fi
echo "✅ Format OK"

# Run flutter analyze (medium speed)
echo "🔬 Running analyzer..."
if ! flutter analyze --no-fatal-infos 2>/dev/null; then
    echo ""
    echo "❌ Analysis failed!"
    echo "Fix the issues above before committing"
    exit 1
fi
echo "✅ Analysis OK"

# Check if generated files need updating
NEEDS_CODEGEN=$(echo "$STAGED_DART_FILES" | xargs grep -l '@riverpod\|@freezed\|@JsonSerializable\|@GenerateMocks' 2>/dev/null || true)
if [ -n "$NEEDS_CODEGEN" ]; then
    echo ""
    echo "⚠️  Warning: Files with code generation annotations were modified."
    echo "Consider running: dart run build_runner build --delete-conflicting-outputs"
fi

echo ""
echo "✅ All pre-commit checks passed!"
EOF

chmod +x "$HOOKS_DIR/pre-commit"

# Create pre-push hook
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Pre-push hook for divine-mobile
# Runs tests related to changed files before pushing

set -e

cd "$(git rev-parse --show-toplevel)/mobile"

echo "🚀 Running pre-push checks..."

# Get the remote and branch being pushed to
remote="$1"
url="$2"

# Always compare against origin/main to catch all changes that will affect CI
# (CI runs against main branch, so we want to test everything that differs from main)
BASE_BRANCH="origin/main"

# Fetch latest main to ensure accurate comparison
git fetch origin main --quiet 2>/dev/null || true

# Get list of changed Dart files (excluding generated files)
CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null | grep '\.dart$' | grep -v '\.g\.dart$' | grep -v '\.freezed\.dart$' || true)

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

# Find corresponding test files
TEST_FILES=""
REPO_ROOT="$(git rev-parse --show-toplevel)"

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
if flutter test $TEST_FILES 2>&1; then
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

chmod +x "$HOOKS_DIR/pre-push"

echo "✅ Git hooks installed!"
echo ""
echo "Pre-commit: Runs 'dart format' and 'flutter analyze'"
echo "Pre-push:   Runs tests for changed files"
echo ""
echo "To bypass hooks (not recommended): --no-verify"
