// Test script to generate real NIP-98 auth event using nostr-tools
import { generateSecretKey, getPublicKey, finalizeEvent, getEventHash } from 'nostr-tools';

// Generate a test keypair
const secretKey = generateSecretKey();
const publicKey = getPublicKey(secretKey);

console.log('Test keypair generated:');
console.log('Secret key:', Buffer.from(secretKey).toString('hex'));
console.log('Public key:', publicKey);

// Create NIP-98 event
const url = 'https://nostrvine-backend.protestnet.workers.dev/v1/media/request-upload';
const method = 'POST';

const eventTemplate = {
  kind: 27235,
  created_at: Math.floor(Date.now() / 1000),
  tags: [
    ['method', method],
    ['u', url]
  ],
  content: '',
};

// Sign the event
const signedEvent = finalizeEvent(eventTemplate, secretKey);

console.log('\nValid NIP-98 Event:');
console.log(JSON.stringify(signedEvent, null, 2));

// Encode for Authorization header
const base64Event = Buffer.from(JSON.stringify(signedEvent)).toString('base64');
console.log('\nBase64 encoded:');
console.log(base64Event);

console.log('\nCurl command:');
console.log(`curl -X POST -s 'https://nostrvine-backend.protestnet.workers.dev/v1/media/request-upload' -H 'Content-Type: application/json' -H 'Authorization: Nostr ${base64Event}' -d '{}'`);