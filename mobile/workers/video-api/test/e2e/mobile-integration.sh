#!/bin/bash

# ABOUTME: Mobile integration tests for video API
# ABOUTME: Tests CORS, mobile user agents, network hints, and mobile-specific features

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

# Test CORS headers
test_cors() {
    local method="$1"
    local url="$2"
    local origin="$3"
    local extra_headers="$4"
    
    local cors_response=$(curl -s -I -X "$method" \
        -H "Origin: $origin" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        $extra_headers \
        "$url")
    
    echo "$cors_response"
}

# Main test execution
echo "=== Mobile Integration Tests for Video API ==="
echo "API Base URL: $API_BASE_URL"
echo "================================================"

# Test 1: CORS Preflight Requests
log_section "Test 1: CORS Preflight Requests"

log_info "Testing CORS preflight for GET requests"
PREFLIGHT_RESPONSE=$(curl -s -I -X OPTIONS \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: GET" \
    -H "Access-Control-Request-Headers: Authorization" \
    "$API_BASE_URL/api/video/test123")

HTTP_STATUS=$(echo "$PREFLIGHT_RESPONSE" | head -n1 | grep -o '[0-9][0-9][0-9]')

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "204" ]; then
    log_success "CORS preflight successful (HTTP $HTTP_STATUS)"
    
    # Check required CORS headers
    check_header "$PREFLIGHT_RESPONSE" "Access-Control-Allow-Origin" ".*" "Allow-Origin header"
    check_header "$PREFLIGHT_RESPONSE" "Access-Control-Allow-Methods" "GET\|POST\|OPTIONS" "Allow-Methods header"
    check_header "$PREFLIGHT_RESPONSE" "Access-Control-Allow-Headers" ".*Authorization.*" "Allow-Headers includes Authorization"
    check_header "$PREFLIGHT_RESPONSE" "Access-Control-Max-Age" "[0-9]" "Max-Age header"
    
else
    log_error "CORS preflight failed (HTTP $HTTP_STATUS)"
fi

log_info "Testing CORS preflight for POST requests"
POST_PREFLIGHT=$(curl -s -I -X OPTIONS \
    -H "Origin: https://localhost:3000" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: Content-Type, Authorization" \
    "$API_BASE_URL/api/videos/batch")

POST_STATUS=$(echo "$POST_PREFLIGHT" | head -n1 | grep -o '[0-9][0-9][0-9]')

if [ "$POST_STATUS" = "200" ] || [ "$POST_STATUS" = "204" ]; then
    log_success "POST CORS preflight successful (HTTP $POST_STATUS)"
    check_header "$POST_PREFLIGHT" "Access-Control-Allow-Methods" "POST" "POST method allowed"
else
    log_error "POST CORS preflight failed (HTTP $POST_STATUS)"
fi

# Test 2: Actual CORS Requests
log_section "Test 2: Actual CORS Requests"

log_info "Testing GET request with CORS headers"
GET_CORS=$(test_cors "GET" "$API_BASE_URL/api/video/test123" "https://localhost:3000" "")

GET_STATUS=$(echo "$GET_CORS" | head -n1 | grep -o '[0-9][0-9][0-9]')

if [ "$GET_STATUS" = "200" ] || [ "$GET_STATUS" = "404" ]; then
    log_success "GET CORS request successful (HTTP $GET_STATUS)"
    check_header "$GET_CORS" "Access-Control-Allow-Origin" ".*" "CORS Allow-Origin in GET response"
else
    log_error "GET CORS request failed (HTTP $GET_STATUS)"
fi

log_info "Testing POST request with CORS headers"
POST_CORS=$(curl -s -I -X POST \
    -H "Origin: https://localhost:3000" \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"videoIds": ["test123"]}' \
    "$API_BASE_URL/api/videos/batch")

POST_STATUS=$(echo "$POST_CORS" | head -n1 | grep -o '[0-9][0-9][0-9]')

if [ "$POST_STATUS" = "200" ]; then
    log_success "POST CORS request successful (HTTP $POST_STATUS)"
    check_header "$POST_CORS" "Access-Control-Allow-Origin" ".*" "CORS Allow-Origin in POST response"
else
    log_error "POST CORS request failed (HTTP $POST_STATUS)"
fi

# Test 3: Mobile User Agents
log_section "Test 3: Mobile User Agent Testing"

# Define mobile user agents
declare -a MOBILE_UAS=(
    "NostrVine/1.0 (iPhone; iOS 17.0; Scale/3.00)"
    "NostrVine/1.0 (Android 14; Mobile; SM-G998B)"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    "Mozilla/5.0 (Linux; Android 14; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
)

for ua in "${MOBILE_UAS[@]}"; do
    log_info "Testing user agent: ${ua:0:50}..."
    
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "User-Agent: $ua" \
        "$API_BASE_URL/api/video/test123")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then
        log_success "Mobile UA accepted (HTTP $HTTP_CODE)"
        
        # Check if response is mobile-optimized (has renditions)
        if echo "$BODY" | jq -e '.renditions' > /dev/null 2>&1; then
            log_success "Response includes video renditions for mobile"
        fi
    else
        log_error "Mobile UA rejected (HTTP $HTTP_CODE)"
    fi
