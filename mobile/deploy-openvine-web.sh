#!/bin/bash

# ABOUTME: One-click deployment script for OpenVine web app to app.openvine.co
# ABOUTME: Handles building Flutter web and deploying to Cloudflare Pages

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 OpenVine Web Deployment${NC}"
echo -e "${BLUE}==========================${NC}"
echo -e "Target: https://app.openvine.co"

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v flutter &> /dev/null; then
        missing+=("flutter")
    fi
    
    if ! command -v npx &> /dev/null; then
        missing+=("npx (install Node.js)")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing dependencies: ${missing[*]}${NC}"
        exit 1
    fi
}

# Build Flutter web app
build_web() {
    echo -e "\n${YELLOW}📦 Building Flutter web app...${NC}"
    
    # Clean previous build
    flutter clean
    
    # Get dependencies
    flutter pub get
    
    # Build for web with aggressive optimizations
    flutter build web \
        --release \
        --web-renderer=html \
        --tree-shake-icons \
        --split-debug-info=build/web/debug_symbols \
        --obfuscate \
        --dart-define=BACKEND_URL=https://api.openvine.co \
        --dart-define=ENVIRONMENT=production \
        --dart-define=flutter.web.canvaskit=false \
        --no-source-maps
    
    echo -e "${GREEN}✅ Web build complete${NC}"
}

# Deploy to Cloudflare Pages
deploy_cloudflare() {
    echo -e "\n${YELLOW}☁️  Deploying to Cloudflare Pages...${NC}"
    
    # Check for Cloudflare credentials
    if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
        echo -e "${YELLOW}⚠️  Cloudflare credentials not found in environment${NC}"
        echo -e "Please enter your Cloudflare credentials:"
        
        if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
            read -p "Cloudflare Account ID: " CLOUDFLARE_ACCOUNT_ID
            export CLOUDFLARE_ACCOUNT_ID
        fi
        
        if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
            echo "Cloudflare API Token (hidden):"
            read -s CLOUDFLARE_API_TOKEN
            export CLOUDFLARE_API_TOKEN
        fi
    fi
    
    # Deploy using Wrangler
    npx wrangler pages deploy build/web \
        --project-name=openvine-app \
        --branch=main \
        --commit-message="Deploy OpenVine web app"
    
    echo -e "${GREEN}✅ Deployed to Cloudflare Pages${NC}"
}

# Configure custom domain (only needed once)
configure_domain() {
    echo -e "\n${YELLOW}🌐 Domain Configuration${NC}"
    echo -e "To configure app.openvine.co:"
    echo -e "1. Go to: https://dash.cloudflare.com/?to=/:account/pages/view/openvine-app/domains"
    echo -e "2. Click 'Add custom domain'"
    echo -e "3. Enter: app.openvine.co"
    echo -e "4. Cloudflare will automatically configure DNS"
}

# Main deployment flow
main() {
    check_dependencies
    
    # Deployment options
    echo -e "\n${BLUE}Select deployment option:${NC}"
    echo "1) Build and deploy (recommended)"
    echo "2) Build only"
    echo "3) Deploy only (use existing build)"
    echo "4) Configure domain"
    
    read -p "Enter choice (1-4): " choice
    
    case $choice in
        1)
            build_web
            deploy_cloudflare
            echo -e "\n${GREEN}🎉 Deployment complete!${NC}"
            echo -e "Your app will be available at:"
            echo -e "  - https://openvine-app.pages.dev (immediate)"
            echo -e "  - https://app.openvine.co (after domain configuration)"
            ;;
        2)
            build_web
            echo -e "\n${GREEN}✅ Build complete!${NC}"
            echo -e "Web files are in: build/web/"
            ;;
        3)
            if [ ! -d "build/web" ]; then
                echo -e "${RED}❌ No build found. Please build first.${NC}"
                exit 1
            fi
            deploy_cloudflare
            ;;
        4)
            configure_domain
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
}

# Show current configuration
echo -e "\n${BLUE}Current Configuration:${NC}"
echo -e "  App Name: OpenVine"
echo -e "  Backend API: https://api.openvine.co"
echo -e "  Target Domain: https://app.openvine.co"
echo -e "  Project: openvine-app (Cloudflare Pages)"

# Run main deployment
main

# Post-deployment info
if [[ $choice == "1" ]] || [[ $choice == "3" ]]; then
    echo -e "\n${BLUE}📋 Post-Deployment Checklist:${NC}"
    echo -e "[ ] Visit https://openvine-app.pages.dev to test"
    echo -e "[ ] Configure custom domain if not done"
    echo -e "[ ] Test video upload functionality"
    echo -e "[ ] Check browser console for errors"
    echo -e "[ ] Verify API connectivity"
fi