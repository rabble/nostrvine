# OpenVine File Upload API Documentation

## Overview

OpenVine provides a comprehensive file upload system that supports NIP-96 compliant uploads with Nostr authentication. The system handles video, image, and audio files with automatic content safety scanning, deduplication, and efficient storage in Cloudflare R2.

## Authentication

All upload requests require NIP-98 HTTP authentication:

```http
Authorization: Nostr <base64-encoded-auth-event>
```

The auth event must be a valid Nostr event with:
- `kind: 27235`
- `tags` including:
  - `["u", "<upload-url>"]` - The full upload URL
  - `["method", "POST"]` - HTTP method
- Valid signature from the uploading user

## API Endpoints

### 1. Main Upload Endpoint

**POST** `/api/upload`

Uploads a file to the server with NIP-96 compliance.

#### Request

- **Headers:**
  - `Authorization: Nostr <base64-encoded-auth-event>` (required)
  - `Content-Type: multipart/form-data`

- **Form Data:**
  - `file` - The file to upload (required)
  - Additional metadata fields (optional)

#### Response

**Success (200 OK):**
```json
{
  "status": "success",
  "message": "File uploaded successfully",
  "url": "https://api.openvine.co/media/{fileId}",
  "download_url": "https://api.openvine.co/media/{fileId}",
  "sha256": "sha256hash",
  "size": 1234567,
  "type": "video/mp4",
  "dimensions": "640x640"
}
```

**Note**: Files are uploaded directly to R2 storage and immediately available. The response includes the direct download URL and file metadata.

**Error Responses:**
- `400 Bad Request` - Invalid file type or missing file
- `401 Unauthorized` - Invalid or missing NIP-98 auth  
- `403 Forbidden` - Content policy violation (CSAM, violence, etc.)
- `413 Payload Too Large` - File exceeds size limit
- `500 Internal Server Error` - Storage or processing failure
- `503 Service Unavailable` - Storage not configured

### 2. Media Serving

**GET** `/media/{fileId}`

Retrieves uploaded media files.

#### Request

- **Headers (optional):**
  - `Range: bytes=0-1000` - For partial content requests

#### Response

- **Headers:**
  - `Content-Type: <media-type>`
  - `Content-Length: <file-size>`
  - `Accept-Ranges: bytes`
  - `Cache-Control: public, max-age=31536000`

### 3. Upload Status

**GET** `/api/status/{jobId}`

Check the status of an upload processing job. Currently returns placeholder data as uploads are processed synchronously.

#### Response

```json
{
  "job_id": "job_12345",
  "status": "processing",
  "progress": 75,
  "message": "Video transcoding in progress",
  "created_at": 1640995200000,
  "updated_at": 1640995230000
}
```

**Note**: This endpoint currently serves placeholder data. Files uploaded via `/api/upload` are processed immediately and don't require status polling.

### 4. Server Capabilities

**GET** `/.well-known/nostr/nip96.json`

Returns server upload capabilities per NIP-96.

#### Response

```json
{
  "api_url": "https://api.openvine.co/api/upload",
  "download_url": "https://api.openvine.co/media",
  "supported_nips": [96, 98],
  "tos_url": "https://api.openvine.co/terms",
  "content_types": ["video/mp4", "video/webm", "image/jpeg", "image/png"],
  "plans": {
    "free": {
      "name": "Free Plan",
      "max_byte_size": 104857600,
      "file_expiry": [31536000, "Files deleted after 1 year of inactivity"],
      "media_transformations": {
        "gif_conversion": ["Convert videos to optimized GIFs", "Support up to 30 frames for vine-style content"],
        "video_transcoding": ["Multiple quality levels (480p, 720p, 1080p)", "Adaptive bitrate streaming (HLS/DASH)"],
        "thumbnail_generation": ["Auto-generated video thumbnails", "Multiple sizes (small, medium, large)"],
        "blurhash_generation": ["Progressive loading placeholders", "Computed for all visual media"]
      }
    },
    "pro": {
      "name": "Pro Plan",
      "max_byte_size": 1073741824,
      "file_expiry": [63072000, "Files kept for 2 years"],
      "media_transformations": {
        "gif_conversion": ["High-quality GIF conversion", "Up to 60 frames with advanced optimization"],
        "video_transcoding": ["Premium quality up to 4K", "Advanced codec support (AV1, HEVC)", "Custom bitrate profiles"],
        "thumbnail_generation": ["Custom thumbnail timestamps", "Animated preview clips"],
        "content_analysis": ["Automatic content tagging", "Scene detection and keyframe extraction"]
      }
    }
  }
}
```

