# End-to-End Test Suite for NostrVine Video API

This directory contains a comprehensive end-to-end testing suite for the NostrVine video API that validates the complete flow from Nostr event discovery to video playback.

## Test Suites

### 1. Nostr Video Flow (`e2e-nostr-video-flow.sh`)
Tests the complete journey from video discovery to streaming:
- Simulates Nostr events with video content
- Tests batch video metadata lookup
- Validates single video endpoint responses
- Verifies signed URL accessibility
- Checks CORS headers

### 2. Performance Testing (`performance-test.sh`)
Measures API performance under various conditions:
- Batch API with varying sizes (1, 5, 10, 20, 50 videos)
- Concurrent request handling
- Single video endpoint performance
- Performance mode comparison (standard vs optimized)

### 3. Cache Testing (`cache-test.sh`)
Validates caching behavior and performance:
- Cache header verification
- Cache miss vs hit performance
- ETag conditional requests
- Quality parameter cache behavior
- Cache consistency across endpoints

### 4. Error Handling (`error-handling.sh`)
Tests comprehensive error scenarios:
- Missing/invalid authorization
- Invalid video ID formats
- Batch validation errors
- Rate limiting behavior
- Malformed requests
- CORS error handling

### 5. Mobile Integration (`mobile-integration.sh`)
Tests mobile app compatibility:
- CORS preflight and actual requests
- Mobile user agent support
- Network hint headers (Save-Data, etc.)
- Mobile batch request optimization
- Performance monitoring headers

### 6. Load Testing (`load-test.sh`)
Tests system under high load:
- Single video endpoint load testing
- Batch endpoint load testing
- Mixed load across multiple endpoints
- Stress testing with gradual load increase
- Uses Apache Bench (ab) when available, falls back to curl

## Quick Start

### Prerequisites
```bash
# Required tools
curl
jq
bc

# Optional (for better load testing)
apache2-utils  # for Apache Bench (ab)
```

### Running All Tests
```bash
# Run all test suites
./run-all-tests.sh

# Run with custom API URL
API_BASE_URL="https://your-api.com" ./run-all-tests.sh

# Skip load tests (faster execution)
SKIP_LOAD_TESTS=true ./run-all-tests.sh
```

### Running Individual Test Suites
```bash
# Core functionality
./e2e-nostr-video-flow.sh

# Performance testing
./performance-test.sh

# Cache behavior
./cache-test.sh

# Error handling
./error-handling.sh

# Mobile integration
./mobile-integration.sh

# Load testing
./load-test.sh
```

## Configuration

### Environment Variables
- `API_BASE_URL`: Base URL of the API (default: `http://localhost:8787`)
- `TEST_API_KEY`: API key for authentication (default: `test-key-123`)
- `SKIP_LOAD_TESTS`: Skip load tests for faster execution (default: `false`)
- `TOTAL_REQUESTS`: Number of requests for load testing (default: `1000`)
- `CONCURRENT_USERS`: Concurrent users for load testing (default: `50`)

### Example Configuration
```bash
export API_BASE_URL="https://api.openvine.co"
export TEST_API_KEY="your-actual-api-key"
export SKIP_LOAD_TESTS=false
./run-all-tests.sh
```

## Test Data Setup

For comprehensive testing, ensure your API has test data:

```bash
# Upload test video metadata (if scripts exist)
cd ../scripts
./upload-test-data.sh

# Or manually ensure these test video IDs exist:
# - 0000000000000000000000000000000000000000000000000000000000000001
# - 0000000000000000000000000000000000000000000000000000000000000002
# - 0000000000000000000000000000000000000000000000000000000000000003
```

## Test Results

### Output Locations
- **Console**: Real-time test progress and summary
- **Log Files**: Detailed output for each test suite in `/tmp/video-api-e2e-*`
- **HTML Report**: Comprehensive test report with visual status indicators
- **Text Summary**: Machine-readable test results

### Understanding Results
- ✓ **Green**: Test passed
- ✗ **Red**: Test failed
- ⚠ **Yellow**: Test skipped or warning

### Success Criteria
- **Response Times**: < 200ms for single video, < 500ms for batch
- **Cache Performance**: Cache hits should be faster than misses
- **Error Handling**: All error scenarios return proper HTTP status codes
- **CORS**: All mobile origins properly supported
- **Load Performance**: > 100 req/s for single video, > 50 req/s for batch

## CI/CD Integration

### GitHub Actions Example
```yaml
name: E2E Tests
on: [push, pull_request]
jobs:
  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y apache2-utils jq bc
      - name: Start API server
        run: |
          cd workers/video-api
          npm install
          wrangler dev &
          sleep 10
      - name: Run E2E tests
        run: |
          cd workers/video-api/test/e2e
          ./run-all-tests.sh
```

## Troubleshooting

### Common Issues

**API Not Responding**
```bash
# Check if API is running
curl http://localhost:8787/health

# Check Wrangler dev server
cd ../../
wrangler dev
```

**Missing Dependencies**
```bash
# macOS
brew install jq apache2-utils

# Ubuntu/Debian
sudo apt-get install jq apache2-utils bc

# Check installation
which curl jq bc ab
```

**Permission Denied**
```bash
# Make scripts executable
chmod +x *.sh
```

**Test Failures**
```bash
# Check detailed logs
cat /tmp/video-api-e2e-*/Error_Handling_output.log

# Run individual test for debugging
./error-handling.sh
```

### Performance Tuning

For better load test results:
- Install Apache Bench (`ab`) for more accurate load testing
- Run tests against production-like environment
- Ensure sufficient system resources
- Use dedicated test environment

## Test Architecture

### Design Principles
- **Comprehensive Coverage**: Tests all API endpoints and scenarios
- **Real-world Simulation**: Mimics actual mobile app usage patterns
- **Performance Focused**: Validates response times and throughput
- **Error Resilient**: Thoroughly tests error conditions
- **Mobile Optimized**: Ensures mobile app compatibility

### Test Dependencies
Tests are designed to be independent and can run in any order. However, some tests may perform better if test data is pre-loaded.

## Contributing

When adding new tests:
1. Follow existing naming conventions
2. Include comprehensive error handling
3. Add appropriate logging and success/failure reporting
4. Update this README with new test descriptions
5. Ensure tests are idempotent and don't affect other tests

## Security Notes

- Test API keys should be different from production keys
- Tests should not expose sensitive data in logs
- Load tests should not overwhelm production systems
- Rate limiting tests should be carefully controlled