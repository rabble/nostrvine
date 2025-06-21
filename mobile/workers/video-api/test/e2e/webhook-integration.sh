#!/bin/bash

# ABOUTME: End-to-end test for Cloudinary webhook integration
# ABOUTME: Tests upload -> webhook -> ready events flow

set -e

WORKER_URL="${WORKER_URL:-http://localhost:8787}"
API_BASE="${WORKER_URL}/v1/media"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Generate test keys
SK=$(node -e "const { generateSecretKey } = require('nostr-tools'); console.log(Buffer.from(generateSecretKey()).toString('hex'));")
PK=$(node -e "const { getPublicKey } = require('nostr-tools'); const sk = new Uint8Array(Buffer.from('$SK', 'hex')); console.log(getPublicKey(sk));")

echo -e "${YELLOW}🔑 Generated test keypair:${NC}"
echo "   Public Key: $PK"

# Helper function to generate NIP-98 auth header
generate_auth_header() {
    local url=$1
    local method=$2
    
    node -e "
    const { finalizeEvent, generateSecretKey, getPublicKey } = require('nostr-tools');
    const sk = new Uint8Array(Buffer.from('$SK', 'hex'));
    const event = {
        kind: 27235,
        created_at: Math.floor(Date.now() / 1000),
        tags: [
            ['u', '$url'],
            ['method', '$method']
        ],
        content: ''
    };
    const signed = finalizeEvent(event, sk);
    const encoded = Buffer.from(JSON.stringify(signed)).toString('base64');
    console.log('Nostr ' + encoded);
    "
}

echo -e "\n${YELLOW}📤 1. Testing Cloudinary upload request${NC}"

AUTH_HEADER=$(generate_auth_header "${API_BASE}/cloudinary/request-upload" "POST")

UPLOAD_RESPONSE=$(curl -s -X POST "${API_BASE}/cloudinary/request-upload" \
    -H "Authorization: $AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d '{
        "fileType": "video/mp4",
        "maxFileSize": 104857600
    }')

echo "Upload Response: $UPLOAD_RESPONSE"

# Extract upload parameters
SIGNATURE=$(echo $UPLOAD_RESPONSE | jq -r '.signature // empty')
TIMESTAMP=$(echo $UPLOAD_RESPONSE | jq -r '.timestamp // empty')
API_KEY=$(echo $UPLOAD_RESPONSE | jq -r '.api_key // empty')

if [ -z "$SIGNATURE" ] || [ -z "$TIMESTAMP" ] || [ -z "$API_KEY" ]; then
    echo -e "${RED}❌ Failed to get upload parameters${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Got signed upload parameters${NC}"

echo -e "\n${YELLOW}🪝 2. Simulating Cloudinary webhook${NC}"

# Create webhook payload
WEBHOOK_PAYLOAD=$(cat <<EOF
{
    "notification_type": "upload",
    "public_id": "test-video-$(date +%s)",
    "version": $(date +%s),
    "width": 1920,
    "height": 1080,
    "format": "mp4",
    "resource_type": "video",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "bytes": 10485760,
    "etag": "test-etag-123",
    "secure_url": "https://res.cloudinary.com/test/video/upload/test-video.mp4",
    "signature": "cloudinary-sig",
    "context": {
        "custom": {
            "pubkey": "$PK"
        }
    },
    "eager": [
        {
            "width": 640,
            "height": 360,
            "secure_url": "https://res.cloudinary.com/test/video/upload/f_mp4/test-video.mp4",
            "format": "mp4",
            "bytes": 5242880,
            "transformation": "f_mp4,vc_h264,q_auto"
        },
        {
            "width": 640,
            "height": 360,
            "secure_url": "https://res.cloudinary.com/test/video/upload/f_webp/test-video.webp",
            "format": "webp",
            "bytes": 2097152,
            "transformation": "f_webp,q_auto:good"
        }
    ]
}
EOF
)

# In a real scenario, this would be signed by Cloudinary
# For testing, we'll use a mock signature
WEBHOOK_TIMESTAMP=$(date +%s)
WEBHOOK_SIGNATURE="mock-signature-for-testing"

