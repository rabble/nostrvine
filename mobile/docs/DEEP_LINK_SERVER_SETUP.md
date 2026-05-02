# Deep Link Server Setup for divine.video

To enable iOS universal links and Android app links, you need to host two
verification files on every claimed Divine hostname. For the current mobile app
that means `divine.video`, `www.divine.video`, and `login.divine.video` for
Android App Links, plus the Apple-associated hosts for universal links.

## Files to Create

### 1. iOS Universal Links Verification

**File**: `apple-app-site-association` (no file extension)
**Primary Location**: `https://divine.video/.well-known/apple-app-site-association`
**Alternative Location**: `https://divine.video/apple-app-site-association`
**Also serve on `www` if claimed**:
`https://www.divine.video/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.co.openvine.app",
        "paths": [
          "/video/*",
          "/profile/*"
        ]
      }
    ]
  }
}
```

**How to get your TEAM_ID**:
1. Go to https://developer.apple.com/account
2. Click on "Membership" in the sidebar
3. Your Team ID is shown under "Team ID"
4. Replace `TEAM_ID` in the file above with your actual Team ID

**Important**:
- The file must be served with `Content-Type: application/json` or `application/pkcs7-mime`
- No `.json` extension in the filename
- Must be accessible via HTTPS
- Should return HTTP 200 status

### 2. Android App Links Verification

**File**: `assetlinks.json`
**Location**: `https://divine.video/.well-known/assetlinks.json`
**Also serve on every claimed Android host**:
- `https://www.divine.video/.well-known/assetlinks.json`
- `https://login.divine.video/.well-known/assetlinks.json`

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "co.openvine.app",
      "sha256_cert_fingerprints": [
        "YOUR_SHA256_FINGERPRINT_HERE"
      ]
    }
  }
]
```

**How to get your SHA-256 fingerprint**:

For your release keystore:
```bash
keytool -list -v -keystore /path/to/your/release.keystore -alias your-key-alias
```

For debug builds (testing only):
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Look for the "SHA256:" line in the output and copy the fingerprint (with colons).

Example output:
```
SHA256: AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90
```

**Important**:
- The file must be served with `Content-Type: application/json`
- Must be accessible via HTTPS
- Should return HTTP 200 status
- You need a separate fingerprint for each signing key (debug, release, etc.)

## Server Configuration

### .well-known Directory

Both files should be placed in the `.well-known` directory on every hostname claimed by the app:
```
https://divine.video/.well-known/
├── apple-app-site-association
└── assetlinks.json
```

If additional hosts are also claimed, mirror the same files there:
```
https://www.divine.video/.well-known/
├── apple-app-site-association
└── assetlinks.json
```

```text
https://login.divine.video/.well-known/
└── assetlinks.json
```

### CORS Headers (if needed)

If you're hosting these files on a different domain or CDN, ensure CORS headers allow access:
```
Access-Control-Allow-Origin: *
```

### Nginx Configuration Example

```nginx
location /.well-known/apple-app-site-association {
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
}

location /.well-known/assetlinks.json {
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
}
```

## Testing

### iOS Universal Links

1. Build and install the app on a physical device (simulator won't work for universal links)
2. Send yourself an email or message with the link: `https://divine.video/video/abc123`
3. Long-press the link - you should see "Open in Divine" option
4. Or simply tap the link and it should open in the app

**Verification Tool**:
- Apple provides a validator: https://search.developer.apple.com/appsearch-validation-tool/
- Enter your domain: `divine.video`

### Android App Links

1. Build and install the app on a device
2. Test the link in a browser or messaging app: `https://divine.video/video/abc123`
3. If `www.divine.video` is supported, also test: `https://www.divine.video/video/abc123`
4. The link should automatically open in the app (no disambiguation dialog)
5. Do not ship new manifest hosts until every claimed host returns HTTP 200 for its `assetlinks.json` file.

**Verification Command**:
```bash
adb shell am start -a android.intent.action.VIEW -d "https://divine.video/video/test123"
adb shell am start -a android.intent.action.VIEW -d "https://www.divine.video/video/test123"
```

**Check verification status**:
```bash
adb shell pm get-app-links co.openvine.app
```

Should show:
```
co.openvine.app:
  ...
  divine.video: verified
  www.divine.video: verified
  login.divine.video: verified
```

## Troubleshooting

### iOS Issues

- **Links open in Safari instead of app**:
  - Verify the `apple-app-site-association` file is accessible
  - Verify the `www.divine.video` AASA file too if the failing link used `www`
  - Check that Team ID matches your Apple Developer account
  - Reinstall the app (iOS caches the association file)

- **"Open in app" banner doesn't appear**:
  - Make sure you're testing on a physical device
  - Check that the app is installed and the bundle ID matches

### Android Issues

- **Links open in browser instead of app**:
  - Verify `assetlinks.json` is accessible
  - Check that SHA-256 fingerprint matches your signing certificate
  - Run: `adb shell pm verify-app-links --re-verify co.openvine.app`

- **Verification fails**:
  - Ensure the JSON file is valid
  - Check that the package name is correct
  - Verify HTTPS is working (Android won't verify over HTTP)

## Example Files

See `apple-app-site-association.template` and `assetlinks.json.template` in this directory for complete examples.
