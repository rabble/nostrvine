#!/bin/bash

# ABOUTME: Error handling tests for video API endpoints
# ABOUTME: Tests authentication, rate limiting, validation, and error responses

set -e

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8787}"
TEST_API_KEY="${TEST_API_KEY:-test-key-123}"
INVALID_API_KEY="invalid-key-123"

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

# Test HTTP status code
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

# Test error response structure
check_error_response() {
    local response="$1"
    local test_name="$2"
    
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        local error_code=$(echo "$response" | jq -r '.error.code // empty')
        local error_message=$(echo "$response" | jq -r '.error.message // empty')
        
        if [ -n "$error_code" ] && [ -n "$error_message" ]; then
            log_success "$test_name has proper error structure (code: $error_code)"
        else
            log_error "$test_name missing error code or message"
        fi
    else
        log_error "$test_name does not have proper error structure"
    fi
}

# Main test execution
echo "=== Error Handling Tests for Video API ==="
echo "API Base URL: $API_BASE_URL"
echo "================================================"

# Test 1: Missing Authorization
log_section "Test 1: Missing Authorization Headers"

log_info "Testing single video endpoint without authorization"
RESPONSE=$(curl -s -w "\n%{http_code}" "$API_BASE_URL/api/video/test123")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

check_status 401 "$HTTP_CODE" "Single video without auth"
if [ "$HTTP_CODE" -eq 401 ]; then
    check_error_response "$BODY" "Single video unauthorized response"
fi

log_info "Testing batch endpoint without authorization"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"videoIds": ["test123"]}' \
    "$API_BASE_URL/api/videos/batch")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

check_status 401 "$HTTP_CODE" "Batch video without auth"

# Test 2: Invalid API Key
log_section "Test 2: Invalid API Keys"

log_info "Testing with invalid API key"
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $INVALID_API_KEY" \
    "$API_BASE_URL/api/video/test123")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

# API might return 401 or 403 for invalid keys
if [ "$HTTP_CODE" -eq 401 ] || [ "$HTTP_CODE" -eq 403 ]; then
    log_success "Invalid API key rejected (HTTP $HTTP_CODE)"
    check_error_response "$BODY" "Invalid API key response"
else
    log_error "Invalid API key not properly rejected (HTTP $HTTP_CODE)"
fi

# Test 3: Invalid Video IDs
log_section "Test 3: Invalid Video ID Formats"

log_info "Testing with invalid video ID format"
INVALID_IDS=("short" "invalid-chars!" "too-long-video-id-that-exceeds-normal-length-requirements-by-a-lot" "")

for invalid_id in "${INVALID_IDS[@]}"; do
    if [ -z "$invalid_id" ]; then
        invalid_id="empty"
        url="$API_BASE_URL/api/video/"
    else
        url="$API_BASE_URL/api/video/$invalid_id"
    fi
    
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$url")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" -eq 400 ] || [ "$HTTP_CODE" -eq 404 ]; then
        log_success "Invalid video ID '$invalid_id' rejected (HTTP $HTTP_CODE)"
    else
        log_error "Invalid video ID '$invalid_id' not properly handled (HTTP $HTTP_CODE)"
    fi
done

# Test 4: Batch API Validation Errors
log_section "Test 4: Batch API Validation"

log_info "Testing empty batch request"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"videoIds": []}' \
    "$API_BASE_URL/api/videos/batch")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

check_status 400 "$HTTP_CODE" "Empty batch request"
if [ "$HTTP_CODE" -eq 400 ]; then
    check_error_response "$BODY" "Empty batch error response"
fi

log_info "Testing oversized batch request (100 videos)"
# Generate 100 video IDs
VIDEO_IDS=$(seq 1 100 | xargs -I {} printf '"%064d",' {} | sed 's/,$//')

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"videoIds\": [$VIDEO_IDS]}" \
    "$API_BASE_URL/api/videos/batch")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

check_status 400 "$HTTP_CODE" "Oversized batch request"
if [ "$HTTP_CODE" -eq 400 ]; then
    check_error_response "$BODY" "Oversized batch error response"
fi

log_info "Testing invalid JSON in batch request"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"videoIds": [invalid json}' \
    "$API_BASE_URL/api/videos/batch")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

check_status 400 "$HTTP_CODE" "Invalid JSON in batch request"

log_info "Testing missing Content-Type header"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -d '{"videoIds": ["test123"]}' \
    "$API_BASE_URL/api/videos/batch")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

check_status 400 "$HTTP_CODE" "Missing Content-Type header"

# Test 5: Upload Request Endpoint Errors (if available)
log_section "Test 5: Upload Request Endpoint Validation"

