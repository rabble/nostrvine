# Agentic Programming Plan: Cloudflare Video Caching for Short-Form Content
## Build Today in 6 Hours Using Claude Code

## Executive Summary

**CRITICAL INSIGHT**: These are 6-second vine videos (1-10MB each), NOT long-form content! This dramatically simplifies our architecture.

**SIMPLIFIED STRATEGY**: 
- Store entire videos in R2 (no chunking needed)
- Use aggressive multi-tier caching (L1: Device, L2: CDN Edge, L3: R2)
- Focus on instant playback and smart prefetching

**Today's Goal**: Build a fast, simple video delivery system optimized for short-form content consumption patterns.

## Agentic Development Strategy

### Core Principles
1. **Simplicity First**: 6-second videos eliminate complex chunking logic
2. **Instant Playback**: Videos should start immediately from cache
3. **Smart Prefetching**: Preload next 3-5 videos as user scrolls
4. **Mobile Optimized**: Multiple quality renditions for different network conditions

## Technical Architecture

### Simplified Storage Strategy
- **Cloudflare R2**: Stores complete video files (1-10MB each)
- **Cloudflare KV**: Video metadata and rendition URLs
- **CDN Edge Cache**: Automatic caching of popular videos at edge locations
- **Device Cache**: Client-side caching of recently viewed videos

### Request Flow
```
Mobile App → Check Device Cache → CDN Edge Cache → CF Worker → 
Check R2 → Return Signed URL → Prefetch Next Videos
```

## 6-Hour Implementation Plan

### Phase 1: Simple Video Delivery (1.5 hours)
**Goal**: Basic video serving from R2 with CDN caching

#### Task 1.1: Video Metadata API (30 minutes)
```typescript
// Prompt for Claude Code:
Create a Cloudflare Worker that serves video metadata and signed URLs.

Requirements:
- Handle GET /api/video/{video_id} requests
- Return JSON with video metadata and signed R2 URL
- Support multiple quality renditions (480p, 720p)
- Add short-lived URL signing (5 minute expiry)
- Handle missing videos gracefully

Response format:
{
  "videoId": "abc123",
  "duration": 6.0,
  "renditions": {
    "480p": "https://r2-signed-url/video_480.mp4",
    "720p": "https://r2-signed-url/video_720.mp4"
  },
  "poster": "https://r2-signed-url/poster.jpg"
}

File: src/video-api.ts
```

#### Task 1.2: Smart Feed API (45 minutes)
```typescript
// Prompt for Claude Code:
Create a feed API that returns multiple videos with prefetch optimization.

Requirements:
- Handle GET /api/feed?cursor={cursor}&limit={limit}
- Return array of video objects with metadata
- Include next cursor for pagination
- Optimize for mobile prefetching (next 5-10 videos)
- Add CDN cache headers (Cache-Control: public, max-age=300)

Response format:
{
  "videos": [...video objects...],
  "nextCursor": "cursor_token",
  "prefetchCount": 5
}

File: src/feed-api.ts
```

#### Task 1.3: Worker Router (15 minutes)
```typescript
// Prompt for Claude Code:
Create the main router for video API endpoints.

Requirements:
- Route /api/video/{id} to video API
- Route /api/feed to feed API  
- Handle CORS for mobile app
- Add basic error handling and logging
- Return proper HTTP status codes

File: src/index.ts
```

### Phase 2: Caching & Optimization (2 hours)

#### Task 2.1: KV Metadata Store (30 minutes)
```typescript
// Prompt for Claude Code:
Create a KV-based metadata storage system for videos.

Requirements:
- Store video metadata: { duration, fileSize, renditions, poster }
- Support batch reads for feed API
- Handle KV read/write errors gracefully
- Add metadata caching in Worker memory
- Include video upload timestamp for sorting

File: src/metadata-store.ts
```

#### Task 2.2: R2 URL Signing (30 minutes)
```typescript
// Prompt for Claude Code:
Create secure R2 URL signing for video access.

Requirements:
- Generate signed URLs with 5-minute expiry
- Support different video qualities (480p, 720p)
- Add request validation (IP, user agent)
- Handle signing errors gracefully
- Include cache-friendly parameters

File: src/url-signer.ts
```

#### Task 2.3: CDN Cache Optimization (30 minutes)
```typescript
// Prompt for Claude Code:
Add aggressive CDN caching for video delivery.

Requirements:
- Set optimal Cache-Control headers for videos
- Implement cache-friendly URL patterns
- Add cache warming for popular videos
- Handle cache invalidation properly
- Monitor cache hit rates

File: src/cache-optimizer.ts
```

#### Task 2.4: Prefetch Logic (30 minutes)
```typescript
// Prompt for Claude Code:
Create intelligent video prefetching system.

Requirements:
- Calculate optimal prefetch count based on scroll velocity
- Prioritize next videos in feed order
- Support quality adaptation (start with 480p)
- Add prefetch analytics tracking
- Handle network condition awareness

File: src/prefetch-manager.ts
```

### Phase 3: Mobile Integration & Security (1.5 hours)

#### Task 3.1: Flutter Video Service (45 minutes)
```dart
// Prompt for Claude Code:
Create a Flutter service optimized for short-form video consumption.

Requirements:
- VideoStreamService class with smart caching
- Method: getVideoFeed(cursor) -> List<VideoItem> 
- Client-side prefetching of next 3 videos
- Quality selection based on network conditions
- Integration with existing VideoPlayerController
- Device storage cache for recently viewed videos

File: lib/services/video_stream_service.dart
```

