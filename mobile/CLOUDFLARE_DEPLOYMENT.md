# NostrVine Web App Deployment Guide

This guide explains how to deploy the NostrVine Flutter web app to Cloudflare Pages at app.openvine.co.

## Prerequisites

1. Cloudflare account with access to manage the openvine.co domain
2. Flutter SDK installed (version 3.32.4 or later)
3. Web support enabled in Flutter (`flutter config --enable-web`)

## Manual Deployment Steps

### 1. Build the Web App

```bash
cd mobile
./deploy-web.sh
```

This script will:
- Clean previous builds
- Get dependencies
- Build the web app in release mode
- Create a `web-deploy` directory with the built files

### 2. Deploy to Cloudflare Pages

#### Option A: Using Cloudflare Dashboard (Recommended for first deployment)

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to Pages
3. Click "Create a project"
4. Choose "Upload assets"
5. Name your project: `nostrvine-app`
6. Upload the contents of the `web-deploy` directory
7. Click "Deploy site"

#### Option B: Using Wrangler CLI

First, install Wrangler:
```bash
npm install -g wrangler
```

Then deploy:
```bash
cd mobile
wrangler pages deploy web-deploy --project-name=nostrvine-app
```

### 3. Configure Custom Domain

After the first deployment:

1. In Cloudflare Pages dashboard, go to your project
2. Navigate to "Custom domains"
3. Add custom domain: `app.openvine.co`
4. Follow the DNS configuration instructions

## Automated Deployment (GitHub Actions)

The repository includes a GitHub Actions workflow that automatically deploys on push to main branch.

### Setup:

1. Add the following secrets to your GitHub repository:
   - `CLOUDFLARE_API_TOKEN`: Your Cloudflare API token with Pages edit permissions
   - `CLOUDFLARE_ACCOUNT_ID`: Your Cloudflare account ID

2. The workflow will automatically:
   - Build the Flutter web app
   - Deploy to Cloudflare Pages
   - Update the live site at app.openvine.co

## Environment Variables

If your app needs environment variables, create a `.env.production` file:

```bash
# Example environment variables
API_URL=https://api.openvine.co
CLOUDINARY_CLOUD_NAME=your-cloud-name
```

## Troubleshooting

### Build Errors

1. Ensure Flutter web is enabled:
   ```bash
   flutter config --enable-web
   flutter doctor
   ```

2. Clear cache and rebuild:
   ```bash
   flutter clean
   flutter pub get
   flutter build web --release
   ```

### Deployment Issues

1. Check Cloudflare Pages build logs in the dashboard
2. Verify API token permissions
3. Ensure the domain DNS is properly configured

### Performance Optimization

The build is already optimized for production with:
- Tree-shaking for smaller bundle size
- Minified JavaScript
- Optimized assets

For additional optimization:
- Consider using `--web-renderer canvaskit` for better performance
- Enable caching rules in Cloudflare

## Support

For issues specific to:
- Flutter build: Check Flutter documentation
- Cloudflare Pages: Check Cloudflare Pages documentation
- NostrVine app: Create an issue in the repository