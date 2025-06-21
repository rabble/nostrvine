#!/bin/bash

# Upload test video metadata to KV store

echo "Uploading test video 1..."
wrangler kv key put --binding=VIDEO_METADATA --preview false "video:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef" '{"videoId":"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef","duration":6,"fileSize":2097152,"renditions":{"480p":{"key":"videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/480p.mp4","size":1048576},"720p":{"key":"videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/720p.mp4","size":2097152}},"poster":"videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/poster.jpg","uploadTimestamp":1750367573639,"originalEventId":"note1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"}'

echo "Uploading test video 2..."
wrangler kv key put --binding=VIDEO_METADATA --preview false "video:abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890" '{"videoId":"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890","duration":5.5,"fileSize":1572864,"renditions":{"480p":{"key":"videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/480p.mp4","size":786432},"720p":{"key":"videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/720p.mp4","size":1572864}},"poster":"videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/poster.jpg","uploadTimestamp":1750444173639,"originalEventId":"note1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"}'

echo "Uploading test video 3..."
wrangler kv key put --binding=VIDEO_METADATA --preview false "video:fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321" '{"videoId":"fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321","duration":6.2,"fileSize":3145728,"renditions":{"480p":{"key":"videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/480p.mp4","size":1572864},"720p":{"key":"videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/720p.mp4","size":3145728}},"poster":"videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/poster.jpg","uploadTimestamp":1750447773639,"originalEventId":"note1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}'

echo "Done! Test the API with:"
echo ""
echo "# Single video:"
echo "curl http://localhost:8787/api/video/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
echo ""
echo "# Batch request:"
echo 'curl -X POST http://localhost:8787/api/videos/batch -H "Content-Type: application/json" -d '"'"'{"videoIds":["1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef","abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890","fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"]}'"'"