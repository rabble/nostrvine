# OpenVine Domain Configuration

## Overview

OpenVine uses the domain `openvine.co` for all production services. This document outlines the domain structure and configuration.

## Domain Structure

### Production Domains
- **Main App**: `https://openvine.co` (future web app)
- **API**: `https://api.openvine.co` (Cloudflare Workers API)
- **CDN**: `https://cdn.openvine.co` (future static assets)
- **Relay**: `wss://relay.openvine.co` (Nostr relay)

### Staging Domains
- **Staging App**: `https://staging.openvine.co`
- **Staging API**: `https://staging-api.openvine.co`
- **Staging Relay**: `wss://staging-relay.openvine.co`

### Development
- **Local API**: `http://localhost:8787`
- **Local App**: `http://localhost:3000`

## Cloudflare Configuration

### DNS Records

Add these DNS records in Cloudflare dashboard:

```
Type    Name              Value                           Proxy
A       @                 192.0.2.1                      ✓
A       api              192.0.2.1                      ✓
A       staging-api      192.0.2.1                      ✓
A       cdn              192.0.2.1                      ✓
A       relay            192.0.2.1                      ✓
A       staging-relay    192.0.2.1                      ✓
```

Note: The IP `192.0.2.1` is a placeholder - Cloudflare will route to the correct Worker.

### Worker Routes

The `wrangler.toml` configures these routes automatically:

- `api.openvine.co/*` → Production Worker
- `staging-api.openvine.co/*` → Staging Worker

## Deployment

### Quick Deploy

```bash
# Deploy to staging
./deploy-openvine.sh
# Choose option 2

# Deploy to production
./deploy-openvine.sh
# Choose option 3
```

### Manual Deploy

```bash
# Staging
wrangler deploy --env staging

# Production
wrangler deploy --env production
```

## Environment Configuration

### Cloudflare Workers

Environment variables set in `wrangler.toml`:

```toml
[env.production.vars]
WORKER_URL = "https://api.openvine.co"

[env.staging.vars]
WORKER_URL = "https://staging-api.openvine.co"
```

### Flutter App

To use production API:

```bash
flutter run --dart-define=BACKEND_URL=https://api.openvine.co
```

Or set in code:
```dart
// lib/config/app_config.dart
static const String backendBaseUrl = 'https://api.openvine.co';
```

## Cloudinary Webhook Configuration

### Production
1. Log into Cloudinary Dashboard
2. Navigate to Settings → Upload
3. Add Notification URL: `https://api.openvine.co/v1/media/webhook`
4. Enable for: Upload, Eager transformations

### Staging
1. Use separate Cloudinary account/environment for staging
2. Add Notification URL: `https://staging-api.openvine.co/v1/media/webhook`

## API Endpoints

### Health Check
```bash
# Production
curl https://api.openvine.co/health

# Staging
curl https://staging-api.openvine.co/health
```

### Video Status
```bash
# Check video processing status
curl https://api.openvine.co/v1/media/status/{videoId}
```

### Cloudinary Upload
```bash
# Request signed upload parameters
curl -X POST https://api.openvine.co/v1/media/cloudinary/request-upload \
  -H "Authorization: Nostr <base64-event>" \
  -H "Content-Type: application/json" \
  -d '{"fileType": "video/mp4"}'
```

## SSL/TLS

Cloudflare automatically provides SSL certificates for all subdomains. No additional configuration needed.

## Monitoring

### Cloudflare Analytics
- View at: https://dash.cloudflare.com
- Monitor: Request volume, error rates, performance

### Worker Logs
```bash
# Tail production logs
wrangler tail

# Tail staging logs
wrangler tail --env staging
```

## Troubleshooting

### Domain Not Resolving
1. Check DNS records in Cloudflare
2. Ensure orange cloud (proxy) is enabled
3. Wait 5-10 minutes for propagation

### Worker Not Responding
1. Check worker routes in Cloudflare dashboard
2. Verify deployment: `wrangler deployments list`
3. Check logs: `wrangler tail`

### CORS Issues
- All endpoints include CORS headers
- Allowed origins: `*` (configure as needed)

## Future Considerations

### Multi-Region
- Consider Cloudflare Workers regional deployments
- Use Durable Objects for stateful operations

### Rate Limiting
- Implement Cloudflare Rate Limiting rules
- Current: 180 requests/minute per IP for status endpoint

### Caching
- Configure Page Rules for static content
- Use Cache API in Workers for dynamic content