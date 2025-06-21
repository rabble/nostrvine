#!/bin/bash

# ABOUTME: Pre-deployment check script for OpenVine
# ABOUTME: Verifies all requirements are met before deploying

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 OpenVine Deployment Readiness Check${NC}"
echo -e "${BLUE}====================================${NC}\n"

READY=true

# Check Flutter
echo -e "${YELLOW}Checking Flutter...${NC}"
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    echo -e "${GREEN}✅ Flutter installed${NC}"
    echo "   $FLUTTER_VERSION"
else
    echo -e "${RED}❌ Flutter not installed${NC}"
    READY=false
fi

# Check web support
if flutter doctor | grep -q "Chrome.*installed"; then
    echo -e "${GREEN}✅ Flutter web support enabled${NC}"
else
    echo -e "${RED}❌ Flutter web support not configured${NC}"
    echo "   Run: flutter config --enable-web"
    READY=false
fi

# Check Node.js
echo -e "\n${YELLOW}Checking Node.js...${NC}"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✅ Node.js installed: $NODE_VERSION${NC}"
else
    echo -e "${RED}❌ Node.js not installed${NC}"
    READY=false
fi

# Check Wrangler
echo -e "\n${YELLOW}Checking Wrangler CLI...${NC}"
if command -v wrangler &> /dev/null; then
    WRANGLER_VERSION=$(wrangler --version 2>/dev/null | head -n 1)
    echo -e "${GREEN}✅ Wrangler installed: $WRANGLER_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Wrangler not installed globally${NC}"
    echo "   Will use npx wrangler (slower but works)"
fi

# Check Cloudflare credentials
echo -e "\n${YELLOW}Checking Cloudflare credentials...${NC}"
if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    echo -e "${GREEN}✅ CLOUDFLARE_API_TOKEN is set${NC}"
else
    echo -e "${YELLOW}⚠️  CLOUDFLARE_API_TOKEN not set${NC}"
    echo "   You'll be prompted during deployment"
fi

if [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo -e "${GREEN}✅ CLOUDFLARE_ACCOUNT_ID is set${NC}"
else
    echo -e "${YELLOW}⚠️  CLOUDFLARE_ACCOUNT_ID not set${NC}"
    echo "   You'll be prompted during deployment"
fi

# Check build
echo -e "\n${YELLOW}Checking Flutter build...${NC}"
if [ -d "build/web" ]; then
    BUILD_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" build/web 2>/dev/null || stat -c "%y" build/web 2>/dev/null | cut -d' ' -f1-2)
    echo -e "${GREEN}✅ Web build exists${NC}"
    echo "   Last built: $BUILD_TIME"
else
    echo -e "${YELLOW}⚠️  No web build found${NC}"
    echo "   Will be created during deployment"
fi

# Check API configuration
echo -e "\n${YELLOW}Checking API configuration...${NC}"
if grep -q "api.openvine.co" lib/config/app_config.dart; then
    echo -e "${GREEN}✅ App configured for production API${NC}"
else
    echo -e "${RED}❌ App not configured for production API${NC}"
    READY=false
fi

# Check deployment scripts
echo -e "\n${YELLOW}Checking deployment scripts...${NC}"
SCRIPTS=(
    "deploy-openvine-web.sh"
    "workers/video-api/deploy-openvine.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo -e "${GREEN}✅ $script is ready${NC}"
    else
        echo -e "${RED}❌ $script not found or not executable${NC}"
        READY=false
    fi
done

# Summary
echo -e "\n${BLUE}====================================${NC}"
if [ "$READY" = true ]; then
    echo -e "${GREEN}✅ Ready for deployment!${NC}\n"
    echo -e "Next steps:"
    echo -e "1. Deploy web app: ${YELLOW}./deploy-openvine-web.sh${NC}"
    echo -e "2. Deploy API: ${YELLOW}cd workers/video-api && ./deploy-openvine.sh${NC}"
else
    echo -e "${RED}❌ Not ready for deployment${NC}"
    echo -e "\nPlease fix the issues above before deploying."
fi

# Show configured domains
echo -e "\n${BLUE}Configured Domains:${NC}"
echo -e "Web App: ${GREEN}https://app.openvine.co${NC}"
echo -e "API: ${GREEN}https://api.openvine.co${NC}"
echo -e "Staging API: ${GREEN}https://staging-api.openvine.co${NC}"