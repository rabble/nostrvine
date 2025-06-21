#!/usr/bin/env node

// Test script for ready events endpoint with NIP-98 authentication
// Usage: node test-ready-events.js

const crypto = require('crypto');

// Generate a test Nostr event for NIP-98 auth
function generateNIP98Event(url, method) {
  const event = {
    id: '',
    pubkey: 'd91191e30e00444b942c0e82cad470b32af171764c2275bee0bd99377efd4075',
    created_at: Math.floor(Date.now() / 1000),
    kind: 27235,
    tags: [
      ['u', url],
      ['method', method]
    ],
    content: '',
    sig: ''
  };

  // Generate event ID (would need proper Nostr signing in production)
  const eventData = JSON.stringify([
    0,
    event.pubkey,
    event.created_at,
    event.kind,
    event.tags,
    event.content
  ]);
  
  event.id = crypto.createHash('sha256').update(eventData).digest('hex');
  
  // In production, this would be signed with the private key
  event.sig = 'test_signature_' + crypto.randomBytes(32).toString('hex');

  return event;
}

// Test endpoints
const endpoints = [
  {
    name: 'Get Ready Events',
    method: 'GET',
    path: '/v1/media/ready-events'
  },
  {
    name: 'Get Specific Event',
    method: 'GET',
    path: '/v1/media/ready-events/test_video_123'
  },
  {
    name: 'Delete Ready Event',
    method: 'DELETE',
    path: '/v1/media/ready-events',
    body: { public_id: 'test_video_123' }
  }
];

console.log('Ready Events Endpoint Tests');
console.log('==========================\\n');

endpoints.forEach(endpoint => {
  const url = `https://api.openvine.co${endpoint.path}`;
  const event = generateNIP98Event(url, endpoint.method);
  const authHeader = 'Nostr ' + Buffer.from(JSON.stringify(event)).toString('base64');

  console.log(`${endpoint.name}:`);
  console.log(`${endpoint.method} ${endpoint.path}`);
  console.log('\\nCURL command:');
  
  let curlCmd = `curl -X ${endpoint.method} ${url} \\
  -H "Authorization: ${authHeader}" \\
  -H "Content-Type: application/json"`;
  
  if (endpoint.body) {
    curlCmd += ` \\
  -d '${JSON.stringify(endpoint.body)}'`;
  }
  
  console.log(curlCmd);
  console.log('\\n---\\n');
});

console.log('Testing with workers.dev URL:');
console.log('============================\\n');

const workersUrl = 'https://nostrvine-video-api.nos-verse.workers.dev/v1/media/ready-events';
const workersEvent = generateNIP98Event(workersUrl, 'GET');
const workersAuth = 'Nostr ' + Buffer.from(JSON.stringify(workersEvent)).toString('base64');

console.log(`curl -X GET ${workersUrl} \\
  -H "Authorization: ${workersAuth}" \\
  -H "Content-Type: application/json"`);

console.log('\\n\\nNote: These are test commands. In production, use proper Nostr key signing.');