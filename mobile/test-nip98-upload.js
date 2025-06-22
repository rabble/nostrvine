#!/usr/bin/env node

// Test NIP-98 authentication with real upload
const crypto = require('crypto');

// Generate a test private key (32 bytes)
function generatePrivateKey() {
  return crypto.randomBytes(32);
}

// Convert private key to public key
function getPublicKey(privateKey) {
  // This is a simplified version - in real implementation you'd use secp256k1
  const hash = crypto.createHash('sha256').update(privateKey).digest();
  return hash.toString('hex');
}

// Create NIP-98 authorization event
function createNIP98Event(privateKey, url, method) {
  const pubkey = getPublicKey(privateKey);
  const now = Math.floor(Date.now() / 1000);
  
  const event = {
    kind: 27235,
    pubkey: pubkey,
    created_at: now,
    tags: [
      ['u', url],
      ['method', method.toUpperCase()]
    ],
    content: ''
  };
  
  // Create event ID (hash of serialized event)
  const serialized = JSON.stringify([
    0,
    event.pubkey,
    event.created_at,
    event.kind,
    event.tags,
    event.content
  ]);
  
  event.id = crypto.createHash('sha256').update(serialized).digest('hex');
  
  // Sign event (simplified - normally would use secp256k1)
  const signature = crypto.createHash('sha256')
    .update(event.id + privateKey.toString('hex'))
    .digest('hex');
  
  event.sig = signature;
  
  return event;
}

// Test the upload
async function testUpload() {
  const privateKey = generatePrivateKey();
  const url = 'https://api.openvine.co/api/upload';
  const method = 'POST';
  
  const event = createNIP98Event(privateKey, url, method);
  const authHeader = `Nostr ${Buffer.from(JSON.stringify(event)).toString('base64')}`;
  
  console.log('🔑 Generated test keys');
  console.log('📝 Created NIP-98 event');
  console.log('🔐 Auth header:', authHeader.substring(0, 50) + '...');
  
  // Create a minimal test video file
  const fs = require('fs');
  const testVideoPath = '/tmp/test-video.mp4';
  fs.writeFileSync(testVideoPath, 'fake video content');
  
  // Use curl to test upload
  const { spawn } = require('child_process');
  
  const curl = spawn('curl', [
    '-X', 'POST',
    'https://api.openvine.co/api/upload',
    '-H', `Authorization: ${authHeader}`,
    '-F', `file=@${testVideoPath};type=video/mp4`,
    '-v'
  ]);
  
  curl.stdout.on('data', (data) => {
    console.log('📤 Response:', data.toString());
  });
  
  curl.stderr.on('data', (data) => {
    console.log('🔍 Debug:', data.toString());
  });
  
  curl.on('close', (code) => {
    console.log(`✅ Process finished with code ${code}`);
    // Cleanup
    fs.unlinkSync(testVideoPath);
  });
}

testUpload().catch(console.error);