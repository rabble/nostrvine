# Analytics Integration

## Overview

OpenVine tracks video view analytics to provide creators with engagement metrics. The analytics system is designed to integrate with the DiVine FunnelCake relay.

## Current Status: STUBBED

**The analytics POST endpoint is not yet implemented on the backend.** View tracking is currently disabled in the mobile app until the funnelcake relay adds the necessary endpoint.

When analytics is enabled, the following metrics will be tracked:
- View starts and completions
- Watch duration and completion rate
- Loop counts (how many times a video loops)
- Pause/resume events

## Backend Integration

### DiVine FunnelCake Relay

- **Base URL**: `https://relay.staging.dvines.org`
- **Swagger Docs**: https://relay.staging.dvines.org/swagger-ui/
- **OpenAPI Spec**: https://relay.staging.dvines.org/openapi.json

### Available Endpoints (Read-Only)

These endpoints are already available for retrieving analytics:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/stats` | GET | Platform-wide statistics |
| `/api/videos/{id}/stats` | GET | Engagement stats for a video |
| `/api/videos/{id}/views` | GET | View metrics for a video |
| `/api/hashtags/trending` | GET | Trending hashtags by engagement |

### Planned Endpoints (TODO)

The following endpoint needs to be implemented on the backend:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/analytics/view` | POST | Record a video view event |

#### Proposed Request Format

```json
{
  "eventId": "nostr-event-id-64-chars",
  "userId": "viewer-pubkey-or-null-for-anonymous",
  "source": "mobile",
  "eventType": "view_start|view_end|loop|pause|resume|skip",
  "creatorPubkey": "creator-pubkey-64-chars",
  "hashtags": ["tag1", "tag2"],
  "title": "Video title",
  "timestamp": "2024-01-15T12:00:00.000Z",
  "watchDuration": 5000,
  "totalDuration": 6000,
  "completionRate": 0.83,
  "loopCount": 2,
  "completedVideo": true
}
```

## Mobile Implementation

### Key Files

- `lib/services/analytics_service.dart` - Main analytics service
- `lib/providers/analytics_provider.dart` - Riverpod provider for analytics

### Feature Flag

The `_analyticsBackendReady` flag in `AnalyticsService` controls whether analytics are sent:

```dart
/// Feature flag: Set to true when backend POST endpoint is implemented
static const bool _analyticsBackendReady = false;
```

### Enabling Analytics

When the backend is ready:

1. Update `_analyticsBackendReady` to `true` in `analytics_service.dart`
2. Verify the endpoint path matches the backend implementation
3. Test with staging environment first
4. Deploy to production

### Privacy Controls

Users can opt-out of analytics tracking in Settings. The preference is stored locally and respected regardless of backend status.

## View Count Display

### Current Behavior

Video view counts currently show **legacy Vine data only** from the `originalLoops` metadata field. This is imported historical data, not live tracking.

### Future Behavior

Once analytics is enabled:
1. Mobile app sends view events to funnelcake relay
2. Relay aggregates view counts per video
3. Mobile app queries `/api/videos/{id}/views` for display
4. Both legacy counts and new counts can be shown

## Related Files

- `lib/models/video_event.dart` - VideoEvent model with `originalLoops` field
- `lib/widgets/video/video_stats_overlay.dart` - UI for displaying view counts

## TODO

- [ ] Implement POST `/api/analytics/view` endpoint on funnelcake relay
- [ ] Enable `_analyticsBackendReady` flag in mobile app
- [ ] Add view count query to video detail/stats display
- [ ] Consider NIP-45 COUNT queries as alternative to centralized analytics
