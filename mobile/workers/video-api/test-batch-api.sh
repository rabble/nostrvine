#!/bin/bash

# Test script for Batch Video API
echo "Testing Batch Video API..."

# Test valid batch request
echo -e "\n1. Testing batch request with multiple videos:"
curl -X POST http://localhost:55713/api/videos/batch \
  -H "Content-Type: application/json" \
  -d '{
    "videoIds": [
      "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
      "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
      "0000000000000000000000000000000000000000000000000000000000000000"
    ]
  }' | jq .

# Test empty batch
echo -e "\n\n2. Testing empty batch (should fail):"
curl -X POST http://localhost:55713/api/videos/batch \
  -H "Content-Type: application/json" \
  -d '{"videoIds": []}' | jq .

# Test oversized batch
echo -e "\n\n3. Testing oversized batch (should fail):"
# Generate 51 video IDs
VIDEO_IDS=$(for i in {1..51}; do printf '"%064d"' $i; if [ $i -lt 51 ]; then printf ','; fi; done)
curl -X POST http://localhost:55713/api/videos/batch \
  -H "Content-Type: application/json" \
  -d "{\"videoIds\": [$VIDEO_IDS]}" | jq .

# Test with quality parameter
echo -e "\n\n4. Testing batch with quality parameter:"
curl -X POST http://localhost:55713/api/videos/batch \
  -H "Content-Type: application/json" \
  -d '{
    "videoIds": ["1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"],
    "quality": "480p"
  }' | jq .

# Test CORS headers
echo -e "\n\n5. Testing CORS headers on batch endpoint:"
curl -i -X OPTIONS http://localhost:55713/api/videos/batch \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" | head -20