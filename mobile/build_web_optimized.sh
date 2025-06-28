#!/bin/bash
# Build Flutter web with optimizations for faster loading

echo "Building optimized Flutter web app..."

# Clean previous build
flutter clean

# Build with specific optimizations for modern Flutter
flutter build web \
  --release \
  --tree-shake-icons \
  --pwa-strategy=offline-first

# Copy updated headers file to build output
cp web-deploy/_headers build/web/_headers

echo "Build complete! Deploy the build/web directory to Cloudflare."