#!/bin/bash
# ABOUTME: Load testing script using Apache Bench for NostrVine API
# ABOUTME: Tests API endpoints under various load scenarios

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8787}"
TEST_API_KEY="${TEST_API_KEY:-test-key-123}"
REPORT_DIR="./load-test-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Check if ab is installed
if ! command -v ab &> /dev/null; then
    echo -e "${RED}Apache Bench (ab) is not installed.${NC}"
    echo "Install it with:"
    echo "  macOS: brew install apache-bench"
    echo "  Ubuntu: sudo apt-get install apache2-utils"
    echo "  CentOS: sudo yum install httpd-tools"
    exit 1
fi

# Create report directory
mkdir -p "$REPORT_DIR"

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to run ab test and save results
run_ab_test() {
    local test_name=$1
    local url=$2
    local requests=$3
    local concurrency=$4
    local extra_args=$5
    
    log "Running test: $test_name"
    log "URL: $url"
    log "Requests: $requests, Concurrency: $concurrency"
    
    local output_file="$REPORT_DIR/${TIMESTAMP}_${test_name// /_}.txt"
    
    # Run Apache Bench
    ab -n "$requests" \
       -c "$concurrency" \
       -H "Authorization: Bearer $TEST_API_KEY" \
       -H "Accept: application/json" \
       -g "$REPORT_DIR/${TIMESTAMP}_${test_name// /_}.tsv" \
       $extra_args \
       "$url" > "$output_file" 2>&1
    
    if [ $? -eq 0 ]; then
        # Extract key metrics
        local rps=$(grep "Requests per second" "$output_file" | awk '{print $4}')
        local avg_time=$(grep "Time per request" "$output_file" | head -n1 | awk '{print $4}')
        local p50=$(grep "50%" "$output_file" | awk '{print $2}')
        local p95=$(grep "95%" "$output_file" | awk '{print $2}')
        local p99=$(grep "99%" "$output_file" | awk '{print $2}')
        local failed=$(grep "Failed requests" "$output_file" | awk '{print $3}')
        
        success "$test_name completed"
        echo "  ├─ RPS: ${rps} req/s"
        echo "  ├─ Avg Response: ${avg_time}ms"
        echo "  ├─ P50: ${p50}ms"
        echo "  ├─ P95: ${p95}ms"
        echo "  ├─ P99: ${p99}ms"
        echo "  └─ Failed: ${failed}"
    else
        error "$test_name failed"
    fi
    
    echo ""
}

# Function to create POST data file for batch API
create_batch_data() {
    local count=$1
    local file="$REPORT_DIR/batch_${count}.json"
    
    # Generate video IDs
    local video_ids=()
    for i in $(seq 1 $count); do
        video_ids+=("\"$(openssl rand -hex 32)\"")
    done
    
    echo "{\"videoIds\":[$(IFS=,; echo "${video_ids[*]}")],\"quality\":\"720p\"}" > "$file"
    echo "$file"
}

