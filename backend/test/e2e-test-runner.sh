#!/bin/bash
# ABOUTME: End-to-end test runner for NostrVine video delivery system
# ABOUTME: Validates complete flow from Nostr discovery to video playback

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8787}"
TEST_API_KEY="${TEST_API_KEY:-test-key-123}"
VERBOSE="${VERBOSE:-false}"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Timing
TOTAL_START_TIME=$(date +%s)

# Helper functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

error() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

run_test() {
    local test_name=$1
    local test_function=$2
    ((TESTS_RUN++))
    
    log "Running test: $test_name"
    
    if $test_function; then
        success "$test_name"
    else
        error "$test_name"
    fi
}

# Measure response time
measure_time() {
    local start_time=$(date +%s%N)
    "$@"
    local end_time=$(date +%s%N)
    echo $(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
}

# Check if API is running
check_api_health() {
    log "Checking API health..."
    
    response=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/health" 2>/dev/null)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" == "200" ]; then
        status=$(echo "$body" | jq -r '.status' 2>/dev/null || echo "unknown")
        if [ "$status" == "healthy" ]; then
            success "API is healthy"
            if [ "$VERBOSE" == "true" ]; then
                echo "$body" | jq '.' 2>/dev/null || echo "$body"
            fi
            return 0
        else
            warning "API status: $status"
            return 1
        fi
    else
        error "Health check failed with HTTP $http_code"
        return 1
    fi
}

# Test 1: Video Metadata API
test_video_metadata_api() {
    local video_id="a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890"
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/video/$video_id" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" == "404" ]; then
        # Expected for non-existent video
        return 0
    elif [ "$http_code" == "200" ]; then
        # Validate response structure
        video_id_response=$(echo "$body" | jq -r '.videoId' 2>/dev/null)
        if [ "$video_id_response" == "$video_id" ]; then
            return 0
        fi
    fi
    
    [ "$VERBOSE" == "true" ] && echo "Response: $body"
    return 1
}

# Test 2: Batch Video Lookup
test_batch_video_lookup() {
    local payload='{
        "videoIds": [
            "1234567890123456789012345678901234567890123456789012345678901234",
            "abcdef0123456789012345678901234567890123456789012345678901234567"
        ],
        "quality": "720p"
    }'
    
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$API_BASE_URL/api/videos/batch" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" == "200" ]; then
        # Validate response structure
        found=$(echo "$body" | jq -r '.found' 2>/dev/null)
        missing=$(echo "$body" | jq -r '.missing' 2>/dev/null)
        videos=$(echo "$body" | jq -r '.videos' 2>/dev/null)
        
        if [ "$found" != "null" ] && [ "$missing" != "null" ] && [ "$videos" != "null" ]; then
            return 0
        fi
    fi
    
    [ "$VERBOSE" == "true" ] && echo "Response: $body"
    return 1
}

# Test 3: Performance - Response Time
test_response_time_performance() {
    local total_time=0
    local iterations=10
    local max_allowed_ms=200
    
    for i in $(seq 1 $iterations); do
        response_time=$(measure_time curl -s -o /dev/null \
            -H "Authorization: Bearer $TEST_API_KEY" \
            "$API_BASE_URL/api/video/test123")
        total_time=$((total_time + response_time))
    done
    
    avg_time=$((total_time / iterations))
    
    if [ "$avg_time" -le "$max_allowed_ms" ]; then
        [ "$VERBOSE" == "true" ] && echo "Average response time: ${avg_time}ms"
        return 0
    else
        warning "Average response time: ${avg_time}ms (exceeds ${max_allowed_ms}ms limit)"
        return 1
    fi
}

