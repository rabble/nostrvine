# Thumbnail Service Documentation

## Overview

The OpenVine Thumbnail Service provides on-demand thumbnail generation for videos with intelligent caching and multiple size options. It integrates with Cloudflare Stream for videos processed through Stream and provides fallback options for direct R2 uploads.

## Features

- **Lazy Generation**: Thumbnails are generated on first request
- **Multiple Sizes**: Small (320x180), Medium (640x360), Large (1280x720)
- **Custom Timestamps**: Extract frames from any point in the video
- **Format Support**: JPEG and WebP formats
- **Caching**: KV metadata cache + R2 storage for generated thumbnails
- **Custom Uploads**: Support for client-uploaded thumbnails

## API Endpoints

### Get/Generate Thumbnail
```
GET /thumbnail/{videoId}?size={size}&t={timestamp}&format={format}
```

**Parameters:**
- `videoId` (required): The video ID
- `size` (optional): `small`, `medium`, or `large` (default: `medium`)
- `t` (optional): Timestamp in seconds (default: `1`)
- `format` (optional): `jpg` or `webp` (default: `jpg`)

**Example:**
```bash
# Get medium thumbnail at 2.5 seconds
curl https://api.openvine.co/thumbnail/abc123?t=2.5

# Get large WebP thumbnail
curl https://api.openvine.co/thumbnail/abc123?size=large&format=webp
```

### Upload Custom Thumbnail
```
POST /thumbnail/{videoId}/upload
```

**Body:** Multipart form data with `thumbnail` field

**Example:**
```bash
curl -X POST https://api.openvine.co/thumbnail/abc123/upload \
  -F "thumbnail=@custom-thumb.jpg"
```

### List Available Thumbnails
```
GET /thumbnail/{videoId}/list
```

**Response:**
```json
{
  "videoId": "abc123",
  "thumbnails": [
    {
      "size": "medium",
      "timestamp": 1,
      "format": "jpg",
      "r2Key": "thumbnails/abc123/medium_t1.jpg",
      "generatedAt": 1704067200000
    }
  ],
  "count": 1
}
```

## How It Works

1. **Request arrives** for a thumbnail
2. **Check KV cache** for existing thumbnail metadata
3. **If cached**: Retrieve from R2 and serve
4. **If not cached**:
   - For Stream videos: Use Stream's thumbnail API with parameters
   - For R2 uploads: Return placeholder (video processing not supported in Workers)
5. **Store generated thumbnail** in R2 for future requests
6. **Cache metadata** in KV for fast lookups

## Storage Structure

```
R2 Bucket: nostrvine-media/
└── thumbnails/
    └── {videoId}/
        ├── small_t1.jpg
        ├── medium_t1.jpg
        ├── large_t1.jpg
        └── custom_t0.jpg
```

## Integration with Video Upload

The thumbnail service integrates seamlessly with the existing video upload flow:

1. **Mobile client** generates and sends thumbnail during upload
2. **Backend** can store the client thumbnail using the upload endpoint
3. **Cloudflare Stream** automatically generates thumbnails for Stream-processed videos
4. **On-demand generation** fills gaps when thumbnails are missing

## Performance Considerations

- **Edge caching**: Thumbnails are cached at Cloudflare edge for 1 year
- **KV metadata**: 30-day TTL for thumbnail existence checks
- **Lazy generation**: Only generate what's requested
- **Size optimization**: Pre-defined sizes prevent arbitrary scaling

## Future Enhancements

1. **Animated thumbnails**: GIF previews showing key moments
2. **Smart frame selection**: Avoid black frames, detect interesting content
3. **Batch generation**: Pre-generate common sizes during upload
4. **AVIF support**: Modern image format for better compression
5. **Client hints**: Responsive images based on device capabilities