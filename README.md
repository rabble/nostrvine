# NostrVine

**A Nostr-based vine-like video sharing Flutter app.**

A decentralized, short-form video sharing mobile application built on the Nostr protocol, inspired by the simplicity and creativity of Vine.

## Features

- **Decentralized**: Built on Nostr protocol for censorship resistance
- **Video Sharing**: Short-form video content (6-15 seconds)
- **Social Features**: Follow, like, comment, and share
- **Cross-Platform**: Flutter app for iOS and Android
- **Open Source**: Fully open source and transparent

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
- **Protocol**: Nostr for decentralized data
- **Platforms**: iOS and Android

**Backend:**
- **Runtime**: Cloudflare Workers
- **Storage**: Cloudflare R2
- **Processing**: WebAssembly + JavaScript
- **API**: RESTful endpoints

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Implement the feature
5. Ensure all tests pass
6. Submit a pull request

## License

ISC License