#!/usr/bin/env node

// Test script for Cloudinary webhook endpoint
// Usage: node test-webhook.js <api-secret>

const crypto = require('crypto');

const API_SECRET = process.argv[2];
if (!API_SECRET) {
  console.error('Usage: node test-webhook.js <api-secret>');
  process.exit(1);
}

// Test webhook payload
const payload = {
  notification_type: 'upload',
  public_id: 'test_video_123',
  version: 1719001234,
  width: 1920,
  height: 1080,
  format: 'mp4',
  resource_type: 'video',
  created_at: new Date().toISOString(),
  bytes: 5242880,
  etag: 'abc123def456',
  secure_url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1719001234/test_video_123.mp4',
  context: 'pubkey=d91191e30e00444b942c0e82cad470b32af171764c2275bee0bd99377efd4075',
  eager: [
    {
      transformation: 'f_mp4,vc_h264,q_auto',
      width: 1920,
      height: 1080,
      bytes: 4194304,
      format: 'mp4',
      secure_url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/f_mp4,vc_h264,q_auto/v1719001234/test_video_123.mp4'
    },
    {
      transformation: 'f_gif,fps_10,q_auto:good',
      width: 480,
      height: 270,
      bytes: 1048576,
      format: 'gif',
      secure_url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/f_gif,fps_10,q_auto:good/v1719001234/test_video_123.gif'
    }
  ]
};

// Generate signature
const timestamp = Math.floor(Date.now() / 1000).toString();
const body = JSON.stringify(payload);
const stringToSign = body + timestamp + API_SECRET;
const signature = crypto.createHash('sha1').update(stringToSign).digest('hex');

console.log('Test Webhook Request:');
console.log('====================');
console.log('URL: https://api.openvine.co/v1/media/webhook');
console.log('Method: POST');
console.log('Headers:');
console.log(`  X-Cld-Signature: ${signature}`);
console.log(`  X-Cld-Timestamp: ${timestamp}`);
console.log('  Content-Type: application/json');
console.log('Body:');
console.log(JSON.stringify(payload, null, 2));
console.log('\nCURL command:');
console.log(`curl -X POST https://api.openvine.co/v1/media/webhook \\
  -H "X-Cld-Signature: ${signature}" \\
  -H "X-Cld-Timestamp: ${timestamp}" \\
  -H "Content-Type: application/json" \\
  -d '${body}'`);

// Test with workers.dev URL (fallback)
console.log('\n\nWorkers.dev URL test:');
console.log(`curl -X POST https://nostrvine-video-api.nos-verse.workers.dev/v1/media/webhook \\
  -H "X-Cld-Signature: ${signature}" \\
  -H "X-Cld-Timestamp: ${timestamp}" \\
  -H "Content-Type: application/json" \\
  -d '${body}'`);