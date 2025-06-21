#!/bin/bash

# ABOUTME: Master test runner for all E2E tests
# ABOUTME: Orchestrates execution of all test suites and generates comprehensive report

set -e

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8787}"
TEST_API_KEY="${TEST_API_KEY:-test-key-123}"
SKIP_LOAD_TESTS="${SKIP_LOAD_TESTS:-false}"
RESULTS_DIR="${RESULTS_DIR:-/tmp/video-api-e2e-$(date +%Y%m%d-%H%M%S)}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SKIPPED_SUITES=0

# Create results directory
mkdir -p "$RESULTS_DIR"

# Helper functions
log_banner() {
    echo -e "\n${CYAN}================================================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}================================================================${NC}"
}

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

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Test suite runner
run_test_suite() {
    local suite_name="$1"
    local script_path="$2"
    local skip_condition="$3"
    
    ((TOTAL_SUITES++))
    
    log_section "Running $suite_name"
    
    # Check if suite should be skipped
    if [ "$skip_condition" = "true" ]; then
        log_warning "$suite_name skipped"
        ((SKIPPED_SUITES++))
        echo "SKIPPED" > "$RESULTS_DIR/${suite_name// /_}_result.txt"
        return 0
    fi
    
    # Check if script exists
    if [ ! -f "$script_path" ]; then
        log_error "$suite_name script not found: $script_path"
        ((FAILED_SUITES++))
        echo "SCRIPT_NOT_FOUND" > "$RESULTS_DIR/${suite_name// /_}_result.txt"
        return 1
    fi
    
    # Run the test suite
    local start_time=$(date +%s)
    
    if API_BASE_URL="$API_BASE_URL" TEST_API_KEY="$TEST_API_KEY" \
       "$script_path" > "$RESULTS_DIR/${suite_name// /_}_output.log" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "$suite_name passed (${duration}s)"
        ((PASSED_SUITES++))
        echo "PASSED:${duration}s" > "$RESULTS_DIR/${suite_name// /_}_result.txt"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_error "$suite_name failed (${duration}s)"
        ((FAILED_SUITES++))
        echo "FAILED:${duration}s" > "$RESULTS_DIR/${suite_name// /_}_result.txt"
        
        # Show last few lines of error output
        echo -e "${RED}Last 10 lines of output:${NC}"
        tail -n 10 "$RESULTS_DIR/${suite_name// /_}_output.log" | sed 's/^/  /'
        
        return 1
    fi
}

# Health check function
check_api_health() {
    log_section "API Health Check"
    
    local health_url="$API_BASE_URL/health"
    log_info "Checking API health at: $health_url"
    
    local response=$(curl -s -w "%{http_code}" "$health_url" -o /dev/null)
    
    if [ "$response" = "200" ]; then
        log_success "API is healthy (HTTP 200)"
        return 0
    else
        log_error "API health check failed (HTTP $response)"
        log_error "Please ensure the API is running at $API_BASE_URL"
        return 1
    fi
}

