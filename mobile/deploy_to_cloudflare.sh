#!/bin/bash
# Deploy OpenVine to Cloudflare Pages with optimizations

echo "🚀 Deploying OpenVine to Cloudflare Pages..."

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf build/web

# Build Flutter web with optimizations
echo "📦 Building optimized Flutter web app..."
flutter build web --release --tree-shake-icons \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=https://www.gstatic.com/flutter-canvaskit/8cd19e509d6bece8ccd74aef027c4ca947363095/

# Copy optimized files
echo "📄 Copying optimized files..."
cp web-deploy/_headers build/web/_headers
cp web/sw.js build/web/sw.js
cp _worker.js build/web/_worker.js

# Optimize main.dart.js with compression
echo "🗜️  Preparing files for deployment..."
if command -v gzip &> /dev/null; then
  # Pre-compress large files for faster serving
  find build/web -name "*.js" -o -name "*.css" -o -name "*.html" | while read file; do
    gzip -9 -k "$file" 2>/dev/null || true
  done
fi

# Deploy to Cloudflare Pages
echo "☁️  Deploying to Cloudflare Pages..."
cd build/web
npx wrangler pages deploy . --project-name=openvine-app --commit-dirty=true

echo "✅ Deployment complete!"
echo "📊 Check performance at: https://pagespeed.web.dev/report?url=https://app.openvine.co"