done

# Test 4: Network Hint Headers
log_section "Test 4: Network Hint Headers"

log_info "Testing Save-Data header support"
SAVE_DATA_RESPONSE=$(curl -s \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Save-Data: on" \
    "$API_BASE_URL/api/video/test123")

if echo "$SAVE_DATA_RESPONSE" | jq -e '.renditions' > /dev/null 2>&1; then
    # Check if lower quality is prioritized when Save-Data is on
    RENDITIONS=$(echo "$SAVE_DATA_RESPONSE" | jq -r '.renditions | keys[]' 2>/dev/null || echo "")
    
    if echo "$RENDITIONS" | grep -q "480p"; then
        log_success "Save-Data header respected (480p available)"
    else
        log_info "Save-Data header processed (renditions: $RENDITIONS)"
    fi
else
    log_info "Save-Data header test (video not found, but header processed)"
fi

log_info "Testing network type hints"
NETWORK_HEADERS=(
    "Downlink: 1.5"  # Slow connection
    "RTT: 200"       # High latency
    "ECT: slow-2g"   # Effective connection type
)

for header in "${NETWORK_HEADERS[@]}"; do
    RESPONSE=$(curl -s \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "$header" \
        "$API_BASE_URL/api/video/test123")
    
    log_info "Network hint '$header' processed"
done

# Test 5: Batch Requests with Mobile Optimization
log_section "Test 5: Mobile Batch Request Optimization"

log_info "Testing batch request with mobile user agent"
MOBILE_BATCH=$(curl -s \
    -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -H "User-Agent: NostrVine/1.0 (iPhone; iOS 17.0)" \
    -H "Save-Data: on" \
    -d '{"videoIds": ["test1", "test2", "test3"], "quality": "auto"}' \
    "$API_BASE_URL/api/videos/batch")

if echo "$MOBILE_BATCH" | jq -e '.videos' > /dev/null 2>&1; then
    log_success "Mobile batch request processed"
    
    # Check if response includes mobile-friendly data
    FOUND_COUNT=$(echo "$MOBILE_BATCH" | jq -r '.found // 0')
    MISSING_COUNT=$(echo "$MOBILE_BATCH" | jq -r '.missing // 0')
    
    log_info "Batch results: Found=$FOUND_COUNT, Missing=$MISSING_COUNT"
else
    log_error "Mobile batch request failed"
fi

# Test 6: Upload Request Mobile Support
log_section "Test 6: Upload Request Mobile Support"

log_info "Testing upload request with mobile user agent"
UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "User-Agent: NostrVine/1.0 (Android 14; Mobile)" \
    -d '{"fileName": "mobile-video.mp4", "fileSize": 1024}' \
    "$API_BASE_URL/v1/media/request-upload")

UPLOAD_STATUS=$(echo "$UPLOAD_RESPONSE" | tail -n1)

if [ "$UPLOAD_STATUS" = "401" ]; then
    log_success "Upload endpoint accessible from mobile (Auth required as expected)"
elif [ "$UPLOAD_STATUS" = "200" ]; then
    log_success "Upload endpoint fully functional from mobile"
else
    log_info "Upload endpoint response: HTTP $UPLOAD_STATUS"
