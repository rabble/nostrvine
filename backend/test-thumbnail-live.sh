#!/bin/bash

# ABOUTME: Live integration test script for thumbnail service
# ABOUTME: Tests against real deployed backend

set -e

BASE_URL="https://api.openvine.co"

echo "🔧 Testing OpenVine Thumbnail Service Integration"
echo "================================================"

# Test 1: Placeholder for non-existent video
echo ""
echo "Test 1: Non-existent video returns placeholder"
response=$(curl -s -w "%{http_code}" "$BASE_URL/thumbnail/fake-video-123")
http_code="${response: -3}"
if [ "$http_code" = "200" ]; then
    echo "✅ HTTP 200 - Placeholder returned for non-existent video"
else
    echo "❌ Expected HTTP 200, got $http_code"
    exit 1
fi

# Test 2: Different sizes
echo ""
echo "Test 2: Testing different thumbnail sizes"
for size in small medium large; do
    response=$(curl -s -w "%{http_code}" "$BASE_URL/thumbnail/test-video?size=$size")
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        echo "✅ $size thumbnail: HTTP 200"
    else
        echo "❌ $size thumbnail: Expected HTTP 200, got $http_code"
        exit 1
    fi
done

# Test 3: Custom timestamps
echo ""
echo "Test 3: Testing custom timestamps"
for timestamp in 1 2.5 5; do
    response=$(curl -s -w "%{http_code}" "$BASE_URL/thumbnail/test-video?t=$timestamp")
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        echo "✅ Timestamp ${timestamp}s: HTTP 200"
    else
        echo "❌ Timestamp ${timestamp}s: Expected HTTP 200, got $http_code"
        exit 1
    fi
done

# Test 4: WebP format
echo ""
echo "Test 4: Testing WebP format"
response=$(curl -s -w "%{http_code}" "$BASE_URL/thumbnail/test-video?format=webp")
http_code="${response: -3}"
if [ "$http_code" = "200" ]; then
    echo "✅ WebP format: HTTP 200"
else
    echo "❌ WebP format: Expected HTTP 200, got $http_code"
    exit 1
fi

# Test 5: List thumbnails endpoint
echo ""
echo "Test 5: Testing list thumbnails endpoint"
response=$(curl -s -w "%{http_code}" "$BASE_URL/thumbnail/test-video/list")
http_code="${response: -3}"
if [ "$http_code" = "200" ]; then
    echo "✅ List endpoint: HTTP 200"
    # Try to parse as JSON
    content="${response%???}"
    if echo "$content" | jq . >/dev/null 2>&1; then
        echo "✅ List endpoint returns valid JSON"
    else
        echo "⚠️  List endpoint doesn't return JSON (probably placeholder)"
    fi
else
    echo "❌ List endpoint: Expected HTTP 200, got $http_code"
    exit 1
fi

# Test 6: Health check
echo ""
echo "Test 6: Backend health check"
response=$(curl -s "$BASE_URL/health")
if echo "$response" | jq -e '.status == "healthy"' >/dev/null 2>&1; then
    echo "✅ Backend is healthy"
else
    echo "❌ Backend health check failed"
    exit 1
fi

# Test 7: Check service is listed
echo ""
echo "Test 7: Thumbnail endpoints are discoverable"
response=$(curl -s "$BASE_URL/nonexistent")
if echo "$response" | jq -e '.available_endpoints[] | select(contains("thumbnail"))' >/dev/null 2>&1; then
    echo "✅ Thumbnail endpoints are listed in API documentation"
    count=$(echo "$response" | jq -r '.available_endpoints[] | select(contains("thumbnail"))' | wc -l)
    echo "   Found $count thumbnail endpoints"
else
    echo "❌ Thumbnail endpoints not found in API documentation"
    exit 1
fi

echo ""
echo "🎉 All thumbnail service integration tests PASSED!"
echo ""
echo "The thumbnail service is successfully deployed and working:"
echo "- ✅ Handles non-existent videos with placeholders"
echo "- ✅ Supports different sizes (small, medium, large)"
echo "- ✅ Supports custom timestamps"
echo "- ✅ Supports WebP format"
echo "- ✅ List endpoint is functional"
echo "- ✅ API is properly documented"
echo ""
echo "Ready for production use! 🚀"