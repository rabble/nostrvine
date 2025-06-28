# Vine Archive Kind 22 Event Specification

## Overview

This document describes how we use Nostr kind 22 events to store archived Vine videos, including our custom extensions and data storage patterns.

## Event Structure

### Basic Kind 22 Format
```json
{
  "id": "<event_id>",
  "pubkey": "<creator_public_key>",
  "created_at": 1234567890,
  "kind": 22,
  "tags": [...],
  "content": "<description>",
  "sig": "<signature>"
}
```

### Required Tags

#### 1. Group Tag (h)
- **Tag**: `["h", "vine"]`
- **Purpose**: Required by vine.hol.is relay for group/community identification
- **NIP**: NIP-72 (Moderated Communities)

#### 2. Replaceable Event ID (d)
- **Tag**: `["d", "<vine_id>"]`
- **Purpose**: Original Vine video ID, makes the event replaceable
- **NIP**: NIP-33 (Parameterized Replaceable Events)
- **Example**: `["d", "500JEAXgLPF"]`

#### 3. Video URL
- **Tag**: `["url", "<cdn_url>"]`
- **Purpose**: Direct link to the video file on CDN
- **Example**: `["url", "https://api.openvine.co/media/1751085897568-0fd41442"]`

#### 4. Media Type
- **Tag**: `["m", "video/mp4"]`
- **Purpose**: MIME type of the video file
- **Values**: Usually `"video/mp4"`, can be `"video/webm"` or `"video/quicktime"`

### Optional Tags

#### 5. Thumbnail
- **Tag**: `["thumb", "<thumbnail_url>"]`
- **Purpose**: Preview image for the video
- **Example**: `["thumb", "https://api.openvine.co/media/1751085892052-74bdc081"]`

#### 6. Image (duplicate of thumb)
- **Tag**: `["image", "<thumbnail_url>"]`
- **Purpose**: Some clients look for "image" instead of "thumb"

#### 7. Dimensions
- **Tag**: `["dim", "480x480"]`
- **Purpose**: Video dimensions (Vines were square format)

#### 8. Hashtags
- **Tag**: `["t", "<hashtag>"]`
- **Purpose**: Original hashtags from the Vine, plus our additions
- **Required hashtags**: `["t", "vine"]`, `["t", "rescued"]`, `["t", "archive"]`

#### 9. Alt Text
- **Tag**: `["alt", "Vine video: <title>"]`
- **Purpose**: Accessibility text describing the video

#### 10. Client
- **Tag**: `["client", "featured-v4-publisher-vine-hol-is"]`
- **Purpose**: Identifies which tool published the event

#### 11. Expiration
- **Tag**: `["expiration", "<unix_timestamp>"]`
- **Purpose**: When the event should be deleted (we use 72-168 hours)
- **NIP**: NIP-40 (Expiration Timestamp)

### Content Field

The content field contains a human-readable description:

```
<title>

Original stats: <loops> loops • <likes> likes

By @<username> on <date>
📅 Rescued from archive.org
🔗 Original: <vine_permalink>
📰 Archive: <wayback_url>

⏰ This post expires in <hours> hours
```

## Data Storage

### 1. Published Vines Tracking
**File**: `published_vines_v4.json`
```json
{
  "published_vines": ["vine_id_1", "vine_id_2", ...],
  "last_updated": 1234567890
}
```

### 2. User Profiles
**Directory**: `vine_user_profiles/`
**File format**: `<sanitized_username>.json`
```json
{
  "username": "original_username",
  "profile": {
    "name": "username",
    "display_name": "username",
    "about": "Rescued Vine creator...",
    "picture": "https://api.openvine.co/static/avatars/vine_<username>.jpg",
    "banner": "https://api.openvine.co/static/banners/vine_archive.jpg",
    "website": "https://openvine.co/vine/<username>",
    "nip05": "<username>@vine.openvine.co"
  },
  "npub": "npub1...",
  "created_at": 1234567890,
  "last_published": 1234567890,
  "videos_published": 5
}
```

### 3. User Keys
**Directory**: `vine_user_profiles/`
**File format**: `<sanitized_username>.nsec`
- Contains the private key in nsec format
- File permissions: 0600 (owner read/write only)

### 4. CDN URL Cache
**File**: `cdn_urls_cache.json` (optional)
```json
{
  "vine_id": "cdn_url",
  ...
}
```

## Vine ID Usage

The vine_id serves multiple purposes:

1. **Unique Identifier**: Links the Nostr event to the original Vine
2. **Deduplication**: Prevents republishing the same content
3. **Replaceability**: Allows updating the event (same vine_id replaces old event)
4. **Querying**: Can search for specific vines using `{"#d": ["vine_id"]}`
5. **Fallback Username**: When no username found, becomes `vine_user_<vine_id>`

## Example Complete Event

```json
{
  "id": "3c30cbe2fae3540544c0a1a1479abb80586ef52243f982c968975a3d403ce626",
  "pubkey": "9cd45e69e0b27f3c565fdfa6d3376947e0d639a12a49593d04a1e672174ade8d",
  "created_at": 1751089237,
  "kind": 22,
  "tags": [
    ["h", "vine"],
    ["d", "500JEAXgLPF"],
    ["url", "https://api.openvine.co/media/1751085897568-0fd41442"],
    ["m", "video/mp4"],
    ["thumb", "https://api.openvine.co/media/1751085892052-74bdc081"],
    ["image", "https://api.openvine.co/media/1751085892052-74bdc081"],
    ["dim", "480x480"],
    ["t", "vine"],
    ["t", "rescued"],
    ["t", "archive"],
    ["alt", "Vine video: Original Vine content"],
    ["client", "featured-v4-publisher-vine-hol-is"],
    ["expiration", "1751348437"]
  ],
  "content": "Original Vine content\n\nOriginal stats: 1,234 loops • 567 likes\n\nBy @username on January 15, 2016\n📅 Rescued from archive.org\n🔗 Original: https://vine.co/v/500JEAXgLPF\n📰 Archive: https://web.archive.org/web/20160115/https://vine.co/v/500JEAXgLPF\n\n⏰ This post expires in 72 hours",
  "sig": "..."
}
```

## Querying Vines

### Find all vines
```json
{
  "kinds": [22],
  "#h": ["vine"]
}
```

### Find specific vine
```json
{
  "kinds": [22],
  "#d": ["500JEAXgLPF"]
}
```

### Find vines by user
```json
{
  "kinds": [22],
  "authors": ["<user_pubkey_hex>"],
  "#h": ["vine"]
}
```

## Implementation Notes

1. Each Vine creator gets their own Nostr identity (keypair)
2. Usernames are sanitized for filesystem safety
3. Unknown users fallback to `vine_user_<vine_id>`
4. Events expire to manage storage (configurable 72-168 hours)
5. The relay vine.hol.is requires the `["h", "vine"]` tag
6. CDN URLs are reused when possible to avoid re-uploading