# Test 4: Cache Headers
test_cache_headers() {
    response_headers=$(curl -s -I \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/video/test123" 2>/dev/null)
    
    # Check for cache headers
    if echo "$response_headers" | grep -i "cache-control" >/dev/null; then
        cache_control=$(echo "$response_headers" | grep -i "cache-control" | cut -d' ' -f2-)
        [ "$VERBOSE" == "true" ] && echo "Cache-Control: $cache_control"
        return 0
    else
        return 1
    fi
}

# Test 5: CORS Headers
test_cors_headers() {
    response_headers=$(curl -s -I \
        -H "Origin: https://nostrvine.com" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/video/test123" 2>/dev/null)
    
    # Check for CORS headers
    if echo "$response_headers" | grep -i "access-control-allow-origin" >/dev/null; then
        cors_origin=$(echo "$response_headers" | grep -i "access-control-allow-origin" | cut -d' ' -f2-)
        [ "$VERBOSE" == "true" ] && echo "CORS Origin: $cors_origin"
        return 0
    else
        return 1
    fi
}

# Test 6: Rate Limiting
test_rate_limiting() {
    local burst_count=20
    local rate_limited=false
    
    log "Sending $burst_count rapid requests..."
    
    for i in $(seq 1 $burst_count); do
        response=$(curl -s -w "\n%{http_code}" \
            -H "Authorization: Bearer $TEST_API_KEY" \
            "$API_BASE_URL/api/video/test123" 2>/dev/null)
        
        http_code=$(echo "$response" | tail -n1)
        
        if [ "$http_code" == "429" ]; then
            rate_limited=true
            [ "$VERBOSE" == "true" ] && echo "Rate limited at request $i"
            break
        fi
    done
    
    # We expect rate limiting to kick in
    if [ "$rate_limited" == "true" ]; then
        return 0
    else
        warning "Rate limiting did not trigger after $burst_count requests"
        return 1
    fi
}

# Test 7: Error Handling - Invalid Video ID
test_error_handling_invalid_id() {
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/video/invalid-id" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" == "400" ]; then
        error_msg=$(echo "$body" | jq -r '.error' 2>/dev/null)
        if [ "$error_msg" != "null" ]; then
            [ "$VERBOSE" == "true" ] && echo "Error message: $error_msg"
            return 0
        fi
    fi
    
    return 1
}

# Test 8: Analytics Endpoint
test_analytics_endpoint() {
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/analytics/popular?window=24h" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" == "200" ]; then
        videos=$(echo "$body" | jq -r '.videos' 2>/dev/null)
        if [ "$videos" != "null" ]; then
            return 0
        fi
    fi
    
    [ "$VERBOSE" == "true" ] && echo "Response: $body"
    return 1
}

# Test 9: Batch API with Large Payload
test_batch_api_large_payload() {
    # Generate 50 video IDs (max allowed)
    local video_ids=()
    for i in $(seq 1 50); do
        video_ids+=("\"$(printf '%064d' $i)\"")
    done
    
    local payload="{
        \"videoIds\": [$(IFS=,; echo "${video_ids[*]}")],
        \"quality\": \"auto\"
    }"
    
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$API_BASE_URL/api/videos/batch" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" == "200" ]; then
        return 0
    else
        [ "$VERBOSE" == "true" ] && echo "HTTP Status: $http_code"
        return 1
    fi
}

# Test 10: OPTIONS Preflight
test_options_preflight() {
    response=$(curl -s -w "\n%{http_code}" \
        -X OPTIONS \
        -H "Origin: https://nostrvine.com" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: authorization,content-type" \
        "$API_BASE_URL/api/videos/batch" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" == "204" ] || [ "$http_code" == "200" ]; then
        return 0
    else
        return 1
    fi
}

# Load Testing Function
run_load_test() {
    log "Starting load test..."
    
    if ! command -v ab &> /dev/null; then
        warning "Apache Bench (ab) not installed. Skipping load test."
        return
    fi
    
    # Run load test with 100 requests, 10 concurrent
    ab_output=$(ab -n 100 -c 10 -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/video/test123" 2>&1)
    
    if [ $? -eq 0 ]; then
        requests_per_sec=$(echo "$ab_output" | grep "Requests per second" | awk '{print $4}')
        mean_time=$(echo "$ab_output" | grep "Time per request" | head -n1 | awk '{print $4}')
        
        success "Load test completed"
        log "Requests per second: $requests_per_sec"
        log "Mean response time: ${mean_time}ms"
    else
        error "Load test failed"
    fi
}

# Main test execution
main() {
    echo "================================================"
    echo " NostrVine End-to-End Test Suite"
    echo " API URL: $API_BASE_URL"
    echo " Time: $(date)"
    echo "================================================"
    echo
    
    # Check if API is accessible
    if ! check_api_health; then
        error "API health check failed. Ensure the API is running."
        exit 1
    fi
    
    echo
    log "Starting E2E tests..."
    echo
    
    # Run all tests
    run_test "Video Metadata API" test_video_metadata_api
    run_test "Batch Video Lookup" test_batch_video_lookup
    run_test "Response Time Performance" test_response_time_performance
    run_test "Cache Headers Validation" test_cache_headers
    run_test "CORS Headers Check" test_cors_headers
    run_test "Rate Limiting" test_rate_limiting
    run_test "Error Handling - Invalid ID" test_error_handling_invalid_id
    run_test "Analytics Endpoint" test_analytics_endpoint
    run_test "Batch API - Large Payload" test_batch_api_large_payload
    run_test "OPTIONS Preflight" test_options_preflight
    
    echo
    
    # Optional load test
    if [ "$RUN_LOAD_TEST" == "true" ]; then
        run_load_test
        echo
    fi
    
    # Calculate total time
    TOTAL_END_TIME=$(date +%s)
    TOTAL_DURATION=$((TOTAL_END_TIME - TOTAL_START_TIME))
    
    # Summary
    echo "================================================"
    echo " Test Summary"
    echo "================================================"
    echo " Total Tests: $TESTS_RUN"
    echo -e " Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e " Failed: ${RED}$TESTS_FAILED${NC}"
    echo " Duration: ${TOTAL_DURATION}s"
    echo "================================================"
    
    # Exit with appropriate code
    if [ "$TESTS_FAILED" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"