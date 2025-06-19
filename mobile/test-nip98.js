// Test script to generate NIP-98 auth event for testing backend
const crypto = require('crypto');

// Generate a test keypair (DO NOT use in production)
const privateKey = crypto.randomBytes(32).toString('hex');
const publicKey = generatePublicKey(privateKey);

function generatePublicKey(privateKeyHex) {
  // This is a simplified version - real implementation needs secp256k1
  return crypto.createHash('sha256').update(privateKeyHex).digest('hex');
}

function createNIP98Event(method, url, privateKey) {
  const event = {
    id: '',
    pubkey: generatePublicKey(privateKey),
    created_at: Math.floor(Date.now() / 1000),
    kind: 27235,
    tags: [
      ['method', method],
      ['u', url]
    ],
    content: '',
    sig: ''
  };
  
  // Calculate event ID (simplified)
  const serialization = [0, event.pubkey, event.created_at, event.kind, event.tags, event.content];
  event.id = crypto.createHash('sha256').update(JSON.stringify(serialization)).digest('hex');
  
  // Sign event (simplified - real implementation needs secp256k1)
  event.sig = crypto.createHash('sha256').update(event.id + privateKey).digest('hex').padEnd(128, '0');
  
  return event;
}

// Create test event
const testEvent = createNIP98Event('POST', 'https://nostrvine-backend.protestnet.workers.dev/v1/media/request-upload', privateKey);
const base64Event = Buffer.from(JSON.stringify(testEvent)).toString('base64');

console.log('Test NIP-98 Event:');
console.log(JSON.stringify(testEvent, null, 2));
console.log('\nBase64 encoded:');
console.log(base64Event);
console.log('\nCurl command:');
console.log(`curl -X POST -s https://nostrvine-backend.protestnet.workers.dev/v1/media/request-upload -H "Content-Type: application/json" -H "Authorization: Nostr ${base64Event}" -d '{}'`);