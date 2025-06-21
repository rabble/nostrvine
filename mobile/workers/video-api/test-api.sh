#!/bin/bash

# Test script for Video Metadata API
echo "Testing Video Metadata API..."

# Health check
echo -e "\n1. Testing health endpoint:"
curl -i http://localhost:55713/health

# Test invalid video ID
echo -e "\n\n2. Testing invalid video ID:"
curl -i http://localhost:55713/api/video/invalid-id

# Test valid format but non-existent video
echo -e "\n\n3. Testing non-existent video:"
curl -i http://localhost:55713/api/video/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef

# Test CORS preflight
echo -e "\n\n4. Testing CORS preflight:"
curl -i -X OPTIONS \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: GET" \
  http://localhost:55713/api/video/test