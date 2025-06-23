# OpenVine

**A decentralized vine-like video sharing app powered by Nostr.**

OpenVine is a decentralized, short-form video sharing mobile application built on the Nostr protocol, inspired by the simplicity and creativity of Vine.

## App Screenshots

<div align="center">
  
### 📱 Mobile Experience
  
<img src="mobile/screenshots/feed-screen.png" alt="Video Feed - Zappix Flix uploads video" width="300"/>
<img src="mobile/screenshots/explore-screen.png" alt="Explore Screen - Browse trending content with hashtags" width="300"/>
<img src="mobile/screenshots/video-player.png" alt="Video Player - Immersive full-screen viewing" width="300"/>

*Experience Vine-style short videos with seamless social features and decentralized content sharing*

**Features shown:** Feed navigation • Hashtag filtering • Video interactions • Social sharing • Real-time content discovery

</div>

## Recent Updates ✨

- **Enhanced Activity Screen**: Video thumbnails in activity notifications are now clickable and open videos in the full player
- **Fixed Video Loading**: Resolved issues with videos getting stuck on loading screen
- **Domain Correction**: Automatic fixing of legacy URL domain issues for seamless video playback
- **Improved Share Menu**: Comprehensive video sharing with content reporting and list management
- **Better Error Handling**: User-friendly error messages and validation for video URLs

## Features

### Core Features
- **Decentralized**: Built on Nostr protocol for censorship resistance
- **Vine-Style Recording**: Short-form video content (6.3 seconds like original Vine)
- **Cross-Platform**: Flutter app for iOS, Android, and Web
- **Real-Time Social**: Follow, like, comment, repost, and share videos
- **Open Source**: Fully open source and transparent

### Video Features
- **Multi-Platform Camera**: Supports iOS, Android, macOS, and Web recording
- **Segmented Recording**: Press-and-hold recording with pause/resume capability
- **Auto-Upload**: Direct video upload to Cloudflare R2 with CDN serving
- **Thumbnail Generation**: Automatic video thumbnail creation
- **Progressive Loading**: Smart video preloading and caching

### Social Features
- **Activity Feed**: Real-time notifications for likes, follows, and interactions
- **Video Sharing**: Comprehensive sharing menu with external app support
- **Content Curation**: Create and manage curated video lists (NIP-51)
- **Content Reporting**: Apple-compliant content moderation and reporting
- **Direct Messaging**: Share videos privately with other users

### Technical Features
- **Nostr Integration**: Full NIP compliance (NIP-01, NIP-02, NIP-18, NIP-25, NIP-71)
- **Offline Support**: Queue uploads and sync when connection restored
- **Error Recovery**: Robust error handling with automatic retry mechanisms
- **Performance Optimized**: Efficient video management with memory limits

## Project Structure

```
nostrvine/
├── mobile/          # Flutter mobile application
├── backend/         # Cloudflare Workers backend
├── docs/           # Documentation and planning
└── README.md       # This file
```

## Quick Start

### Mobile App
```bash
cd mobile
flutter pub get
flutter run
```

### Backend
```bash
cd backend
npm install
wrangler dev
```

## Development

### Prerequisites

**Mobile App:**
- Flutter SDK (latest stable)
- Dart SDK
- iOS development: Xcode
- Android development: Android Studio

**Backend:**
- Node.js (latest LTS)
- Cloudflare account
- Wrangler CLI

### Available Commands

**Mobile:**
- `flutter run` - Run the app
- `flutter build` - Build for production
- `flutter test` - Run tests
- `flutter analyze` - Analyze code

**Backend:**
- `wrangler dev` - Local development
- `wrangler publish` - Deploy to Cloudflare
- `npm test` - Run tests

## Architecture

**Mobile App:**
- **Framework**: Flutter with Dart
- **Protocol**: Nostr for decentralized social networking
- **Platforms**: iOS, Android, macOS, and Web
- **Video Processing**: Multi-platform camera with segmented recording
- **State Management**: Provider pattern with reactive data flow
- **Storage**: Hive for local data persistence

**Backend:**
- **Runtime**: Cloudflare Workers (serverless)
- **Storage**: Cloudflare R2 for video hosting
- **CDN**: Global video delivery via Cloudflare
- **Processing**: Direct video upload with thumbnail generation
- **API**: RESTful endpoints with NIP-98 authentication

**Nostr Integration:**
- **Event Types**: Kind 22 (videos), Kind 6 (reposts), Kind 0 (profiles)
- **NIPs Supported**: NIP-01, NIP-02, NIP-18, NIP-25, NIP-71, NIP-94, NIP-98
- **Relays**: Multi-relay support for redundancy and performance

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Implement the feature
5. Ensure all tests pass
6. Submit a pull request

## License

ISC License