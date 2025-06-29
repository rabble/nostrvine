#!/usr/bin/env node

/**
 * ABOUTME: Bulk thumbnail generation script for videos without thumbnails using Nostr NDK
 * ABOUTME: Connects to vine.hol.is relay via NDK and generates thumbnails for Kind 22 events via API service
 */

const https = require('https');
const http = require('http');
const { URL } = require('url');
const NDK = require('@nostr-dev-kit/ndk').default;
const { NDKPrivateKeySigner } = require('@nostr-dev-kit/ndk');

// Configuration
const CONFIG = {
  RELAY_URL: 'wss://vine.hol.is',
  API_BASE_URL: 'https://api.openvine.co',
  BATCH_SIZE: 5,
  MAX_VIDEOS: 1000,
  TIME_OFFSET: 2.5,
  REQUEST_TIMEOUT: 30000,
  BATCH_DELAY: 2000, // ms between batches
  NDK_TIMEOUT: 15000, // NDK connection timeout
};

// Statistics
const stats = {
  totalVideosFound: 0,
  videosWithoutThumbnails: 0,
  thumbnailsGenerated: 0,
  thumbnailsFailed: 0,
  videosSkipped: 0,
};

/**
 * Parse command line arguments
 */
function parseArguments() {
  const args = process.argv.slice(2);
  const options = {
    limit: CONFIG.MAX_VIDEOS,
    dryRun: false,
    batchSize: CONFIG.BATCH_SIZE,
    timeOffset: CONFIG.TIME_OFFSET,
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--limit':
      case '-l':
        options.limit = parseInt(args[++i]) || CONFIG.MAX_VIDEOS;
        break;
      case '--dry-run':
      case '-d':
        options.dryRun = true;
        break;
      case '--batch-size':
      case '-b':
        options.batchSize = parseInt(args[++i]) || CONFIG.BATCH_SIZE;
        break;
      case '--time-offset':
      case '-t':
        options.timeOffset = parseFloat(args[++i]) || CONFIG.TIME_OFFSET;
        break;
      case '--help':
      case '-h':
        printUsage();
        process.exit(0);
        break;
      default:
        console.error(`❌ Unknown option: ${args[i]}`);
        process.exit(1);
    }
  }

  return options;
}

/**
 * Print usage information
 */
function printUsage() {
  console.log(`
Usage: node bulk_thumbnail_generator.js [options]

Options:
  -l, --limit <number>       Maximum number of videos to process (default: ${CONFIG.MAX_VIDEOS})
  -d, --dry-run             Don't actually generate thumbnails, just report what would be done
  -b, --batch-size <number>  Number of videos to process in each batch (default: ${CONFIG.BATCH_SIZE})
  -t, --time-offset <number> Time offset in seconds for thumbnail extraction (default: ${CONFIG.TIME_OFFSET})
  -h, --help                Show this help message

Examples:
  node bulk_thumbnail_generator.js --limit 100 --dry-run
  node bulk_thumbnail_generator.js --batch-size 5 --time-offset 3.0
  `);
}

/**
 * Initialize NDK with relay and authentication
 */
async function initializeNDK() {
  console.log(`🔌 Initializing NDK with relay: ${CONFIG.RELAY_URL}`);
  
  // Create a temporary signer for authentication
  const signer = NDKPrivateKeySigner.generate();
  
  // Initialize NDK
  const ndk = new NDK({
    explicitRelayUrls: [CONFIG.RELAY_URL],
    signer: signer,
  });

  // Connect to relays
  await ndk.connect(CONFIG.NDK_TIMEOUT);
  
  console.log(`✅ NDK connected with public key: ${signer.user.pubkey}`);
  console.log(`📡 Connected relays: ${Array.from(ndk.pool.relays.keys()).join(', ')}`);
  
  return ndk;
}

/**
 * Fetch video events from the relay using NDK
 */
