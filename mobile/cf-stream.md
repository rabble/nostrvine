# Cloudflare Stream + Workers Video Caching Architecture

## Problem Statement

OpenVine currently streams videos directly from the open internet, causing:
- Server configuration errors (CoreMediaErrorDomain -12939 - byte range issues)
- Slow loading times and network timeouts  
- Inconsistent video quality and formats
- No adaptive bitrate streaming
- Poor caching and preloading performance

## Solution Architecture

Implement a **hybrid proactive/reactive video caching system** using Cloudflare Stream + Workers as a caching/proxy layer.

### Core Insight
Instead of purely reactive caching (wait for user requests), **proactively crawl the Nostr network** for video events and pre-process the most valuable content, falling back to reactive mode for edge cases.

## Technical Architecture

### Phase 1: Immediate Fix (2 weeks)
**Simple Proxy Worker** to fix byte-range issues without caching complexity.

```typescript
// /src/proxy-worker.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const videoUrl = url.searchParams.get('url');
    
    if (!videoUrl) {
      return new Response('Missing video URL', { status: 400 });
    }
    
    // Security pre-flight checks
    const headResponse = await fetch(videoUrl, { method: 'HEAD' });
    const contentLength = parseInt(headResponse.headers.get('content-length') || '0');
    const contentType = headResponse.headers.get('content-type') || '';
    
    // Reject if too large or not video
    if (contentLength > 200 * 1024 * 1024) { // 200MB limit
      return new Response('Video too large', { status: 413 });
    }
    
    if (!contentType.startsWith('video/')) {
      return new Response('Not a video file', { status: 415 });
    }
    
    // Proxy the request with fixed headers
    const response = await fetch(videoUrl, {
      headers: {
        ...request.headers,
        'Accept-Ranges': 'bytes',
        'User-Agent': 'OpenVine/1.0',
      },
    });
    
    // Fix response headers for video playback
    const headers = new Headers(response.headers);
    headers.set('Accept-Ranges', 'bytes');
    headers.set('Cache-Control', 'public, max-age=3600');
    
    return new Response(response.body, {
      status: response.status,
      headers,
    });
  }
};
```

### Phase 2: Integration with Existing Crawlers (2 weeks)

#### 2.1 Webhook Endpoint for Existing Crawlers

Since you already have Nostr crawling infrastructure, we'll create a webhook endpoint that your existing crawlers can send video events to:

```typescript
// /src/crawler-webhook.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }
    
    // Verify webhook signature from your crawler system
    const signature = request.headers.get('X-Webhook-Signature');
    if (!await this.verifySignature(request, signature, env.WEBHOOK_SECRET)) {
      return new Response('Unauthorized', { status: 401 });
    }
    
    const events = await request.json();
    
    // Process batch of video events from your crawler
    for (const event of events) {
      if (event.kind === 22 && this.hasVideoContent(event)) {
        await env.PRIORITIZATION_QUEUE.send({
          eventId: event.id,
          pubkey: event.pubkey,
          videoUrl: this.extractVideoUrl(event),
          createdAt: event.created_at,
          content: event.content,
          tags: event.tags,
        });
      }
    }
    
    return new Response('OK', { status: 200 });
  },
  
  async verifySignature(request: Request, signature: string, secret: string): Promise<boolean> {
    // Implement HMAC signature verification
    const body = await request.clone().text();
    const expectedSignature = await this.generateHMAC(body, secret);
    return signature === expectedSignature;
  },
  
  hasVideoContent(event: any): boolean {
    // Check if event contains video URL in content or tags
    const content = event.content.toLowerCase();
    const videoExtensions = ['.mp4', '.webm', '.mov', '.avi'];
    
    return videoExtensions.some(ext => content.includes(ext)) ||
           event.tags?.some((tag: string[]) => 
             tag[0] === 'url' && videoExtensions.some(ext => tag[1]?.includes(ext))
           );
  },
  
  extractVideoUrl(event: any): string | null {
    // Extract video URL from event content or tags
    const urlRegex = /(https?:\/\/[^\s]+\.(mp4|webm|mov|avi))/i;
    
    // Check content first
    const contentMatch = event.content.match(urlRegex);
    if (contentMatch) return contentMatch[1];
    
    // Check tags
    const urlTag = event.tags?.find((tag: string[]) => tag[0] === 'url');
    if (urlTag && urlTag[1]) return urlTag[1];
    
    return null;
  }
};
```

