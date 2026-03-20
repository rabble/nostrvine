Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# OpenVine Analytics Service Documentation

**ABOUTME: Comprehensive documentation for OpenVine's analytics system architecture**  
**ABOUTME: Details API endpoints, data structures, scoring algorithms, and integration testing**

## Overview

OpenVine's analytics system is hosted at `https://api.openvine.co/analytics/` and provides comprehensive video view tracking, trending calculations, and engagement metrics. The system is built using Cloudflare Workers with KV storage for high-performance, global distribution.

## Architecture

### Backend Implementation

**Location**: `/backend/src/handlers/` and `/backend/src/services/`

**Key Components**:
- **View Tracking Handler** (`view-tracking.ts`): Processes video view events and engagement metrics
- **Trending Calculator** (`trending-calculator.ts`): Calculates trending scores and maintains popular video rankings
- **Trending Handlers**: Various endpoints for trending videos, creators, and hashtags
- **Analytics Engine** (`analytics-engine.ts`): Advanced analytics processing and aggregation

### Data Storage

**Primary Storage**: Cloudflare KV (ANALYTICS_KV namespace)  
**Cache Duration**: 
- View data: Permanent storage (no TTL)
- Trending data: 15-minute cache
- User view tracking: 1 year TTL
- Hourly buckets: 31 days TTL

## API Endpoints

### 1. View Tracking (POST `/analytics/view`)

**Purpose**: Track video views and engagement metrics

**Request Format**:
```json
{
  "eventId": "64-character-hex-string",
  "userId": "optional-user-pubkey-for-unique-counting",
  "source": "web|mobile|api",
  "creatorPubkey": "optional-creator-pubkey",
  "hashtags": ["optional", "hashtag", "array"],
  "title": "optional-video-title",
  "eventType": "view_start|view_end|loop|pause|resume|skip",
  "watchDurationMs": 1500,
  "totalDurationMs": 6300,
  "completionRate": 0.85,
  "loopCount": 3,
  "completedVideo": true,
  "timestamp": "2024-07-30T18:03:36.000Z"
}
```

**Response**:
```json
{
  "success": true,
  "eventId": "video-event-id",
  "views": 42
}
```

**Validation**:
- `eventId` must be exactly 64 characters (hex string)
- Invalid event IDs return 400 Bad Request
- Malformed data returns 400 Bad Request

**Performance**: ~50-60ms response time globally

### 2. Trending Videos (GET `/analytics/trending/vines`)

**Purpose**: Retrieve top performing videos based on view counts and time decay

**Parameters**:
- `limit`: Maximum videos to return (default: 20, max: 100)

**Response Format**:
```json
{
  "vines": [
    {
      "eventId": "64-character-hex-event-id",
      "views": 150,
      "score": 125.3,
      "title": "Optional Video Title",
      "hashtags": ["optional", "tags"]
    }
  ],
  "algorithm": "global_popularity",
  "updatedAt": 1722368616000,
  "period": "24h",
  "totalVines": 20
}
```

**Trending Algorithm**:
```javascript
score = views / (ageInHours + 1)
```

**Cache**: 5-minute public cache, 15-minute internal cache

**Performance**: ~50-70ms response time

### 3. Video Statistics (GET `/analytics/video/{eventId}/stats`)

**Purpose**: Get detailed statistics for a specific video

**Response**: Detailed view data including engagement metrics

### 4. Creator Analytics (GET `/analytics/trending/viners`)

**Purpose**: Get trending video creators

**Response**: List of creators with view counts and video counts

### 5. Hashtag Trending (GET `/analytics/hashtag/{hashtag}/trending`)

**Purpose**: Get trending videos for specific hashtags

## Data Structures

### ViewData
```typescript
interface ViewData {
  count: number;                    // Total view count
  uniqueViewers?: number;           // Unique user count
  lastUpdate: number;               // Timestamp
  hashtags?: string[];              // Associated hashtags
  creatorPubkey?: string;           // Creator's public key
  title?: string;                   // Video title
  // Engagement metrics
  totalWatchTimeMs?: number;        // Total watch time
  completionRate?: number;          // Average completion rate
  loopCount?: number;               // Total replays
  completedViews?: number;          // Complete views
  pauseCount?: number;              // Pause events
  skipCount?: number;               // Skip events
  averageWatchTimeMs?: number;      // Average watch time
}
```

### TrendingVideo
```typescript
interface TrendingVideo {
  eventId: string;                  // 64-char hex event ID
  views: number;                    // Total views
  score: number;                    // Calculated trending score
  title?: string;                   // Optional metadata
  hashtags?: string[];              // Optional hashtags
}
```

## Features

