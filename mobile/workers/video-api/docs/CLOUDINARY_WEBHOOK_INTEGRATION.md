# Cloudinary Webhook Integration

## Overview

This document describes the Cloudinary webhook integration for NostrVine video processing. The integration allows asynchronous processing of uploaded videos with automatic generation of NIP-94 compliant Nostr events.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   Client    │────>│  Video API   │────>│   Cloudinary    │
│  (Flutter)  │     │  (Workers)   │     │    (Upload)     │
└─────────────┘     └──────────────┘     └─────────────────┘
       │                    │                      │
       │                    │<─────────────────────┘
       │                    │    Webhook (async)
       │                    │
       │<───────────────────┘
       │   Poll for events
       │
       v
┌─────────────┐
│    Nostr    │
│   (Event)   │
└─────────────┘
```

## Endpoints

### 1. Request Upload Parameters
**POST** `/v1/media/cloudinary/request-upload`

Returns signed upload parameters for direct client upload to Cloudinary.

**Request:**
```json
{
  "fileType": "video/mp4",
  "maxFileSize": 104857600
}
```

**Response:**
```json
{
  "signature": "sha1-hash",
  "timestamp": 1234567890,
  "api_key": "your-api-key",
  "cloud_name": "your-cloud-name",
  "upload_preset": "nostrvine_video_uploads",
  "context": "pubkey=hex-pubkey"
}
```

### 2. Webhook Handler
**POST** `/v1/media/webhook`

Receives Cloudinary webhook notifications for processed videos.

**Headers Required:**
- `X-Cld-Signature`: Webhook signature
- `X-Cld-Timestamp`: Request timestamp

**Webhook Processing:**
1. Validates signature
2. Extracts video metadata
3. Generates NIP-94 tags
4. Stores ready event in KV

### 3. Poll for Ready Events
**GET** `/v1/media/ready-events`

Returns processed video events ready for Nostr publishing.

**Response:**
```json
{
  "events": [
    {
      "public_id": "video-id",
      "tags": [
        ["url", "https://..."],
        ["m", "video/mp4"],
        ["size", "10485760"],
        ["dim", "1920x1080"]
      ],
      "content_suggestion": "🎬 Shared a video...",
      "formats": {
        "mp4": "https://...",
        "webp": "https://...",
        "gif": "https://..."
      },
      "metadata": {
        "width": 1920,
        "height": 1080,
        "size_bytes": 10485760
      },
      "timestamp": "2024-01-01T00:00:00Z"
    }
  ],
  "count": 1
}
```

### 4. Get Specific Event
**GET** `/v1/media/ready-events/{public_id}`

Returns a specific ready event by Cloudinary public_id.

### 5. Delete Ready Event
**DELETE** `/v1/media/ready-events`

Removes a ready event after client has processed it.

**Request:**
```json
{
  "public_id": "video-id"
}
```

## Client Implementation Flow

```javascript
// 1. Request upload parameters
const uploadParams = await requestUploadParams(fileType, fileSize);

// 2. Upload directly to Cloudinary
const formData = new FormData();
formData.append('file', videoFile);
formData.append('signature', uploadParams.signature);
formData.append('timestamp', uploadParams.timestamp);
formData.append('api_key', uploadParams.api_key);
formData.append('upload_preset', uploadParams.upload_preset);
formData.append('context', uploadParams.context);

// Note: Replace 'your-cloud-name' with your actual Cloudinary cloud name
const cloudinaryResponse = await fetch(
  `https://api.cloudinary.com/v1_1/${uploadParams.cloud_name}/video/upload`,
  { method: 'POST', body: formData }
);

const { public_id } = await cloudinaryResponse.json();

// 3. Poll for ready event
let readyEvent = null;
while (!readyEvent) {
  await sleep(2000); // Poll every 2 seconds
  const events = await fetchReadyEvents();
  readyEvent = events.find(e => e.public_id === public_id);
}

// 4. Create and sign Nostr event
const nostrEvent = {
  kind: 1063, // NIP-94 file metadata
  tags: readyEvent.tags,
  content: readyEvent.content_suggestion
};

const signedEvent = await signNostrEvent(nostrEvent);

// 5. Publish to Nostr
await publishToNostr(signedEvent);

// 6. Clean up ready event
await deleteReadyEvent(public_id);
```

## Configuration

### Cloudinary Settings

1. **Upload Preset**: `nostrvine_video_uploads`
   - Unsigned uploads allowed
   - Auto-tagging enabled
   - Eager transformations configured

2. **Webhook URL**: `https://api.openvine.co/v1/media/webhook`
   - Configure in Cloudinary console
   - Enable for upload and eager notifications

3. **Eager Transformations**:
   - MP4: `f_mp4,vc_h264,q_auto`
   - WebP: `f_webp,q_auto:good`
   - GIF: `f_gif,fps_10,q_auto:good`

### Worker Secrets

Set via Wrangler CLI:
```bash
wrangler secret put CLOUDINARY_API_KEY --env production
wrangler secret put CLOUDINARY_API_SECRET --env production
```

## Security Considerations

1. **Webhook Validation**: All webhooks are validated using HMAC-SHA1 signatures
2. **NIP-98 Authentication**: All client requests require valid Nostr authentication
3. **Rate Limiting**: 30 uploads per hour per pubkey
4. **TTL**: Ready events expire after 24 hours
5. **No Secret Exposure**: API secrets never sent to clients

## Monitoring

### Key Metrics
- Upload request rate
- Webhook processing time
- Ready event retrieval rate
- Error rates by type

### Error Handling
- Invalid signatures: 401 Unauthorized
- Malformed payloads: 400 Bad Request
- Missing pubkey context: Event dropped silently
- KV failures: Logged but don't fail webhook

## Testing

### Unit Tests
```bash
npm test -- cloudinary-webhook.test.ts ready-events.test.ts
```

### E2E Tests
```bash
./test/e2e/webhook-integration.sh
```

### Manual Testing
1. Use Cloudinary upload widget
2. Monitor webhook logs
3. Poll for ready events
4. Verify NIP-94 tag generation

## Deployment Checklist

- [ ] Set CLOUDINARY_API_KEY secret
- [ ] Set CLOUDINARY_API_SECRET secret
- [ ] Configure webhook URL in Cloudinary
- [ ] Enable webhook notifications
- [ ] Test webhook signature validation
- [ ] Verify KV namespace is configured
- [ ] Test end-to-end flow
- [ ] Monitor initial uploads