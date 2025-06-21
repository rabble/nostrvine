# NostrVine Web Deployment Guide

## Current Status ✅
- Backend: Fully configured for Cloudflare Workers
- Web App: Flutter web ready, needs CF deployment config

## Quick Deploy Options

### Option 1: Cloudflare Pages (Recommended)
```bash
# 1. Build Flutter web
flutter build web --release

# 2. Deploy to Cloudflare Pages
npx wrangler pages deploy build/web --project-name nostrvine-web

# 3. Set custom domain (optional)
# Configure in Cloudflare dashboard
```

### Option 2: Add to Existing Workers (Advanced)
Add to `../backend/wrangler.jsonc`:
```json
"assets": { 
  "directory": "../mobile/build/web/", 
  "binding": "WEB_ASSETS" 
}
```

### Option 3: R2 + CDN
```bash
# Upload to R2 bucket
wrangler r2 object put nostrvine-web/index.html --file=build/web/index.html
```

## Build Commands
```bash
# Test locally
flutter run -d chrome --release

# Build for production  
flutter build web --release --base-href="/"

# Build with custom base href
flutter build web --release --base-href="/app/"
```

## Environment Configuration
Update `lib/config/app_config.dart` for web:
```dart
static const String backendUrl = kIsWeb 
  ? 'https://api.nostrvine.com'  // Production
  : 'http://localhost:8787';     // Development
```