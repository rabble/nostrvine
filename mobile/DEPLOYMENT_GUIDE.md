# NostrVine Production Deployment Guide

This guide covers deploying the complete NostrVine video hosting infrastructure to production using Cloudflare services.

## Overview

NostrVine uses:
- **Cloudflare Workers** for the serverless backend API
- **Cloudflare Stream** for video upload, processing, and CDN delivery
- **R2 Object Storage** for media file storage
- **KV Storage** for metadata caching
- **Nostr Protocol** for decentralized social features

## Prerequisites

1. Cloudflare account with:
   - Workers Paid plan (for Durable Objects)
   - Stream enabled
   - R2 enabled
   
2. Tools installed:
   - Node.js (v18+)
   - Wrangler CLI: `npm install -g wrangler`
   - Flutter SDK (for mobile app)

3. Cloudflare Account ID and API tokens

## Backend Deployment

### Step 1: Clone and Setup

```bash
# Clone the repository
git clone <your-repo>
cd nostrvine/backend

# Install dependencies
npm install

# Login to Cloudflare
wrangler login
```

### Step 2: Create Cloudflare Resources

#### Create R2 Buckets
```bash
# Create the three required buckets
wrangler r2 bucket create nostrvine-frames
wrangler r2 bucket create nostrvine-media
wrangler r2 bucket create nostrvine-cache
```

#### Create KV Namespace
```bash
# Create KV namespace for metadata
wrangler kv:namespace create "METADATA_CACHE"

# Note the returned ID and update wrangler.jsonc:
# "id": "YOUR_KV_NAMESPACE_ID"
```

#### Create Analytics Dataset
```bash
# This is done automatically on first deploy
# Dataset name: nostrvine_uploads
```

### Step 3: Configure Cloudflare Stream

1. Go to Cloudflare Dashboard → Stream
2. Enable Stream for your account
3. Create an API token:
   - Go to My Profile → API Tokens
   - Create Token → Custom Token
   - Permissions: `Stream:Edit`
   - Save the token for next step

### Step 4: Update Configuration

Edit `backend/wrangler.jsonc`:

```json
{
  "kv_namespaces": [
    {
      "binding": "METADATA_CACHE",
      "id": "YOUR_ACTUAL_KV_NAMESPACE_ID"  // Replace this!
    }
  ],
  
  "env": {
    "production": {
      "vars": {
        "ENVIRONMENT": "production",
        "BASE_URL": "https://api.openvine.co"  // Your domain
      }
    }
  }
}
```

### Step 5: Set Production Secrets

```bash
# Set your Cloudflare Account ID
wrangler secret put CLOUDFLARE_ACCOUNT_ID --env production
# Enter your account ID when prompted

# Set Stream API Token
wrangler secret put CLOUDFLARE_STREAM_TOKEN --env production
# Enter the token you created in Step 3

# Generate and set webhook secret
wrangler secret put STREAM_WEBHOOK_SECRET --env production
# Enter a secure random string (save this for webhook config)
```

### Step 6: Deploy Backend

```bash
# Deploy to production
wrangler deploy --env production

# You'll see output like:
# ✨ Success! Your worker was deployed to:
# https://nostrvine-backend.YOUR-SUBDOMAIN.workers.dev
```

### Step 7: Configure Stream Webhooks

1. Go to Cloudflare Dashboard → Stream → Settings
2. Add webhook endpoint:
   - URL: `https://api.openvine.co/v1/webhooks/stream-complete`
   - Secret: (use the same secret from Step 5)
   - Events: Select "Video ready to stream"

### Step 8: Set Custom Domain (Optional)

1. In Cloudflare Dashboard → Workers & Pages
2. Select your worker
3. Go to Triggers → Custom Domains
4. Add `api.openvine.co` (or your preferred domain)

## Mobile App Configuration

### Update API Endpoints

Edit `mobile/lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String backendUrl = kIsWeb 
    ? 'https://api.openvine.co'  // Production URL
    : 'https://api.openvine.co'; // Same for mobile
    
  static const String streamCDNUrl = 'https://customer-YOUR-HASH.cloudflarestream.com';
}
```

### Build and Deploy Mobile App

```bash
cd mobile

# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web (optional)
flutter build web --release
```

## Verification Steps

### 1. Test Health Endpoint
```bash
curl https://api.openvine.co/health
```

Expected response:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "services": {
    "nip96": "active",
    "r2_storage": "healthy",
    "stream_api": "active",
    "video_cache_api": "active"
  }
}
```

### 2. Test Upload Flow

Use the mobile app or this curl command:

```bash
# First, generate NIP-98 auth header (example)
AUTH_HEADER="Nostr <base64-encoded-event>"

# Request upload URL
curl -X POST https://api.openvine.co/v1/media/request-upload \
  -H "Authorization: $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d '{"fileName": "test.mp4"}'
```

### 3. Monitor Logs
```bash
# View real-time logs
wrangler tail --env production
```

## Production Checklist

- [ ] R2 buckets created
- [ ] KV namespace created and ID updated
- [ ] Stream API token generated and set
- [ ] Webhook secret set
- [ ] Backend deployed successfully
- [ ] Stream webhooks configured
- [ ] Custom domain configured (optional)
- [ ] Mobile app updated with production URLs
- [ ] Health check passing
- [ ] Test upload working

## Troubleshooting

### Videos Not Appearing in Feed

1. **Check Nostr relay connections**:
   - Ensure the app is connecting to relays
   - Verify Kind 22 events are being published

2. **Verify Stream webhook**:
   - Check worker logs for webhook calls
   - Ensure webhook secret matches

3. **Check video processing**:
   - Use `/v1/media/status/{videoId}` to check status
   - Look for errors in Stream dashboard

### Upload Failures

1. **Rate limiting**: Check if user exceeded 30 uploads/hour
2. **Auth issues**: Verify NIP-98 authentication is correct
3. **Stream API**: Check if token has correct permissions

### CORS Issues

If experiencing CORS errors:
1. Verify origin is allowed in backend handlers
2. Check preflight (OPTIONS) responses
3. Consider adding specific allowed origins for production

## Monitoring

### Cloudflare Analytics
- Workers & Pages → Your worker → Analytics
- Stream → Analytics for video metrics
- R2 → Metrics for storage usage

### Custom Analytics
Access analytics dashboard:
```
GET https://api.openvine.co/api/analytics/dashboard
GET https://api.openvine.co/api/analytics/popular
```

## Cost Considerations

- **Workers**: Free tier includes 100k requests/day
- **Stream**: $1 per 1,000 minutes of video stored
- **R2**: $0.015 per GB stored, free egress
- **KV**: 100k reads/day free

## Security Notes

1. **NIP-98 Authentication**: All uploads require valid Nostr signatures
2. **Rate Limiting**: 30 uploads/hour per public key
3. **Content Moderation**: Phase 1 auto-approves, Phase 2 will add moderation
4. **Webhook Validation**: All Stream webhooks are signature-verified

## Next Steps

1. Set up monitoring and alerts
2. Configure backup strategy for R2
3. Plan for content moderation implementation
4. Consider CDN configuration for optimal video delivery
5. Set up analytics dashboards

## Support

For issues:
1. Check worker logs: `wrangler tail --env production`
2. Review Cloudflare Stream dashboard
3. Check GitHub issues
4. Contact Cloudflare support for infrastructure issues