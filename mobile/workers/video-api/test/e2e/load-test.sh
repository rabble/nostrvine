#!/bin/bash

# ABOUTME: Load testing script for video API using Apache Bench and curl
# ABOUTME: Tests system under high load conditions and measures performance metrics

set -e

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8787}"
TEST_API_KEY="${TEST_API_KEY:-test-key-123}"
TOTAL_REQUESTS="${TOTAL_REQUESTS:-1000}"
CONCURRENT_USERS="${CONCURRENT_USERS:-50}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Result files
RESULTS_DIR="/tmp/video-api-load-test-$(date +%s)"
mkdir -p "$RESULTS_DIR"

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

# Check if Apache Bench is available
check_ab() {
    if command -v ab > /dev/null 2>&1; then
        log_success "Apache Bench (ab) is available"
        return 0
    else
        log_error "Apache Bench (ab) not found. Install with: brew install httpd (macOS) or apt-get install apache2-utils (Ubuntu)"
        return 1
    fi
}

# Alternative load test using curl (if ab is not available)
curl_load_test() {
    local url="$1"
    local requests="$2"
    local concurrent="$3"
    local method="${4:-GET}"
    local headers="$5"
    local data="$6"
    
    log_info "Running curl-based load test: $requests requests, $concurrent concurrent"
    
    local start_time=$(date +%s)
    local success_count=0
    local error_count=0
    local total_time=0
    
    # Create temp directory for results
    local temp_dir="$RESULTS_DIR/curl-test-$$"
    mkdir -p "$temp_dir"
    
    # Launch concurrent requests
    for batch in $(seq 1 $((requests / concurrent))); do
        for i in $(seq 1 $concurrent); do
            (
                local req_start=$(date +%s%3N)
                if [ "$method" = "POST" ]; then
                    local response=$(curl -s -w "%{http_code},%{time_total}" \
                        -X POST \
                        $headers \
                        -d "$data" \
                        "$url" -o /dev/null 2>/dev/null)
                else
                    local response=$(curl -s -w "%{http_code},%{time_total}" \
                        $headers \
                        "$url" -o /dev/null 2>/dev/null)
                fi
                local req_end=$(date +%s%3N)
                
                echo "$response,$((req_end - req_start))" > "$temp_dir/result-$batch-$i.txt"
            ) &
        done
        
        # Wait for this batch to complete
        wait
        
        # Brief pause between batches
        sleep 0.1
    done
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Analyze results
    local min_time=999999
    local max_time=0
    local total_response_time=0
    
    for result_file in "$temp_dir"/result-*.txt; do
        if [ -f "$result_file" ]; then
            local line=$(cat "$result_file")
            local http_code=$(echo "$line" | cut -d',' -f1)
            local response_time=$(echo "$line" | cut -d',' -f2)
            local wall_time=$(echo "$line" | cut -d',' -f3)
            
            if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
                ((success_count++))
                
                # Convert response time to milliseconds
                local time_ms=$(echo "$response_time * 1000" | bc -l 2>/dev/null | cut -d. -f1)
                total_response_time=$((total_response_time + time_ms))
                
                if [ "$time_ms" -lt "$min_time" ]; then
                    min_time=$time_ms
                fi
                
                if [ "$time_ms" -gt "$max_time" ]; then
                    max_time=$time_ms
                fi
            else
                ((error_count++))
            fi
        fi
    done
    
    # Calculate metrics
    local total_requests=$((success_count + error_count))
    local success_rate=$(echo "scale=2; $success_count * 100 / $total_requests" | bc -l 2>/dev/null || echo "0")
    local avg_response_time=0
    local requests_per_second=0
    
    if [ "$success_count" -gt 0 ]; then
        avg_response_time=$((total_response_time / success_count))
        requests_per_second=$(echo "scale=2; $success_count / $total_duration" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Output results
    echo "Load Test Results (curl-based):"
    echo "  Total requests: $total_requests"
    echo "  Successful requests: $success_count"
    echo "  Failed requests: $error_count"
    echo "  Success rate: $success_rate%"
    echo "  Total time: ${total_duration}s"
    echo "  Requests per second: $requests_per_second"
    if [ "$success_count" -gt 0 ]; then
        echo "  Average response time: ${avg_response_time}ms"
        echo "  Min response time: ${min_time}ms"
        echo "  Max response time: ${max_time}ms"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Return success if most requests succeeded
    local success_threshold=80
    if [ "$(echo "$success_rate >= $success_threshold" | bc -l 2>/dev/null)" = "1" ]; then
        return 0
    else
        return 1
    fi
}

# Main test execution
echo "=== Load Testing for Video API ==="
echo "API Base URL: $API_BASE_URL"
echo "Total Requests: $TOTAL_REQUESTS"
echo "Concurrent Users: $CONCURRENT_USERS"
echo "Results Directory: $RESULTS_DIR"
echo "================================================"

# Test 1: Single Video Endpoint Load Test
log_section "Test 1: Single Video Endpoint Load Test"

TEST_VIDEO_ID="0000000000000000000000000000000000000000000000000000000000000001"
SINGLE_URL="$API_BASE_URL/api/video/$TEST_VIDEO_ID"

if check_ab; then
    log_info "Using Apache Bench for single video endpoint"
    
    ab -n "$TOTAL_REQUESTS" -c "$CONCURRENT_USERS" \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -g "$RESULTS_DIR/single-video-gnuplot.tsv" \
        "$SINGLE_URL" > "$RESULTS_DIR/single-video-ab.txt" 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Single video load test completed with Apache Bench"
        
        # Extract key metrics
        REQUESTS_PER_SEC=$(grep "Requests per second" "$RESULTS_DIR/single-video-ab.txt" | awk '{print $4}')
        AVG_TIME=$(grep "Time per request:" "$RESULTS_DIR/single-video-ab.txt" | head -n1 | awk '{print $4}')
        FAILED_REQUESTS=$(grep "Failed requests:" "$RESULTS_DIR/single-video-ab.txt" | awk '{print $3}')
        
        echo "  Requests per second: $REQUESTS_PER_SEC"
        echo "  Average response time: ${AVG_TIME}ms"
        echo "  Failed requests: $FAILED_REQUESTS"
        
        if [ "$(echo "$REQUESTS_PER_SEC > 100" | bc -l 2>/dev/null)" = "1" ]; then
            log_success "Single endpoint throughput acceptable (>100 req/s)"
        else
            log_error "Single endpoint throughput too low (<100 req/s)"
        fi
    else
        log_error "Apache Bench test failed"
    fi
else
    log_info "Using curl for single video endpoint load test"
    if curl_load_test "$SINGLE_URL" 100 10 "GET" "-H 'Authorization: Bearer $TEST_API_KEY'"; then
        log_success "Single video curl load test passed"
    else
        log_error "Single video curl load test failed"
    fi
fi

# Test 2: Batch Video Endpoint Load Test
log_section "Test 2: Batch Video Endpoint Load Test"

BATCH_URL="$API_BASE_URL/api/videos/batch"

# Create batch request data file
BATCH_DATA='{"videoIds": ["test1", "test2", "test3", "test4", "test5"]}'
echo "$BATCH_DATA" > "$RESULTS_DIR/batch-request.json"

if check_ab; then
    log_info "Using Apache Bench for batch video endpoint"
    
    ab -n $((TOTAL_REQUESTS / 2)) -c $((CONCURRENT_USERS / 2)) \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "Content-Type: application/json" \
        -p "$RESULTS_DIR/batch-request.json" \
        -g "$RESULTS_DIR/batch-video-gnuplot.tsv" \
        "$BATCH_URL" > "$RESULTS_DIR/batch-video-ab.txt" 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Batch video load test completed with Apache Bench"
        
        # Extract key metrics
        BATCH_RPS=$(grep "Requests per second" "$RESULTS_DIR/batch-video-ab.txt" | awk '{print $4}')
        BATCH_AVG_TIME=$(grep "Time per request:" "$RESULTS_DIR/batch-video-ab.txt" | head -n1 | awk '{print $4}')
        BATCH_FAILED=$(grep "Failed requests:" "$RESULTS_DIR/batch-video-ab.txt" | awk '{print $3}')
        
        echo "  Requests per second: $BATCH_RPS"
        echo "  Average response time: ${BATCH_AVG_TIME}ms"
        echo "  Failed requests: $BATCH_FAILED"
        
        if [ "$(echo "$BATCH_RPS > 50" | bc -l 2>/dev/null)" = "1" ]; then
            log_success "Batch endpoint throughput acceptable (>50 req/s)"
        else
            log_error "Batch endpoint throughput too low (<50 req/s)"
        fi
    else
        log_error "Batch Apache Bench test failed"
    fi
else
    log_info "Using curl for batch endpoint load test"
    if curl_load_test "$BATCH_URL" 50 5 "POST" "-H 'Authorization: Bearer $TEST_API_KEY' -H 'Content-Type: application/json'" "$BATCH_DATA"; then
        log_success "Batch video curl load test passed"
    else
        log_error "Batch video curl load test failed"
    fi
fi

# Test 3: Optimized Batch Endpoint Load Test
log_section "Test 3: Optimized Batch Endpoint Load Test"

OPTIMIZED_URL="$API_BASE_URL/api/videos/batch?optimize=true"

if check_ab; then
    log_info "Using Apache Bench for optimized batch endpoint"
    
    ab -n $((TOTAL_REQUESTS / 4)) -c $((CONCURRENT_USERS / 4)) \
        -H "Authorization: Bearer $TEST_API_KEY" \
        -H "Content-Type: application/json" \
        -H "X-Performance-Mode: optimized" \
        -p "$RESULTS_DIR/batch-request.json" \
        -g "$RESULTS_DIR/optimized-batch-gnuplot.tsv" \
        "$OPTIMIZED_URL" > "$RESULTS_DIR/optimized-batch-ab.txt" 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Optimized batch load test completed"
        
        OPT_RPS=$(grep "Requests per second" "$RESULTS_DIR/optimized-batch-ab.txt" | awk '{print $4}')
        OPT_AVG_TIME=$(grep "Time per request:" "$RESULTS_DIR/optimized-batch-ab.txt" | head -n1 | awk '{print $4}')
        
        echo "  Optimized requests per second: $OPT_RPS"
        echo "  Optimized average response time: ${OPT_AVG_TIME}ms"
        
        # Compare with standard batch if both exist
        if [ -n "$BATCH_RPS" ] && [ -n "$OPT_RPS" ]; then
            IMPROVEMENT=$(echo "scale=1; ($OPT_RPS - $BATCH_RPS) * 100 / $BATCH_RPS" | bc -l 2>/dev/null || echo "0")
            if [ "$(echo "$IMPROVEMENT > 0" | bc -l 2>/dev/null)" = "1" ]; then
                log_success "Optimized API is ${IMPROVEMENT}% faster"
            else
                log_info "Optimized API performance: ${IMPROVEMENT}% difference"
            fi
        fi
    else
        log_error "Optimized batch Apache Bench test failed"
    fi
fi

# Test 4: Mixed Load Test (different endpoints)
log_section "Test 4: Mixed Load Test"

log_info "Testing mixed load across different endpoints"

# Create mixed load test
MIXED_REQUESTS=200
MIXED_CONCURRENT=20

log_info "Launching mixed load test with $MIXED_REQUESTS requests across multiple endpoints"

# Split requests across endpoints
SINGLE_REQS=$((MIXED_REQUESTS / 3))
BATCH_REQS=$((MIXED_REQUESTS / 3))
HEALTH_REQS=$((MIXED_REQUESTS - SINGLE_REQS - BATCH_REQS))

(
    for i in $(seq 1 $SINGLE_REQS); do
        curl -s -H "Authorization: Bearer $TEST_API_KEY" \
            "$API_BASE_URL/api/video/mixed-test-$i" > /dev/null &
        
        if [ $((i % MIXED_CONCURRENT)) -eq 0 ]; then
            wait
        fi
    done
) &

(
    for i in $(seq 1 $BATCH_REQS); do
        curl -s -X POST \
            -H "Authorization: Bearer $TEST_API_KEY" \
            -H "Content-Type: application/json" \
            -d '{"videoIds": ["mixed1", "mixed2"]}' \
            "$API_BASE_URL/api/videos/batch" > /dev/null &
        
        if [ $((i % (MIXED_CONCURRENT / 2))) -eq 0 ]; then
            wait
        fi
    done
) &

(
    for i in $(seq 1 $HEALTH_REQS); do
        curl -s "$API_BASE_URL/health" > /dev/null &
        
        if [ $((i % MIXED_CONCURRENT)) -eq 0 ]; then
            wait
        fi
    done
) &

# Wait for all background jobs to complete
wait

log_success "Mixed load test completed"

# Test 5: Stress Test (gradual load increase)
log_section "Test 5: Stress Test"

log_info "Running stress test with gradual load increase"

for concurrent in 10 25 50 75 100; do
    log_info "Testing with $concurrent concurrent requests"
    
    if check_ab; then
        # Quick stress test with ab
        ab -n $((concurrent * 5)) -c "$concurrent" \
            -H "Authorization: Bearer $TEST_API_KEY" \
            "$API_BASE_URL/health" > "$RESULTS_DIR/stress-$concurrent.txt" 2>&1
        
        if [ $? -eq 0 ]; then
            STRESS_RPS=$(grep "Requests per second" "$RESULTS_DIR/stress-$concurrent.txt" | awk '{print $4}')
            STRESS_FAILED=$(grep "Failed requests:" "$RESULTS_DIR/stress-$concurrent.txt" | awk '{print $3}')
            
            if [ "$STRESS_FAILED" = "0" ]; then
                log_success "Stress level $concurrent: ${STRESS_RPS} req/s, 0 failures"
            else
                log_error "Stress level $concurrent: ${STRESS_FAILED} failures detected"
                break
            fi
        else
            log_error "Stress test failed at concurrency level $concurrent"
            break
        fi
    else
        # Quick curl-based stress test
        local start_time=$(date +%s)
        local failed=0
        
        for i in $(seq 1 "$concurrent"); do
            (curl -s -H "Authorization: Bearer $TEST_API_KEY" \
                "$API_BASE_URL/health" > /dev/null || ((failed++))) &
        done
        
        wait
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ "$failed" -eq 0 ]; then
            local rps=$(echo "scale=2; $concurrent / $duration" | bc -l 2>/dev/null || echo "0")
            log_success "Stress level $concurrent: ${rps} req/s, 0 failures"
        else
            log_error "Stress level $concurrent: $failed failures"
            break
        fi
    fi
    
    # Brief pause between stress levels
    sleep 2
