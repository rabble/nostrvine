// crawler.js - Simple Nostr video crawler
import { config } from 'dotenv';
import { SimplePool } from 'nostr-tools';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import fetch from 'node-fetch';
import crypto from 'crypto';
import path from 'path';
import { fileURLToPath } from 'url';

// Get current directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables from the crawler directory
config({ path: path.join(__dirname, '.env') });

// Open SQLite database for deduplication
const db = await open({
  filename: path.join(__dirname, 'crawler.db'),
  driver: sqlite3.Database
});

// Create tables
await db.exec(`
  CREATE TABLE IF NOT EXISTS seen_events (
    event_id TEXT PRIMARY KEY,
    created_at INTEGER
  );
  CREATE TABLE IF NOT EXISTS seen_videos (
    video_id TEXT PRIMARY KEY,
    url TEXT,
    submitted_at INTEGER
  );
`);

// Initialize Nostr connection
const pool = new SimplePool();
const relays = process.env.NOSTR_RELAYS.split(',');

console.log('🚀 Starting NostrVine crawler...');
console.log(`📡 Connecting to relays: ${relays.join(', ')}`);

// Track stats
let stats = {
  eventsFound: 0,
  newVideos: 0,
  duplicates: 0,
  apiErrors: 0
};

// Video batch queue
let videoQueue = [];
const BATCH_SIZE = 10;

// Process video event
async function processVideoEvent(event) {
  stats.eventsFound++;
  
  // Check if we've seen this event
  const existing = await db.get(
    'SELECT event_id FROM seen_events WHERE event_id = ?',
    event.id
  );
  
  if (existing) {
    stats.duplicates++;
    return;
  }
  
  // Mark as seen
  await db.run(
    'INSERT INTO seen_events (event_id, created_at) VALUES (?, ?)',
    event.id,
    Date.now()
  );
  
  // Extract video data
  const videoData = extractVideoData(event);
  if (!videoData.url) {
    console.log('⚠️  No video URL found in event:', event.id.substring(0, 8));
    return;
  }
  
  // Check if we've seen this video URL
  const videoId = crypto.createHash('sha256').update(videoData.url).digest('hex');
  const existingVideo = await db.get(
    'SELECT video_id FROM seen_videos WHERE video_id = ?',
    videoId
  );
  
  if (existingVideo) {
    stats.duplicates++;
    return;
  }
  
  // Add to queue
  videoQueue.push({
    id: videoId,
    ...videoData,
    discovered_at: new Date().toISOString()
  });
  
  console.log(`✅ Found new video: ${videoData.title || 'Untitled'} by ${event.pubkey.substring(0, 8)}...`);
  stats.newVideos++;
  
  // Submit batch if ready
  if (videoQueue.length >= BATCH_SIZE) {
    await submitVideoBatch();
  }
}

// Extract video metadata from event
function extractVideoData(event) {
  const data = {
    url: null,
    title: null,
    thumbnail: null,
    duration: null,
    author_pubkey: event.pubkey,
    created_at: new Date(event.created_at * 1000).toISOString()
  };
  
  // Parse tags
  for (const tag of event.tags) {
    if (tag[0] === 'url' && tag[1]) {
      data.url = tag[1];
    } else if (tag[0] === 'title' && tag[1]) {
      data.title = tag[1];
    } else if (tag[0] === 'thumb' && tag[1]) {
      data.thumbnail = tag[1];
    } else if (tag[0] === 'thumbnail' && tag[1]) {
      data.thumbnail = tag[1];
    } else if (tag[0] === 'duration' && tag[1]) {
      data.duration = parseInt(tag[1]);
    } else if (tag[0] === 'imeta' && tag.length > 1) {
      // Parse imeta tags which contain space-separated key-value pairs
      for (let i = 1; i < tag.length; i++) {
        const part = tag[i];
        if (part.startsWith('url ')) {
          data.url = part.substring(4);
        } else if (part.startsWith('m ') && part.includes('video')) {
          // It's a video mime type
          data.mimeType = part.substring(2);
        } else if (part.startsWith('alt ')) {
          data.title = part.substring(4) || data.title;
        } else if (part.startsWith('dim ')) {
          data.dimensions = part.substring(4);
        } else if (part.startsWith('size ')) {
          data.fileSize = parseInt(part.substring(5));
        }
      }
    }
  }
  
  // Check content for URL if not in tags (especially for Kind 1063)
  if (!data.url && event.content) {
    const urlMatch = event.content.match(/(https?:\/\/[^\s]+\.(mp4|mov|webm|gif))/i);
    if (urlMatch) {
      data.url = urlMatch[1];
    }
  }
  
  // Parse content as potential title if no title tag and it's short
  if (!data.title && event.content && event.content.length < 200 && event.content.length > 0) {
    data.title = event.content.trim();
  }
  
  // Only return if we found a video URL
  if (data.url && data.url.match(/\.(mp4|mov|webm|gif)/i)) {
    return data;
  }
  
  return { ...data, url: null }; // No valid video URL found
}

