// Simple crawler that just finds and logs videos without API
import { config } from 'dotenv';
import { SimplePool } from 'nostr-tools';
import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import crypto from 'crypto';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs/promises';

// Get current directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
config({ path: path.join(__dirname, '.env') });

// Open SQLite database
const db = await open({
  filename: path.join(__dirname, 'videos.db'),
  driver: sqlite3.Database
});

// Create tables
await db.exec(`
  CREATE TABLE IF NOT EXISTS videos (
    video_id TEXT PRIMARY KEY,
    url TEXT NOT NULL,
    title TEXT,
    author_pubkey TEXT,
    event_kind INTEGER,
    created_at INTEGER,
    metadata TEXT
  );
`);

// Initialize Nostr connection
const pool = new SimplePool();
const relays = process.env.NOSTR_RELAYS.split(',');

console.log('🚀 Starting simple video finder...');
console.log(`📡 Connecting to relays: ${relays.join(', ')}`);

// Track stats
let stats = {
  eventsFound: 0,
  videosFound: 0,
  duplicates: 0
};

// Process video event
async function processVideoEvent(event) {
  stats.eventsFound++;
  
  // Extract video data
  const videoData = extractVideoData(event);
  if (!videoData.url) {
    return;
  }
  
  // Generate video ID
  const videoId = crypto.createHash('sha256').update(videoData.url).digest('hex').substring(0, 16);
  
  // Check if already saved
  const existing = await db.get('SELECT video_id FROM videos WHERE video_id = ?', videoId);
  if (existing) {
    stats.duplicates++;
    return;
  }
  
  // Save to database
  await db.run(
    `INSERT INTO videos (video_id, url, title, author_pubkey, event_kind, created_at, metadata) 
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    videoId,
    videoData.url,
    videoData.title || 'Untitled',
    event.pubkey,
    event.kind,
    event.created_at,
    JSON.stringify(videoData)
  );
  
  stats.videosFound++;
  console.log(`✅ #${stats.videosFound} ${videoData.title || 'Untitled'} - ${videoData.url}`);
}

// Extract video metadata
function extractVideoData(event) {
  const data = {
    url: null,
    title: null,
    thumbnail: null,
    duration: null
  };
  
  // Parse tags
  for (const tag of event.tags) {
    if (tag[0] === 'url' && tag[1]) {
      data.url = tag[1];
    } else if (tag[0] === 'title' && tag[1]) {
      data.title = tag[1];
    } else if (tag[0] === 'imeta' && tag.length > 1) {
      // Parse imeta tags
      for (let i = 1; i < tag.length; i++) {
        const part = tag[i];
        if (part.startsWith('url ')) {
          data.url = part.substring(4);
        } else if (part.startsWith('alt ')) {
          data.title = part.substring(4) || data.title;
        }
      }
    }
  }
  
  // Check content for URL
  if (!data.url && event.content) {
    const urlMatch = event.content.match(/(https?:\/\/[^\s]+\.(mp4|mov|webm|gif))/i);
    if (urlMatch) {
      data.url = urlMatch[1];
    }
  }
  
  // Use content as title if short
  if (!data.title && event.content && event.content.length < 200 && event.content.length > 0) {
    data.title = event.content.trim();
  }
  
  // Only return if valid video URL
  if (data.url && data.url.match(/\.(mp4|mov|webm|gif)/i)) {
    return data;
  }
  
  return { url: null };
}

// Subscribe to video events
console.log('📺 Looking for video events in the last 7 days...\n');

const since = Math.floor(Date.now() / 1000) - (7 * 24 * 3600); // 7 days

const sub = pool.sub(relays, [{
  kinds: [22, 34235, 34236, 34550, 1063],
  since: since,
  limit: 5000
}]);

sub.on('event', (event) => {
  processVideoEvent(event).catch(console.error);
});

sub.on('eose', () => {
  console.log(`\n📄 Finished! Found ${stats.videosFound} unique videos from ${stats.eventsFound} events`);
  setTimeout(async () => {
    // Export to CSV
    const videos = await db.all('SELECT * FROM videos ORDER BY created_at DESC LIMIT 100');
    const csv = [
      'Title,URL,Author,Kind,Date',
      ...videos.map(v => {
        const meta = JSON.parse(v.metadata);
        return `"${v.title}","${v.url}","${v.author_pubkey.substring(0, 8)}...",${v.event_kind},"${new Date(v.created_at * 1000).toISOString()}"`;
      })
    ].join('\n');
    
    await fs.writeFile(path.join(__dirname, 'found-videos.csv'), csv);
    console.log('\n📊 Exported top 100 videos to found-videos.csv');
    
    pool.close(relays);
    await db.close();
    process.exit(0);
  }, 2000);
});

// Periodic stats
const statsInterval = setInterval(() => {
  console.log(`\n📊 Progress: ${stats.videosFound} videos found (${stats.duplicates} duplicates)`);
}, 10000);

// Graceful shutdown
process.on('SIGINT', async () => {
  clearInterval(statsInterval);
  console.log('\n👋 Shutting down...');
  pool.close(relays);
  await db.close();
  process.exit(0);
});