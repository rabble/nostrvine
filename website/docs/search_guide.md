# OpenVine Search Implementation Guide

## Overview

OpenVine implements comprehensive real-time search by connecting directly to Nostr relays and filtering events client-side. The search functionality queries for multiple event types including videos, playlists, and user profiles, providing instant results without requiring server-side infrastructure.

## How It Works

### 1. Connection to Nostr Relay

OpenVine connects to the `vine.hol.is` relay using WebSocket:

```javascript
const ws = new WebSocket('wss://vine.hol.is');
```

### 2. Event Subscription

The search requests multiple event types from the relay:

```javascript
const subscription = {
    kinds: [0, 22, 30023], // Kind 0: profiles, Kind 22: videos, Kind 30023: playlists
    limit: 100,            // Get recent events to search through  
    since: Math.floor(Date.now() / 1000) - (30 * 24 * 60 * 60) // Last 30 days
};

ws.send(JSON.stringify(['REQ', subscription.id, subscription]));
```

### 3. Client-Side Filtering

Since vine.hol.is doesn't support NIP-50 (search capability), OpenVine filters events client-side by content type:

```javascript
function processSearchEvent(event, searchQuery) {
    const searchLower = searchQuery.toLowerCase();
    
    switch (event.kind) {
        case 0: // User Profile
            return searchProfile(event, searchLower);
        case 22: // Short Video  
            return searchVideo(event, searchLower);
        case 30023: // Playlist
            return searchPlaylist(event, searchLower);
        default:
            return null;
    }
}

function searchProfile(event, searchLower) {
    try {
        const profile = JSON.parse(event.content);
        const matchesSearch = 
            (profile.name && profile.name.toLowerCase().includes(searchLower)) ||
            (profile.display_name && profile.display_name.toLowerCase().includes(searchLower)) ||
            (profile.about && profile.about.toLowerCase().includes(searchLower)) ||
            event.pubkey.toLowerCase().includes(searchLower);
            
        if (matchesSearch) {
            return {
                type: 'profile',
                pubkey: event.pubkey,
                name: profile.name || profile.display_name || 'Unknown',
                about: profile.about || '',
                picture: profile.picture || '',
                nip05: profile.nip05 || ''
            };
        }
    } catch (e) {
        console.error('Error parsing profile:', e);
    }
    return null;
}

function searchVideo(event, searchLower) {
    const matchesSearch = 
        (event.content && event.content.toLowerCase().includes(searchLower)) ||
        event.pubkey.toLowerCase().includes(searchLower) ||
        event.tags.some(tag => 
            tag[0] === 't' && tag[1] && tag[1].toLowerCase().includes(searchLower)
        );
        
    if (matchesSearch) {
        return convertNostrEventToVideo(event);
    }
    return null;
}

function searchPlaylist(event, searchLower) {
    try {
        const playlist = JSON.parse(event.content);
        const matchesSearch = 
            (playlist.name && playlist.name.toLowerCase().includes(searchLower)) ||
            (playlist.description && playlist.description.toLowerCase().includes(searchLower)) ||
            event.pubkey.toLowerCase().includes(searchLower);
            
        if (matchesSearch) {
            return {
                type: 'playlist',
                id: event.id,
                pubkey: event.pubkey,
                name: playlist.name || 'Untitled Playlist',
                description: playlist.description || '',
                created_at: event.created_at,
                videos: extractPlaylistVideos(event.tags)
            };
        }
    } catch (e) {
        console.error('Error parsing playlist:', e);
    }
    return null;
}
```

### 4. Data Extraction Helpers

#### Video Data Extraction (Kind 22)

```javascript
function convertNostrEventToVideo(event) {
    let videoUrl = '';
    let thumbnailUrl = '';
    
    // Extract video URL from 'r' tags
    for (const tag of event.tags || []) {
        if (tag[0] === 'r' && tag[1]) {
            if (tag[2] === 'video') {
                videoUrl = tag[1];
            } else if (tag[2] === 'thumbnail') {
                thumbnailUrl = tag[1];
            }
        }
    }
    
    if (!videoUrl) return null;
    
    return {
        type: 'video',
        id: event.id,
        url: videoUrl,
        thumbnail: thumbnailUrl,
        username: `${event.pubkey.slice(0, 8)}...`,
        title: event.content || 'Classic Vine',
        pubkey: event.pubkey,
        created_at: event.created_at,
        category: extractTag(event.tags, 'category') || 'General'
    };
}
```

#### Playlist Data Extraction (Kind 30023)

