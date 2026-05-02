# Server Deployment Checklist for Deep Links

## Files Ready to Deploy

All verification files are ready in the `mobile/docs/` directory:

### ✅ iOS Universal Links
- **File**: `apple-app-site-association`
- **Team ID**: GZCZBKH7MY
- **App ID**: co.openvine.app
- **Paths**: /video/*, /profile/*

### ✅ Android App Links (Debug)
- **File**: `assetlinks.json`
- **Package**: co.openvine.app
- **SHA-256 (Debug)**: 6F:36:C3:68:74:18:5E:03:B4:79:3D:82:EF:54:CE:34:26:ED:6E:C8:12:B7:CD:E2:F4:FA:9C:81:2F:C7:14:F4

### ⚠️ Android App Links (Production)
For production builds, you'll need to:
1. Get your release keystore SHA-256:
   ```bash
   keytool -list -v -keystore /path/to/release.keystore -alias your-alias
   ```
2. Add it to `assetlinks-production.json` (replace the placeholder)

## Deployment Steps

### 1. Create .well-known directory on every claimed host

```bash
mkdir -p /var/www/divine.video/.well-known
mkdir -p /var/www/www.divine.video/.well-known
mkdir -p /var/www/login.divine.video/.well-known
```

### 2. Copy files to every claimed host

```bash
# iOS file (no extension!)
cp mobile/docs/apple-app-site-association /var/www/divine.video/.well-known/
cp mobile/docs/apple-app-site-association /var/www/www.divine.video/.well-known/

# Android file (for testing with debug builds)
cp mobile/docs/assetlinks.json /var/www/divine.video/.well-known/
cp mobile/docs/assetlinks.json /var/www/www.divine.video/.well-known/
cp mobile/docs/assetlinks.json /var/www/login.divine.video/.well-known/

# For production, use assetlinks-production.json after adding release fingerprint
# cp mobile/docs/assetlinks-production.json /var/www/divine.video/.well-known/assetlinks.json
```

### 3. Set correct permissions

```bash
chmod 644 /var/www/divine.video/.well-known/apple-app-site-association
chmod 644 /var/www/divine.video/.well-known/assetlinks.json
chmod 644 /var/www/www.divine.video/.well-known/apple-app-site-association
chmod 644 /var/www/www.divine.video/.well-known/assetlinks.json
chmod 644 /var/www/login.divine.video/.well-known/assetlinks.json
```

### 4. Configure web server

#### Nginx Configuration

Add to your divine.video nginx config:

```nginx
server {
    server_name divine.video;

    # ... existing config ...

    # Deep linking verification files
    location /.well-known/apple-app-site-association {
        default_type application/json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "public, max-age=86400";
    }

    location /.well-known/assetlinks.json {
        default_type application/json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "public, max-age=86400";
    }
}
```

#### Apache Configuration

Add to your divine.video apache config:

```apache
<Directory /var/www/divine.video/.well-known>
    <Files "apple-app-site-association">
        Header set Content-Type "application/json"
        Header set Access-Control-Allow-Origin "*"
        Header set Cache-Control "public, max-age=86400"
    </Files>

    <Files "assetlinks.json">
        Header set Content-Type "application/json"
        Header set Access-Control-Allow-Origin "*"
        Header set Cache-Control "public, max-age=86400"
    </Files>
</Directory>
```

### 5. Reload web server

```bash
# Nginx
sudo nginx -t && sudo nginx -s reload

# Apache
sudo apachectl configtest && sudo systemctl reload apache2
```

## Verification

Do not ship the Android manifest host change until all claimed hosts return
HTTP 200 for their verification files. Android 11 and lower require manifest
hosts to verify together before the app becomes the default handler.

### Test iOS file is accessible

```bash
curl -I https://divine.video/.well-known/apple-app-site-association
curl -I https://www.divine.video/.well-known/apple-app-site-association
```

Expected:
- HTTP/2 200
- Content-Type: application/json

Verify content:
```bash
curl https://divine.video/.well-known/apple-app-site-association
curl https://www.divine.video/.well-known/apple-app-site-association
```

Should return the JSON with your Team ID (GZCZBKH7MY).

### Test Android file is accessible

```bash
curl -I https://divine.video/.well-known/assetlinks.json
curl -I https://www.divine.video/.well-known/assetlinks.json
curl -I https://login.divine.video/.well-known/assetlinks.json
```

Expected:
- HTTP/2 200
- Content-Type: application/json

Verify content:
```bash
curl https://divine.video/.well-known/assetlinks.json
curl https://www.divine.video/.well-known/assetlinks.json
curl https://login.divine.video/.well-known/assetlinks.json
```

Should return the JSON array with your package name and SHA-256 fingerprint.

### Use Apple's Validator

Go to: https://search.developer.apple.com/appsearch-validation-tool/

Enter: `divine.video`

Should show: ✅ Valid association file found

### Test Android Verification

On a device with the app installed:

```bash
# Verify the link
adb shell pm verify-app-links --re-verify co.openvine.app

# Check status
adb shell pm get-app-links co.openvine.app
```

Should show:
```
co.openvine.app:
  divine.video: verified
  www.divine.video: verified
  login.divine.video: verified
```

## Testing Deep Links

### iOS (requires physical device)

1. Send yourself an email or message with: `https://divine.video/video/test123`
2. Long-press the link - should see "Open in Divine" option
3. Tap the link - should open directly in the app

### Android

1. In Chrome or another browser, navigate to: `https://divine.video/video/test123`
2. Should automatically open in the app (no dialog)

Or use adb:
```bash
adb shell am start -a android.intent.action.VIEW -d "https://divine.video/video/test123"
```

## Troubleshooting

### iOS links not working

1. **Check file is accessible**: Curl the URL and verify JSON is returned
2. **Verify Team ID**: Make sure GZCZBKH7MY matches your Apple Developer account
3. **Reinstall app**: iOS caches the association file, reinstalling forces a refresh
4. **Check device logs**:
   ```bash
   # Connect device and view console logs
   # Look for "swcd" (Shared Web Credentials Daemon) errors
   ```

### Android links not working

1. **Check file is accessible**: Curl the URL and verify JSON is returned
2. **Re-verify**: Run `adb shell pm verify-app-links --re-verify co.openvine.app`
3. **Check verification status**: Run `adb shell pm get-app-links co.openvine.app`
4. **Check logcat**:
   ```bash
   adb logcat | grep -i "applinks\|assetlinks"
   ```

### Links open in browser instead of app

- For iOS: User may have previously chosen "Open in Safari" - they need to long-press and select app
- For Android: Verification may have failed - check with `pm get-app-links`

## Production Deployment

Before deploying to production:

1. ✅ Get your release keystore SHA-256 fingerprint
2. ✅ Update `assetlinks-production.json` with the release fingerprint
3. ✅ Test with a production build
4. ✅ Deploy assetlinks-production.json as assetlinks.json

## Notes

- **Cache**: iOS and Android cache these files. If you update them, users may need to reinstall the app
- **HTTPS Required**: Both platforms require HTTPS - HTTP will not work
- **Multiple Fingerprints**: You can include both debug and release fingerprints in assetlinks.json
- **Wildcard Paths**: The `/*` in paths means any path under /video/ or /profile/
