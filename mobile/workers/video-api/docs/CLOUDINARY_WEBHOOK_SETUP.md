# Cloudinary Webhook Setup Guide

This guide explains how to configure Cloudinary webhooks to work with the OpenVine video API.

## Prerequisites

1. Cloudinary account with API access
2. Deployed OpenVine API (currently deployed to production)
3. API secrets configured in Cloudflare Workers

## Webhook Endpoint

The webhook endpoint is available at:
```
https://api.openvine.co/v1/media/webhook
```

**Note**: The domain DNS must be configured in Cloudflare for this to work. Until then, use the workers.dev URL.

## Cloudinary Console Configuration

1. Log into your Cloudinary console
2. Navigate to Settings → Upload
3. Find the "Notification URL" section
4. Add the webhook URL: `https://api.openvine.co/v1/media/webhook`

## Webhook Events

The API handles the following Cloudinary notification types:
- `upload` - When a new video/image is uploaded
- `eager` - When transformations are completed

## Security

The webhook endpoint validates requests using:
- `X-Cld-Signature` header - HMAC-SHA1 signature
- `X-Cld-Timestamp` header - Request timestamp
- Request body - Used in signature verification

## Testing the Webhook

You can test the webhook locally using:

```bash
# Generate test signature (requires API secret)
TIMESTAMP=$(date +%s)
BODY='{"notification_type":"upload","public_id":"test123"}'
SECRET="your-api-secret"

# The signature would be: SHA1(body + timestamp + secret)
```

## Upload Context

When uploading videos, include the user's pubkey in the context:

```javascript
const uploadParams = {
  upload_preset: 'nostrvine_video_uploads',
  context: `pubkey=${userPubkey}`,
  notification_url: 'https://api.openvine.co/v1/media/webhook'
};
```

## Webhook Processing Flow

1. Cloudinary sends webhook notification
2. API validates signature
3. Extracts pubkey from context
4. Generates NIP-94 tags
5. Stores ready event in KV storage
6. Client polls `/v1/media/ready-events` to get processed events

## Ready Events Polling

Clients should poll for ready events using NIP-98 authentication:

```bash
GET /v1/media/ready-events
Authorization: Nostr <base64-encoded-nip98-event>
```

## Troubleshooting

### Domain Not Resolving
If `api.openvine.co` is not resolving:
1. Check Cloudflare DNS settings
2. Ensure CNAME or A record points to the worker
3. Use workers.dev URL as temporary workaround

### Webhook Not Received
1. Check Cloudinary notification URL configuration
2. Verify API secrets match between Cloudinary and Workers
3. Check worker logs: `wrangler tail`

### Signature Validation Failing
1. Ensure CLOUDINARY_API_SECRET is correctly set
2. Verify timestamp is recent (within 5 minutes)
3. Check request body is not modified

## Environment Variables Required

Set these using `wrangler secret put`:
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`
- `STREAM_API_TOKEN` (if using Cloudflare Stream)