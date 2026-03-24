# Divine Geo-Blocker

Status: Current
Validated against: `geo-blocker/src` on 2026-03-19.

Tiny Cloudflare Worker that checks if a user's IP is in a restricted region (currently Mississippi due to age verification laws).

## Features

- **Zero dependencies**: Uses Cloudflare's built-in geolocation
- **CORS enabled**: Works with Flutter mobile app
- **Fail-open**: If geolocation fails, allows access
- **HTTP 451**: Returns proper "Unavailable For Legal Reasons" status when blocked

## API

### `GET /`

Returns geolocation check result:

```json
{
  "blocked": false,
  "country": "US",
  "region": "CA",
  "city": "San Francisco",
  "reason": null
}
```

If blocked (HTTP 451):
```json
{
  "blocked": true,
  "country": "US",
  "region": "MS",
  "city": "Jackson",
  "reason": "Age verification laws in your state prevent access to this service"
}
```

## Development

```bash
npm install
npm run dev      # Start local dev server
npm run deploy   # Deploy to Cloudflare
```

## Configuration

Edit `src/index.js` to add more blocked regions:

```javascript
const BLOCKED_REGIONS = ['MS', 'TX']; // Add more state codes as needed
```

## Deployment

1. Install Wrangler: `npm install`
2. Login to Cloudflare: `npx wrangler login`
3. Deploy: `npm run deploy`
4. Configure route in Cloudflare dashboard (e.g., `geo.divine.video/*`)

## How It Works

Cloudflare automatically adds geolocation data to every request via `request.cf`:
- `request.cf.country` - ISO country code
- `request.cf.region` - US state code (for US requests)
- `request.cf.city` - City name

No external API calls needed - it's all built into Cloudflare's edge network.