done

# Generate summary report
log_section "Load Test Summary Report"

echo "Load Test Results Summary" > "$RESULTS_DIR/summary.txt"
echo "=========================" >> "$RESULTS_DIR/summary.txt"
echo "Test Date: $(date)" >> "$RESULTS_DIR/summary.txt"
echo "API Base URL: $API_BASE_URL" >> "$RESULTS_DIR/summary.txt"
echo "Total Requests: $TOTAL_REQUESTS" >> "$RESULTS_DIR/summary.txt"
echo "Concurrent Users: $CONCURRENT_USERS" >> "$RESULTS_DIR/summary.txt"
echo "" >> "$RESULTS_DIR/summary.txt"

# Add ab results if available
if [ -f "$RESULTS_DIR/single-video-ab.txt" ]; then
    echo "Single Video Endpoint:" >> "$RESULTS_DIR/summary.txt"
    grep -E "(Requests per second|Time per request|Failed requests)" "$RESULTS_DIR/single-video-ab.txt" >> "$RESULTS_DIR/summary.txt"
    echo "" >> "$RESULTS_DIR/summary.txt"
fi

if [ -f "$RESULTS_DIR/batch-video-ab.txt" ]; then
    echo "Batch Video Endpoint:" >> "$RESULTS_DIR/summary.txt"
    grep -E "(Requests per second|Time per request|Failed requests)" "$RESULTS_DIR/batch-video-ab.txt" >> "$RESULTS_DIR/summary.txt"
    echo "" >> "$RESULTS_DIR/summary.txt"
fi

echo "Detailed results available in: $RESULTS_DIR"
cat "$RESULTS_DIR/summary.txt"

log_success "Load testing completed! Results saved to $RESULTS_DIR"