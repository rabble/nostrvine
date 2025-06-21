#!/bin/bash

# ABOUTME: Cache testing script for video API endpoints
# ABOUTME: Validates caching behavior, cache headers, and cache performance

set -e

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8787}"
TEST_API_KEY="${TEST_API_KEY:-test-key-123}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

log_info() {
    echo -e "${YELLOW}$1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    ((TESTS_FAILED++))
}

# Check if header exists and has expected value
check_header() {
    local headers="$1"
    local header_name="$2"
    local expected_pattern="$3"
    local test_name="$4"
    
    local header_value=$(echo "$headers" | grep -i "^$header_name:" | cut -d' ' -f2- | tr -d '\r\n')
    
    if [ -n "$header_value" ]; then
        if echo "$header_value" | grep -q "$expected_pattern"; then
            log_success "$test_name: $header_value"
        else
            log_error "$test_name: Expected pattern '$expected_pattern', got '$header_value'"
        fi
    else
        log_error "$test_name: Header '$header_name' not found"
    fi
}

# Measure response time
time_request() {
    local url="$1"
    local headers="$2"
    
    local start=$(date +%s%3N)
    local response=$(curl -s -I $headers "$url")
    local end=$(date +%s%3N)
    
    local duration=$((end - start))
    echo "$duration:$response"
}

# Main test execution
echo "=== Cache Testing for Video API ==="
echo "API Base URL: $API_BASE_URL"
echo "================================================"

# Test video ID
TEST_VIDEO_ID="0000000000000000000000000000000000000000000000000000000000000001"
CACHE_TEST_VIDEO_ID="cache-test-$(date +%s)"

# Test 1: Single video endpoint cache headers
log_section "Test 1: Single Video Endpoint Cache Headers"

log_info "Testing cache headers for single video endpoint"

HEADERS=$(curl -s -I -H "Authorization: Bearer $TEST_API_KEY" \
    "$API_BASE_URL/api/video/$TEST_VIDEO_ID")

HTTP_STATUS=$(echo "$HEADERS" | head -n1 | grep -o '[0-9][0-9][0-9]')

if [ "$HTTP_STATUS" = "200" ]; then
    log_success "Video endpoint returned HTTP 200"
    
    # Check cache-related headers
    check_header "$HEADERS" "Cache-Control" "public.*max-age" "Cache-Control header"
    check_header "$HEADERS" "ETag" "\".*\"" "ETag header"
    
    # Check if cache duration is reasonable (should be at least 180 seconds)
    MAX_AGE=$(echo "$HEADERS" | grep -i "cache-control" | grep -o "max-age=[0-9]*" | cut -d= -f2)
    if [ -n "$MAX_AGE" ] && [ "$MAX_AGE" -ge 180 ]; then
        log_success "Cache max-age is reasonable: ${MAX_AGE}s"
    else
        log_error "Cache max-age too low or missing: ${MAX_AGE}s"
    fi
    
elif [ "$HTTP_STATUS" = "404" ]; then
    log_info "Test video not found (404), using alternative test"
    
    # Test with batch endpoint which should return cached data
    BATCH_HEADERS=$(curl -s -I -X POST \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"videoIds\": [\"$TEST_VIDEO_ID\"]}" \
        "$API_BASE_URL/api/videos/batch")
    
    check_header "$BATCH_HEADERS" "Cache-Control" "max-age" "Batch endpoint cache header"
else
    log_error "Unexpected HTTP status: $HTTP_STATUS"
fi

# Test 2: Cache hit/miss behavior simulation
log_section "Test 2: Cache Miss vs Cache Hit Performance"

log_info "Testing cache performance with repeated requests"

# First request (potential cache miss)
log_info "First request (cache miss expected)..."
RESULT1=$(time_request "$API_BASE_URL/api/video/$TEST_VIDEO_ID" "-H 'Authorization: Bearer $TEST_API_KEY'")
TIME1=$(echo "$RESULT1" | cut -d: -f1)
HEADERS1=$(echo "$RESULT1" | cut -d: -f2-)

