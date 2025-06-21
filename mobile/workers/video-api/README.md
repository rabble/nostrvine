# NostrVine Video API

Video Metadata API for NostrVine - provides signed URLs for 6-second vine videos.

## API Endpoints

### `GET /api/video/{video_id}`
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

### `GET /health`
Health check endpoint.

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