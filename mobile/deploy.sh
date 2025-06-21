#!/bin/bash
# NostrVine Deployment Script

set -e

echo "🚀 NostrVine Deployment Script"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: Not in the mobile directory. Please run from nostrvine/mobile${NC}"
    exit 1
fi

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo ""
echo "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists flutter; then
    echo -e "${RED}❌ Flutter not found. Please install Flutter first.${NC}"
    exit 1
fi

if ! command_exists wrangler; then
    echo -e "${RED}❌ Wrangler not found. Install with: npm install -g wrangler${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites installed${NC}"

# Menu
echo -e "\n${YELLOW}What would you like to deploy?${NC}"
echo "1) Backend to Cloudflare Workers"
echo "2) Mobile app (Android APK)"
echo "3) Mobile app (iOS)"
echo "4) Web app to Cloudflare Pages"
echo "5) Full deployment (all of the above)"
echo "6) Check deployment status"
echo ""
read -p "Select option (1-6): " choice

case $choice in
    1)
        echo -e "\n${YELLOW}Deploying Backend to Cloudflare Workers...${NC}"
        cd ../backend
        
        # Check if logged in
        if ! wrangler whoami >/dev/null 2>&1; then
            echo "Please login to Cloudflare:"
            wrangler login
        fi
        
        # Check for secrets
        echo -e "\n${YELLOW}Checking secrets...${NC}"
        echo "Have you set the following secrets? (y/n)"
        echo "- CLOUDFLARE_ACCOUNT_ID"
        echo "- CLOUDFLARE_STREAM_TOKEN"
        echo "- STREAM_WEBHOOK_SECRET"
        read -p "Continue? (y/n): " confirm
        
        if [ "$confirm" != "y" ]; then
            echo -e "${RED}Please set secrets first:${NC}"
            echo "wrangler secret put CLOUDFLARE_ACCOUNT_ID --env production"
            echo "wrangler secret put CLOUDFLARE_STREAM_TOKEN --env production"
            echo "wrangler secret put STREAM_WEBHOOK_SECRET --env production"
            exit 1
        fi
        
        # Deploy
        echo -e "\n${YELLOW}Deploying to production...${NC}"
        npm install
        wrangler deploy --env production
        
        echo -e "${GREEN}✅ Backend deployed successfully!${NC}"
        echo "Don't forget to configure Stream webhooks in Cloudflare dashboard!"
        ;;
        
    2)
        echo -e "\n${YELLOW}Building Android APK...${NC}"
        
        # Update backend URL for production
        echo "Using production backend URL..."
        export BACKEND_URL="https://api.nostrvine.com"
        
        # Clean and build
        flutter clean
        flutter pub get
        flutter build apk --release \
            --dart-define=BACKEND_URL=$BACKEND_URL \
            --dart-define=ENVIRONMENT=production
        
        echo -e "${GREEN}✅ Android APK built successfully!${NC}"
        echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
        ;;
        
    3)
        echo -e "\n${YELLOW}Building iOS app...${NC}"
        
        # Check if on macOS
        if [[ "$OSTYPE" != "darwin"* ]]; then
            echo -e "${RED}❌ iOS builds require macOS${NC}"
            exit 1
        fi
        
        # Update backend URL for production
        echo "Using production backend URL..."
        export BACKEND_URL="https://api.nostrvine.com"
        
        # Clean and build
        flutter clean
        flutter pub get
        flutter build ios --release \
            --dart-define=BACKEND_URL=$BACKEND_URL \
            --dart-define=ENVIRONMENT=production
        
        echo -e "${GREEN}✅ iOS app built successfully!${NC}"
        echo "Open Xcode to archive and upload to App Store Connect"
        ;;
        
    4)
        echo -e "\n${YELLOW}Building and deploying web app...${NC}"
        
        # Update backend URL for production
        export BACKEND_URL="https://api.nostrvine.com"
        
        # Build web
        flutter clean
        flutter pub get
        flutter build web --release \
            --dart-define=BACKEND_URL=$BACKEND_URL \
            --dart-define=ENVIRONMENT=production
        
        # Deploy to Cloudflare Pages
        echo -e "\n${YELLOW}Deploying to Cloudflare Pages...${NC}"
        cd build/web
        npx wrangler pages deploy . --project-name nostrvine-web
        
        echo -e "${GREEN}✅ Web app deployed successfully!${NC}"
        ;;
        
    5)
        echo -e "\n${YELLOW}Full deployment - this will take a while...${NC}"
        # Run all deployments
        bash "$0" 1  # Backend
        bash "$0" 2  # Android
        if [[ "$OSTYPE" == "darwin"* ]]; then
            bash "$0" 3  # iOS (only on macOS)
        fi
        bash "$0" 4  # Web
        ;;
        
    6)
        echo -e "\n${YELLOW}Checking deployment status...${NC}"
        
        # Check backend health
        echo -e "\nChecking backend health..."
        BACKEND_URL=${BACKEND_URL:-"https://api.nostrvine.com"}
        
        if curl -s "$BACKEND_URL/health" | grep -q "healthy"; then
            echo -e "${GREEN}✅ Backend is healthy${NC}"
            curl -s "$BACKEND_URL/health" | python3 -m json.tool
        else
            echo -e "${RED}❌ Backend health check failed${NC}"
        fi
        
        # Check Stream webhook
        echo -e "\n${YELLOW}Remember to verify:${NC}"
        echo "1. Stream webhooks are configured in Cloudflare dashboard"
        echo "2. R2 buckets are created"
        echo "3. KV namespace is configured"
        echo "4. Custom domain is set up (if applicable)"
        ;;
        
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}Done!${NC}"