log_info "Testing upload request without NIP-98 auth"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"fileName": "test.mp4", "fileSize": 1024}' \
    "$API_BASE_URL/v1/media/request-upload")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

check_status 401 "$HTTP_CODE" "Upload request without auth"
if [ "$HTTP_CODE" -eq 401 ]; then
    check_error_response "$BODY" "Upload auth error response"
fi

log_info "Testing upload request with invalid auth scheme"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer invalid-token" \
    -d '{"fileName": "test.mp4", "fileSize": 1024}' \
    "$API_BASE_URL/v1/media/request-upload")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

check_status 401 "$HTTP_CODE" "Upload request with invalid auth scheme"

log_info "Testing upload request without fileName"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Nostr invalid-base64" \
    -d '{"fileSize": 1024}' \
    "$API_BASE_URL/v1/media/request-upload")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 400 ] || [ "$HTTP_CODE" -eq 401 ]; then
    log_success "Upload request validation working (HTTP $HTTP_CODE)"
else
    log_error "Upload request validation not working (HTTP $HTTP_CODE)"
fi

# Test 6: Method Not Allowed
log_section "Test 6: Method Not Allowed"

log_info "Testing unsupported HTTP methods"
METHODS=("PUT" "DELETE" "PATCH")

for method in "${METHODS[@]}"; do
    RESPONSE=$(curl -s -w "\n%{http_code}" -X "$method" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/video/test123")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" -eq 405 ] || [ "$HTTP_CODE" -eq 404 ]; then
        log_success "$method method properly rejected (HTTP $HTTP_CODE)"
    else
        log_error "$method method not properly rejected (HTTP $HTTP_CODE)"
    fi
done

# Test 7: Content Type Validation
log_section "Test 7: Content Type Validation"

log_info "Testing batch endpoint with wrong content type"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: text/plain" \
    -d '{"videoIds": ["test123"]}' \
    "$API_BASE_URL/api/videos/batch")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

check_status 400 "$HTTP_CODE" "Wrong content type rejection"

# Test 8: Rate Limiting (if implemented)
log_section "Test 8: Rate Limiting"

log_info "Testing potential rate limiting"
RATE_LIMIT_DETECTED=false
CONSECUTIVE_REQUESTS=50

for i in $(seq 1 $CONSECUTIVE_REQUESTS); do
    RESPONSE=$(curl -s -w "%{http_code}" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/video/rate-test-$i" \
        -o /dev/null)
    
    if [ "$RESPONSE" -eq 429 ]; then
        RATE_LIMIT_DETECTED=true
        log_success "Rate limiting detected at request $i (HTTP 429)"
        break
    fi
    
    # Brief pause to avoid overwhelming
    sleep 0.01
done

if [ "$RATE_LIMIT_DETECTED" = false ]; then
    log_info "No rate limiting detected in $CONSECUTIVE_REQUESTS requests"
fi

# Test 9: Malformed Requests
log_section "Test 9: Malformed Requests"

log_info "Testing requests with no body"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    "$API_BASE_URL/api/videos/batch")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

check_status 400 "$HTTP_CODE" "POST request with no body"

log_info "Testing extremely large request body"
LARGE_BODY=$(printf '{"videoIds": [%s]}' "$(seq 1 10000 | xargs -I {} printf '"id%d",' {} | sed 's/,$//')")

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$LARGE_BODY" \
    "$API_BASE_URL/api/videos/batch" \
    --max-time 10)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 400 ] || [ "$HTTP_CODE" -eq 413 ] || [ "$HTTP_CODE" -eq 000 ]; then
    log_success "Large request body properly rejected (HTTP $HTTP_CODE)"
else
    log_error "Large request body not properly handled (HTTP $HTTP_CODE)"
fi

# Test 10: CORS Preflight Errors
log_section "Test 10: CORS Error Handling"

log_info "Testing CORS preflight for unsupported methods"
RESPONSE=$(curl -s -w "\n%{http_code}" -X OPTIONS \
    -H "Origin: http://localhost:3000" \
    -H "Access-Control-Request-Method: DELETE" \
    "$API_BASE_URL/api/video/test123")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

# CORS preflight should either be allowed (200) or forbidden
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 403 ] || [ "$HTTP_CODE" -eq 405 ]; then
    log_success "CORS preflight handled properly (HTTP $HTTP_CODE)"
else
    log_error "CORS preflight not handled properly (HTTP $HTTP_CODE)"
fi

# Summary
log_section "Error Handling Test Summary"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All error handling tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some error handling tests failed!${NC}"
    exit 1
fi