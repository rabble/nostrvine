#!/usr/bin/env node

// Script to create test video metadata in KV for development/testing
// Run with: node scripts/create-test-data.js

const testVideos = [
  {
    videoId: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    duration: 6.0,
    fileSize: 2097152, // 2MB
    renditions: {
      '480p': { key: 'videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/480p.mp4', size: 1048576 },
      '720p': { key: 'videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/720p.mp4', size: 2097152 }
    },
    poster: 'videos/1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef/poster.jpg',
    uploadTimestamp: Date.now() - 86400000, // 1 day ago
    originalEventId: 'note1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq'
  },
  {
    videoId: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    duration: 5.5,
    fileSize: 1572864, // 1.5MB
    renditions: {
      '480p': { key: 'videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/480p.mp4', size: 786432 },
      '720p': { key: 'videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/720p.mp4', size: 1572864 }
    },
    poster: 'videos/abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890/poster.jpg',
    uploadTimestamp: Date.now() - 7200000, // 2 hours ago
    originalEventId: 'note1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'
  },
  {
    videoId: 'fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321',
    duration: 6.2,
    fileSize: 3145728, // 3MB
    renditions: {
      '480p': { key: 'videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/480p.mp4', size: 1572864 },
      '720p': { key: 'videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/720p.mp4', size: 3145728 }
    },
    poster: 'videos/fedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321/poster.jpg',
    uploadTimestamp: Date.now() - 3600000, // 1 hour ago
    originalEventId: 'note1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  }
];

console.log('Test Video Metadata for KV Store:');
console.log('=================================\n');

testVideos.forEach(video => {
  console.log(`Key: video:${video.videoId}`);
  console.log(`Value: ${JSON.stringify(video, null, 2)}`);
  console.log('\n---\n');
});

console.log('\nWrangler Commands to Add Test Data:');
console.log('===================================\n');

testVideos.forEach(video => {
  const key = `video:${video.videoId}`;
  const value = JSON.stringify(video);
  console.log(`wrangler kv key put --binding=VIDEO_METADATA "${key}" '${value}'`);
});

console.log('\n\nBatch Upload Script:');
console.log('===================\n');
console.log('# Save this as upload-test-data.sh and run with bash\n');

console.log('#!/bin/bash\n');
testVideos.forEach(video => {
  const key = `video:${video.videoId}`;
  const value = JSON.stringify(video).replace(/'/g, "'\"'\"'");
  console.log(`echo "Uploading ${video.videoId}..."`);
  console.log(`wrangler kv key put --binding=VIDEO_METADATA "${key}" '${value}' --env development`);
  console.log('');
});

console.log('\n\nTest URLs:');
console.log('==========\n');

console.log('# Local development:');
testVideos.forEach(video => {
  console.log(`curl http://localhost:8787/api/video/${video.videoId}`);
});

console.log('\n# Staging:');
testVideos.forEach(video => {
  console.log(`curl https://nostrvine-video-api-staging.protestnet.workers.dev/api/video/${video.videoId}`);
});

console.log('\n# Batch test:');
const videoIds = testVideos.map(v => v.videoId);
console.log(`curl -X POST http://localhost:8787/api/videos/batch \\
  -H "Content-Type: application/json" \\
  -d '{"videoIds": ${JSON.stringify(videoIds, null, 2).split('\n').join('\n  ')}}'`);