echo "First request time: ${TIME1}ms"

# Brief pause to ensure any async cache operations complete
sleep 1

# Second request (potential cache hit)
log_info "Second request (cache hit expected)..."
RESULT2=$(time_request "$API_BASE_URL/api/video/$TEST_VIDEO_ID" "-H 'Authorization: Bearer $TEST_API_KEY'")
TIME2=$(echo "$RESULT2" | cut -d: -f1)
HEADERS2=$(echo "$RESULT2" | cut -d: -f2-)

echo "Second request time: ${TIME2}ms"

# Compare response times
if [ "$TIME2" -le "$TIME1" ]; then
    IMPROVEMENT=$(echo "scale=1; ($TIME1 - $TIME2) * 100 / $TIME1" | bc -l 2>/dev/null || echo "0")
    log_success "Second request was faster (${IMPROVEMENT}% improvement)"
else
    DEGRADATION=$(echo "scale=1; ($TIME2 - $TIME1) * 100 / $TIME1" | bc -l 2>/dev/null || echo "0")
    log_info "Second request was slower (${DEGRADATION}% slower) - may indicate cache miss"
fi

# Test 3: Batch endpoint caching
log_section "Test 3: Batch Endpoint Cache Headers"

log_info "Testing batch endpoint cache behavior"

BATCH_RESPONSE=$(curl -s -I -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"videoIds\": [\"$TEST_VIDEO_ID\", \"nonexistent123\"]}" \
    "$API_BASE_URL/api/videos/batch")

BATCH_STATUS=$(echo "$BATCH_RESPONSE" | head -n1 | grep -o '[0-9][0-9][0-9]')

if [ "$BATCH_STATUS" = "200" ]; then
    log_success "Batch endpoint returned HTTP 200"
    
    # Check for cache headers on batch endpoint
    check_header "$BATCH_RESPONSE" "Cache-Control" "max-age" "Batch cache headers"
    
    # Batch endpoints should have shorter cache times (3 minutes)
    BATCH_MAX_AGE=$(echo "$BATCH_RESPONSE" | grep -i "cache-control" | grep -o "max-age=[0-9]*" | cut -d= -f2)
    if [ -n "$BATCH_MAX_AGE" ] && [ "$BATCH_MAX_AGE" -ge 60 ] && [ "$BATCH_MAX_AGE" -le 300 ]; then
        log_success "Batch cache duration appropriate: ${BATCH_MAX_AGE}s"
    else
        log_error "Batch cache duration inappropriate: ${BATCH_MAX_AGE}s"
    fi
else
    log_error "Batch endpoint failed: HTTP $BATCH_STATUS"
fi

# Test 4: Conditional requests (ETag)
log_section "Test 4: Conditional Requests with ETag"

if echo "$HEADERS1" | grep -q "ETag:"; then
    ETAG=$(echo "$HEADERS1" | grep -i "etag:" | cut -d' ' -f2- | tr -d '\r\n')
    log_info "Testing conditional request with ETag: $ETAG"
    
    CONDITIONAL_RESPONSE=$(curl -s -I \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "If-None-Match: $ETAG" \
        "$API_BASE_URL/api/video/$TEST_VIDEO_ID")
    
    CONDITIONAL_STATUS=$(echo "$CONDITIONAL_RESPONSE" | head -n1 | grep -o '[0-9][0-9][0-9]')
    
    if [ "$CONDITIONAL_STATUS" = "304" ]; then
        log_success "Conditional request returned 304 Not Modified"
    elif [ "$CONDITIONAL_STATUS" = "200" ]; then
        log_info "Conditional request returned 200 (ETag may have changed)"
    else
        log_error "Unexpected conditional request status: $CONDITIONAL_STATUS"
    fi
