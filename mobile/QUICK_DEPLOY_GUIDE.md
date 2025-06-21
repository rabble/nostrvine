# Quick Deploy Guide for app.openvine.co

## Prerequisites
- Cloudflare account with openvine.co domain
- CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID

## Step 1: Initial Setup (One-time)

```bash
# Install dependencies
npm install -g wrangler

# Set environment variables
export CLOUDFLARE_API_TOKEN=your-api-token
export CLOUDFLARE_ACCOUNT_ID=your-account-id
```

## Step 2: Deploy

```bash
cd mobile
./deploy-to-cloudflare.sh
```

## Step 3: Configure Domain (First deployment only)

1. Go to Cloudflare Dashboard > Pages > nostrvine-app
2. Click "Custom domains"
3. Add `app.openvine.co`
4. Cloudflare will automatically configure the DNS

## Subsequent Deployments

Just run:
```bash
cd mobile
./deploy-to-cloudflare.sh
```

## Manual Build & Deploy

If you prefer manual steps:

```bash
cd mobile
# Build
flutter build web --release

# Deploy
cd build/web
wrangler pages deploy . --project-name=nostrvine-app
```

## Verify Deployment

- Preview URL: https://nostrvine-app.pages.dev
- Production URL: https://app.openvine.co (after DNS propagation)

## Troubleshooting

If deployment fails:
1. Check API token permissions (needs Pages:Edit)
2. Verify account ID is correct
3. Ensure Flutter web build succeeded
4. Check Cloudflare Pages dashboard for errors