#!/bin/bash

# ABOUTME: Performance testing script for video API with varying batch sizes
# ABOUTME: Tests response times, concurrent requests, and throughput

set -e

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8787}"
TEST_API_KEY="${TEST_API_KEY:-test-key-123}"
MAX_CONCURRENT="${MAX_CONCURRENT:-10}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
RESULTS_FILE="/tmp/video-api-perf-$(date +%s).log"

# Helper functions
log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

log_info() {
    echo -e "${YELLOW}$1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Generate test video IDs
generate_video_ids() {
    local count=$1
    local ids=""
    for i in $(seq 1 $count); do
        # Generate 64-character hex string
        id=$(printf "%064d" $i | sed 's/./a/g' | sed "s/a/$(printf '%x' $((i % 16)))/g")
        if [ $i -eq 1 ]; then
            ids="\"$id\""
        else
            ids="$ids, \"$id\""
        fi
    done
    echo "$ids"
}

# Test single request timing
time_request() {
    local url=$1
    local data=$2
    local method=${3:-GET}
    
    if [ "$method" = "POST" ]; then
        local result=$(curl -s -w "@curl-format.txt" -X POST "$url" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TEST_API_KEY" \
            -d "$data" -o /dev/null)
    else
        local result=$(curl -s -w "@curl-format.txt" -H "Authorization: Bearer $TEST_API_KEY" \
            "$url" -o /dev/null)
    fi
    
    echo "$result"
}

# Create curl format file for timing
create_curl_format() {
    cat > curl-format.txt << 'EOF'
time_namelookup:    %{time_namelookup}\n
time_connect:       %{time_connect}\n
time_appconnect:    %{time_appconnect}\n
time_pretransfer:   %{time_pretransfer}\n
time_redirect:      %{time_redirect}\n
time_starttransfer: %{time_starttransfer}\n
time_total:         %{time_total}\n
http_code:          %{http_code}\n
size_download:      %{size_download}\n
EOF
}

# Main test execution
echo "=== Performance Testing for Video API ==="
echo "API Base URL: $API_BASE_URL"
echo "Results will be logged to: $RESULTS_FILE"
echo "================================================"

# Create timing format file
create_curl_format

# Test 1: Batch API with varying sizes
log_section "Test 1: Batch API Performance with Varying Sizes"

echo "Batch Size,Response Time (ms),HTTP Code,Response Size (bytes)" > "$RESULTS_FILE"

for batch_size in 1 5 10 20 50; do
    log_info "Testing batch size: $batch_size"
    
    # Generate video IDs
    video_ids=$(generate_video_ids $batch_size)
    
    # Create request body
    request_body="{\"videoIds\": [$video_ids]}"
    
    # Measure request time
    start_time=$(date +%s%3N)
    
    response=$(curl -s -w "\n%{http_code}\n%{time_total}\n%{size_download}" \
        -X POST "$API_BASE_URL/api/videos/batch" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -d "$request_body")
    
    end_time=$(date +%s%3N)
    duration=$((end_time - start_time))
    
    # Parse response
    http_code=$(echo "$response" | tail -n3 | head -n1)
    time_total=$(echo "$response" | tail -n2 | head -n1)
    size_download=$(echo "$response" | tail -n1)
    
    # Convert time_total to milliseconds
    time_ms=$(echo "$time_total * 1000" | bc -l | cut -d. -f1)
    
    echo "$batch_size,$time_ms,$http_code,$size_download" >> "$RESULTS_FILE"
    
    if [ "$http_code" = "200" ]; then
        log_success "Batch size $batch_size: ${time_ms}ms"
    else
        log_error "Batch size $batch_size failed: HTTP $http_code"
    fi
    
    # Avoid rate limiting
    sleep 0.5
done

# Test 2: Concurrent batch requests
log_section "Test 2: Concurrent Batch Requests"

concurrent_requests=10
batch_size=5
video_ids=$(generate_video_ids $batch_size)
request_body="{\"videoIds\": [$video_ids]}"

log_info "Testing $concurrent_requests concurrent requests with batch size $batch_size"

# Create temp directory for concurrent test results
mkdir -p /tmp/concurrent-test
rm -f /tmp/concurrent-test/*

start_time=$(date +%s%3N)

# Launch concurrent requests
for i in $(seq 1 $concurrent_requests); do
    (
        response=$(curl -s -w "%{http_code},%{time_total}" \
            -X POST "$API_BASE_URL/api/videos/batch" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TEST_API_KEY" \
            -d "$request_body")
        echo "$response" > "/tmp/concurrent-test/result-$i.txt"
    ) &
done

# Wait for all requests to complete
wait

end_time=$(date +%s%3N)
total_duration=$((end_time - start_time))

# Analyze results
successful_requests=0
total_response_time=0
min_time=999999
max_time=0

for i in $(seq 1 $concurrent_requests); do
    if [ -f "/tmp/concurrent-test/result-$i.txt" ]; then
        result=$(cat "/tmp/concurrent-test/result-$i.txt")
        http_code=$(echo "$result" | tail -c 20 | cut -d',' -f1)
        response_time=$(echo "$result" | tail -c 20 | cut -d',' -f2)
        
        if [ "$http_code" = "200" ]; then
            ((successful_requests++))
            
            # Convert to milliseconds
            time_ms=$(echo "$response_time * 1000" | bc -l | cut -d. -f1)
            total_response_time=$((total_response_time + time_ms))
            
            if [ "$time_ms" -lt "$min_time" ]; then
                min_time=$time_ms
            fi
            
            if [ "$time_ms" -gt "$max_time" ]; then
                max_time=$time_ms
            fi
        fi
    fi
done

if [ "$successful_requests" -gt 0 ]; then
    avg_response_time=$((total_response_time / successful_requests))
    throughput=$(echo "scale=2; $successful_requests * 1000 / $total_duration" | bc -l)
    
    echo -e "\nConcurrent Request Results:"
    echo "  Successful requests: $successful_requests/$concurrent_requests"
    echo "  Total time: ${total_duration}ms"
    echo "  Average response time: ${avg_response_time}ms"
    echo "  Min response time: ${min_time}ms"
    echo "  Max response time: ${max_time}ms"
    echo "  Throughput: ${throughput} requests/second"
    
    # Log to results file
    echo -e "\n--- Concurrent Test Results ---" >> "$RESULTS_FILE"
    echo "Successful: $successful_requests/$concurrent_requests" >> "$RESULTS_FILE"
    echo "Avg Response Time: ${avg_response_time}ms" >> "$RESULTS_FILE"
    echo "Throughput: ${throughput} req/sec" >> "$RESULTS_FILE"
    
    if [ "$avg_response_time" -lt 500 ]; then
        log_success "Average response time under 500ms"
    else
        log_error "Average response time too high: ${avg_response_time}ms"
    fi
else
    log_error "All concurrent requests failed"
fi

# Test 3: Single video endpoint performance
log_section "Test 3: Single Video Endpoint Performance"

test_video_id="0000000000000000000000000000000000000000000000000000000000000001"
single_requests=20

log_info "Testing $single_requests requests to single video endpoint"

total_time=0
successful_count=0

for i in $(seq 1 $single_requests); do
    start=$(date +%s%3N)
    
    response=$(curl -s -w "%{http_code}" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "$API_BASE_URL/api/video/$test_video_id")
    
    end=$(date +%s%3N)
    duration=$((end - start))
    
    http_code=$(echo "$response" | tail -c 4)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
        total_time=$((total_time + duration))
        ((successful_count++))
    fi
    
    # Brief pause to avoid overwhelming the server
    sleep 0.1
done

if [ "$successful_count" -gt 0 ]; then
    avg_time=$((total_time / successful_count))
    echo "Single video endpoint average response time: ${avg_time}ms"
    
    if [ "$avg_time" -lt 200 ]; then
        log_success "Single video response time under 200ms"
    else
        log_error "Single video response time too high: ${avg_time}ms"
    fi
else
    log_error "All single video requests failed"
fi

# Test 4: Performance mode comparison
log_section "Test 4: Performance Mode Comparison"

log_info "Comparing standard vs optimized batch API"

# Test standard batch API
standard_time=$(curl -s -w "%{time_total}" \
    -X POST "$API_BASE_URL/api/videos/batch" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -d "{\"videoIds\": [$(generate_video_ids 10)]}" \
    -o /dev/null)

# Test optimized batch API
optimized_time=$(curl -s -w "%{time_total}" \
    -X POST "$API_BASE_URL/api/videos/batch?optimize=true" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TEST_API_KEY" \
    -d "{\"videoIds\": [$(generate_video_ids 10)]}" \
    -o /dev/null)

standard_ms=$(echo "$standard_time * 1000" | bc -l | cut -d. -f1)
optimized_ms=$(echo "$optimized_time * 1000" | bc -l | cut -d. -f1)

echo "Standard API: ${standard_ms}ms"
echo "Optimized API: ${optimized_ms}ms"

if [ "$optimized_ms" -lt "$standard_ms" ]; then
    improvement=$(echo "scale=1; ($standard_ms - $optimized_ms) * 100 / $standard_ms" | bc -l)
    log_success "Optimized API is ${improvement}% faster"
else
    log_error "Optimized API is not faster than standard API"
fi

# Cleanup
rm -f curl-format.txt
rm -rf /tmp/concurrent-test

# Final summary
log_section "Performance Test Summary"
echo "Detailed results saved to: $RESULTS_FILE"
echo "Review the log file for complete timing data."

if [ -f "$RESULTS_FILE" ]; then
    echo -e "\nBatch Size Performance:"
    echo "======================="
    cat "$RESULTS_FILE" | head -n6
fi

echo -e "\n${GREEN}Performance testing completed!${NC}"