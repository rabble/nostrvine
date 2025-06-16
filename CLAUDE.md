# NostrVine Memory

## Project Overview
NostrVine is a Nostr-based vine-like video sharing application with:
- **Flutter Mobile App**: Cross-platform client for capturing and sharing short videos
- **Cloudflare Workers Backend**: Serverless backend for GIF creation and media processing

## Current Focus  
**Camera Integration Implementation** - Building hybrid frame capture for vine recording

## Technology Stack
- **Frontend**: Flutter (Dart) with Camera plugin
- **Backend**: Cloudflare Workers + R2 Storage
- **Protocol**: Nostr (decentralized social network)
- **Media Processing**: Real-time frame capture → GIF creation

## Development Environment

### Local Development Server
**App URL**: http://localhost:53424/

The Flutter app is typically already running locally on Chrome when working on development. Use this URL to access the running app during debugging sessions.

### Debug Environment
- **Platform**: Chrome browser (flutter run -d chrome)
- **Hot Reload**: Available for rapid development
- **Debug Tools**: Chrome DevTools for Flutter debugging

## Build/Test Commands
```bash
# Flutter commands (run from /mobile directory)
flutter run -d chrome --release    # Run in Chrome browser
flutter build apk --debug          # Build Android debug APK
flutter test                       # Run unit tests
flutter analyze                    # Static analysis

# Backend commands (run from /backend directory)  
npm run dev                        # Local Cloudflare Workers development
npm run deploy                     # Deploy to Cloudflare
npm test                           # Run backend tests
```

## Key Files
- `mobile/lib/services/camera_service.dart` - Hybrid frame capture implementation
- `mobile/lib/screens/camera_screen.dart` - Camera UI with real preview
- `mobile/spike/frame_capture_approaches/` - Research prototypes and analysis
- `backend/src/` - Cloudflare Workers GIF creation logic

## Recent Decisions
**2024-12-16**: Selected Hybrid Frame Capture approach based on comprehensive prototype analysis
- Combines video recording + real-time streaming with intelligent fallback
- 87.5/100 confidence score from performance benchmarking
- Provides maximum reliability for production vine app

[See ./.claude/memories/ for universal standards]