else
    log_error "No ETag found in initial response for conditional testing"
fi

# Test 5: Cache behavior with different quality parameters
log_section "Test 5: Quality Parameter Cache Behavior"

log_info "Testing cache behavior with different quality parameters"

# Test different quality requests
for quality in "480p" "720p" "auto"; do
    log_info "Testing quality: $quality"
    
    QUALITY_RESPONSE=$(curl -s -I \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/video/$TEST_VIDEO_ID?quality=$quality")
    
    QUALITY_STATUS=$(echo "$QUALITY_RESPONSE" | head -n1 | grep -o '[0-9][0-9][0-9]')
    
    if [ "$QUALITY_STATUS" = "200" ] || [ "$QUALITY_STATUS" = "404" ]; then
        log_success "Quality $quality request: HTTP $QUALITY_STATUS"
        
        # Check if Vary header is present for quality-dependent responses
        if echo "$QUALITY_RESPONSE" | grep -qi "vary:"; then
            VARY_HEADER=$(echo "$QUALITY_RESPONSE" | grep -i "vary:" | cut -d' ' -f2- | tr -d '\r\n')
            log_info "Vary header present: $VARY_HEADER"
        fi
    else
        log_error "Quality $quality request failed: HTTP $QUALITY_STATUS"
    fi
done

# Test 6: Performance mode cache behavior
log_section "Test 6: Performance Mode Cache Behavior"

log_info "Testing optimized API cache headers"

OPTIMIZED_RESPONSE=$(curl -s -I -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -H "X-Performance-Mode: optimized" \
    -d "{\"videoIds\": [\"$TEST_VIDEO_ID\"]}" \
    "$API_BASE_URL/api/videos/batch")

OPTIMIZED_STATUS=$(echo "$OPTIMIZED_RESPONSE" | head -n1 | grep -o '[0-9][0-9][0-9]')

if [ "$OPTIMIZED_STATUS" = "200" ]; then
    log_success "Optimized batch endpoint: HTTP 200"
    
    # Check for performance mode header
    if echo "$OPTIMIZED_RESPONSE" | grep -qi "X-Performance-Mode: optimized"; then
        log_success "Performance mode header present"
    else
        log_error "Performance mode header missing"
    fi
    
    check_header "$OPTIMIZED_RESPONSE" "Cache-Control" "max-age" "Optimized API cache headers"
else
    log_error "Optimized batch endpoint failed: HTTP $OPTIMIZED_STATUS"
fi

# Test 7: Cache invalidation behavior
log_section "Test 7: Cache Consistency"

log_info "Testing cache consistency across endpoints"

# Get video info from single endpoint
SINGLE_RESPONSE=$(curl -s -H "Authorization: Bearer $TEST_API_KEY" \
    "$API_BASE_URL/api/video/$TEST_VIDEO_ID" 2>/dev/null || echo '{}')

# Get same video info from batch endpoint
BATCH_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"videoIds\": [\"$TEST_VIDEO_ID\"]}" \
    "$API_BASE_URL/api/videos/batch" 2>/dev/null || echo '{}')

# Compare responses (basic check)
SINGLE_AVAILABLE=$(echo "$SINGLE_RESPONSE" | jq -r '.available // false' 2>/dev/null || echo "false")
BATCH_AVAILABLE=$(echo "$BATCH_RESPONSE" | jq -r ".videos[\"$TEST_VIDEO_ID\"].available // false" 2>/dev/null || echo "false")

if [ "$SINGLE_AVAILABLE" = "$BATCH_AVAILABLE" ]; then
    log_success "Single and batch endpoints return consistent availability"
else
    log_error "Inconsistent availability between endpoints: single=$SINGLE_AVAILABLE, batch=$BATCH_AVAILABLE"
fi

# Summary
log_section "Cache Test Summary"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All cache tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some cache tests failed!${NC}"
    exit 1
fi