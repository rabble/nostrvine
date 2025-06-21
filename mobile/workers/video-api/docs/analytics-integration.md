# Video API Analytics Integration

## Overview

The VideoAnalyticsService has been integrated into the NostrVine video API handlers to track key metrics and performance data. Analytics run in the background using Cloudflare Workers' `ctx.waitUntil()` to ensure they don't impact API response times.

## Tracked Metrics

### Video Metadata API (`/api/video/{video_id}`)
- **Cache Hit/Miss**: Whether the video metadata was found in KV storage
- **Response Time**: Time taken to process the request
- **Quality Preference**: Tracks whether users prefer 480p, 720p, or both
- **Errors**: Any errors encountered during processing

Quality preferences are detected from:
1. Query parameter: `?quality=480p` or `?quality=720p`
2. Request header: `x-video-quality: 480p` or `x-video-quality: 720p`

### Batch Video API (`/api/videos/batch`)
- **Requested Count**: Number of videos requested in the batch
- **Found Count**: Number of videos successfully found
- **Missing Count**: Number of videos not found
- **Quality Preference**: The quality mode requested (auto/480p/720p)
- **Response Time**: Time to process the entire batch
- **Average Batch Size**: Running average of batch sizes

### Error Tracking
All API errors are tracked with:
- Endpoint name
- Error message
- HTTP status code
- Timestamp
- Video ID (when applicable)

## Data Storage

Analytics data is stored in the VIDEO_METADATA KV namespace with the following structure:

### Individual Metrics
- Key pattern: `analytics:video:{videoId}:{timestamp}` or `analytics:batch:{timestamp}`
- TTL: 7 days
- Contains raw metric data

### Aggregated Metrics
- Key pattern: `analytics:aggregate:{category}:{YYYY-MM-DD-HH}`
- TTL: 30 days
- Contains hourly aggregates with running averages

## Analytics API

Access analytics summaries via the `/api/analytics` endpoint:

```bash
# Get last 24 hours of analytics
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.nostrvine.com/api/analytics

# Get specific time range
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.nostrvine.com/api/analytics?hours=48
```

Response format:
```json
{
  "summary": [
    {
      "hour": "2025-06-20-14",
      "videoMetadata": {
        "totalRequests": 1250,
        "cacheHits": 1100,
        "avgResponseTime": 45.2,
        "qualityBreakdown": {
          "480p": 600,
          "720p": 450,
          "both": 200
        }
      },
      "batchVideo": {
        "totalRequests": 150,
        "totalVideosRequested": 3500,
        "totalVideosFound": 3200,
        "totalVideosMissing": 300,
        "avgResponseTime": 125.5,
        "avgBatchSize": 23.3
      },
      "errors": {
        "video_metadata": {
          "404": 150,
          "500": 2
        }
      }
    }
  ],
  "timestamp": "2025-06-20T15:30:00Z"
}
```

## Configuration

Analytics can be disabled by setting the `ENABLE_ANALYTICS` environment variable to `false` in `wrangler.toml`.

## Performance Impact

Analytics are designed to have minimal performance impact:
- All analytics operations run asynchronously using `ctx.waitUntil()`
- KV writes are batched where possible
- Aggregations are computed incrementally
- Failed analytics operations are caught and logged without affecting the main request

## Future Enhancements

1. **Real-time Dashboards**: Connect to monitoring services for live metrics
2. **Alerting**: Set up thresholds for error rates or response times
3. **User Analytics**: Track unique users and usage patterns
4. **Geographic Analytics**: Track request origins for CDN optimization
5. **A/B Testing**: Track performance of different video qualities