async function fetchVideoEvents(ndk, limit) {
  console.log(`📡 Fetching Kind 22 events from relay...`);
  
  try {
    // Create filter for Kind 22 events with vine group tag
    const filter = {
      kinds: [22],
      '#h': ['vine'],
      limit: limit,
    };
    
    console.log(`🔍 Filter: ${JSON.stringify(filter, null, 2)}`);
    
    // Fetch events using NDK
    const events = await ndk.fetchEvents(filter);
    
    // Convert NDKEvent set to array of plain objects
    const eventArray = Array.from(events).map(event => ({
      id: event.id,
      pubkey: event.pubkey,
      kind: event.kind,
      created_at: event.created_at,
      content: event.content,
      tags: event.tags,
      sig: event.sig,
    }));
    
    console.log(`📥 Successfully received ${eventArray.length} Kind 22 events from relay`);
    return eventArray;
    
  } catch (error) {
    console.error(`❌ Failed to fetch from relay: ${error.message}`);
    console.log('📋 Using sample events for testing...');
    
    // Return sample events for testing
    return [
      {
        id: '87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344',
        pubkey: '0461fcbecc4c3374439932d6b8f11269ccdb7cc973ad7a50ae362db135a474dd',
        kind: 22,
        created_at: Math.floor(Date.now() / 1000),
        content: 'Sample video without thumbnail',
        tags: [
          ['h', 'vine'],
          ['d', 'sample123'],
          ['r', 'https://blossom.primal.net/87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344.mp4', 'video'],
          ['m', 'video/mp4'],
          ['t', 'sample'],
          ['t', 'test'],
        ],
      },
    ];
  }
}

/**
 * Make HTTP request
 */
function makeRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const client = urlObj.protocol === 'https:' ? https : http;
    
    const requestOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method: options.method || 'GET',
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'OpenVine-ThumbnailGenerator/1.0',
        'Content-Type': 'application/json',
        ...options.headers,
      },
      timeout: CONFIG.REQUEST_TIMEOUT,
    };

    const req = client.request(requestOptions, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const jsonData = data ? JSON.parse(data) : null;
          resolve({
            statusCode: res.statusCode,
            data: jsonData,
            rawData: data,
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            data: null,
            rawData: data,
          });
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    if (options.body) {
      req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
    }
    
    req.end();
  });
}

/**
 * Parse video event to check if it has video and thumbnail
 */
function parseVideoEvent(event) {
  let videoUrl = null;
  let thumbnailUrl = null;
  let vineId = null;
  
  // Debug: log events without thumbnails
  let hasVideoForDebug = false;
  let hasThumbnailForDebug = false;
  
  // Parse tags to find video URL, thumbnail, and vine ID
  for (const tag of event.tags || []) {
    if (!Array.isArray(tag) || tag.length < 2) continue;
    
    const [tagName, tagValue] = tag;
    
    switch (tagName) {
      case 'url':
        if (isValidVideoUrl(tagValue)) {
          videoUrl = tagValue;
        }
        break;
      case 'r':
        // Handle "r" tags with video/thumbnail type annotation
        if (tag.length >= 3) {
          const url = tagValue;
          const type = tag[2];
          if (type === 'video' && isValidVideoUrl(url)) {
            videoUrl = url;
            hasVideoForDebug = true;
          } else if (type === 'thumbnail' && url && !url.includes('apt.openvine.co') && !url.includes('picsum.photos')) {
            thumbnailUrl = url;
            hasThumbnailForDebug = true;
          }
        } else if (isValidVideoUrl(tagValue)) {
          // Fallback: if no type annotation, treat as video if it looks like video
          videoUrl = tagValue;
          hasVideoForDebug = true;
        }
        break;
      case 'thumb':
      case 'image':
        if (tagValue && !tagValue.includes('apt.openvine.co') && !tagValue.includes('picsum.photos')) {
          thumbnailUrl = tagValue;
          hasThumbnailForDebug = true;
        }
        break;
      case 'd':
        vineId = tagValue; // Vine ID from replaceable event tag
        break;
      case 'vine_id':
        vineId = tagValue; // Alternative vine ID tag
        break;
      case 'imeta':
        // Parse imeta tag for video URL
        for (let i = 1; i < tag.length; i++) {
          const item = tag[i];
          if (item.startsWith('url ')) {
            const url = item.substring(4);
            if (isValidVideoUrl(url)) {
              videoUrl = url;
            }
          } else if (item.startsWith('thumb ')) {
            const thumb = item.substring(6);
            if (thumb && !thumb.includes('apt.openvine.co') && !thumb.includes('picsum.photos')) {
              thumbnailUrl = thumb;
            }
          }
        }
        break;
    }
  }
  
  const result = {
    id: event.id,
    pubkey: event.pubkey,
    vineId,
    hasVideo: !!videoUrl,
    videoUrl,
    thumbnailUrl,
    content: event.content || '',
  };
  
  // Debug: log videos without thumbnails
  if (result.hasVideo && !result.thumbnailUrl) {
    console.log(`🚨 VIDEO WITHOUT THUMBNAIL: ${event.id.substring(0, 8)} (vine: ${result.vineId || 'unknown'})`);
    console.log(`   Video URL: ${result.videoUrl}`);
    console.log(`   Tags: ${JSON.stringify(event.tags, null, 2)}`);
  }
  
  return result;
}

