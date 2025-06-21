# NostrVine Video Caching System - Implementation Guide

## Overview
This document describes the implemented video caching system for NostrVine's 6-second videos, optimized for instant playback and Nostr-driven discovery.

## Architecture Summary

### Key Architectural Decision: Client-Driven Discovery
Unlike traditional feed-based systems, NostrVine uses a **decentralized approach**:
1. **Video Discovery**: Clients discover videos through Nostr relay subscriptions
2. **Metadata Lookup**: Clients batch request metadata from our API
3. **Content Delivery**: Server provides signed URLs for secure video access

## Implemented APIs

### 1. Single Video Metadata API
**Endpoint**: `GET /api/video/{video_id}`

**Purpose**: Retrieve metadata for a single video with signed R2 URLs

**Response**:
```json
{
  "videoId": "abc123...",
  "duration": 6.0,
  "renditions": {
    "480p": "https://signed-url/video_480.mp4?X-Signature=...",
    "720p": "https://signed-url/video_720.mp4?X-Signature=..."
  },
  "poster": "https://signed-url/poster.jpg?X-Signature=..."
}
```

### 2. Batch Video Lookup API
**Endpoint**: `POST /api/videos/batch`

**Purpose**: Efficiently retrieve metadata for multiple videos (up to 50)

**Request**:
```json
{
  "videoIds": ["video123", "video456", "video789"],
  "quality": "auto"  // "auto" | "480p" | "720p"
}
```

**Response**:
```json
{
  "videos": {
    "video123": {
      "videoId": "video123",
      "duration": 6.0,
      "renditions": {
        "480p": "https://signed-url/...",
        "720p": "https://signed-url/..."
      },
      "poster": "https://signed-url/...",
      "available": true
    },
    "video456": {
      "videoId": "video456",
      "available": false,
      "reason": "not_found"
    }
  },
  "found": 1,
  "missing": 1
}
```

## Video ID Generation
Video IDs are SHA256 hashes of the original video URL:
```javascript
async function generateVideoId(url: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(url);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}
```

## Storage Architecture

### KV Metadata Store
- **Key Format**: `video:{videoId}`
- **TTL**: 30 days
- **Content**: Video metadata including duration, sizes, and paths

### R2 Object Storage
- **Structure**:
  ```
  videos/
    {videoId}/
      480p.mp4
      720p.mp4
  posters/
    {videoId}.jpg
  ```

### URL Signing
- **Expiry**: 5 minutes (300 seconds)
- **Security**: HMAC-SHA256 signatures
- **Prevents**: Hotlinking and unauthorized access

## Performance Optimizations

### 1. Request-Level Caching
```javascript
// In-memory cache for request lifecycle
const requestCache = new Map<string, VideoMetadata>();
```

### 2. CDN Cache Headers
```javascript
'Cache-Control': 'public, max-age=60, s-maxage=300',  // 1 min browser, 5 min CDN
'CDN-Cache-Control': 'max-age=300'  // Cloudflare specific
```

### 3. Parallel Processing
- Batch API processes all video lookups in parallel
- URL signing happens concurrently for all renditions

## Flutter Integration Guide

