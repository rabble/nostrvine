Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Backend API Reference

ABOUTME: Complete reference for OpenVine backend API endpoints across both workers
ABOUTME: Documents domain separation, authentication, request/response formats for all APIs

This document provides comprehensive documentation for OpenVine's backend API endpoints. OpenVine uses two separate Cloudflare Workers deployed to different domains:

## Domain Architecture

| Domain | Purpose | Authentication | Rate Limiting |
|--------|---------|---------------|---------------|
| `api.openvine.co` | Core backend services (includes analytics) | NIP-98 for uploads | Standard |

## Main Backend API (`api.openvine.co`)

### Authentication

Most upload and modification endpoints require NIP-98 authentication:
- Include `Authorization` header with NIP-98 signed event
- Event should contain request details and signature
- See [NIP-98 specification](https://github.com/nostr-protocol/nips/blob/master/98.md) for details

### File Upload & Media

#### Upload Video
```http
POST /api/upload
Content-Type: multipart/form-data
Authorization: Nostr <base64-encoded-event>

file: <video-file>
alt?: <description>
content_type?: <mime-type>
```

**Response:**
```json
{
  "status": "success", 
  "message": "Upload initiated",
  "nip94_event": {...},
  "jobId": "uuid"
}
```

#### Import Video from URL
```http
POST /api/import-url
Content-Type: application/json

{
  "url": "https://example.com/video.mp4",
  "alt": "Video description"
}
```

#### Check Upload Status
```http
GET /api/status/{jobId}
```

**Response:**
```json
{
  "status": "completed|processing|failed",
  "progress": 85,
  "fileId": "abc123",
  "error": "Error message if failed"
}
```

#### Check File Exists
```http
GET /api/check-hash/{sha256}
```

**Response:**
```json
{
  "exists": true,
  "fileId": "abc123",
  "uploadedAt": "2025-01-01T00:00:00Z"
}
```

#### Serve Media
```http
GET /media/{fileId}
```
Returns the actual media file with appropriate headers.

### Video Management (Cloudflare Stream)

#### Request Upload URL
```http
POST /v1/media/request-upload
Content-Type: application/json

{
  "filename": "video.mp4",
  "contentType": "video/mp4"
}
```

**Response:**
```json
{
  "uploadURL": "https://upload.videodelivery.net/...",
  "uid": "video-id"
}
```

#### Stream Processing Webhook
```http
POST /v1/webhooks/stream-complete
Content-Type: application/json

{
  "uid": "video-id",
  "status": "ready",
  "meta": {...}
}
```

#### Video Processing Status
```http
GET /v1/media/status/{videoId}
```

**Response:**
```json
{
  "status": "ready|encoding|error",
  "preview": "https://customer-...-watch.videodelivery.net/...",
  "thumbnail": "https://customer-...-thumb.videodelivery.net/..."
}
```

### Video Cache & Lookup

#### Get Video Metadata
```http
GET /api/video/{videoId}
```

**Response:**
```json
{
  "id": "video-id",
  "title": "Video Title",
  "duration": 6.3,
  "thumbnail": "https://...",
  "url": "https://...",
  "uploadedAt": "2025-01-01T00:00:00Z"
}
```

#### Batch Video Lookup
```http
POST /api/videos/batch
Content-Type: application/json

{
  "videoIds": ["id1", "id2", "id3"]
}
```

**Response:**
```json
{
  "videos": [
    {"id": "id1", ...},
    {"id": "id2", ...}
  ],
  "notFound": ["id3"]
}
```

### Thumbnails

#### Get/Generate Thumbnail
```http
GET /thumbnail/{videoId}
```
Returns JPEG image or generates one if not cached.

#### Upload Custom Thumbnail
```http
POST /thumbnail/{videoId}/upload
Content-Type: multipart/form-data
Authorization: Nostr <base64-encoded-event>

thumbnail: <image-file>
```

#### List Available Thumbnails
```http
GET /thumbnail/{videoId}/list
```

**Response:**
```json
{
  "thumbnails": [
    {
      "type": "auto",
      "url": "https://...",
      "timestamp": 3.15
    },
    {
      "type": "custom", 
      "url": "https://...",
      "uploadedAt": "2025-01-01T00:00:00Z"
    }
  ]
}
```

### NIP-05 Identity

#### NIP-05 Verification
```http
GET /.well-known/nostr.json?name={username}
```

**Response:**
```json
{
  "names": {
    "username": "npub1..."
  }
}
```

#### Register NIP-05 Username
```http
POST /api/nip05/register
Content-Type: application/json

{
  "username": "alice",
  "pubkey": "npub1...",
  "signature": "..."
}
```

### Feature Flags

#### List Feature Flags
```http
GET /api/feature-flags
```

**Response:**
```json
{
  "flags": [
    {
      "name": "new_camera",
      "enabled": true,
      "rollout": 50
    }
  ]
}
```

#### Check Feature Flag
```http
GET /api/feature-flags/{flagName}/check?user={userId}
```

**Response:**
```json
{
  "enabled": true,
  "variant": "control|treatment"
}
```

### Content Moderation

#### Report Content
```http
POST /api/moderation/report
Content-Type: application/json

{
  "contentId": "video-id",
  "reason": "spam|inappropriate|copyright",
  "details": "Additional information"
}
```

#### Check Moderation Status
```http
GET /api/moderation/status/{videoId}
```

**Response:**
```json
{
  "status": "approved|pending|rejected",
  "reason": "Violation details if rejected"
}
```

## Analytics API (`api.openvine.co/analytics`)

### View Tracking

#### Track Video View
```http
POST /analytics/view
Content-Type: application/json

{
  "eventId": "nostr-event-id",
  "userId": "optional-user-id",
  "source": "feed|explore|profile",
  "creatorPubkey": "creator-pubkey",
  "hashtags": ["tag1", "tag2"],
  "title": "Video title",
  "eventType": "view_start|view_end|view_complete",
  "watchDuration": 3.2,
  "totalDuration": 6.3,
  "loopCount": 2,
  "completedVideo": true
}
```

**Response:**
```json
{
  "status": "tracked",
  "timestamp": "2025-01-01T00:00:00Z"
}
```

### Trending Content

#### Get Trending Videos
```http
GET /analytics/trending/vines?limit=20
```

**Response:**
```json
{
  "vines": [
    {
      "eventId": "...",
      "score": 95.5,
      "views": 1250,
      "engagement": 0.15,
      "velocity": 0.8
    }
  ],
  "algorithm": "global_popularity",
  "updatedAt": 1640995200000,
  "period": "24h",
  "totalVines": 45
}
```

#### Get Trending Creators
```http
GET /analytics/trending/viners?limit=10
```

**Response:**
```json
{
  "viners": [
    {
      "pubkey": "...",
      "score": 88.2,
      "totalViews": 15000,
      "videoCount": 12,
      "avgEngagement": 0.18
    }
  ],
  "algorithm": "creator_momentum",
  "updatedAt": 1640995200000
}
```

#### Get Velocity Trending
```http
GET /analytics/trending/velocity?timeframe=1h
```

**Response:**
```json
{
  "videos": [
    {
      "eventId": "...",
      "velocityScore": 0.95,
      "currentViews": 500,
      "previousViews": 50,
      "growthRate": 9.0
    }
  ],
  "timeframe": "1h"
}
```

### Video Analytics

#### Get Video Statistics
```http
GET /analytics/video/{eventId}/stats
```

**Response:**
```json
{
  "eventId": "...",
  "views": 1250,
  "uniqueViewers": 890,
  "completionRate": 0.75,
  "averageWatchTime": 4.2,
  "loopCount": 2840,
  "lastUpdate": "2025-01-01T00:00:00Z"
}
```

### Hashtag Analytics

#### Get Hashtag Trending
```http
GET /analytics/hashtag/{hashtag}/trending?limit=20
```

**Response:**
```json
{
  "hashtag": "funny",
  "videos": [
    {
      "eventId": "...",
      "score": 82.1,
      "views": 890,
      "recency": 0.9
    }
  ],
  "totalVideos": 156
}
```

#### Get Trending Hashtags
```http
GET /analytics/hashtags/trending?limit=10
```

**Response:**
```json
{
  "hashtags": [
    {
      "tag": "funny",
      "score": 95.2,
      "videoCount": 156,
      "totalViews": 45000,
      "momentum": 1.8
    }
  ]
}
```

### Health Check

#### Service Health
```http
GET /analytics/health
```

**Response:**
```json
{
  "status": "healthy",
  "environment": "production",
  "timestamp": "2025-01-01T00:00:00Z"
}
```

## Error Responses

All endpoints return standardized error responses:

```json
{
  "error": "Error type",
  "message": "Human readable description", 
  "code": 400,
  "details": "Additional error context"
}
```

Common HTTP status codes:
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (missing/invalid auth)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found (resource doesn't exist)
- `429` - Too Many Requests (rate limited)
- `500` - Internal Server Error

## Rate Limiting

| Endpoint Category | Limit | Window |
|-------------------|-------|--------|
| File uploads | 10 uploads | 1 hour |
| Analytics tracking | 1000 events | 1 minute |
| API queries | 100 requests | 1 minute |
| Admin operations | 10 requests | 1 minute |

Rate limit headers are included in responses:
- `X-RateLimit-Limit` - Maximum requests allowed
- `X-RateLimit-Remaining` - Requests remaining
- `X-RateLimit-Reset` - Reset timestamp

## Development

For local development, both workers can be run with:

```bash
# Main backend
cd backend && wrangler dev

# Analytics worker  
cd analytics-worker && wrangler dev
```

The workers will be available at:
- Main backend: `http://localhost:8787`
- Analytics: `http://localhost:8788`