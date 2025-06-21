# NostrVine Production Deployment Checklist

## 🚀 Quick Start

Run the deployment script:
```bash
./deploy.sh
```

## ✅ Pre-Deployment Checklist

### 1. Cloudflare Account Setup
- [ ] Cloudflare account created
- [ ] Workers Paid plan activated (for Durable Objects)
- [ ] Stream enabled on account
- [ ] Account ID obtained from dashboard

### 2. Backend Configuration
- [ ] Update `backend/wrangler.jsonc` with production values
- [ ] Replace KV namespace ID with actual ID
- [ ] Update production URLs

### 3. Create Resources
```bash
# From backend directory
cd ../backend

# Create R2 buckets
wrangler r2 bucket create nostrvine-frames
wrangler r2 bucket create nostrvine-media  
wrangler r2 bucket create nostrvine-cache

# Create KV namespace
wrangler kv:namespace create "METADATA_CACHE"
# Copy the returned ID to wrangler.jsonc
```

### 4. Set Secrets
```bash
# Get Account ID from Cloudflare dashboard
wrangler secret put CLOUDFLARE_ACCOUNT_ID --env production

# Create Stream API token (from dashboard) with Stream:Edit permission
wrangler secret put CLOUDFLARE_STREAM_TOKEN --env production

# Generate secure webhook secret
wrangler secret put STREAM_WEBHOOK_SECRET --env production
# Save this value for webhook configuration!
```

### 5. Deploy Backend
```bash
cd backend
npm install
wrangler deploy --env production
```

### 6. Configure Stream Webhooks
1. Go to Cloudflare Dashboard → Stream → Settings → Webhooks
2. Add webhook:
   - URL: `https://api.nostrvine.com/v1/webhooks/stream-complete`
   - Secret: (use the STREAM_WEBHOOK_SECRET from step 4)
   - Events: ✓ Video ready to stream

### 7. Update Mobile App
Edit `mobile/lib/config/app_config.dart`:
```dart
static const String backendBaseUrl = 'https://api.nostrvine.com';
```

### 8. Build & Deploy Apps
```bash
cd mobile

# Android
flutter build apk --release --dart-define=BACKEND_URL=https://api.nostrvine.com

# iOS (macOS only)
flutter build ios --release --dart-define=BACKEND_URL=https://api.nostrvine.com

# Web
flutter build web --release --dart-define=BACKEND_URL=https://api.nostrvine.com
npx wrangler pages deploy build/web --project-name nostrvine-web
```

## 🧪 Post-Deployment Testing

### 1. Backend Health Check
```bash
curl https://api.nostrvine.com/health
```

### 2. Test Video Upload Flow
1. Open mobile app
2. Record a video
3. Check upload completes
4. Verify video appears in feed

### 3. Monitor Logs
```bash
wrangler tail --env production
```

## 🐛 Troubleshooting

### Videos Not Showing in Feed
1. **Check Nostr Events**: The app uses Kind 22 events for videos
2. **Verify Relays**: Ensure app connects to relays that have Kind 22 events
3. **Check Logs**: Look for "No kind 22 events found" in app logs

### Upload Failures
1. **Rate Limits**: 30 uploads/hour per user
2. **Auth Issues**: Check NIP-98 authentication
3. **Stream Token**: Verify token has correct permissions

### Webhook Not Firing
1. **Secret Mismatch**: Ensure webhook secret matches
2. **URL Correct**: Verify webhook URL in Stream settings
3. **Check Logs**: Look for webhook calls in worker logs

## 📊 Production URLs

- **Backend API**: https://api.nostrvine.com
- **Health Check**: https://api.nostrvine.com/health
- **Web App**: https://app.nostrvine.com (after Pages deployment)
- **Analytics**: https://api.nostrvine.com/api/analytics/dashboard

## 💰 Cost Monitoring

Monitor usage in Cloudflare dashboard:
- **Workers**: 100k requests/day free
- **Stream**: $1 per 1,000 minutes stored
- **R2**: $0.015/GB stored, free egress
- **KV**: 100k reads/day free

## 🔒 Security Reminders

1. **Change webhook secret** from development default
2. **Restrict CORS** origins in production
3. **Monitor rate limits** for abuse
4. **Review moderation** queue regularly

## 📱 App Store Submission

### Android (Google Play)
1. Sign APK with release key
2. Create app listing
3. Upload APK
4. Submit for review

### iOS (App Store)
1. Archive in Xcode
2. Upload to App Store Connect
3. Fill app metadata
4. Submit for review

## 🎉 Launch Checklist

- [ ] Backend deployed and healthy
- [ ] Stream webhooks configured
- [ ] Mobile apps built with production URL
- [ ] Web app deployed (optional)
- [ ] Test video upload working
- [ ] Monitoring set up
- [ ] Cost alerts configured
- [ ] Documentation updated

## Need Help?

1. Check worker logs: `wrangler tail --env production`
2. Review this guide: `DEPLOYMENT_GUIDE.md`
3. Check Cloudflare Stream dashboard
4. File GitHub issue if needed