### View Tracking
- **No Rate Limiting**: All app usage is tracked
- **Unique Viewer Counting**: Uses userId for deduplication
- **Engagement Metrics**: Watch time, completion rate, loops, pauses
- **Background Processing**: Hashtag and creator metrics updated asynchronously
- **Hourly Bucketing**: Time-based analytics for trend calculation

### Trending Calculation
- **Time Decay Algorithm**: Recent views weighted higher
- **Minimum View Threshold**: Configurable (default: 3 views)
- **Performance Optimized**: Limits KV queries (50 entries per calculation)
- **Caching Strategy**: 15-minute cache with extended tolerance
- **Background Updates**: Trending scores calculated periodically

### Data Privacy
- **Minimal Tracking**: Only video engagement, no personal data
- **Opt-in User IDs**: userId field optional for unique counting
- **Public Analytics**: All trending data is public

## Integration Testing

**Location**: `/mobile/test/integration/analytics_integration_test.dart`

**Coverage**: 10 comprehensive tests validating:
- ✅ **Trending Endpoint**: Data structure validation, performance
- ✅ **View Tracking**: Valid data submission, error handling
- ✅ **Error Scenarios**: Invalid endpoints, malformed data, timeouts
- ✅ **Performance**: Sub-3-second response times verified

**Test Results**:
- All endpoints operational ✅
- Response times: 50-70ms (excellent) ⚡
- Error handling: Proper HTTP status codes 🛡️
- Data validation: Accepts valid, rejects invalid ✅
- Current trending dataset: 20 videos 📈

**Running Tests**:
```bash
cd mobile/
flutter test test/integration/analytics_integration_test.dart
```

## Performance Characteristics

### Response Times
- **View Tracking**: ~50ms globally
- **Trending Retrieval**: ~60ms globally
- **Individual Video Stats**: ~70ms

### Scalability
- **Global Distribution**: Cloudflare Workers edge deployment
- **KV Storage**: Automatically scales globally
- **Background Processing**: Non-blocking hashtag/creator updates
- **Efficient Caching**: Multi-layer caching strategy

### Rate Limiting
- **View Tracking**: None (intentionally unlimited)
- **API Endpoints**: Standard Cloudflare protection
- **Cache Headers**: Appropriate TTL values set

## Mobile App Integration

**Service**: `AnalyticsService` (`mobile/lib/services/analytics_service.dart`)

**Key Features**:
- **Automatic Tracking**: Views tracked on video play
- **Privacy Controls**: User can disable analytics
- **Background Mode**: Queues analytics when app backgrounded
- **Retry Logic**: 3 attempts with exponential backoff
- **Rate Limiting**: 100ms intervals for batch operations

**Usage Examples**:
```dart
// Track basic view
await analyticsService.trackVideoView(video, source: 'mobile');

// Track detailed engagement
await analyticsService.trackDetailedVideoViewWithUser(
  video,
  userId: userPubkey,
  source: 'mobile',
  eventType: 'view_start',
  watchDuration: Duration(seconds: 4),
  totalDuration: Duration(seconds: 6),
  loopCount: 2,
);
```

## Configuration

**Environment Variables**:
- `MIN_VIEWS_FOR_TRENDING`: Minimum views for trending inclusion (default: 3)
- `TRENDING_UPDATE_INTERVAL`: Cache refresh interval (default: 300s)
- `ENVIRONMENT`: Deployment environment
- `ANALYTICS_KV`: KV namespace binding

## Monitoring & Health Checks

**Health Endpoint**: `GET /analytics/health`

**Dashboard**: Available at backend domain `/api/analytics/dashboard`

**Dependencies Monitored**:
- KV Storage connectivity
- R2 Storage health
- Rate limiter functionality

## Error Handling

### View Tracking Errors
- **400**: Invalid event ID format
- **400**: Malformed request data  
- **500**: Server processing error

### Trending Errors
- **Empty Results**: Returns empty array gracefully
- **Calculation Failures**: Falls back to cached data
- **Timeout Protection**: Background calculation prevents blocking

## Future Enhancements

### Planned Features
- **D1 Database Integration**: SQL analytics for complex queries
- **Personalization**: Opt-in recommendation system
- **Real-time Updates**: WebSocket support for live metrics
- **Advanced Algorithms**: ML-based trending calculation

### Data Retention
- **View Data**: Permanent storage (archival strategy needed)
- **User Tracking**: 1-year retention
- **Trending Cache**: 15-minute refresh cycles

---

## Technical Notes

**Last Updated**: 2025-08-01  
**API Version**: v1  
**Backend Commit**: Current production deployment  
**Test Coverage**: All major endpoints verified ✅

**Development Contact**: Check backend implementation in `/backend/src/handlers/` for latest changes.