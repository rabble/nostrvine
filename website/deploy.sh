#!/bin/bash
# ABOUTME: Deployment script for OpenVine website to Cloudflare Pages
# ABOUTME: Builds and deploys the static site

set -e

echo "🍇 Deploying OpenVine Website to Cloudflare Pages..."

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "❌ Wrangler CLI not found. Installing..."
    npm install -g wrangler
fi

# Login check
echo "🔐 Checking Cloudflare authentication..."
if ! wrangler whoami &> /dev/null; then
    echo "❌ Not logged into Cloudflare. Please run: wrangler login"
    exit 1
fi

# Create pages project if it doesn't exist
echo "📄 Setting up Cloudflare Pages project..."
wrangler pages project create openvine-website --production-branch=main || echo "Project may already exist"

# Deploy to Cloudflare Pages
echo "🚀 Deploying to Cloudflare Pages..."
wrangler pages deploy . --project-name=openvine-website

echo "✅ Deployment complete!"
echo "🌐 Your site should be available at: https://openvine-website.pages.dev"
echo "📝 To set up custom domain openvine.co:"
echo "   1. Go to Cloudflare Dashboard > Pages > openvine-website > Custom domains"
echo "   2. Add openvine.co as a custom domain"
echo "   3. Update DNS records as instructed"