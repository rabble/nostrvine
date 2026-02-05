#!/bin/bash
# Comprehensive review checklist

echo "=== Code Review Checklist ==="

# 1. Check TODOs
./.claude/check_todos.sh || exit 1

# 2. Check test coverage
cd mobile
flutter test --coverage
COVERAGE=$(lcov --summary coverage/lcov.info 2>/dev/null | grep "lines" | grep -o '[0-9.]*' | head -1)
if (( $(echo "$COVERAGE < 80" | bc -l) )); then
    echo "❌ Coverage $COVERAGE% is below 80%"
    exit 1
fi

# 3. Check for Future.delayed
if grep -r "Future.delayed" mobile/lib/; then
    echo "❌ Found Future.delayed - use proper async patterns"
    exit 1
fi

# 4. Run flutter analyze
flutter analyze || exit 1

# 5. Check for duplicates
dart .claude/check_duplicates.dart || exit 1

echo "✅ All checks passed!"
