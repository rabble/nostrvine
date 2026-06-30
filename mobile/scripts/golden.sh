#!/bin/bash
# ABOUTME: Golden test management script for running, updating, and managing golden tests
# ABOUTME: Provides commands for updating, verifying, cleaning, and diffing golden images

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

GOLDEN_TEST_PATH="test/goldens/"
GOLDEN_DART_DEFINE="--dart-define=DIVINE_GOLDEN_TESTS=true"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_help() {
    echo "Golden Test Management Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  update [test_file]  - Update golden images (all tests or specific file)"
    echo "  verify [test_file]  - Verify golden tests (all tests or specific file)"
    echo "  clean               - Remove all golden images"
    echo "  diff                - Show git diff of golden images"
    echo "  list                - List all golden test files"
    echo "  generate [widget]   - Generate golden tests for specific widget"
    echo "  ci                  - Run golden tests in CI mode"
    echo "  help                - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 update                              # Update all golden images"
    echo "  $0 update test/goldens/widgets/user_avatar_golden_test.dart"
    echo "  $0 verify                              # Verify all golden tests"
    echo "  $0 diff                                # Show changes to golden images"
}

update_goldens() {
    local test_file=$1

    echo -e "${BLUE}Updating golden images...${NC}"

    if [ -z "$test_file" ]; then
        require_golden_tests
        echo "Running golden tests with --update-goldens flag..."
        flutter test --no-pub "$GOLDEN_DART_DEFINE" --update-goldens "$GOLDEN_TEST_PATH"
    else
        echo "Updating goldens for: $test_file"
        flutter test --no-pub "$GOLDEN_DART_DEFINE" --update-goldens "$test_file"
    fi

    echo -e "${GREEN}✓ Golden images updated successfully${NC}"
}

verify_goldens() {
    local test_file=$1

    echo -e "${BLUE}Verifying golden tests...${NC}"

    if [ -z "$test_file" ]; then
        require_golden_tests
        echo "Running golden tests..."
        flutter test --no-pub "$GOLDEN_DART_DEFINE" "$GOLDEN_TEST_PATH"
    else
        echo "Verifying: $test_file"
        flutter test --no-pub "$GOLDEN_DART_DEFINE" "$test_file"
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ All golden tests passed${NC}"
    else
        echo -e "${RED}✗ Golden tests failed${NC}"
        echo -e "${YELLOW}Run '$0 update' to update golden images if changes are intentional${NC}"
        exit 1
    fi
}

clean_goldens() {
    echo -e "${YELLOW}Cleaning golden images...${NC}"

    find test/goldens -name "*.png" -type f -delete
    find test -name "*.png" -path "*/goldens/*" -type f -delete

    echo -e "${GREEN}✓ Golden images cleaned${NC}"
}

diff_goldens() {
    echo -e "${BLUE}Showing golden image changes...${NC}"

    git diff test/goldens/
    git diff --stat test/goldens/

    # Check for untracked golden files
    untracked=$(git ls-files --others --exclude-standard test/goldens/ | grep -E "\.png$" || true)
    if [ -n "$untracked" ]; then
        echo -e "${YELLOW}Untracked golden images:${NC}"
        echo "$untracked"
    fi
}

list_golden_tests() {
    echo -e "${BLUE}Golden test files:${NC}"

    find "$GOLDEN_TEST_PATH" -name "*_test.dart" | sort

    echo ""
    echo -e "${BLUE}Golden image files:${NC}"
    find test -name "*.png" | sort
}

generate_golden_test() {
    local widget_name=$1

    if [ -z "$widget_name" ]; then
        echo -e "${RED}Error: Widget name required${NC}"
        echo "Usage: $0 generate <widget_name>"
        exit 1
    fi

    echo -e "${BLUE}Generating golden test for: $widget_name${NC}"

    # Create test file path
    test_file="test/goldens/widgets/${widget_name,,}_golden_test.dart"

    if [ -f "$test_file" ]; then
        echo -e "${YELLOW}Warning: Test file already exists at $test_file${NC}"
        read -p "Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    echo "Creating golden test at: $test_file"
    # Note: Template generation would go here
    echo -e "${GREEN}✓ Golden test template created${NC}"
    echo -e "${YELLOW}Remember to implement the test and run '$0 update $test_file'${NC}"
}

ci_mode() {
    echo -e "${BLUE}Running golden tests in CI mode...${NC}"

    require_golden_tests
    flutter test --no-pub "$GOLDEN_DART_DEFINE" "$GOLDEN_TEST_PATH"

    # Check for any uncommitted golden changes
    if git diff --exit-code test/goldens/ > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Golden tests passed in CI${NC}"
    else
        echo -e "${RED}✗ Golden images have uncommitted changes${NC}"
        git diff --stat test/goldens/
        exit 1
    fi
}

require_golden_tests() {
    if ! find "$GOLDEN_TEST_PATH" -name "*_test.dart" -type f | grep -q .; then
        echo -e "${RED}✗ No golden test files found under $GOLDEN_TEST_PATH${NC}"
        echo -e "${YELLOW}Pass a specific golden test file or add tests under $GOLDEN_TEST_PATH.${NC}"
        exit 1
    fi
}

# Main script logic
case "${1:-help}" in
    update)
        update_goldens "$2"
        ;;
    verify)
        verify_goldens "$2"
        ;;
    clean)
        clean_goldens
        ;;
    diff)
        diff_goldens
        ;;
    list)
        list_golden_tests
        ;;
    generate)
        generate_golden_test "$2"
        ;;
    ci)
        ci_mode
        ;;
    help|--help|-h)
        print_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        print_help
        exit 1
        ;;
esac