#### 2.2 Crawler Integration Configuration

Your existing crawlers would send batched video events to our webhook:

```bash
# Example webhook call from your crawler
curl -X POST https://video-ingest.nostrvine.workers.dev/webhook \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Signature: sha256=..." \
  -d '[
    {
      "id": "event_id_123",
      "kind": 22,
      "pubkey": "npub...",
      "created_at": 1699123456,
      "content": "Check out this video: https://example.com/video.mp4",
      "tags": [["url", "https://example.com/video.mp4"]]
    }
  ]'
```

#### 2.3 Integration Requirements

To integrate with your existing Nostr crawlers, we need:

1. **Webhook Endpoint**: Deploy our webhook endpoint for receiving video events
2. **Crawler Configuration**: Configure your crawlers to send video events to our webhook
3. **Event Filtering**: Your crawlers should send us events that contain video URLs (kind 22 or any event with video content)

**Example integration in your crawler:**
```python
# In your existing crawler code
import requests
import hmac
import hashlib

def send_video_events_to_nostrvine(events):
    webhook_url = "https://video-ingest.nostrvine.workers.dev/webhook"
    webhook_secret = "your-shared-secret"
    
    # Filter for video events
    video_events = [
        event for event in events 
        if has_video_content(event)
    ]
    
    if not video_events:
        return
    
    payload = json.dumps(video_events)
    signature = hmac.new(
        webhook_secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    
    response = requests.post(
        webhook_url,
        data=payload,
        headers={
            'Content-Type': 'application/json',
            'X-Webhook-Signature': f'sha256={signature}'
        }
    )
    
    return response.status_code == 200

def has_video_content(event):
    # Check if event contains video URLs
    content = event.get('content', '').lower()
    video_extensions = ['.mp4', '.webm', '.mov', '.avi']
    
    # Check content
    if any(ext in content for ext in video_extensions):
        return True
    
    # Check tags
    tags = event.get('tags', [])
    for tag in tags:
        if len(tag) >= 2 and tag[0] == 'url':
            if any(ext in tag[1].lower() for ext in video_extensions):
                return True
    
    return False
```

#### 2.4 Smart Ingestion Funnel

```typescript
// /src/prioritization-worker.ts
export default {
  async queue(batch: MessageBatch<any>, env: Env): Promise<void> {
    for (const message of batch.messages) {
      const { eventId, pubkey, videoUrl, createdAt } = message.body;
      
      // Layer 2: Trust & Engagement Analysis
      const trustScore = await this.getTrustScore(pubkey, videoUrl, env);
      const engagementScore = await this.getEngagementScore(eventId, env);
      
      const priority = this.calculatePriority(trustScore, engagementScore);
      
      if (priority === 'high') {
        // Immediate ingestion
        await env.INGEST_QUEUE.send({ eventId, videoUrl, priority: 'high' });
      } else if (priority === 'low') {
        // Off-peak ingestion
        await env.LOW_PRIORITY_QUEUE.send({ eventId, videoUrl, priority: 'low' });
      }
      // 'reject' priority is dropped
    }
  },
  
  async getTrustScore(pubkey: string, videoUrl: string, env: Env): Promise<number> {
    const domain = new URL(videoUrl).hostname;
    
    // Query trust scores from D1
    const pubkeyTrust = await env.DB.prepare(
      'SELECT score FROM trust_scores WHERE type = ? AND identifier = ?'
    ).bind('pubkey', pubkey).first();
    
    const domainTrust = await env.DB.prepare(
      'SELECT score FROM trust_scores WHERE type = ? AND identifier = ?'
    ).bind('domain', domain).first();
    
    const pubkeyScore = pubkeyTrust?.score || 50; // Default neutral
    const domainScore = domainTrust?.score || 50;
    
    return (pubkeyScore * 0.7) + (domainScore * 0.3);
  }
};
```

