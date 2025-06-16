# NostrVine Backend

Cloudflare Workers-based serverless backend for processing image sequences into animated GIFs and videos.

## Features
- Image frame processing using WebAssembly
- GIF creation from image sequences
- R2 storage integration for media files
- Caching layer for optimized performance
- RESTful API for mobile app integration

## Getting Started

### Prerequisites
- Node.js (latest LTS version)
- Cloudflare account with Workers and R2 enabled
- Wrangler CLI for deployment

### Installation
```bash
cd backend
npm install
wrangler dev
```

### Deployment
```bash
wrangler publish
```

## Architecture
- **src/**: Main application source code
- **src/handlers/**: API endpoint handlers
- **src/services/**: Business logic services
- **src/utils/**: Utility functions
- **types/**: TypeScript type definitions
- **wrangler.toml**: Cloudflare Workers configuration