```javascript
function extractPlaylistVideos(tags) {
    const videos = [];
    
    // Look for 'e' tags referencing video events
    for (const tag of tags || []) {
        if (tag[0] === 'e' && tag[1]) {
            videos.push({
                eventId: tag[1],
                relay: tag[2] || null,
                marker: tag[3] || null
            });
        }
    }
    
    return videos;
}
```

#### Profile Data Extraction (Kind 0)

```javascript
function extractProfileData(event) {
    try {
        const profile = JSON.parse(event.content);
        
        return {
            type: 'profile',
            pubkey: event.pubkey,
            name: profile.name || profile.display_name || 'Unknown User',
            display_name: profile.display_name || profile.name || '',
            about: profile.about || '',
            picture: profile.picture || '',
            banner: profile.banner || '',
            nip05: profile.nip05 || '',
            lud16: profile.lud16 || profile.lud06 || '',
            website: profile.website || '',
            created_at: event.created_at
        };
    } catch (e) {
        console.error('Error parsing profile JSON:', e);
        return null;
    }
}
```

## Authentication Requirements

### Current Implementation: No Authentication Required

**Good news!** The vine.hol.is relay allows unauthenticated reads for Kind 22 events, so no authentication is needed for search functionality.

```javascript
// No auth required - connect and query directly
ws.onopen = () => {
    ws.send(JSON.stringify(['REQ', subscription.id, subscription]));
};
```

### If Authentication Were Required (NIP-42)

For relays that require authentication, here's how NIP-42 auth would work:

#### 1. Generate Disposable Key Pair

```javascript
import { schnorr, utils, etc } from '@noble/secp256k1';

function generateKeyPair() {
    const privateKey = utils.randomPrivateKey();
    const publicKey = schnorr.getPublicKey(privateKey);
    
    return { 
        privateKey: etc.bytesToHex(privateKey),
        publicKey: etc.bytesToHex(publicKey)
    };
}
```

#### 2. Handle AUTH Challenge

```javascript
ws.onmessage = async (event) => {
    const message = JSON.parse(event.data);
    const [type, ...args] = message;
    
    if (type === 'AUTH') {
        const challenge = args[0];
        await handleAuth(challenge);
    }
};
```

#### 3. Create Signed AUTH Event

```javascript
async function handleAuth(challenge) {
    const authEvent = {
        kind: 22242,
        pubkey: publicKey,
        created_at: Math.floor(Date.now() / 1000),
        tags: [
            ['relay', 'wss://vine.hol.is'],
            ['challenge', challenge]
        ],
        content: ''
    };
    
    const signedEvent = await signEvent(authEvent, privateKey);
    ws.send(JSON.stringify(['AUTH', signedEvent]));
}
```

#### 4. Sign Event with Schnorr Signature

```javascript
async function signEvent(event, privateKeyHex) {
    // Create serialized event for signing
    const serialized = JSON.stringify([
        0, // Reserved
        event.pubkey,
        event.created_at,
        event.kind,
        event.tags,
        event.content
    ]);
    
    // Hash the serialized event
    const hash = crypto.createHash('sha256').update(serialized).digest();
    event.id = etc.bytesToHex(hash);
    
    // Sign with Schnorr signature
    const signature = await schnorr.sign(hash, privateKeyHex);
    event.sig = etc.bytesToHex(signature);
    
    return event;
}
```

## Nostr Event Structures

### Kind 0 Event (User Profile)

```json
{
    "id": "abc123...",
    "kind": 0,
    "pubkey": "2d6a0f27043055948f4e2d0ff203d0112138ffd394b2a1c94f9da1d6d97f6911",
    "created_at": 1751161705,
    "content": "{\"name\":\"vineuser\",\"display_name\":\"Vine User\",\"about\":\"Creating classic vines\",\"picture\":\"https://example.com/avatar.jpg\",\"nip05\":\"vineuser@openvine.co\",\"website\":\"https://openvine.co\"}",
    "tags": [],
    "sig": "..."
}
```

### Kind 22 Event (Short Video)

```json
{
    "id": "e1857e4d70c7f697af246fe2b3a56deef1d485a8b7797b1474098aaff7cafe7c",
    "kind": 22,
    "pubkey": "2d6a0f27043055948f4e2d0ff203d0112138ffd394b2a1c94f9da1d6d97f6911",
    "created_at": 1751161705,
    "content": "Classic Vine: #christmastree\n\nOriginal creator: Karim Ghantous\nCategory: Nature\nVine ID: 500M0la3d6F\n\n#ClassicVines #Vine #Preserved",
    "tags": [
        ["h", "vine"],
        ["r", "https://api.openvine.co/media/1751113551163-f1895397", "video"],
        ["r", "https://api.openvine.co/media/1751113555090-77f1b0f8", "thumbnail"],
        ["t", "classicvines"],
        ["t", "vine"],
        ["vine_id", "500M0la3d6F"],
        ["category", "Nature"],
        ["original_author", "Karim Ghantous"]
    ],
    "sig": "97a9e1f4f9066a8ee7b4cb3e6c2ca09343dc63c4f11fb5f587369757d8def68f..."
}
```

