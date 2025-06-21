#!/bin/bash
# ABOUTME: Script to build and prepare Flutter web app for Cloudflare Pages deployment
# ABOUTME: Handles cleaning, building, and organizing the output for deployment

set -e

echo "🚀 Building NostrVine Web App for deployment..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web
echo "🔨 Building web app..."
flutter build web --release

# Create deployment directory
echo "📁 Preparing deployment files..."
if [ -d "web-deploy" ]; then
    rm -rf web-deploy
fi
cp -r build/web web-deploy

echo "✅ Build complete! The web-deploy directory is ready for Cloudflare Pages."
echo "📍 Deploy the 'web-deploy' directory to Cloudflare Pages"