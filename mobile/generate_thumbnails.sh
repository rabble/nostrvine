#!/bin/bash

# ABOUTME: Shell wrapper for bulk thumbnail generation script
# ABOUTME: Makes it easy to run the Dart script with common options

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DART_SCRIPT="$SCRIPT_DIR/lib/scripts/bulk_thumbnail_generator.dart"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 OpenVine Bulk Thumbnail Generator${NC}"
echo -e "${BLUE}====================================${NC}"

# Check if dart is available
if ! command -v dart &> /dev/null; then
    echo -e "${RED}❌ Dart is not installed or not in PATH${NC}"
    echo "Please install Flutter/Dart first"
    exit 1
fi

# Check if script exists
if [[ ! -f "$DART_SCRIPT" ]]; then
    echo -e "${RED}❌ Script not found: $DART_SCRIPT${NC}"
    exit 1
fi

# Default options
LIMIT=100
DRY_RUN=""
BATCH_SIZE=5
TIME_OFFSET=2.5

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        -b|--batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        -t|--time-offset)
            TIME_OFFSET="$2"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -l, --limit <number>       Maximum videos to process (default: $LIMIT)"
            echo "  -d, --dry-run             Don't generate thumbnails, just report"
            echo "  -b, --batch-size <number>  Batch size (default: $BATCH_SIZE)"
            echo "  -t, --time-offset <number> Time offset in seconds (default: $TIME_OFFSET)"
            echo "  -h, --help                Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --limit 50 --dry-run"
            echo "  $0 --batch-size 10 --time-offset 3.0"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Show configuration
echo -e "${YELLOW}📋 Configuration:${NC}"
echo "   Limit: $LIMIT videos"
echo "   Batch size: $BATCH_SIZE"
echo "   Time offset: ${TIME_OFFSET}s"
if [[ -n "$DRY_RUN" ]]; then
    echo -e "   Mode: ${YELLOW}DRY RUN${NC} (no actual generation)"
else
    echo -e "   Mode: ${GREEN}LIVE${NC} (will generate thumbnails)"
fi
echo ""

# Confirm before proceeding (unless dry run)
if [[ -z "$DRY_RUN" ]]; then
    echo -e "${YELLOW}⚠️  This will make actual API calls to generate thumbnails.${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Change to the mobile directory for proper package resolution
cd "$SCRIPT_DIR"

# Run the Dart script
echo -e "${GREEN}🎬 Starting thumbnail generation...${NC}"
echo ""

dart run "lib/scripts/bulk_thumbnail_generator.dart" \
    --limit "$LIMIT" \
    --batch-size "$BATCH_SIZE" \
    --time-offset "$TIME_OFFSET" \
    $DRY_RUN

echo ""
echo -e "${GREEN}✅ Thumbnail generation completed!${NC}"