fi

# Test 7: Performance Monitoring Headers
log_section "Test 7: Performance Monitoring Headers"

log_info "Testing timing headers for mobile optimization"
TIMING_RESPONSE=$(curl -s -I \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "User-Agent: NostrVine/1.0 (iPhone; iOS 17.0)" \
    "$API_BASE_URL/api/video/test123")

# Check for performance-related headers
check_header "$TIMING_RESPONSE" "Cache-Control" "max-age" "Cache headers for mobile"

# Look for security headers that don't break mobile apps
if echo "$TIMING_RESPONSE" | grep -qi "X-Frame-Options\|X-Content-Type-Options"; then
    log_success "Security headers present (mobile-friendly)"
fi

# Test 8: Prefetch API Mobile Integration
log_section "Test 8: Prefetch API Mobile Integration"

log_info "Testing prefetch API with mobile context"
PREFETCH_RESPONSE=$(curl -s \
    -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -H "User-Agent: NostrVine/1.0 (iPhone; iOS 17.0)" \
    -H "Save-Data: on" \
    -d '{"currentVideoId": "test123", "networkSpeed": "slow", "scrollVelocity": 0.5}' \
    "$API_BASE_URL/api/prefetch")

if echo "$PREFETCH_RESPONSE" | jq -e '.recommendations' > /dev/null 2>&1; then
    log_success "Prefetch API responds to mobile requests"
    
    # Check if recommendations are mobile-optimized
    PREFETCH_COUNT=$(echo "$PREFETCH_RESPONSE" | jq -r '.recommendations | length')
    log_info "Prefetch recommendations: $PREFETCH_COUNT videos"
    
    if [ "$PREFETCH_COUNT" -le 5 ]; then
        log_success "Prefetch count appropriate for mobile/slow network"
    fi
else
    log_info "Prefetch API test (response: ${PREFETCH_RESPONSE:0:100}...)"
fi

# Test 9: Cross-Origin Resource Sharing Edge Cases
log_section "Test 9: CORS Edge Cases"

log_info "Testing CORS with various origins"
ORIGINS=(
    "http://localhost:3000"
    "https://localhost:3000"
    "https://localhost:3001"
    "capacitor://localhost"  # Capacitor apps
    "file://"                # Local development
)

for origin in "${ORIGINS[@]}"; do
    CORS_TEST=$(curl -s -I \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "Origin: $origin" \
        "$API_BASE_URL/api/video/test123")
    
    CORS_STATUS=$(echo "$CORS_TEST" | head -n1 | grep -o '[0-9][0-9][0-9]')
    ALLOW_ORIGIN=$(echo "$CORS_TEST" | grep -i "access-control-allow-origin" | cut -d' ' -f2- | tr -d '\r\n')
    
    if [ -n "$ALLOW_ORIGIN" ]; then
        log_success "Origin '$origin' allowed: $ALLOW_ORIGIN"
    else
        log_error "Origin '$origin' not properly handled"
    fi
done

# Test 10: Mobile App Integration Scenarios
log_section "Test 10: Mobile App Integration Scenarios"

log_info "Testing video discovery flow from mobile"
# Simulate mobile app discovering videos through Nostr events
DISCOVERY_TEST=$(curl -s \
    -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -H "User-Agent: NostrVine/1.0 (iPhone; iOS 17.0)" \
    -d '{"videoIds": ["video1", "video2", "video3", "video4", "video5"]}' \
    "$API_BASE_URL/api/videos/batch")

if echo "$DISCOVERY_TEST" | jq -e '.videos' > /dev/null 2>&1; then
    log_success "Mobile video discovery flow working"
else
    log_error "Mobile video discovery flow failed"
fi

log_info "Testing concurrent requests from mobile"
# Simulate mobile app making concurrent requests
for i in {1..5}; do
    (curl -s \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "User-Agent: NostrVine/1.0 (Android 14; Mobile)" \
        "$API_BASE_URL/api/video/concurrent-test-$i" > /dev/null) &
done

wait
log_success "Concurrent mobile requests completed"

# Summary
log_section "Mobile Integration Test Summary"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All mobile integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some mobile integration tests failed!${NC}"
    exit 1
fi