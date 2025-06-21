# OpenVine Deployment Status

## Domain Configuration

| Service | Domain | Status | Platform |
|---------|--------|--------|----------|
| Web App | https://app.openvine.co | 🟡 Ready to Deploy | Cloudflare Pages |
| API | https://api.openvine.co | 🟡 Ready to Deploy | Cloudflare Workers |
| Staging API | https://staging-api.openvine.co | 🟡 Ready to Deploy | Cloudflare Workers |
| Nostr Relay | wss://relay.openvine.co | 🔴 Not Configured | TBD |

## Quick Deploy Commands

### Deploy Web App
```bash
cd mobile
./deploy-openvine-web.sh
# Choose option 1
```

### Deploy API
```bash
cd workers/video-api
./deploy-openvine.sh
# Choose option 3 for production
```

## First-Time Setup

### 1. Configure Cloudflare Account
```bash
# Set your Cloudflare credentials
export CLOUDFLARE_API_TOKEN="your-api-token"
export CLOUDFLARE_ACCOUNT_ID="your-account-id"
```

### 2. Deploy Web App
```bash
cd mobile
./deploy-openvine-web.sh
```

### 3. Configure Custom Domain
1. Go to Cloudflare Dashboard → Pages → openvine-app
2. Click "Custom domains"
3. Add `app.openvine.co`
4. Cloudflare will automatically configure DNS

### 4. Deploy API
```bash
cd workers/video-api
./deploy-openvine.sh
```

## Verification

### Check Web App
```bash
# Test deployment URL
curl -I https://openvine-app.pages.dev

# Test custom domain (after DNS propagation)
curl -I https://app.openvine.co
```

### Check API
```bash
# Health check
curl https://api.openvine.co/health

# Status endpoint
curl https://api.openvine.co/v1/media/status/test
```

## Environment URLs

### Production
- Web: https://app.openvine.co
- API: https://api.openvine.co
- Cloudinary Webhook: https://api.openvine.co/v1/media/webhook

### Staging
- Web: https://staging.app.openvine.co (not configured)
- API: https://staging-api.openvine.co
- Cloudinary Webhook: https://staging-api.openvine.co/v1/media/webhook

### Development
- Web: http://localhost:3000
- API: http://localhost:8787

## Deployment Checklist

- [ ] Cloudflare account configured
- [ ] API credentials set (CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET)
- [ ] Web app deployed to Cloudflare Pages
- [ ] Custom domain configured for web app
- [ ] API deployed to Cloudflare Workers
- [ ] Custom domain configured for API
- [ ] Cloudinary webhook URL configured
- [ ] SSL certificates active (automatic with Cloudflare)
- [ ] CORS headers verified
- [ ] Mobile app updated with production URLs

## Monitoring

- Cloudflare Analytics: https://dash.cloudflare.com
- Pages Dashboard: https://dash.cloudflare.com/?to=/:account/pages/view/openvine-app
- Workers Dashboard: https://dash.cloudflare.com/?to=/:account/workers/services/view/nostrvine-video-api

## Support

For deployment issues:
1. Check Cloudflare status: https://www.cloudflarestatus.com/
2. View deployment logs: `wrangler tail` (for Workers)
3. Check GitHub Actions: https://github.com/rabble/nostrvine/actions