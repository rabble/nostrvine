# NIP-05 Deployment Guide

## Overview
This guide covers deploying the NIP-05 verification system for OpenVine, allowing users to have human-readable identifiers like `username@openvine.co`.

## Backend Deployment

### 1. Create KV Namespace
```bash
# Create the NIP-05 store namespace
wrangler kv:namespace create "NIP05_STORE"

# Note the ID returned and update wrangler.jsonc with the actual ID
```

### 2. Update Environment Variables
Add to your wrangler secrets:
```bash
# Admin token for reserved username management
wrangler secret put ADMIN_TOKEN
```

### 3. Deploy Backend
```bash
cd backend
npm run deploy
```

### 4. Verify Endpoints
Test the NIP-05 endpoints:
```bash
# Check verification endpoint
curl https://openvine.co/.well-known/nostr.json?name=testuser

# Test registration (replace with actual values)
curl -X POST https://openvine.co/api/nip05/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "pubkey": "your_hex_pubkey",
    "relays": ["wss://relay.damus.io"]
  }'
```

## Frontend Deployment

### 1. Deploy Website Files
The following files need to be deployed to the website:
- `profile.html` - Profile page template
- `profile-styles.css` - Profile page styles
- `nostr-profile-viewer.js` - Profile loading logic
- Updated `router.js` - Handles /username routing

### 2. Configure Routing
Ensure your web server (Cloudflare Pages, Nginx, etc.) routes all `/username` paths to the main index.html for client-side routing.

For Cloudflare Pages, add to `_redirects`:
```
/*    /index.html   200
```

## Reserved Username Import

### 1. Prepare Username List
Create a JSON file with legacy Vine usernames:
```json
{
  "usernames": ["username1", "username2", "12345"],
  "markAsClaimable": true
}
```

### 2. Import Reserved Usernames
```bash
curl -X POST https://openvine.co/admin/reserved-usernames/import \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d @reserved_usernames.json
```

## Mobile App Integration

The mobile app needs to be updated to:

1. **Add NIP-05 Registration UI**
   - Username input field in profile settings
   - Validation for username format
   - API call to register username

2. **Display Verification Badge**
   - Check user metadata for `nip05` field
   - Verify the NIP-05 identifier
   - Show checkmark badge for verified users

3. **Handle Profile Links**
   - Make usernames clickable to open profile pages
   - Support deep linking to `openvine.co/username`

## Testing Checklist

- [ ] NIP-05 JSON endpoint returns correct format
- [ ] Username registration works with validation
- [ ] Reserved usernames are blocked from registration
- [ ] Profile pages load correctly at /username
- [ ] Verification badges appear for NIP-05 verified users
- [ ] Profile pages show user videos, reposts, and likes
- [ ] Mobile app can register NIP-05 identifiers
- [ ] Legacy Vine username claiming process works

## Monitoring

Monitor these metrics:
- NIP-05 verification requests per minute
- Username registration success/failure rates
- Profile page load times
- 404 rates for non-existent usernames

## Security Considerations

1. **Rate Limiting**: Implement rate limits on registration endpoint
2. **Username Validation**: Strict validation to prevent injection attacks
3. **Reserved List**: Regularly update reserved username list
4. **Admin Access**: Secure admin endpoints with strong authentication
5. **CORS**: Ensure proper CORS headers for cross-origin requests

## Future Enhancements

1. **Email Verification**: Add email verification for username claims
2. **Username Changes**: Allow users to change their username with limits
3. **Premium Usernames**: Implement paid premium username system
4. **Unicode Support**: Extend to support international characters
5. **Subdomain Support**: Allow `username.openvine.co` URLs