# Main execution
main() {
    echo "================================================"
    echo " NostrVine Load Testing Suite"
    echo " API URL: $API_BASE_URL"
    echo " Timestamp: $TIMESTAMP"
    echo "================================================"
    echo
    
    # Test 1: Light load - Single video endpoint
    run_ab_test "Light Load - Single Video" \
        "${API_BASE_URL}/api/video/$(openssl rand -hex 32)" \
        100 \
        10 \
        ""
    
    # Test 2: Medium load - Single video endpoint
    run_ab_test "Medium Load - Single Video" \
        "${API_BASE_URL}/api/video/$(openssl rand -hex 32)" \
        1000 \
        50 \
        ""
    
    # Test 3: Heavy load - Single video endpoint
    run_ab_test "Heavy Load - Single Video" \
        "${API_BASE_URL}/api/video/$(openssl rand -hex 32)" \
        5000 \
        100 \
        ""
    
    # Test 4: Batch API - Small batches
    local batch_small=$(create_batch_data 10)
    run_ab_test "Batch API - 10 Videos" \
        "${API_BASE_URL}/api/videos/batch" \
        500 \
        25 \
        "-p $batch_small -T application/json"
    
    # Test 5: Batch API - Large batches
    local batch_large=$(create_batch_data 50)
    run_ab_test "Batch API - 50 Videos" \
        "${API_BASE_URL}/api/videos/batch" \
        200 \
        10 \
        "-p $batch_large -T application/json"
    
    # Test 6: Analytics endpoint
    run_ab_test "Analytics - Popular Videos" \
        "${API_BASE_URL}/api/analytics/popular?window=24h" \
        500 \
        20 \
        ""
    
    # Test 7: Spike test - Sudden load increase
    log "Running spike test..."
    for i in {1..5}; do
        log "Spike $i/5"
        ab -n 200 -c 50 \
           -H "Authorization: Bearer $TEST_API_KEY" \
           "${API_BASE_URL}/api/video/$(openssl rand -hex 32)" \
           > /dev/null 2>&1 &
    done
    wait
    success "Spike test completed"
    echo
    
    # Test 8: Sustained load test
    log "Running sustained load test (60 seconds)..."
    local sustained_output="$REPORT_DIR/${TIMESTAMP}_sustained_load.txt"
    
    timeout 60 ab -t 60 -c 50 \
        -H "Authorization: Bearer $TEST_API_KEY" \
        "${API_BASE_URL}/api/video/$(openssl rand -hex 32)" \
        > "$sustained_output" 2>&1 || true
    
    if [ -f "$sustained_output" ]; then
        local total_requests=$(grep "Complete requests" "$sustained_output" | awk '{print $3}')
        local rps=$(grep "Requests per second" "$sustained_output" | awk '{print $4}')
        success "Sustained load test completed"
        echo "  ├─ Total requests in 60s: $total_requests"
        echo "  └─ Average RPS: $rps"
    fi
    echo
    
    # Generate summary report
    generate_summary_report
}

generate_summary_report() {
    local summary_file="$REPORT_DIR/${TIMESTAMP}_summary.md"
    
    cat > "$summary_file" << EOF
# NostrVine Load Test Summary

**Date**: $(date)
**API URL**: $API_BASE_URL

## Test Results

EOF
    
    # Parse all test results
    for file in "$REPORT_DIR/${TIMESTAMP}_"*.txt; do
        if [ -f "$file" ]; then
            local test_name=$(basename "$file" .txt | sed "s/${TIMESTAMP}_//g" | sed 's/_/ /g')
            local rps=$(grep "Requests per second" "$file" 2>/dev/null | awk '{print $4}' || echo "N/A")
            local avg_time=$(grep "Time per request" "$file" 2>/dev/null | head -n1 | awk '{print $4}' || echo "N/A")
            local failed=$(grep "Failed requests" "$file" 2>/dev/null | awk '{print $3}' || echo "0")
            
            cat >> "$summary_file" << EOF
### $test_name
- **Requests per second**: $rps
- **Average response time**: ${avg_time}ms
- **Failed requests**: $failed

EOF
        fi
    done
    
    cat >> "$summary_file" << EOF

## Recommendations

Based on the load test results:

1. **Capacity Planning**: The API can handle approximately $(find "$REPORT_DIR/${TIMESTAMP}_"*.txt -exec grep "Requests per second" {} \; 2>/dev/null | awk '{sum+=$4; count++} END {if(count>0) print int(sum/count); else print "N/A"}') requests per second on average.

2. **Performance Optimization**: Focus on endpoints with response times above 200ms.

3. **Scaling Strategy**: Consider horizontal scaling when sustained load exceeds current capacity.

4. **Monitoring**: Set up alerts for response times exceeding P95 values observed in tests.

## Raw Data

All detailed test results are available in:
\`$REPORT_DIR/${TIMESTAMP}_*.txt\`

EOF
    
    success "Summary report generated: $summary_file"
    echo
    cat "$summary_file"
}

# Cleanup function
cleanup() {
    # Remove temporary JSON files
    rm -f "$REPORT_DIR"/batch_*.json
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"