WEBHOOK_RESPONSE=$(curl -s -X POST "${API_BASE}/webhook" \
    -H "X-Cld-Signature: $WEBHOOK_SIGNATURE" \
    -H "X-Cld-Timestamp: $WEBHOOK_TIMESTAMP" \
    -H "Content-Type: application/json" \
    -d "$WEBHOOK_PAYLOAD")

echo "Webhook Response: $WEBHOOK_RESPONSE"

if [ "$WEBHOOK_RESPONSE" = "OK" ]; then
    echo -e "${GREEN}✅ Webhook processed successfully${NC}"
else
    echo -e "${RED}❌ Webhook processing failed${NC}"
    exit 1
fi

# Extract public_id from payload for later use
PUBLIC_ID=$(echo $WEBHOOK_PAYLOAD | jq -r '.public_id')

echo -e "\n${YELLOW}📥 3. Fetching ready events${NC}"

# Wait a moment for processing
sleep 1

AUTH_HEADER=$(generate_auth_header "${API_BASE}/ready-events" "GET")

EVENTS_RESPONSE=$(curl -s -X GET "${API_BASE}/ready-events" \
    -H "Authorization: $AUTH_HEADER")

echo "Ready Events Response: $EVENTS_RESPONSE"

EVENT_COUNT=$(echo $EVENTS_RESPONSE | jq -r '.count // 0')

if [ "$EVENT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $EVENT_COUNT ready event(s)${NC}"
    
    # Display event details
    echo $EVENTS_RESPONSE | jq '.events[0]'
else
    echo -e "${RED}❌ No ready events found${NC}"
    exit 1
fi

echo -e "\n${YELLOW}🔍 4. Getting specific event${NC}"

AUTH_HEADER=$(generate_auth_header "${API_BASE}/ready-events/${PUBLIC_ID}" "GET")

SPECIFIC_EVENT=$(curl -s -X GET "${API_BASE}/ready-events/${PUBLIC_ID}" \
    -H "Authorization: $AUTH_HEADER")

echo "Specific Event Response: $SPECIFIC_EVENT"

# Verify event has required NIP-94 tags
HAS_URL=$(echo $SPECIFIC_EVENT | jq -r '.tags[] | select(.[0] == "url") | length > 0')
HAS_MIME=$(echo $SPECIFIC_EVENT | jq -r '.tags[] | select(.[0] == "m") | length > 0')
HAS_SIZE=$(echo $SPECIFIC_EVENT | jq -r '.tags[] | select(.[0] == "size") | length > 0')

if [ "$HAS_URL" ] && [ "$HAS_MIME" ] && [ "$HAS_SIZE" ]; then
    echo -e "${GREEN}✅ Event has required NIP-94 tags${NC}"
else
    echo -e "${RED}❌ Event missing required NIP-94 tags${NC}"
    exit 1
fi

echo -e "\n${YELLOW}🗑️  5. Deleting ready event${NC}"

AUTH_HEADER=$(generate_auth_header "${API_BASE}/ready-events" "DELETE")

DELETE_RESPONSE=$(curl -s -X DELETE "${API_BASE}/ready-events" \
    -H "Authorization: $AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"public_id\": \"$PUBLIC_ID\"}")

echo "Delete Response: $DELETE_RESPONSE"

DELETE_SUCCESS=$(echo $DELETE_RESPONSE | jq -r '.success // false')

if [ "$DELETE_SUCCESS" = "true" ]; then
    echo -e "${GREEN}✅ Event deleted successfully${NC}"
else
    echo -e "${RED}❌ Failed to delete event${NC}"
    exit 1
fi

echo -e "\n${YELLOW}📥 6. Verifying event deletion${NC}"

AUTH_HEADER=$(generate_auth_header "${API_BASE}/ready-events/${PUBLIC_ID}" "GET")

DELETED_CHECK=$(curl -s -X GET "${API_BASE}/ready-events/${PUBLIC_ID}" \
    -H "Authorization: $AUTH_HEADER")

ERROR_MESSAGE=$(echo $DELETED_CHECK | jq -r '.error.message // empty')

if [ "$ERROR_MESSAGE" = "Event not found" ]; then
    echo -e "${GREEN}✅ Event successfully deleted${NC}"
else
    echo -e "${RED}❌ Event still exists after deletion${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 All webhook integration tests passed!${NC}"