# Cloudinary Console Setup Guide

This guide walks through configuring Cloudinary to send webhooks to the OpenVine API.

## Step 1: Access Cloudinary Settings

1. Log into your Cloudinary console at https://cloudinary.com/console
2. Navigate to **Settings** (gear icon in the top right)
3. Go to the **Upload** tab

## Step 2: Configure Upload Preset

First, ensure you have the correct upload preset:

1. In Settings → Upload, find **Upload presets**
2. Look for `nostrvine_video_uploads` preset (or create it if missing)
3. Edit the preset and ensure these settings:
   - **Unsigned uploading**: Disabled (for security)
   - **Folder**: Leave empty or set to your preference
   - **Allowed formats**: mp4, mov, avi, webm, mkv, flv
   - **Max file size**: 500MB (or your preference)

## Step 3: Configure Webhook Notification

1. In the same Upload settings page, find **Notification URL**
2. Add the webhook URL:
   ```
   https://api.openvine.co/v1/media/webhook
   ```

3. Make sure to **Save** the settings

## Step 4: Configure Eager Transformations

In the upload preset, add these eager transformations:

1. **MP4 Optimization**:
   - Format: mp4
   - Video codec: h264
   - Quality: auto

2. **GIF Generation**:
   - Format: gif
   - FPS: 10
   - Quality: auto:good

3. **Thumbnail**:
   - Format: jpg
   - Width: 400
   - Height: 300
   - Crop: fill

## Step 5: Test the Integration

### Quick Test Upload

Use this cURL command to test an upload:

```bash
curl -X POST https://api.cloudinary.com/v1_1/dswu0ugmo/video/upload \
  -F "file=@test-video.mp4" \
  -F "upload_preset=nostrvine_video_uploads" \
  -F "context=pubkey=d91191e30e00444b942c0e82cad470b32af171764c2275bee0bd99377efd4075" \
  -F "api_key=YOUR_API_KEY"
```

### Expected Webhook Flow

1. Upload video with pubkey in context
2. Cloudinary processes the video
3. Webhook sent to `https://api.openvine.co/v1/media/webhook`
4. API validates signature and stores ready event
5. Client polls `/v1/media/ready-events` to get NIP-94 tags

## Step 6: Verify Webhook Delivery

After uploading, check:

1. **Cloudinary Console**: Look for webhook delivery status
2. **Worker Logs**: `wrangler tail` to see incoming webhooks
3. **Ready Events**: Poll the ready events endpoint

## Troubleshooting

### Webhook Not Received
- Verify the notification URL is saved in Cloudinary
- Check that api.openvine.co is resolving
- Look for webhook errors in Cloudinary's logs

### Signature Validation Failing
- Ensure CLOUDINARY_API_SECRET is correctly set in Workers
- Verify the secret matches your Cloudinary account

### Missing Context
- Always include `context=pubkey=<user-pubkey>` in uploads
- The pubkey is required for event storage

## Security Notes

1. **Never expose your API secret** in client code
2. **Use signed uploads** for production
3. **Validate webhook signatures** (already implemented)
4. **Rate limit polling** to prevent abuse

## Next Steps

Once configured:
1. Update the Flutter app to use the signed upload endpoint
2. Implement polling for ready events in the client
3. Test the full upload → webhook → poll flow