#### 2.3 Database Schema (Cloudflare D1)

```sql
-- Core video metadata
CREATE TABLE videos (
    event_id TEXT PRIMARY KEY,
    url_hash TEXT NOT NULL,
    stream_uid TEXT,
    r2_key TEXT,
    status TEXT NOT NULL CHECK (status IN ('INGESTING', 'AVAILABLE', 'FAILED', 'MODERATED')),
    created_at INTEGER NOT NULL,
    last_accessed_ts INTEGER,
    pubkey TEXT NOT NULL,
    source_url TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'low'
);

-- URL deduplication index
CREATE UNIQUE INDEX idx_videos_url_hash ON videos(url_hash);

-- Lifecycle management indexes
CREATE INDEX idx_videos_status_created ON videos(status, created_at);
CREATE INDEX idx_videos_last_accessed ON videos(last_accessed_ts);

-- Trust scoring
CREATE TABLE trust_scores (
    type TEXT NOT NULL CHECK (type IN ('pubkey', 'domain')),
    identifier TEXT NOT NULL,
    score INTEGER NOT NULL DEFAULT 50 CHECK (score >= 0 AND score <= 100),
    submissions INTEGER NOT NULL DEFAULT 0,
    violations INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (type, identifier)
);

-- URL reference counting for cleanup
CREATE TABLE url_references (
    url_hash TEXT PRIMARY KEY,
    stream_uid TEXT,
    ref_count INTEGER NOT NULL DEFAULT 0,
    first_seen INTEGER NOT NULL,
    last_accessed INTEGER
);
```

#### 2.5 Ingestion Worker

```typescript
// /src/ingest-worker.ts
export default {
  async queue(batch: MessageBatch<any>, env: Env): Promise<void> {
    for (const message of batch.messages) {
      await this.processVideo(message.body, env);
    }
  },
  
  async processVideo(data: any, env: Env): Promise<void> {
    const { eventId, videoUrl, priority } = data;
    const urlHash = await this.hashUrl(videoUrl);
    
    try {
      // Check if already exists
      const existing = await env.DB.prepare(
        'SELECT stream_uid FROM videos WHERE event_id = ? OR url_hash = ?'
      ).bind(eventId, urlHash).first();
      
      if (existing) {
        // Link this event to existing video
        await env.DB.prepare(
          'INSERT OR IGNORE INTO videos (event_id, url_hash, stream_uid, status, created_at, pubkey, source_url) VALUES (?, ?, ?, ?, ?, ?, ?)'
        ).bind(eventId, urlHash, existing.stream_uid, 'AVAILABLE', Date.now(), data.pubkey, videoUrl).run();
        return;
      }
      
      // Mark as ingesting
      await env.DB.prepare(
        'INSERT INTO videos (event_id, url_hash, status, created_at, pubkey, source_url, priority) VALUES (?, ?, ?, ?, ?, ?, ?)'
      ).bind(eventId, urlHash, 'INGESTING', Date.now(), data.pubkey, videoUrl, priority).run();
      
      // Upload to Cloudflare Stream
      const uploadResult = await this.uploadToStream(videoUrl, env);
      
      if (uploadResult.success) {
        // Update with stream UID
        await env.DB.prepare(
          'UPDATE videos SET stream_uid = ?, status = ? WHERE event_id = ?'
        ).bind(uploadResult.streamUid, 'AVAILABLE', eventId).run();
        
        // Update reference count
        await env.DB.prepare(
          'INSERT OR REPLACE INTO url_references (url_hash, stream_uid, ref_count, first_seen) VALUES (?, ?, COALESCE((SELECT ref_count FROM url_references WHERE url_hash = ?), 0) + 1, ?)'
        ).bind(urlHash, uploadResult.streamUid, urlHash, Date.now()).run();
      } else {
        // Mark as failed
        await env.DB.prepare(
          'UPDATE videos SET status = ? WHERE event_id = ?'
        ).bind('FAILED', eventId).run();
      }
      
    } catch (error) {
      console.error('Ingestion failed:', error);
    }
  },
  
  async uploadToStream(videoUrl: string, env: Env): Promise<{success: boolean, streamUid?: string}> {
    try {
      // Use Cloudflare Stream's "URL upload" feature
      const response = await fetch('https://api.cloudflare.com/client/v4/accounts/' + env.CLOUDFLARE_ACCOUNT_ID + '/stream/copy', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.CLOUDFLARE_API_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          url: videoUrl,
          meta: {
            name: `OpenVine Video`,
          },
        }),
      });
      
      const result = await response.json();
      
      if (result.success) {
        return { success: true, streamUid: result.result.uid };
      } else {
        return { success: false };
      }
    } catch (error) {
      return { success: false };
    }
  }
};
```

