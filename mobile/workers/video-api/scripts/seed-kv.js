#\!/usr/bin/env node

// Script to seed KV with test video metadata
// Usage: node scripts/seed-kv.js

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
    uploadTimestamp: Date.now(),
    originalEventId: 'nostr-event-123'
  }
];

console.log('Seeding KV with test video metadata...');
console.log('\nTo seed your KV namespace, run these commands:');

testVideos.forEach(video => {
  const key = `video:${video.videoId}`;
  const value = JSON.stringify(video);
  console.log(`\nwrangler kv:key put --binding VIDEO_METADATA "${key}" '${value}'`);
});
EOF < /dev/null