### Kind 30023 Event (Playlist)

```json
{
    "id": "def456...",
    "kind": 30023,
    "pubkey": "2d6a0f27043055948f4e2d0ff203d0112138ffd394b2a1c94f9da1d6d97f6911",
    "created_at": 1751161705,
    "content": "{\"name\":\"Comedy Gold\",\"description\":\"Best comedy vines compilation\"}",
    "tags": [
        ["d", "comedy-playlist-1"],
        ["e", "video1_event_id", "wss://relay.example.com", "root"],
        ["e", "video2_event_id", "wss://relay.example.com"],
        ["e", "video3_event_id", "wss://relay.example.com"],
        ["t", "comedy"],
        ["t", "playlist"],
        ["image", "https://example.com/playlist-cover.jpg"]
    ],
    "sig": "..."
}
```

### Tag Meanings

#### Video Events (Kind 22)
- `["h", "vine"]` - Hashtag
- `["r", "url", "video"]` - Video file URL
- `["r", "url", "thumbnail"]` - Thumbnail image URL  
- `["t", "tag"]` - General tags
- `["vine_id", "id"]` - Original Vine ID
- `["category", "name"]` - Content category
- `["original_author", "name"]` - Creator name

#### Playlist Events (Kind 30023)
- `["d", "identifier"]` - Unique playlist identifier (replaceable events)
- `["e", "event_id", "relay", "marker"]` - Reference to video events in playlist
- `["t", "tag"]` - Playlist tags (comedy, music, etc.)
- `["image", "url"]` - Playlist cover image
- `["title", "name"]` - Alternative to JSON content for playlist name

#### Profile Events (Kind 0)
- Content is JSON with profile metadata
- No special tags typically used

## Relay Capabilities

### vine.hol.is Relay Information

```json
{
    "name": "vine.hol.is",
    "description": "Groups relay for OpenVine",
    "pubkey": "...",
    "contact": "...",
    "supported_nips": [1, 9, 11, 29, 40, 42, 70],
    "software": "...",
    "version": "..."
}
```

**Important Notes:**
- ✅ Supports NIP-29 (Simple Groups)
- ✅ Supports NIP-42 (Authentication) but doesn't require it for reads
- ❌ Does NOT support NIP-50 (Search) - hence client-side filtering
- ✅ Contains hundreds of Kind 22 video events
- ❓ May contain Kind 0 (profile) and Kind 30023 (playlist) events
- ✅ Allows unauthenticated event subscriptions

**Current Content Analysis:**
- **Kind 22 (Videos)**: ✅ Abundant - hundreds of classic Vine videos
- **Kind 0 (Profiles)**: ❓ Unknown - needs investigation
- **Kind 30023 (Playlists)**: ❓ Unknown - needs investigation

## Performance Considerations

### Search Optimization

1. **Limited Time Range**: Only search last 30 days to reduce data transfer
2. **Event Limit**: Cap at 100 events per content type to maintain responsiveness  
3. **Separate Subscriptions**: Query different kinds separately for better performance
4. **Result Categorization**: Group results by type (videos, profiles, playlists)
5. **Client-Side Caching**: Cache recent events to avoid re-fetching
6. **Connection Timeout**: 8-second timeout prevents hanging connections

#### Multi-Type Search Implementation

```javascript
async function searchAllContent(query) {
    const results = {
        videos: [],
        profiles: [],
        playlists: []
    };
    
    // Search each content type separately for better performance
    const searches = [
        searchContentType(query, [22], 'videos'),      // Videos
        searchContentType(query, [0], 'profiles'),     // Profiles  
        searchContentType(query, [30023], 'playlists') // Playlists
    ];
    
    const searchResults = await Promise.all(searches);
    
    // Combine results
    results.videos = searchResults[0];
    results.profiles = searchResults[1];
    results.playlists = searchResults[2];
    
    return results;
}
```

### Fallback Strategy