## File Requirements

### Supported File Types

- **Video:** `video/mp4`, `video/quicktime`, `video/webm`
- **Images:** `image/jpeg`, `image/png`, `image/gif`, `image/webp`
- **Audio:** `audio/mpeg`, `audio/wav`, `audio/webm`

### Size Limits

- **Free Plan:** 100MB max file size
- **Pro Plan:** 1GB max file size

### Content Validation

- Files are validated by MIME type and magic numbers
- Automatic content safety scanning (CSAM detection)
- SHA256 deduplication prevents redundant uploads

## Upload Flow

1. **Client prepares NIP-98 auth event**
   ```javascript
   const authEvent = {
     kind: 27235,
     created_at: Math.floor(Date.now() / 1000),
     tags: [
       ["u", "https://api.openvine.co/api/upload"],
       ["method", "POST"]
     ],
     content: "",
     pubkey: userPubkey
   };
   // Sign event with user's private key
   ```

2. **Client sends upload request**
   ```javascript
   const formData = new FormData();
   formData.append('file', fileBlob);
   
   const response = await fetch('https://api.openvine.co/api/upload', {
     method: 'POST',
     headers: {
       'Authorization': `Nostr ${btoa(JSON.stringify(signedAuthEvent))}`
     },
     body: formData
   });
   ```

3. **Server processes upload**
   - Validates authentication
   - Checks file type and size
   - Scans for content safety
   - Checks for duplicates
   - Stores in R2
   - Returns NIP-94 event data

4. **Client broadcasts NIP-94 event**
   ```javascript
   const nip94Event = response.nip94_event;
   // Broadcast to Nostr relays
   ```

## Error Handling

### NIP-96 Error Codes

- `AUTH_REQUIRED` - Missing authentication
- `INVALID_AUTH` - Invalid NIP-98 event
- `FILE_TOO_LARGE` - Exceeds size limit
- `UNSUPPORTED_TYPE` - Invalid file type
- `QUOTA_EXCEEDED` - User quota exceeded
- `CONTENT_VIOLATION` - Failed safety scan

### HTTP Status Codes

- `200` - Successful upload
- `400` - Bad request (invalid file)
- `401` - Unauthorized
- `413` - Payload too large
- `415` - Unsupported media type
- `451` - Content policy violation
- `500` - Internal server error

## Best Practices

1. **Always include proper NIP-98 authentication**
2. **Check file size before uploading** to avoid wasted bandwidth
3. **Handle range requests** for video streaming
4. **Implement exponential backoff** for retries  
5. **Cache media URLs** as they are permanent
6. **Use SHA256 deduplication** to avoid re-uploading identical files
7. **Validate file content** with magic number checks

## Example Implementation

```javascript
async function uploadVideo(file, userPrivkey) {
  // 1. Create NIP-98 auth event
  const authEvent = createAuthEvent(userPrivkey);
  
  // 2. Upload file
  const formData = new FormData();
  formData.append('file', file);
  
  const response = await fetch('https://api.openvine.co/api/upload', {
    method: 'POST',
    headers: {
      'Authorization': `Nostr ${btoa(JSON.stringify(authEvent))}`
    },
    body: formData
  });
  
  if (!response.ok) {
    const error = await response.json();
    throw new Error(`Upload failed: ${error.message}`);
  }
  
  const result = await response.json();
  
  // 3. Create and broadcast NIP-94 event using returned data
  const nip94Event = {
    kind: 1063,
    tags: [
      ['url', result.url],
      ['x', result.sha256],
      ['size', result.size.toString()],
      ['m', result.type]
    ],
    content: 'Uploaded video'
  };
  await broadcastToRelays(nip94Event);
  
  return result;
}
```

## Storage Details

- Files are stored in Cloudflare R2 under `uploads/` prefix
- Permanent storage with no expiration
- Global CDN distribution via Cloudflare network
- Automatic WebP conversion for images (when requested)
- Video files served with proper streaming headers

## Security Considerations

1. **Content Safety**: All uploads are scanned for CSAM
2. **Authentication**: NIP-98 prevents unauthorized uploads
3. **Rate Limiting**: Prevents abuse and DoS attacks
4. **CORS**: Properly configured for cross-origin requests
5. **Input Validation**: Strict file type and size validation