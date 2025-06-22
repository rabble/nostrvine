# Cloudinary Setup Checklist

Follow these steps in your Cloudinary console to configure webhook integration:

## ✅ Checklist

### 1. Log into Cloudinary Console
- [ ] Go to https://cloudinary.com/console
- [ ] Sign in with your account

### 2. Navigate to Settings
- [ ] Click the gear icon (⚙️) in the top right
- [ ] Select "Upload" tab

### 3. Configure Notification URL
- [ ] Find the "Notification URL" field
- [ ] Enter: `https://api.openvine.co/v1/media/webhook`
- [ ] Click "Save" at the bottom of the page

### 4. Create/Update Upload Preset
- [ ] In the Upload tab, find "Upload presets" section
- [ ] Click "Add upload preset" or edit existing `nostrvine_video_uploads`
- [ ] Configure these settings:
  - [ ] **Preset name**: `nostrvine_video_uploads`
  - [ ] **Signing Mode**: Unsigned (for now, we'll switch to signed later)
  - [ ] **Folder**: Leave empty or set to `nostrvine`
  
### 5. Add Eager Transformations
In the same upload preset, add these transformations:
- [ ] Click "Add eager transformation"
- [ ] **Transformation 1 (MP4)**:
  - Format: mp4
  - Video codec: h264
  - Quality: auto
  - [ ] Click "Add"
  
- [ ] **Transformation 2 (GIF)**:
  - Format: gif
  - FPS: 10
  - Quality: auto:good
  - Width: 480
  - [ ] Click "Add"
  
- [ ] **Transformation 3 (Thumbnail)**:
  - Format: jpg
  - Width: 400
  - Height: 300
  - Crop: fill
  - [ ] Click "Add"

### 6. Save Upload Preset
- [ ] Click "Save" to save the upload preset

### 7. Get Your API Credentials
- [ ] Go to Dashboard
- [ ] Note your:
  - Cloud Name: `dswu0ugmo`
  - API Key: (visible in dashboard)
  - API Secret: (click to reveal)

## 🧪 Test Upload Command

Once configured, test with this command (replace YOUR_API_KEY):

```bash
curl -X POST https://api.cloudinary.com/v1_1/dswu0ugmo/video/upload \
  -F "file=@test-video.mp4" \
  -F "upload_preset=nostrvine_video_uploads" \
  -F "context=pubkey=d91191e30e00444b942c0e82cad470b32af171764c2275bee0bd99377efd4075" \
  -F "api_key=YOUR_API_KEY" \
  -F "eager=w_400,h_300,c_fill|f_gif,fps_10|f_mp4,vc_h264,q_auto" \
  -F "notification_url=https://api.openvine.co/v1/media/webhook"
```

## 🔍 Verify Webhook Delivery

1. After uploading, check Cloudinary's webhook logs
2. Monitor worker logs: `wrangler tail`
3. Check ready events (requires NIP-98 auth)

## ⚠️ Important Notes

- The webhook URL must be HTTPS
- Include `context=pubkey=<user-pubkey>` in all uploads
- The API validates webhook signatures for security
- Ready events are stored for 24 hours