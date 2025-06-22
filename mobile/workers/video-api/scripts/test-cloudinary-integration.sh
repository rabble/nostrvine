#!/bin/bash

# Test script for Cloudinary webhook integration
# This script tests the full upload → webhook → ready events flow

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Cloudinary Integration Test${NC}"
echo -e "${BLUE}=============================${NC}\n"

# Check if API is accessible
echo -e "${YELLOW}1. Testing API health...${NC}"
HEALTH_RESPONSE=$(curl -s https://api.openvine.co/health || echo "Failed")
if [[ "$HEALTH_RESPONSE" == *"healthy"* ]] || [[ "$HEALTH_RESPONSE" == *"ok"* ]]; then
    echo -e "${GREEN}✅ API is healthy${NC}\n"
else
    echo -e "${RED}❌ API health check failed: $HEALTH_RESPONSE${NC}"
    echo -e "${YELLOW}Please ensure DNS has propagated and the worker is deployed${NC}"
    exit 1
fi

# Test webhook endpoint (should return 401 without proper signature)
echo -e "${YELLOW}2. Testing webhook endpoint...${NC}"
WEBHOOK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST https://api.openvine.co/v1/media/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": true}')

if [[ "$WEBHOOK_STATUS" == "401" ]]; then
    echo -e "${GREEN}✅ Webhook endpoint is responding correctly (401 for unsigned request)${NC}\n"
else
    echo -e "${RED}❌ Unexpected webhook response: HTTP $WEBHOOK_STATUS${NC}"
    exit 1
fi

# Test ready events endpoint (should return 401 without NIP-98 auth)
echo -e "${YELLOW}3. Testing ready events endpoint...${NC}"
READY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://api.openvine.co/v1/media/ready-events)

if [[ "$READY_STATUS" == "401" ]]; then
    echo -e "${GREEN}✅ Ready events endpoint is responding correctly (401 for unauthenticated request)${NC}\n"
else
    echo -e "${RED}❌ Unexpected ready events response: HTTP $READY_STATUS${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 All API endpoints are responding correctly!${NC}\n"

echo -e "${BLUE}📋 Next Steps:${NC}"
echo -e "1. Configure webhook URL in Cloudinary console:"
echo -e "   ${YELLOW}https://api.openvine.co/v1/media/webhook${NC}"
echo -e ""
echo -e "2. Set up upload preset in Cloudinary:"
echo -e "   - Name: ${YELLOW}nostrvine_video_uploads${NC}"
echo -e "   - Eager transformations: mp4, gif, thumbnail"
echo -e ""
echo -e "3. Test a real upload with context:"
echo -e "   ${YELLOW}context=pubkey=YOUR_NOSTR_PUBKEY${NC}"
echo -e ""
echo -e "4. Monitor webhook delivery:"
echo -e "   ${YELLOW}wrangler tail${NC}"
echo -e ""
echo -e "5. Check ready events after upload:"
echo -e "   Use NIP-98 authenticated request to /v1/media/ready-events"

# Create sample upload test command
echo -e "\n${BLUE}📤 Sample Upload Command:${NC}"
echo -e "curl -X POST https://api.cloudinary.com/v1_1/dswu0ugmo/video/upload \\"
echo -e "  -F \"file=@test-video.mp4\" \\"
echo -e "  -F \"upload_preset=nostrvine_video_uploads\" \\"
echo -e "  -F \"context=pubkey=d91191e30e00444b942c0e82cad470b32af171764c2275bee0bd99377efd4075\" \\"
echo -e "  -F \"api_key=YOUR_API_KEY\""