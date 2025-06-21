#!/bin/bash

# ABOUTME: End-to-end test for Nostr event to video playback flow
# ABOUTME: Tests the complete journey from video discovery to streaming

set -e

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8787}"
TEST_API_KEY="${TEST_API_KEY:-test-key-123}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_test() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    ((TESTS_FAILED++))
}

check_status() {
    local expected=$1
    local actual=$2
    local test_name=$3
    
    if [ "$actual" -eq "$expected" ]; then
        log_success "$test_name (HTTP $actual)"
    else
        log_error "$test_name (Expected: $expected, Got: $actual)"
    fi
}

# Main test flow
echo "=== Testing Nostr Event to Video Flow ==="
echo "API Base URL: $API_BASE_URL"
echo "================================================"

# Step 1: Simulate Nostr event with video
log_test "Step 1: Simulating Nostr event with video"
VIDEO_URL="https://example.com/test-video.mp4"
VIDEO_ID=$(echo -n "$VIDEO_URL" | shasum -a 256 | cut -d' ' -f1)
EVENT_ID="test-event-123"

echo "Video URL: $VIDEO_URL"
echo "Video ID: $VIDEO_ID"
echo "Event ID: $EVENT_ID"

# Step 2: Test batch video lookup
log_test "Step 2: Testing batch video lookup"

# Create request body
BATCH_REQUEST=$(cat <<EOF
{
    "videoIds": ["$VIDEO_ID", "invalid-id-456"],
    "quality": "auto"
}
EOF
)

# Make batch request
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE_URL/api/videos/batch" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -d "$BATCH_REQUEST")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

check_status 200 "$HTTP_CODE" "Batch video lookup"

# Validate response structure
if echo "$BODY" | jq -e '.videos' > /dev/null 2>&1; then
    log_success "Response has videos field"
    
    # Check if response contains our video ID
    if echo "$BODY" | jq -e ".videos[\"$VIDEO_ID\"]" > /dev/null 2>&1; then
        VIDEO_AVAILABLE=$(echo "$BODY" | jq -r ".videos[\"$VIDEO_ID\"].available")
        if [ "$VIDEO_AVAILABLE" = "false" ]; then
            log_success "Video correctly marked as unavailable"
        else
            log_error "Video should be marked as unavailable"
        fi
    else
        log_error "Video ID not found in response"
    fi
    
    # Check batch statistics
    FOUND_COUNT=$(echo "$BODY" | jq -r '.found // 0')
    MISSING_COUNT=$(echo "$BODY" | jq -r '.missing // 0')
    echo "Found: $FOUND_COUNT, Missing: $MISSING_COUNT"
else
    log_error "Response missing videos field"
fi

# Step 3: Test single video metadata
log_test "Step 3: Testing single video endpoint"

RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TEST_API_KEY" \
    "$API_BASE_URL/api/video/$VIDEO_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

# For non-existent videos, we expect 404
check_status 404 "$HTTP_CODE" "Single video lookup (non-existent)"

# Step 4: Test with a known video ID (from test data)
log_test "Step 4: Testing with known test video"

# Use a test video ID that should exist in the system
TEST_VIDEO_ID="0000000000000000000000000000000000000000000000000000000000000001"

RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TEST_API_KEY" \
    "$API_BASE_URL/api/video/$TEST_VIDEO_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -eq 200 ]; then
    log_success "Test video found (HTTP 200)"
    
    # Validate video metadata structure
    if echo "$BODY" | jq -e '.videoId' > /dev/null 2>&1; then
        log_success "Response has videoId"
    else
        log_error "Response missing videoId"
    fi
    
    if echo "$BODY" | jq -e '.duration' > /dev/null 2>&1; then
        log_success "Response has duration"
    else
        log_error "Response missing duration"
    fi
    
    if echo "$BODY" | jq -e '.renditions' > /dev/null 2>&1; then
        log_success "Response has renditions"
        
        # Check for 480p and 720p
        if echo "$BODY" | jq -e '.renditions."480p"' > /dev/null 2>&1; then
            log_success "Has 480p rendition"
        else
            log_error "Missing 480p rendition"
        fi
        
        if echo "$BODY" | jq -e '.renditions."720p"' > /dev/null 2>&1; then
            log_success "Has 720p rendition"
        else
            log_error "Missing 720p rendition"
        fi
    else
        log_error "Response missing renditions"
    fi
    
    # Step 5: Verify signed URLs work
    log_test "Step 5: Testing signed URL access"
    
    SIGNED_URL=$(echo "$BODY" | jq -r '.renditions."480p" // empty')
    if [ -n "$SIGNED_URL" ] && [ "$SIGNED_URL" != "null" ]; then
        # Test if URL is accessible (HEAD request)
        SIGNED_RESPONSE=$(curl -s -I "$SIGNED_URL" | head -n1)
        
        if echo "$SIGNED_RESPONSE" | grep -q "200\|206\|302"; then
            log_success "Signed URL is accessible"
        else
            log_error "Signed URL not accessible: $SIGNED_RESPONSE"
        fi
    else
        log_error "No signed URL available for testing"
    fi
elif [ "$HTTP_CODE" -eq 404 ]; then
    log_error "Test video not found - please run upload-test-data.sh first"
else
    log_error "Unexpected status code: $HTTP_CODE"
fi

# Step 6: Test CORS headers
log_test "Step 6: Testing CORS headers"

CORS_RESPONSE=$(curl -s -I -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Origin: http://localhost:3000" \
    "$API_BASE_URL/api/video/$TEST_VIDEO_ID")

if echo "$CORS_RESPONSE" | grep -q "Access-Control-Allow-Origin"; then
    log_success "CORS headers present"
    echo "$CORS_RESPONSE" | grep "Access-Control-"
else
    log_error "CORS headers missing"
fi

# Summary
echo -e "\n================================================"
echo -e "Test Summary:"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "================================================"

# Exit with appropriate code
if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi