# OpenVine Video API

Video Metadata API for OpenVine (formerly NostrVine) - provides signed URLs for 6-second vine videos with support for both Cloudflare Stream and Cloudinary processing.

**Production URL**: https://api.openvine.co  
**Staging URL**: https://staging-api.openvine.co

## API Endpoints

### Video Retrieval

#### `GET /api/video/{video_id}`
Returns metadata and signed URLs for a specific video.

**Response:**
```json
{
  "videoId": "abc123...",
  "duration": 6.0,
  "renditions": {
    "480p": "https://signed-url-480p",
    "720p": "https://signed-url-720p"
  },
  "poster": "https://signed-url-poster"
}
```

### Video Upload (Cloudinary - Recommended)

#### `POST /v1/media/cloudinary/request-upload`
Request signed upload parameters for direct client upload to Cloudinary.

**Request:**
```json
{
  "fileType": "video/mp4",
  "maxFileSize": 104857600
}
```

**Response:**
```json
{
  "signature": "sha1-hash",
  "timestamp": 1234567890,
  "api_key": "your-api-key",
  "cloud_name": "your-cloud-name",
  "upload_preset": "nostrvine_video_uploads",
  "context": "pubkey=hex-pubkey"
}
```

#### `GET /v1/media/ready-events`
Poll for processed videos ready for Nostr publishing (requires NIP-98 auth).

#### `DELETE /v1/media/ready-events`
Remove a ready event after processing (requires NIP-98 auth).

### Video Status Polling

#### `GET /v1/media/status/{videoId}`
Check processing status of an uploaded video (videoId must be UUID v4).

**Response (Published):**
```json
{
  "status": "published",
  "hlsUrl": "https://customer-xxx.cloudflarestream.com/.../manifest/video.m3u8",
  "dashUrl": "https://customer-xxx.cloudflarestream.com/.../manifest/video.mpd",
  "thumbnailUrl": "https://customer-xxx.cloudflarestream.com/.../thumbnails/thumbnail.jpg",
  "createdAt": "2024-01-01T12:00:00.000Z"
}
```

**Other Statuses:**
- `pending_upload` - Waiting for video upload
- `processing` - Video being processed
- `failed` - Processing failed (includes error message)
- `quarantined` - Video flagged by moderation

### Video Upload (Cloudflare Stream - Deprecated)

#### `POST /v1/media/request-upload`
Request upload URL for Cloudflare Stream (being phased out).

### Batch Operations

#### `POST /api/videos/batch`
Fetch multiple videos in a single request.

### Feed & Discovery

#### `GET /api/feed`
Get personalized video feed with smart recommendations.

### Analytics & Monitoring

#### `GET /health`
Health check endpoint with comprehensive system status.

#### `GET /api/performance`
Performance metrics and optimization recommendations.

#### `GET /api/analytics/dashboard`
Analytics dashboard (requires authentication).

## Development

### Setup
```bash
npm install
```

### Local Development
```bash
# Start local dev server
npm run dev

# Or use wrangler directly
wrangler dev
```

### Seed Test Data
```bash
# Generate KV seed commands
node scripts/seed-kv.js

# Then run the generated commands to seed KV
```

### Testing
```bash
npm test
```

### Deployment
```bash
# Deploy to staging
wrangler publish --env staging

# Deploy to production
wrangler publish --env production
```

## Architecture Notes

- Video IDs are SHA256 hashes (64 hex characters)
- Signed URLs expire after 5 minutes
- Videos stored in R2: `/videos/{video_id}/{quality}.mp4`
- Metadata stored in KV with key: `video:{video_id}`

## For Other Agents

This is the foundation API that provides video metadata. Other components depend on this:
- Batch API (#130) will call this internally
- Mobile app (#127) will consume these URLs
- Make sure video ID format is consistent (SHA256 of video URL)