/**
 * Check if URL is a valid video URL
 */
function isValidVideoUrl(url) {
  if (!url) return false;
  
  try {
    const urlObj = new URL(url);
    const path = urlObj.pathname.toLowerCase();
    const host = urlObj.hostname.toLowerCase();
    
    // Check for video file extensions
    if (path.endsWith('.mp4') || path.endsWith('.webm') || path.endsWith('.mov') || 
        path.endsWith('.avi') || path.endsWith('.gif')) {
      return true;
    }
    
    // Check for known video hosting domains
    if (host.includes('blossom.primal.net') || host.includes('nostr.build') ||
        host.includes('void.cat') || host.includes('nostpic.com') ||
        host.includes('openvine.co') || host.includes('satellite.earth')) {
      return true;
    }
    
    return false;
  } catch {
    return false;
  }
}

/**
 * Filter events that don't have thumbnails
 */
function filterEventsWithoutThumbnails(events) {
  const filtered = [];
  
  for (const event of events) {
    const parsed = parseVideoEvent(event);
    
    if (parsed.hasVideo) {
      stats.totalVideosFound++;
      
      if (!parsed.thumbnailUrl) {
        filtered.push({
          ...parsed,
          originalEvent: event,
        });
        stats.videosWithoutThumbnails++;
      }
    }
  }
  
  console.log(`📊 Found ${stats.totalVideosFound} total video events`);
  console.log(`📊 ${stats.videosWithoutThumbnails} videos without thumbnails`);
  console.log(`📊 ${stats.totalVideosFound - stats.videosWithoutThumbnails} videos already have thumbnails`);
  
  return filtered;
}

/**
 * Generate thumbnail for a single video
 */
async function generateThumbnailForVideo(video, timeOffset) {
  const videoId = video.id;
  const shortId = videoId.substring(0, 8);
  
  try {
    console.log(`🎬 Generating thumbnail for video ${shortId}${video.vineId ? ` (vine: ${video.vineId})` : ''}...`);
    
    // First check if thumbnail already exists
    const checkUrl = `${CONFIG.API_BASE_URL}/thumbnail/${videoId}?t=${timeOffset}`;
    const checkResponse = await makeRequest(checkUrl, { method: 'HEAD' });
    
    if (checkResponse.statusCode === 200) {
      console.log(`✅ Thumbnail already exists for ${shortId}`);
      stats.thumbnailsGenerated++;
      return checkUrl;
    }
    
    // Generate thumbnail using the correct endpoint
    const generateUrl = `${CONFIG.API_BASE_URL}/thumbnail/${videoId}`;
    const generateResponse = await makeRequest(generateUrl, {
      method: 'POST',
      body: { timeSeconds: timeOffset },
    });
    
    if (generateResponse.statusCode === 200 || generateResponse.statusCode === 201) {
      const thumbnailUrl = `${CONFIG.API_BASE_URL}/thumbnail/${videoId}?t=${timeOffset}`;
      console.log(`✅ Generated thumbnail for ${shortId}: ${thumbnailUrl}`);
      stats.thumbnailsGenerated++;
      return thumbnailUrl;
    } else {
      throw new Error(`HTTP ${generateResponse.statusCode}: ${generateResponse.rawData}`);
    }
    
  } catch (error) {
    console.log(`❌ Failed to generate thumbnail for ${shortId}: ${error.message}`);
    stats.thumbnailsFailed++;
    return null;
  }
}

/**
 * Generate thumbnails in batches
 */
