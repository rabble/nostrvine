# Video API Monitoring Endpoints

This document describes the monitoring and analytics endpoints available in the NostrVine Video API.

## Endpoints Overview

### Public Endpoints

#### GET /health
Enhanced health check endpoint that provides comprehensive system status.

**Response:**
```json
{
  "status": "healthy" | "degraded" | "unhealthy",
  "timestamp": "2024-12-20T10:30:00Z",
  "environment": "production",
  "services": {
    "kv": {
      "status": "operational",
      "latency": 12
    },
    "r2": {
      "status": "operational", 
      "latency": 45
    }
  },
  "metrics": {
    "lastHourRequests": 1543,
    "cacheHitRate": 0.78,
    "avgResponseTime": 234,
    "errorRate": 0.02
  }
}
```

### Authenticated Endpoints

All authenticated endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <your-api-token>
```

#### GET /api/analytics/popular
Get popular videos for different time windows.

**Query Parameters:**
- `window` - Time window: `1h`, `24h`, or `7d` (default: `24h`)

**Response:**
```json
{
  "window": "24h",
  "videos": [
    {
      "videoId": "abc123...",
      "viewCount": 245,
      "uniqueViewers": 189,
      "avgResponseTime": 123,
      "cacheHitRate": 0.82
    }
  ],
  "timestamp": "2024-12-20T10:30:00Z"
}
```

#### GET /api/analytics/dashboard
Comprehensive dashboard data endpoint with all system metrics.

**Query Parameters:**
- `hours` - Number of hours to include in metrics (default: 24, max: 168)

**Response:**
```json
{
  "data": {
    "health": {
      // Same as /health endpoint response
    },
    "performance": {
      "requestsPerHour": [120, 145, 178, ...],
      "avgResponseTimes": [234, 256, 198, ...],
      "cacheHitRates": [0.76, 0.78, 0.81, ...],
      "errorRates": [0.02, 0.01, 0.03, ...]
    },
    "popularVideos": {
      "lastHour": [...],
      "last24Hours": [...],
      "last7Days": [...]
    },
    "errors": {
      "recent": [
        {
          "endpoint": "/api/video/123",
          "error": "HTTP 404",
          "statusCode": 404,
          "timestamp": "2024-12-20-10",
          "count": 5
        }
      ],
      "byEndpoint": {
        "/api/video/[id]": 23,
        "/api/videos/batch": 5
      },
      "byStatusCode": {
        "404": 18,
        "500": 5,
        "503": 5
      }
    },
    "cache": {
      "hitRate": 0.78,
      "missRate": 0.22,
      "totalRequests": 4523,
      "avgTTL": 3600
    }
  },
  "timestamp": "2024-12-20T10:30:00Z",
  "period": {
    "hours": 24
  }
}
```

## Health Status Definitions

- **healthy**: All systems operational, error rate < 5%, response times < 1s
- **degraded**: Some issues detected, error rate 5-10%, or response times 1-2s, or cache hit rate < 50%
- **unhealthy**: Major issues, error rate > 10%, or response times > 2s

## Usage Examples

### Check System Health
```bash
curl https://your-api.workers.dev/health
```

### Get Popular Videos (Last 24 Hours)
```bash
curl -H "Authorization: Bearer your-token" \
  https://your-api.workers.dev/api/analytics/popular?window=24h
```

### Get Full Dashboard Data
```bash
curl -H "Authorization: Bearer your-token" \
  https://your-api.workers.dev/api/analytics/dashboard?hours=48
```

## Implementation Notes

1. All endpoints include CORS headers for cross-origin access
2. Analytics data is aggregated hourly and stored for 30 days
3. Individual request metrics are stored for 7 days
4. Popular videos are calculated based on view count within the time window
5. The monitoring handler uses the VideoAnalyticsService for data collection
6. Health checks test both KV and R2 service availability and latency
7. Dashboard data includes comprehensive performance, error, and cache metrics

## Files Created/Modified

### New Files Created:
- `src/monitoring-handler.ts` - Main monitoring handler with all endpoint implementations
- `test/monitoring-endpoints.test.ts` - Comprehensive test suite for monitoring endpoints
- `MONITORING_API.md` - API documentation (this file)

### Files Modified:
- `src/index.ts` - Updated routing to include new monitoring endpoints
- `src/video-analytics-service.ts` - Added `getHealthStatus()` and `countActiveVideos()` methods

## Authentication

The authentication is currently basic Bearer token validation. In production, you should implement proper token validation against your authentication service or use Cloudflare Access for more robust authentication.

## Testing

All monitoring endpoints have been thoroughly tested with:
- Health check functionality (healthy/degraded/unhealthy states)
- Popular videos retrieval with time windows
- Authentication validation
- Dashboard data compilation
- Error handling and edge cases

Run tests with: `npm test -- monitoring-endpoints`