#### Task 3.2: Security & Rate Limiting (30 minutes)
```typescript
// Prompt for Claude Code:
Add security controls for the video delivery API.

Requirements:
- API key validation for mobile app
- Rate limiting: 1000 requests/hour per API key
- Basic DDoS protection
- Request logging for abuse detection
- IP-based throttling for suspicious activity

File: src/security.ts
```

#### Task 3.3: Analytics & Monitoring (15 minutes)
```typescript
// Prompt for Claude Code:
Add basic analytics for video delivery performance.

Requirements:
- Track: video requests, cache hit rates, popular videos
- Monitor: response times, error rates, bandwidth usage
- Export metrics to Cloudflare Analytics
- Simple health check endpoint (/health)

File: src/analytics.ts
```

### Phase 4: Testing & Deployment (1 hour)

#### Task 4.1: End-to-End Testing (30 minutes)
```bash
# Prompt for Claude Code:
Create comprehensive testing for the video delivery system.

Requirements:
- Test video API endpoints with curl
- Verify signed URL generation and validation
- Test feed API pagination and caching
- Load test with multiple concurrent requests
- Test mobile app integration locally

File: test/e2e-test.sh
```

#### Task 4.2: Deployment & Feature Flags (30 minutes)
```dart
// Prompt for Claude Code:
Add feature flag integration for gradual rollout.

Requirements:
- Boolean flag: useVideoStreamService
- Percentage rollout starting at 5%
- A/B testing metrics collection
- Fallback to original video URLs on failure
- Easy enable/disable via remote config

Update: lib/providers/video_feed_provider.dart
Add: lib/services/feature_flags.dart
```

## Deployment & Testing Plan

### Immediate Testing (Throughout Development)
1. **Unit Tests**: Each component has comprehensive tests
2. **Integration Tests**: End-to-end request flows
3. **Performance Tests**: Cache hit rates, response times
4. **Load Tests**: Handle concurrent requests

### Deployment Strategy
1. **Local Development**: Use miniflare for all testing
2. **Staging Deploy**: Deploy to Cloudflare Workers staging
3. **Internal Testing**: Test with actual NostrVine mobile app
4. **Gradual Rollout**: Start with 1% of users via feature flag

## Agentic Task Execution Strategy

### Claude Code Session Management
1. **One task per session**: Focus on single, well-defined component
2. **Clear requirements**: Specific inputs, outputs, error handling
3. **Immediate testing**: Validate each component before proceeding
4. **Iterative refinement**: Test, debug, enhance in tight loops

### Parallel Development Opportunities
- Tasks 1.1, 1.2, 1.3 can be built simultaneously
- Tasks 2.1, 2.2, 2.3 are independent and can be parallel
- Frontend and backend work can overlap

### Success Criteria for Each Phase
- **Phase 1**: Can proxy video requests without caching
- **Phase 2**: Cache hit rate >80% on repeated requests
- **Phase 3**: No security vulnerabilities, comprehensive logging
- **Phase 4**: Mobile app successfully uses proxy service

## Risk Mitigation

### Technical Risks
1. **R2 Performance**: Test with real video sizes early
2. **Memory Usage**: Monitor Worker memory consumption
3. **Stream API Limits**: Implement proper rate limiting
4. **Network Timeouts**: Add appropriate timeout handling

### Development Risks
1. **Scope Creep**: Stick to MVP features only
2. **Integration Issues**: Test mobile app integration early
3. **Performance Issues**: Profile and optimize continuously
4. **Deployment Problems**: Use staging environment first

## Expected Outcomes for Short-Form Video Optimization

### End of Day Results
1. **Instant video playback**: Sub-second start times for cached videos
2. **Smart prefetching**: Next 3-5 videos preloaded automatically  
3. **Multi-quality support**: 480p/720p renditions based on network
4. **Mobile optimized**: Device caching and intelligent quality switching
5. **Production ready**: Secure API with rate limiting and monitoring

### Performance Targets (Short-Form Optimized)
- **Cache Hit Rate**: >95% for popular videos (CDN edge cache)
- **First Video Load**: <2s (from R2 + CDN)
- **Cached Video Load**: <500ms (instant playback)
- **Prefetch Success**: 90% of next videos ready before user swipes
- **Bandwidth Efficiency**: 50% reduction via quality adaptation

### Success Metrics
- **User Experience**: Instant playback for 95% of videos
- **Network Efficiency**: Average 2MB per video (480p default)
- **Cost**: <$50/month for 100K short videos (6-second average)
- **Reliability**: >99.9% API availability
- **Mobile Performance**: Smooth scrolling with zero loading delays

### Key Optimizations for Short-Form Content
1. **Simplified Architecture**: No chunking complexity needed
2. **Aggressive Caching**: Entire 1-10MB videos cached at edge
3. **Quality Ladder**: Start 480p, upgrade to 720p when available
4. **Predictive Loading**: Prefetch based on scroll velocity
5. **Device Storage**: Recently viewed videos cached locally

This streamlined approach leverages the unique characteristics of short-form content (small file sizes, sequential consumption) to deliver a significantly better user experience with simpler architecture.