// Submit video batch to API
async function submitVideoBatch() {
  if (videoQueue.length === 0) return;
  
  const batch = videoQueue.splice(0, BATCH_SIZE);
  console.log(`📤 Submitting batch of ${batch.length} videos to API...`);
  
  try {
    const response = await fetch(`${process.env.API_URL}/api/videos/batch`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ videos: batch })
    });
    
    if (response.ok) {
      console.log(`✅ Batch submitted successfully`);
      
      // Mark videos as submitted
      for (const video of batch) {
        await db.run(
          'INSERT INTO seen_videos (video_id, url, submitted_at) VALUES (?, ?, ?)',
          video.id,
          video.url,
          Date.now()
        );
      }
    } else {
      const errorText = await response.text();
      console.error(`❌ API error: ${response.status} ${response.statusText}`);
      console.error(`Response: ${errorText}`);
      stats.apiErrors++;
      // Put videos back in queue
      videoQueue.unshift(...batch);
    }
  } catch (error) {
    console.error('❌ Network error:', error.message);
    stats.apiErrors++;
    // Put videos back in queue
    videoQueue.unshift(...batch);
  }
}

// Subscribe to video events
console.log('📺 Subscribing to video events (kinds 22 and 34550)...\n');

// Look back 24 hours for more videos
const since = Math.floor(Date.now() / 1000) - (24 * 3600);
console.log(`⏰ Looking for videos since: ${new Date(since * 1000).toISOString()}\n`);

const sub = pool.sub(relays, [{
  kinds: [22, 34235, 34236, 34550, 1063], // All video-related events
  since: since,
  limit: 1000 // Get more events
}]);

let totalEvents = 0;

sub.on('event', (event) => {
  totalEvents++;
  if (totalEvents === 1) {
    console.log(`🎯 First event received! Kind: ${event.kind}, ID: ${event.id.substring(0, 8)}...`);
    console.log(`   Tags:`, event.tags.slice(0, 5)); // Show first 5 tags
  }
  processVideoEvent(event).catch(console.error);
});

sub.on('eose', () => {
  console.log(`📄 End of stored events received. Total events: ${totalEvents}\n`);
});

// Periodic batch submission
setInterval(submitVideoBatch, 30000); // Every 30 seconds

// Stats reporting
setInterval(() => {
  console.log('\n📊 Stats:', {
    ...stats,
    queueSize: videoQueue.length,
    uptime: Math.floor(process.uptime() / 60) + ' minutes'
  });
}, 60000); // Every minute

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n👋 Shutting down...');
  
  // Submit remaining videos
  if (videoQueue.length > 0) {
    console.log(`📤 Submitting final batch of ${videoQueue.length} videos...`);
    await submitVideoBatch();
  }
  
  // Close connections
  pool.close(relays);
  await db.close();
  
  console.log('✅ Cleanup complete');
  process.exit(0);
});

console.log('🎬 Crawler is running! Press Ctrl+C to stop.\n');