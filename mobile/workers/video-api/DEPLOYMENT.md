# NostrVine Video API Deployment Summary

## Deployment Status ✅

The NostrVine Video API has been successfully deployed to both staging and production environments.

### Environment URLs

- **Staging**: https://nostrvine-video-api-staging.protestnet.workers.dev
- **Production**: https://nostrvine-video-api.protestnet.workers.dev

### API Endpoints

1. **Health Check**
   - GET `/health`
   - Returns: `{"status": "healthy", "timestamp": "...", "environment": "..."}`

2. **Single Video Metadata**
   - GET `/api/video/{video_id}`
   - video_id must be 64 hex characters (SHA256 hash)
   - Returns signed URLs for video renditions and metadata

3. **Batch Video Lookup**
   - POST `/api/videos/batch`
   - Body: `{"videoIds": ["..."], "quality": "auto|480p|720p"}`
   - Max 50 videos per request
   - Returns availability status and signed URLs for each video

### Resources Created

1. **KV Namespaces**:
   - Development: `85ae949f9eee483693c8fe5c1b707c52`
   - Staging: `38ac1592adba4a068ac0f8c693efb159`
   - Production: `9a013d14d2f54c0284564486dc030b63`

2. **R2 Buckets**:
   - Development: `nostrvine-videos-dev`
   - Staging: `nostrvine-videos-staging`
   - Production: `nostrvine-videos`

### Testing

All unit tests passing (10/10):
```bash
npm test
```

### CORS Support

All endpoints include CORS headers for mobile app access:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, OPTIONS`
- `Access-Control-Allow-Headers: Content-Type, Authorization`

### Next Steps

1. Upload test videos to R2 buckets
2. Add video metadata to KV namespaces
3. Integration testing with Flutter app
4. Implement feature flags for gradual rollout (Issue #134)
5. Set up monitoring and analytics (Issue #129)

### Deployment Commands

```bash
# Deploy to staging
npm run deploy -- --env staging

# Deploy to production
npm run deploy -- --env production

# View logs
wrangler tail --env production
```

## Architecture Notes

- Videos are stored as complete files (no byte-range requests)
- Signed URLs expire after 5 minutes
- Optimized for 6-second vine videos (1-10MB)
- Clients discover videos via Nostr events, then use batch API for metadata