# OpenVine Analytics Worker v1

**Minimal, privacy-focused analytics for content popularity tracking**

## Purpose

This analytics worker is the foundation for OpenVine's trending content discovery. It tracks what videos are popular **without collecting any user data**, creating the groundwork for:

- Popular/trending video feeds  
- Global content discovery
- Future opt-in personalization algorithms

## Privacy-First Design

✅ **What we track:** Video views by event ID  
✅ **What we DON'T track:** Users, IPs, personal data  
✅ **Rate limiting:** Anonymous IP hashing (not stored)  
✅ **Future ready:** Infrastructure for opt-in user features

## API Endpoints

### Track Video View
```bash
POST /analytics/view
Content-Type: application/json

{
  "eventId": "22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3",
  "source": "web"
}
```

### Get Trending Videos
```bash
GET /analytics/trending/videos?limit=20
```

### Get Video Stats
```bash
GET /analytics/video/{eventId}/stats
```

## Deployment

1. **Create KV Namespace:**
```bash
wrangler kv:namespace create "ANALYTICS_KV"
wrangler kv:namespace create "ANALYTICS_KV" --preview
```

2. **Update wrangler.toml** with your KV namespace IDs

3. **Deploy:**
```bash
npm install
wrangler deploy
```

## Future Algorithm Foundation

This minimal system creates the data foundation for:

- **Hashtag trending** (when we extract them from Nostr events)
- **Personalized feeds** (if users opt-in and authenticate)  
- **Content recommendations** (based on viewing patterns)
- **Creator analytics** (view metrics for content creators)

The architecture is designed to add these features **without breaking privacy** for users who prefer anonymous browsing.

## Integration

The analytics worker integrates with:
- **Website Nostr viewer** (automatic view tracking)
- **Mobile app** (via same API endpoints)
- **Future admin dashboards** (for trending content curation)

View tracking happens automatically when users watch videos, enabling organic trending discovery while respecting privacy choices.