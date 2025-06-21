#!/bin/bash

# ABOUTME: Deployment script for OpenVine video API to Cloudflare Workers
# ABOUTME: Configures custom domain routing on openvine.co

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 OpenVine Video API Deployment${NC}"
echo -e "${BLUE}================================${NC}"

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo -e "${RED}❌ Wrangler CLI not found. Please install it:${NC}"
    echo "npm install -g wrangler"
    exit 1
fi

# Check if logged in
if ! wrangler whoami &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Cloudflare. Running login...${NC}"
    wrangler login
fi

# Function to deploy environment
deploy_environment() {
    local ENV=$1
    local DOMAIN=$2
    
    echo -e "\n${YELLOW}📦 Deploying to $ENV environment...${NC}"
    
    # Set secrets if not already set
    echo -e "${YELLOW}🔐 Checking secrets...${NC}"
    
    # Check if secrets exist (this will fail if not set, which is ok)
    if ! wrangler secret list --env $ENV 2>&1 | grep -q "CLOUDINARY_API_KEY"; then
        echo -e "${YELLOW}Setting CLOUDINARY_API_KEY secret...${NC}"
        echo "Enter Cloudinary API Key for $ENV:"
        read -s CLOUDINARY_API_KEY
        echo "$CLOUDINARY_API_KEY" | wrangler secret put CLOUDINARY_API_KEY --env $ENV
    fi
    
    if ! wrangler secret list --env $ENV 2>&1 | grep -q "CLOUDINARY_API_SECRET"; then
        echo -e "${YELLOW}Setting CLOUDINARY_API_SECRET secret...${NC}"
        echo "Enter Cloudinary API Secret for $ENV:"
        read -s CLOUDINARY_API_SECRET
        echo "$CLOUDINARY_API_SECRET" | wrangler secret put CLOUDINARY_API_SECRET --env $ENV
    fi
    
    # Deploy the worker
    echo -e "${YELLOW}🚀 Deploying worker...${NC}"
    if [ "$ENV" == "production" ]; then
        wrangler deploy
    else
        wrangler deploy --env $ENV
    fi
    
    echo -e "${GREEN}✅ Deployed to $ENV at $DOMAIN${NC}"
}

# Main deployment flow
echo -e "\n${BLUE}Select deployment target:${NC}"
echo "1) Development (localhost)"
echo "2) Staging (staging-api.openvine.co)"
echo "3) Production (api.openvine.co)"
echo "4) All environments"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo -e "\n${YELLOW}📦 Starting local development server...${NC}"
        wrangler dev
        ;;
    2)
        deploy_environment "staging" "https://staging-api.openvine.co"
        ;;
    3)
        echo -e "\n${RED}⚠️  WARNING: Deploying to PRODUCTION!${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" == "yes" ]; then
            deploy_environment "production" "https://api.openvine.co"
        else
            echo "Deployment cancelled."
        fi
        ;;
    4)
        echo -e "\n${YELLOW}📦 Deploying to all environments...${NC}"
        deploy_environment "staging" "https://staging-api.openvine.co"
        
        echo -e "\n${RED}⚠️  WARNING: About to deploy to PRODUCTION!${NC}"
        read -p "Continue with production deployment? (yes/no): " confirm
        if [ "$confirm" == "yes" ]; then
            deploy_environment "production" "https://api.openvine.co"
        fi
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Post-deployment information
echo -e "\n${BLUE}📋 Deployment Summary${NC}"
echo -e "${BLUE}===================${NC}"
echo -e "Domain: openvine.co"
echo -e "Production API: https://api.openvine.co"
echo -e "Staging API: https://staging-api.openvine.co"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Configure Cloudinary webhook URL in Cloudinary console:"
echo "   - Production: https://api.openvine.co/v1/media/webhook"
echo "   - Staging: https://staging-api.openvine.co/v1/media/webhook"
echo "2. Test the endpoints:"
echo "   - curl https://api.openvine.co/health"
echo "   - curl https://api.openvine.co/v1/media/ready-events"
echo "3. Update Flutter app with production URL if needed"

echo -e "\n${GREEN}🎉 Deployment complete!${NC}"