#### 2.6 User-Facing API

```typescript
// /src/video-api.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const eventId = url.pathname.split('/').pop();
    
    if (!eventId) {
      return new Response('Missing event ID', { status: 400 });
    }
    
    // Lookup video
    const video = await env.DB.prepare(
      'SELECT stream_uid, r2_key, status FROM videos WHERE event_id = ?'
    ).bind(eventId).first();
    
    if (!video) {
      // Fallback to reactive mode
      return this.handleReactiveRequest(eventId, env);
    }
    
    if (video.status !== 'AVAILABLE') {
      return new Response(JSON.stringify({ status: video.status }), { status: 202 });
    }
    
    // Update last accessed timestamp for lifecycle management
    await env.DB.prepare(
      'UPDATE videos SET last_accessed_ts = ? WHERE event_id = ?'
    ).bind(Date.now(), eventId).run();
    
    // Return stream URL
    const streamUrl = `https://videodelivery.net/${video.stream_uid}/manifest/video.m3u8`;
    
    return new Response(JSON.stringify({
      status: 'ready',
      url: streamUrl,
      adaptive: true,
    }), {
      headers: { 'Content-Type': 'application/json' },
    });
  },
  
  async handleReactiveRequest(eventId: string, env: Env): Promise<Response> {
    // TODO: Implement reactive fallback for videos not in cache
    // This handles the 0.01% of cases where proactive crawling missed something
    return new Response(JSON.stringify({ status: 'not_found' }), { status: 404 });
  }
};
```

### Phase 3: Lifecycle Management (2 weeks)

#### 3.1 Content Cleanup Worker

```typescript
// /src/cleanup-worker.ts
export default {
  async scheduled(event: ScheduledEvent, env: Env): Promise<void> {
    const fourteenDaysAgo = Date.now() - (14 * 24 * 60 * 60 * 1000);
    const ninetyDaysAgo = Date.now() - (90 * 24 * 60 * 60 * 1000);
    
    // Delete unwatched videos after 14 days
    const unwatchedVideos = await env.DB.prepare(
      'SELECT event_id, stream_uid FROM videos WHERE created_at < ? AND last_accessed_ts IS NULL'
    ).bind(fourteenDaysAgo).all();
    
    for (const video of unwatchedVideos.results) {
      await this.deleteVideo(video.stream_uid, env);
      await env.DB.prepare('DELETE FROM videos WHERE event_id = ?').bind(video.event_id).run();
    }
    
    // Move old watched videos to R2 storage
    const oldVideos = await env.DB.prepare(
      'SELECT event_id, stream_uid FROM videos WHERE last_accessed_ts < ? AND r2_key IS NULL'
    ).bind(ninetyDaysAgo).all();
    
    for (const video of oldVideos.results) {
      const r2Key = await this.moveToR2(video.stream_uid, env);
      if (r2Key) {
        await env.DB.prepare(
          'UPDATE videos SET r2_key = ?, stream_uid = NULL WHERE event_id = ?'
        ).bind(r2Key, video.event_id).run();
      }
    }
  },
  
  async deleteVideo(streamUid: string, env: Env): Promise<void> {
    await fetch(`https://api.cloudflare.com/client/v4/accounts/${env.CLOUDFLARE_ACCOUNT_ID}/stream/${streamUid}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${env.CLOUDFLARE_API_TOKEN}`,
      },
    });
  }
};
```

## Mobile App Integration

### Changes Required

1. **Video URL Resolution Service**
```dart
class VideoUrlResolver {
  static const String _baseUrl = 'https://video-api.nostrvine.workers.dev';
  