async function generateThumbnailsInBatches(videos, options) {
  if (options.dryRun) {
    console.log(`🔍 DRY RUN: Would generate thumbnails for ${videos.length} videos`);
    for (const video of videos) {
      console.log(`   - ${video.id.substring(0, 8)}${video.vineId ? ` (vine: ${video.vineId})` : ''}`);
    }
    return;
  }
  
  console.log(`🎬 Generating thumbnails for ${videos.length} videos...`);
  console.log(`⚙️ Batch size: ${options.batchSize}`);
  console.log(`⏱️ Time offset: ${options.timeOffset}s`);
  
  for (let i = 0; i < videos.length; i += options.batchSize) {
    const batch = videos.slice(i, i + options.batchSize);
    const batchNumber = Math.floor(i / options.batchSize) + 1;
    const totalBatches = Math.ceil(videos.length / options.batchSize);
    
    console.log(`\n📦 Processing batch ${batchNumber}/${totalBatches} (${batch.length} videos)...`);
    
    // Process batch concurrently
    const promises = batch.map(video => generateThumbnailForVideo(video, options.timeOffset));
    await Promise.all(promises);
    
    // Brief pause between batches
    if (i + options.batchSize < videos.length) {
      console.log(`⏸️ Waiting ${CONFIG.BATCH_DELAY}ms before next batch...`);
      await new Promise(resolve => setTimeout(resolve, CONFIG.BATCH_DELAY));
    }
  }
}

/**
 * Print final statistics
 */
function printFinalStatistics() {
  console.log('\n📈 FINAL STATISTICS');
  console.log('===================');
  console.log(`Total videos found: ${stats.totalVideosFound}`);
  console.log(`Videos without thumbnails: ${stats.videosWithoutThumbnails}`);
  console.log(`Thumbnails generated: ${stats.thumbnailsGenerated}`);
  console.log(`Thumbnails failed: ${stats.thumbnailsFailed}`);
  console.log(`Videos skipped: ${stats.videosSkipped}`);
  
  const successRate = stats.videosWithoutThumbnails > 0 
    ? (stats.thumbnailsGenerated / stats.videosWithoutThumbnails * 100).toFixed(1)
    : '0.0';
  console.log(`Success rate: ${successRate}%`);
  
  if (stats.thumbnailsGenerated > 0) {
    console.log(`🎉 Successfully generated ${stats.thumbnailsGenerated} thumbnails!`);
  }
  
  if (stats.thumbnailsFailed > 0) {
    console.log(`⚠️ ${stats.thumbnailsFailed} thumbnails failed to generate`);
  }
}

/**
 * Main function
 */
async function main() {
  console.log('🚀 OpenVine Bulk Thumbnail Generator (Nostr NDK)');
  console.log('==============================================');
  
  let ndk = null;
  try {
    // Parse command line arguments
    const options = parseArguments();
    
    console.log('📋 Configuration:');
    console.log(`   Relay: ${CONFIG.RELAY_URL}`);
    console.log(`   Limit: ${options.limit} videos`);
    console.log(`   Batch size: ${options.batchSize}`);
    console.log(`   Time offset: ${options.timeOffset}s`);
    console.log(`   Mode: ${options.dryRun ? 'DRY RUN' : 'LIVE'}`);
    console.log('');
    
    // Step 1: Initialize NDK and connect to relay
    ndk = await initializeNDK();
    
    // Step 2: Fetch video events via NDK
    const events = await fetchVideoEvents(ndk, options.limit);
    
    if (events.length === 0) {
      console.log('❌ No video events found. Exiting.');
      return;
    }
    
    // Step 3: Filter events without thumbnails
    const eventsWithoutThumbnails = filterEventsWithoutThumbnails(events);
    
    if (eventsWithoutThumbnails.length === 0) {
      console.log('🎉 All videos already have thumbnails!');
      return;
    }
    
    // Step 4: Generate thumbnails
    await generateThumbnailsInBatches(eventsWithoutThumbnails, options);
    
    // Step 5: Print statistics
    printFinalStatistics();
    
  } catch (error) {
    console.error('❌ Script failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  } finally {
    // Clean up NDK connection
    if (ndk) {
      try {
        // NDK doesn't have an explicit close method, just let it clean up naturally
        console.log('🔌 Cleaning up NDK connection...');
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }
}

// Run the script
if (require.main === module) {
  main();
}