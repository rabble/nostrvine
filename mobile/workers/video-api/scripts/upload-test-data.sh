Test Video Metadata for KV Store:
=================================

Key: video:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
Value: {
  "videoId": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "duration": 6,
  "fileSize": 2097152,
  "renditions": {
    "480p": {
      "key": "videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/480p.mp4",
      "size": 1048576
    },
    "720p": {
      "key": "videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/720p.mp4",
      "size": 2097152
    }
  },
  "poster": "videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/poster.jpg",
  "uploadTimestamp": 1750367573639,
  "originalEventId": "note1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"
}

---

Key: video:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
Value: {
  "videoId": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  "duration": 5.5,
  "fileSize": 1572864,
  "renditions": {
    "480p": {
      "key": "videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/480p.mp4",
      "size": 786432
    },
    "720p": {
      "key": "videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/720p.mp4",
      "size": 1572864
    }
  },
  "poster": "videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/poster.jpg",
  "uploadTimestamp": 1750446773640,
  "originalEventId": "note1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
}

---

Key: video:fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321
Value: {
  "videoId": "fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321",
  "duration": 6.2,
  "fileSize": 3145728,
  "renditions": {
    "480p": {
      "key": "videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/480p.mp4",
      "size": 1572864
    },
    "720p": {
      "key": "videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/720p.mp4",
      "size": 3145728
    }
  },
  "poster": "videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/poster.jpg",
  "uploadTimestamp": 1750450373640,
  "originalEventId": "note1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

---


Wrangler Commands to Add Test Data:
===================================

wrangler kv key put --binding=VIDEO_METADATA "video:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef" '{"videoId":"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef","duration":6,"fileSize":2097152,"renditions":{"480p":{"key":"videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/480p.mp4","size":1048576},"720p":{"key":"videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/720p.mp4","size":2097152}},"poster":"videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/poster.jpg","uploadTimestamp":1750367573639,"originalEventId":"note1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"}'
wrangler kv key put --binding=VIDEO_METADATA "video:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890" '{"videoId":"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890","duration":5.5,"fileSize":1572864,"renditions":{"480p":{"key":"videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/480p.mp4","size":786432},"720p":{"key":"videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/720p.mp4","size":1572864}},"poster":"videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/poster.jpg","uploadTimestamp":1750446773640,"originalEventId":"note1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"}'
wrangler kv key put --binding=VIDEO_METADATA "video:fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321" '{"videoId":"fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321","duration":6.2,"fileSize":3145728,"renditions":{"480p":{"key":"videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/480p.mp4","size":1572864},"720p":{"key":"videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/720p.mp4","size":3145728}},"poster":"videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/poster.jpg","uploadTimestamp":1750450373640,"originalEventId":"note1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}'


Batch Upload Script:
===================

# Save this as upload-test-data.sh and run with bash

#!/bin/bash

echo "Uploading 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef..."
wrangler kv key put --binding=VIDEO_METADATA "video:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef" '{"videoId":"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef","duration":6,"fileSize":2097152,"renditions":{"480p":{"key":"videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/480p.mp4","size":1048576},"720p":{"key":"videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/720p.mp4","size":2097152}},"poster":"videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/poster.jpg","uploadTimestamp":1750367573639,"originalEventId":"note1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"}' --env development

echo "Uploading abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890..."
wrangler kv key put --binding=VIDEO_METADATA "video:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890" '{"videoId":"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890","duration":5.5,"fileSize":1572864,"renditions":{"480p":{"key":"videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/480p.mp4","size":786432},"720p":{"key":"videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/720p.mp4","size":1572864}},"poster":"videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/poster.jpg","uploadTimestamp":1750446773640,"originalEventId":"note1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"}' --env development

echo "Uploading fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321..."
wrangler kv key put --binding=VIDEO_METADATA "video:fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321" '{"videoId":"fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321","duration":6.2,"fileSize":3145728,"renditions":{"480p":{"key":"videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/480p.mp4","size":1572864},"720p":{"key":"videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/720p.mp4","size":3145728}},"poster":"videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/poster.jpg","uploadTimestamp":1750450373640,"originalEventId":"note1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}' --env development



Test URLs:
==========

# Local development:
curl http://localhost:8787/api/video/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
curl http://localhost:8787/api/video/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
curl http://localhost:8787/api/video/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321

# Staging:
curl https://nostrvine-video-api-staging.protestnet.workers.dev/api/video/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
curl https://nostrvine-video-api-staging.protestnet.workers.dev/api/video/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
curl https://nostrvine-video-api-staging.protestnet.workers.dev/api/video/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321

# Batch test:
curl -X POST http://localhost:8787/api/videos/batch \
  -H "Content-Type: application/json" \
  -d '{"videoIds": [
    "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
    "fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"
  ]}'