  Future<String?> resolveVideoUrl(String eventId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/video/$eventId'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'];
      } else if (response.statusCode == 202) {
        // Video is processing, show loading state
        return null;
      }
    } catch (e) {
      // Fallback to original URL from Nostr event
      return _extractOriginalUrl(eventId);
    }
    
    return null;
  }
}
```

2. **VideoPlayerController Integration**
```dart
// In VideoFeedProvider
Future<void> _loadVideo(VideoEvent event) async {
  final resolvedUrl = await VideoUrlResolver().resolveVideoUrl(event.id);
  
  if (resolvedUrl != null) {
    // Use resolved Cloudflare Stream URL
    final controller = VideoPlayerController.network(resolvedUrl);
    await controller.initialize();
    // ... rest of video loading logic
  } else {
    // Show loading state or use fallback
    _showVideoProcessingState(event);
  }
}
```

## Cost Optimization

### Tiered Storage Strategy
1. **Hot Tier (Cloudflare Stream)**: New and frequently accessed videos
2. **Warm Tier (R2)**: Older videos moved after 90 days of no access
3. **Cold Tier (Deleted)**: Completely removed after extended periods

### Cost Controls
- **Content Filtering**: Only ingest videos from trusted sources initially
- **Engagement-Based Priority**: Higher engagement = higher retention priority
- **Regional Optimization**: Cache popular content globally, niche content regionally
- **Quality Settings**: Use compressed quality settings for cost savings

## Security & Content Moderation

### Security Measures
1. **Request Authentication**: Bearer tokens for API access
2. **Rate Limiting**: 10 videos per hour per pubkey for submissions
3. **Content Validation**: File size, type, and duration limits
4. **Domain Filtering**: Blocklist/allowlist for source domains

### Content Moderation
1. **Automated Scanning**: Enable Cloudflare Stream's built-in content moderation
2. **Trust Scoring**: Dynamic scoring based on user behavior and content quality
3. **DMCA Compliance**: Automated takedown mechanisms
4. **Community Reporting**: Integration with Nostr's reporting mechanisms

## Migration Strategy

### Phased Rollout
1. **Phase 1 (2 weeks)**: Deploy proxy worker with feature flag (1% of users)
2. **Phase 2 (2 weeks)**: Integrate with existing crawlers and deploy ingestion system (10% of users)
3. **Phase 3 (2 weeks)**: Full lifecycle management and optimization (50% of users)
4. **Phase 4 (1 week)**: 100% rollout with monitoring

**Total Timeline: 7 weeks** (reduced from 12 weeks due to existing crawler infrastructure)

### Success Metrics
- **Video Load Time**: <2s for cached videos, <10s for first-time processing
- **Cache Hit Rate**: >99% for videos older than 1 hour
- **Cost Target**: <$1000/month for 100K videos
- **Reliability**: >99.9% API availability

## Monitoring & Observability

### Key Metrics
1. **Crawler Health**: Relay connection status, events processed per hour
2. **Ingestion Performance**: Queue depth, processing time, success rate
3. **API Performance**: Response times, cache hit rates, error rates
4. **Cost Tracking**: Stream storage costs, bandwidth costs, processing costs
5. **User Experience**: Video start times, playback success rates

### Alerting
- Crawler disconnections from major relays
- High ingestion queue backlog
- API error rates above threshold
- Cost exceeding budget thresholds

This architecture provides a robust, scalable solution that eliminates the current video streaming reliability issues while maintaining cost control and providing excellent user experience through proactive content preparation.