// Quick test to find video events on Nostr
import { SimplePool } from 'nostr-tools';

const pool = new SimplePool();
const relays = ['wss://relay.damus.io', 'wss://nos.lol', 'wss://relay.nostr.band'];

console.log('🔍 Searching for video-related events...\n');

// Search for various video-related kinds
const videoKinds = [
  22,     // NIP-71 short video
  34235,  // Video event
  34236,  // Short video event  
  34550,  // NostrVine specific
  1063,   // File metadata (might include videos)
];

console.log(`Looking for kinds: ${videoKinds.join(', ')}\n`);

const sub = pool.sub(relays, [{
  kinds: videoKinds,
  limit: 100
}]);

let count = 0;
const eventsByKind = {};

sub.on('event', (event) => {
  count++;
  if (!eventsByKind[event.kind]) {
    eventsByKind[event.kind] = 0;
  }
  eventsByKind[event.kind]++;
  
  console.log(`Found Kind ${event.kind} event from ${event.pubkey.substring(0, 8)}...`);
  
  // Show some tags to understand structure
  if (count <= 5) {
    console.log('Tags:', event.tags.filter(tag => tag[0] === 'url' || tag[0] === 'imeta' || tag[0] === 'title'));
    console.log('Content preview:', event.content.substring(0, 100));
    console.log('---');
  }
});

sub.on('eose', () => {
  console.log(`\n✅ Search complete! Found ${count} total events`);
  console.log('Events by kind:', eventsByKind);
  pool.close(relays);
  process.exit(0);
});

// Timeout after 30 seconds
setTimeout(() => {
  console.log('\n⏱️ Timeout reached');
  console.log(`Found ${count} events so far`);
  console.log('Events by kind:', eventsByKind);
  pool.close(relays);
  process.exit(0);
}, 30000);