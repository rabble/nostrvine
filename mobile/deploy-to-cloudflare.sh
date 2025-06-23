#!/bin/bash
# ABOUTME: Direct deployment script for Cloudflare Pages using the API
# ABOUTME: Requires CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID environment variables

set -e

# Check if required environment variables are set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ Error: CLOUDFLARE_API_TOKEN environment variable is not set"
    echo "Please set it with: export CLOUDFLARE_API_TOKEN=your-token"
    exit 1
fi

if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo "❌ Error: CLOUDFLARE_ACCOUNT_ID environment variable is not set"
    echo "Please set it with: export CLOUDFLARE_ACCOUNT_ID=your-account-id"
    exit 1
fi

PROJECT_NAME="nostrvine-app"
BRANCH="main"

echo "🚀 Deploying OpenVine to Cloudflare Pages..."

# Build the app first
echo "🔨 Building Flutter web app..."
./deploy-web.sh

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "📦 Installing Wrangler CLI..."
    npm install -g wrangler
fi

# Deploy to Cloudflare Pages
echo "☁️  Deploying to Cloudflare Pages..."
cd web-deploy
wrangler pages deploy . \
    --project-name="$PROJECT_NAME" \
    --branch="$BRANCH" \
    --commit-message="Deploy OpenVine web app"

echo "✅ Deployment complete!"
echo "🌐 Your app will be available at:"
echo "   https://$PROJECT_NAME.pages.dev"
echo "   https://app.openvine.co (after domain configuration)"