# Pre-test validation
validate_environment() {
    log_section "Environment Validation"
    
    # Check required tools
    local missing_tools=()
    
    if ! command -v curl > /dev/null 2>&1; then
        missing_tools+=("curl")
    fi
    
    if ! command -v jq > /dev/null 2>&1; then
        missing_tools+=("jq")
    fi
    
    if ! command -v bc > /dev/null 2>&1; then
        missing_tools+=("bc")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install missing tools and try again"
        return 1
    fi
    
    log_success "All required tools available"
    
    # Validate API URL format
    if [[ ! "$API_BASE_URL" =~ ^https?:// ]]; then
        log_error "Invalid API_BASE_URL format: $API_BASE_URL"
        return 1
    fi
    
    log_success "API URL format valid: $API_BASE_URL"
    
    # Check test API key
    if [ -z "$TEST_API_KEY" ]; then
        log_warning "TEST_API_KEY not set, using default"
    else
        log_success "TEST_API_KEY configured"
    fi
    
    return 0
}

# Generate comprehensive report
generate_report() {
    log_section "Generating Test Report"
    
    local report_file="$RESULTS_DIR/comprehensive-report.html"
    local summary_file="$RESULTS_DIR/test-summary.txt"
    
    # Create text summary
    cat > "$summary_file" << EOF
Video API E2E Test Report
========================

Test Execution Details:
- Date: $(date)
- API Base URL: $API_BASE_URL
- Results Directory: $RESULTS_DIR

Test Suite Summary:
- Total Suites: $TOTAL_SUITES
- Passed: $PASSED_SUITES
- Failed: $FAILED_SUITES
- Skipped: $SKIPPED_SUITES

Individual Suite Results:
EOF
    
    # Add individual results
    for result_file in "$RESULTS_DIR"/*_result.txt; do
        if [ -f "$result_file" ]; then
            local suite_name=$(basename "$result_file" _result.txt | tr '_' ' ')
            local result=$(cat "$result_file")
            echo "- $suite_name: $result" >> "$summary_file"
        fi
    done
    
    # Create HTML report
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Video API E2E Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .suite { margin: 15px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .passed { border-left: 5px solid #4CAF50; }
        .failed { border-left: 5px solid #f44336; }
        .skipped { border-left: 5px solid #ff9800; }
        .details { margin-top: 10px; font-size: 0.9em; color: #666; }
        .log-link { color: #2196F3; text-decoration: none; }
        .metrics { background: #f9f9f9; padding: 10px; border-radius: 3px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Video API E2E Test Report</h1>
        <p><strong>Date:</strong> $(date)</p>
        <p><strong>API Base URL:</strong> $API_BASE_URL</p>
        <p><strong>Results Directory:</strong> $RESULTS_DIR</p>
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <div class="metrics">
            <p><strong>Total Suites:</strong> $TOTAL_SUITES</p>
            <p><strong>Passed:</strong> <span style="color: #4CAF50;">$PASSED_SUITES</span></p>
            <p><strong>Failed:</strong> <span style="color: #f44336;">$FAILED_SUITES</span></p>
            <p><strong>Skipped:</strong> <span style="color: #ff9800;">$SKIPPED_SUITES</span></p>
        </div>
    </div>
    
    <div class="suites">
        <h2>Test Suite Details</h2>
EOF
    
    # Add suite details to HTML
    for result_file in "$RESULTS_DIR"/*_result.txt; do
        if [ -f "$result_file" ]; then
            local suite_name=$(basename "$result_file" _result.txt | tr '_' ' ')
            local result=$(cat "$result_file")
            local status=$(echo "$result" | cut -d: -f1)
            local duration=$(echo "$result" | cut -d: -f2 2>/dev/null || echo "")
            local log_file="${result_file%_result.txt}_output.log"
            
            local css_class="skipped"
            if [ "$status" = "PASSED" ]; then
                css_class="passed"
            elif [ "$status" = "FAILED" ]; then
                css_class="failed"
            fi
            
            cat >> "$report_file" << EOF
        <div class="suite $css_class">
            <h3>$suite_name</h3>
            <p><strong>Status:</strong> $status</p>
            $(if [ -n "$duration" ]; then echo "<p><strong>Duration:</strong> $duration</p>"; fi)
            <div class="details">
                $(if [ -f "$log_file" ]; then echo "<a href=\"file://$log_file\" class=\"log-link\">View detailed log</a>"; fi)
            </div>
        </div>
EOF
        fi
    done
    
    cat >> "$report_file" << EOF
    </div>
</body>
</html>
EOF
    
    log_success "Test report generated:"
    echo "  Text summary: $summary_file"
    echo "  HTML report: $report_file"
    
    # Display summary
    echo -e "\n${CYAN}Test Summary:${NC}"
    cat "$summary_file"
}

# Main execution
log_banner "Video API End-to-End Test Suite"

echo "Configuration:"
echo "  API Base URL: $API_BASE_URL"
echo "  Test API Key: ${TEST_API_KEY:0:8}..."
echo "  Results Directory: $RESULTS_DIR"
echo "  Skip Load Tests: $SKIP_LOAD_TESTS"

# Validate environment
if ! validate_environment; then
    log_error "Environment validation failed"
    exit 1
fi

# Check API health
if ! check_api_health; then
    log_error "API health check failed - tests may not work properly"
    log_info "Continuing anyway..."
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run test suites in order
log_banner "Executing Test Suites"

# 1. Core functionality tests
run_test_suite "Nostr Video Flow" "$SCRIPT_DIR/e2e-nostr-video-flow.sh" "false"

# 2. Error handling tests
run_test_suite "Error Handling" "$SCRIPT_DIR/error-handling.sh" "false"

# 3. Cache behavior tests
run_test_suite "Cache Testing" "$SCRIPT_DIR/cache-test.sh" "false"

# 4. Mobile integration tests
run_test_suite "Mobile Integration" "$SCRIPT_DIR/mobile-integration.sh" "false"

# 5. Performance tests
run_test_suite "Performance Testing" "$SCRIPT_DIR/performance-test.sh" "false"

# 6. Load tests (optional)
run_test_suite "Load Testing" "$SCRIPT_DIR/load-test.sh" "$SKIP_LOAD_TESTS"

# 7. Webhook integration tests
run_test_suite "Webhook Integration" "$SCRIPT_DIR/webhook-integration.sh" "false"

# 8. Status polling tests
run_test_suite "Status Polling" "$SCRIPT_DIR/status-polling.sh" "false"

# Generate final report
log_banner "Test Execution Complete"
generate_report

# Final results
success_rate=0
if [ "$TOTAL_SUITES" -gt 0 ]; then
    success_rate=$(echo "scale=1; $PASSED_SUITES * 100 / $TOTAL_SUITES" | bc -l)
fi

echo -e "\n${CYAN}Final Results:${NC}"
echo "  Success Rate: $success_rate%"
echo "  Total Duration: $(( $(date +%s) - $(stat -f %B "$RESULTS_DIR" 2>/dev/null || echo 0) )) seconds"

# Exit with appropriate code
if [ "$FAILED_SUITES" -eq 0 ]; then
    log_success "All test suites completed successfully!"
    exit 0
else
    log_error "$FAILED_SUITES test suite(s) failed"
    exit 1
fi