```javascript
// If relay search fails, fall back to local search for each content type
function fallbackToLocalSearch(query) {
    const results = {
        videos: [],
        profiles: [],
        playlists: []
    };
    
    // Search local videos
    if (HOMEPAGE_VIDEOS) {
        results.videos = HOMEPAGE_VIDEOS.filter(v => 
            v.username.toLowerCase().includes(query.toLowerCase()) ||
            v.category.toLowerCase().includes(query.toLowerCase()) ||
            v.title.toLowerCase().includes(query.toLowerCase())
        );
    }
    
    // Search local profiles (if any)
    if (FEATURED_USERS) {
        results.profiles = FEATURED_USERS.filter(u =>
            u.username.toLowerCase().includes(query.toLowerCase()) ||
            (u.bio && u.bio.toLowerCase().includes(query.toLowerCase()))
        );
    }
    
    // Search local playlists (if any)
    if (LOCAL_PLAYLISTS) {
        results.playlists = LOCAL_PLAYLISTS.filter(p =>
            p.name.toLowerCase().includes(query.toLowerCase()) ||
            (p.description && p.description.toLowerCase().includes(query.toLowerCase()))
        );
    }
    
    return results;
}
```

## Future Enhancements

1. **Multiple Relays**: Query multiple relays simultaneously for broader results
2. **Advanced Filtering**: Filter by content type, category, date range, creator
3. **Result Ranking**: Sort results by relevance, popularity, or recency
4. **Search Suggestions**: Auto-complete based on popular searches
5. **Profile Following**: Search through followed users' content first
6. **Playlist Management**: Create and edit playlists from search results  
7. **Content Discovery**: Recommend related content based on search history
8. **Real-time Updates**: Live updates when new content matches search terms
9. **Caching Layer**: Cache frequent searches and popular content
10. **NIP-50 Support**: Use server-side search when relays support it

### Search Result UI Components

```javascript
// Example search result display structure
function displaySearchResults(results) {
    return `
        <div class="search-results">
            ${results.videos.length > 0 ? `
                <section class="videos-section">
                    <h3>Videos (${results.videos.length})</h3>
                    <div class="video-grid">
                        ${results.videos.map(video => renderVideoCard(video)).join('')}
                    </div>
                </section>
            ` : ''}
            
            ${results.profiles.length > 0 ? `
                <section class="profiles-section">
                    <h3>Profiles (${results.profiles.length})</h3>
                    <div class="profile-list">
                        ${results.profiles.map(profile => renderProfileCard(profile)).join('')}
                    </div>
                </section>
            ` : ''}
            
            ${results.playlists.length > 0 ? `
                <section class="playlists-section">
                    <h3>Playlists (${results.playlists.length})</h3>
                    <div class="playlist-grid">
                        ${results.playlists.map(playlist => renderPlaylistCard(playlist)).join('')}
                    </div>
                </section>
            ` : ''}
        </div>
    `;
}
```

## Testing

### Current Test Page

Use the test page at `/test-simple.html` to verify:
- ✅ Relay connectivity to vine.hol.is
- ✅ Kind 22 (video) event retrieval  
- ✅ Basic search functionality
- ✅ Error handling

### Expanded Testing Needed

Create enhanced test page to verify:
- ❓ Kind 0 (profile) event availability
- ❓ Kind 30023 (playlist) event availability  
- ❓ Multi-type search performance
- ❓ Cross-content type search accuracy

### Test Implementation

```javascript
// Enhanced test for all content types
async function testAllContentTypes() {
    const contentTests = [
        { kinds: [0], name: 'Profiles', limit: 20 },
        { kinds: [22], name: 'Videos', limit: 50 },  
        { kinds: [30023], name: 'Playlists', limit: 20 },
        { kinds: [0, 22, 30023], name: 'All Content', limit: 100 }
    ];
    
    for (const test of contentTests) {
        console.log(`Testing ${test.name}...`);
        const results = await queryRelay(test.kinds, test.limit);
        console.log(`Found ${results.length} ${test.name.toLowerCase()}`);
    }
}
```

The test page provides real-time debugging information and demonstrates search capabilities without authentication complexity.

## Security Notes

- **Disposable Keys**: Always use disposable key pairs for authentication
- **No Sensitive Data**: Never store private keys or send sensitive information
- **HTTPS Only**: Always use secure WebSocket connections (wss://)
- **Input Validation**: Sanitize search queries to prevent injection attacks

## Dependencies

For authentication-enabled relays:
```javascript
import { schnorr, utils, etc } from '@noble/secp256k1';
```

For basic functionality:
- Native WebSocket API
- Native crypto API (for hashing)
- Standard JavaScript (ES6+)