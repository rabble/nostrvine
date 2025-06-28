#!/bin/bash
# Build Flutter web with optimizations for faster loading

echo "Building optimized Flutter web app..."

# Clean previous build
flutter clean

# Build with specific optimizations
flutter build web \
  --release \
  --web-renderer canvaskit \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://www.gstatic.com/flutter-canvaskit/8cd19e509d6bece8ccd74aef027c4ca947363095/ \
  --tree-shake-icons \
  --pwa-strategy=offline-first

# Copy updated headers file to build output
cp web-deploy/_headers build/web/_headers

echo "Build complete! Deploy the build/web directory to Cloudflare."