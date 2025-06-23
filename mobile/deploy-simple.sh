#!/bin/bash
# OpenVine Simple Deployment Script

set -e

echo "🚀 OpenVine Deployment Script"
echo "=============================="

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo ""
echo "Checking prerequisites..."

if ! command_exists flutter; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

if ! command_exists wrangler; then
    echo "❌ Wrangler not found. Install with: npm install -g wrangler"
    exit 1
fi

echo "✅ All prerequisites installed"

# Menu
echo ""
echo "What would you like to deploy?"
echo "1) Backend to Cloudflare Workers"
echo "2) Mobile app (Android APK)"
echo "3) Mobile app (iOS)"
echo "4) Web app to Cloudflare Pages"
echo "5) Check deployment status"
echo ""
read -p "Select option (1-5): " choice

case $choice in
    1)
        echo ""
        echo "Deploying Backend to Cloudflare Workers..."
        cd ../backend
        
        # Check if logged in
        if ! wrangler whoami >/dev/null 2>&1; then
            echo "Please login to Cloudflare:"
            wrangler login
        fi
        
        # Check for secrets
        echo ""
        echo "Have you set the following secrets? (y/n)"
        echo "- CLOUDFLARE_ACCOUNT_ID"
        echo "- CLOUDFLARE_STREAM_TOKEN"
        echo "- STREAM_WEBHOOK_SECRET"
        read -p "Continue? (y/n): " confirm
        
        if [ "$confirm" != "y" ]; then
            echo ""
            echo "Please set secrets first:"
            echo "wrangler secret put CLOUDFLARE_ACCOUNT_ID --env production"
            echo "wrangler secret put CLOUDFLARE_STREAM_TOKEN --env production"
            echo "wrangler secret put STREAM_WEBHOOK_SECRET --env production"
            exit 1
        fi
        
        # Deploy
        echo ""
        echo "Deploying to production..."
        npm install
        wrangler deploy --env production
        
        echo ""
        echo "✅ Backend deployed successfully!"
        echo "Don't forget to configure Stream webhooks in Cloudflare dashboard!"
        ;;
        
    2)
        echo ""
        echo "Building Android APK..."
        
        # Update backend URL for production
        echo "Using production backend URL..."
        BACKEND_URL="https://api.nostrvine.com"
        
        # Clean and build
        flutter clean
        flutter pub get
        flutter build apk --release \
            --dart-define=BACKEND_URL=$BACKEND_URL \
            --dart-define=ENVIRONMENT=production
        
        echo ""
        echo "✅ Android APK built successfully!"
        echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
        ;;
        
    3)
        echo ""
        echo "Building iOS app..."
        
        # Check if on macOS
        if [[ "$OSTYPE" != "darwin"* ]]; then
            echo "❌ iOS builds require macOS"
            exit 1
        fi
        
        # Update backend URL for production
        echo "Using production backend URL..."
        BACKEND_URL="https://api.nostrvine.com"
        
        # Clean and build
        flutter clean
        flutter pub get
        flutter build ios --release \
            --dart-define=BACKEND_URL=$BACKEND_URL \
            --dart-define=ENVIRONMENT=production
        
        echo ""
        echo "✅ iOS app built successfully!"
        echo "Open Xcode to archive and upload to App Store Connect"
        ;;
        
    4)
        echo ""
        echo "Building and deploying web app..."
        
        # Update backend URL for production
        BACKEND_URL="https://api.nostrvine.com"
        
        # Build web
        flutter clean
        flutter pub get
        flutter build web --release \
            --dart-define=BACKEND_URL=$BACKEND_URL \
            --dart-define=ENVIRONMENT=production
        
        # Check if wrangler pages is available
        if command_exists npx; then
            echo ""
            echo "Deploying to Cloudflare Pages..."
            cd build/web
            npx wrangler pages deploy . --project-name nostrvine-web
            echo ""
            echo "✅ Web app deployed successfully!"
        else
            echo ""
            echo "✅ Web app built successfully!"
            echo "To deploy, run: npx wrangler pages deploy build/web --project-name nostrvine-web"
        fi
        ;;
        
    5)
        echo ""
        echo "Checking deployment status..."
        
        # Check backend health
        echo ""
        echo "Checking backend health..."
        BACKEND_URL="https://api.nostrvine.com"
        
        if curl -s "$BACKEND_URL/health" >/dev/null 2>&1; then
            echo "✅ Backend is reachable"
            echo ""
            echo "Health check response:"
            curl -s "$BACKEND_URL/health" | python3 -m json.tool 2>/dev/null || curl -s "$BACKEND_URL/health"
        else
            echo "❌ Backend health check failed"
            echo "Make sure the backend is deployed and the domain is configured"
        fi
        
        echo ""
        echo "Remember to verify:"
        echo "1. Stream webhooks are configured in Cloudflare dashboard"
        echo "2. R2 buckets are created"
        echo "3. KV namespace is configured"
        echo "4. Custom domain is set up (if applicable)"
        ;;
        
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "Done!"