### Important: API Mismatch
The Flutter service (Issue #127) expects a feed-based API, but our implementation is client-driven. Here's how to integrate:

### 1. Replace Feed API with Nostr Discovery
Instead of:
```dart
final response = await _dio.get('/api/feed');
```

Use:
```dart
// 1. Get video IDs from Nostr events
final videoIds = await nostrService.getLatestVideoIds();

// 2. Batch request metadata
final response = await _dio.post('/api/videos/batch', data: {
  'videoIds': videoIds,
  'quality': _getQualityForNetwork()
});
```

### 2. Video Service Adapter
Create an adapter to bridge the architectural difference:

```dart
class VideoStreamService {
  final NostrService _nostrService;
  final Dio _dio;
  
  Future<List<VideoItem>> getVideoFeed({String? cursor, int limit = 10}) async {
    // Get video events from Nostr
    final events = await _nostrService.getVideoEvents(
      since: cursor,
      limit: limit * 2  // Request more to account for unavailable videos
    );
    
    // Extract video IDs
    final videoIds = events.map((e) => extractVideoId(e)).toList();
    
    // Batch fetch metadata
    final response = await _dio.post('/api/videos/batch', data: {
      'videoIds': videoIds.take(50).toList(),  // API limit
      'quality': 'auto'
    });
    
    // Convert to VideoItem list
    final videos = <VideoItem>[];
    final videosData = response.data['videos'] as Map<String, dynamic>;
    
    for (final entry in videosData.entries) {
      if (entry.value['available'] == true) {
        videos.add(VideoItem.fromMetadata(entry.value));
      }
    }
    
    return videos.take(limit).toList();
  }
}
```

### 3. Prefetching Strategy
Since we don't have server-side feed recommendations, implement client-side prefetching:

```dart
void prefetchNextVideos(List<String> currentVideoIds) async {
  // Get next set of video IDs from Nostr
  final upcomingEvents = await _nostrService.getUpcomingVideoEvents();
  final upcomingIds = upcomingEvents.map((e) => extractVideoId(e)).toList();
  
  // Batch prefetch metadata
  await _dio.post('/api/videos/batch', data: {
    'videoIds': upcomingIds.take(5).toList(),
    'quality': _getQualityForNetwork()
  });
}
```

## Deployment Instructions

### 1. Deploy to Cloudflare Workers

```bash
cd backend

# Install dependencies
npm install

# Configure KV namespace
wrangler kv:namespace create "METADATA_CACHE"

# Update wrangler.jsonc with the namespace ID

# Deploy to staging
wrangler deploy --env staging

# Deploy to production
wrangler deploy --env production
```

### 2. Configure R2 Buckets

```bash
# Create R2 buckets
wrangler r2 bucket create nostrvine-media
wrangler r2 bucket create nostrvine-cache

# Set up CORS for R2 (if serving directly)
wrangler r2 bucket cors put nostrvine-media --config cors.json
```

### 3. Environment Variables

Set these secrets:
```bash
wrangler secret put R2_SIGNING_KEY
wrangler secret put CLOUDFLARE_ACCOUNT_ID
```

### 4. Populate Test Data

For development, use the test data population function:
```javascript
// In video-cache-api.ts
await populateTestData(env);
```

## Testing the Implementation

### 1. Test Single Video API
```bash
curl https://your-worker.workers.dev/api/video/[video-id]
```

### 2. Test Batch API
```bash
curl -X POST https://your-worker.workers.dev/api/videos/batch \
  -H "Content-Type: application/json" \
  -d '{
    "videoIds": ["id1", "id2", "id3"],
    "quality": "auto"
  }'
```

### 3. Verify URL Signing
- Check that URLs expire after 5 minutes
- Verify signatures prevent URL tampering

## Monitoring and Analytics

### Key Metrics to Track
1. **Cache Hit Rate**: Should exceed 95% for popular videos
2. **Response Times**: Target <200ms for batch requests
3. **URL Generation Time**: Should be <50ms per video
4. **KV Operation Latency**: Monitor for performance issues

### Cloudflare Analytics
```javascript
// Track in your worker
ctx.waitUntil(
  env.ANALYTICS.writeDataPoint({
    blobs: ['batch_request'],
    doubles: [videos.length, responseTime],
    indexes: ['video_cache']
  })
);
```

## Common Issues and Solutions

### 1. Video Not Found
- Ensure video metadata is properly stored in KV
- Check that R2 objects exist at expected paths
- Verify video ID generation matches between upload and retrieval

### 2. Slow Response Times
- Increase KV caching TTL
- Implement request-level caching
- Use Promise.all() for parallel operations

### 3. CORS Issues
- All API endpoints include proper CORS headers
- OPTIONS requests are handled for preflight

## Future Enhancements

1. **Edge Caching**: Implement Cloudflare Cache API for metadata
2. **Adaptive Bitrate**: Add HLS streaming for longer videos
3. **Analytics Integration**: Track popular videos for better prefetching
4. **Regional Optimization**: Use Cloudflare's geographic routing

## Coordination with Other Teams

### Backend Team
- Ensure video upload process generates correct metadata format
- Coordinate on video ID generation method
- Align on R2 bucket structure

### Flutter Team
- Implement Nostr-based video discovery
- Adapt feed expectations to batch API model
- Use quality hints based on network conditions

### Testing Team
- Create end-to-end tests for video playback flow
- Load test batch API with 50 video requests
- Verify CDN caching behavior

## Summary

The video caching system is fully implemented with:
- ✅ Single and batch video metadata APIs
- ✅ Secure R2 URL signing with 5-minute expiry
- ✅ KV-based metadata storage
- ✅ CDN-optimized caching headers
- ✅ CORS support for mobile apps
- ✅ Parallel processing for performance

The main architectural difference from the original plan is the shift from server-side feeds to client-driven discovery via Nostr, which better aligns with the decentralized nature of the platform.