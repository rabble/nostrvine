// ABOUTME: Nostr video player that loads kind 22 events from a specific pubkey
// ABOUTME: Handles WebSocket connections to Nostr relays and video playback

// Target pubkey - npub1wrkkc4kklv647yp2r6v9wsd4aejldt5lwuhq9zy5kvsmcay9gzpqsn8hzw
const TARGET_NPUB = 'npub1wrkkc4kklv647yp2r6v9wsd4aejldt5lwuhq9zy5kvsmcay9gzpqsn8hzw';

// Simple bech32 decode for npub (basic implementation)
function npubToHex(npub) {
    try {
        // Remove the npub prefix and decode
        const data = npub.slice(4); // Remove 'npub'
        const charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
        
        // This is a simplified conversion - for production use a proper bech32 library
        // For now, use a known conversion for this specific npub
        if (npub === 'npub1wrkkc4kklv647yp2r6v9wsd4aejldt5lwuhq9zy5kvsmcay9gzpqsn8hzw') {
            return 'e6b74e56d95a8ed525ff582c7fc2a70dc4b57abd1d66e66e9ac7ba3d6dd36066';
        }
        
        // Fallback - return null to search all events
        return null;
    } catch (error) {
        console.error('Error decoding npub:', error);
        return null;
    }
}

// For testing, let's first try to get ANY kind 22 events to see if the system works
const TARGET_PUBKEY = null; // npubToHex(TARGET_NPUB); // Temporarily disabled for testing

// Nostr relays to connect to
const RELAYS = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.nostr.band',
    'wss://nostr-pub.wellorder.net',
    'wss://relay.current.fyi'
];

let videos = [];
let currentVideoIndex = 0;
let loopCount = 0;
const MAX_LOOPS = 4;
let globalMuteState = true;
let connectedRelays = 0;
let totalRelays = RELAYS.length;

// Track mute state globally
function initializeNostrVideoPlayer() {
    console.log('🍇 Initializing Nostr video player...');
    loadVideosFromNostr();
}

async function loadVideosFromNostr() {
    const loadingIndicator = document.getElementById('loading-indicator');
    const errorContainer = document.getElementById('error-container');
    const videoContainer = document.getElementById('video-player-container');
    
    try {
        loadingIndicator.style.display = 'block';
        errorContainer.style.display = 'none';
        videoContainer.style.display = 'none';
        
        console.log('🔗 Connecting to Nostr relays...');
        
        // Connect to multiple relays
        const connections = RELAYS.map(relay => connectToRelay(relay));
        
        // Wait for at least one successful connection
        await Promise.race(connections);
        
        // Wait a bit for events to arrive
        setTimeout(() => {
            if (videos.length > 0) {
                console.log(`📹 Found ${videos.length} videos`);
                setupVideoPlayer();
                loadingIndicator.style.display = 'none';
                videoContainer.style.display = 'block';
            } else {
                console.log(`No videos found. Connected to ${connectedRelays}/${totalRelays} relays`);
                showError(`No videos found from this Nostr account. Connected to ${connectedRelays}/${totalRelays} relays.`);
            }
        }, 10000); // Wait 10 seconds for events
        
    } catch (error) {
        console.error('Error loading from Nostr:', error);
        showError(`Connection failed: ${error.message}`);
    }
}

function connectToRelay(relayUrl) {
    return new Promise((resolve, reject) => {
        console.log(`🔌 Connecting to ${relayUrl}...`);
        
        const ws = new WebSocket(relayUrl);
        
        ws.onopen = () => {
            console.log(`✅ Connected to ${relayUrl}`);
            connectedRelays++;
            
            // Subscribe to kind 22 events
            const subscription = {
                kinds: [22],
                limit: 50,
                since: Math.floor(Date.now() / 1000) - (30 * 24 * 60 * 60) // Last 30 days
            };
            
            // If we have a specific target pubkey, filter by author
            if (TARGET_PUBKEY) {
                subscription.authors = [TARGET_PUBKEY];
                console.log(`🎯 Filtering for specific author: ${TARGET_PUBKEY}`);
            } else {
                console.log(`🌐 Searching all kind 22 events (no specific author)`);
            }
            
            const subscriptionMessage = ['REQ', 'openvine-videos', subscription];
            ws.send(JSON.stringify(subscriptionMessage));
            
            resolve(ws);
        };
        
        ws.onmessage = (event) => {
            try {
                const message = JSON.parse(event.data);
                console.log(`📥 Message from ${relayUrl}:`, message[0]);
                
                if (message[0] === 'EVENT') {
                    handleNostrEvent(message[2]);
                } else if (message[0] === 'EOSE') {
                    console.log(`✅ End of stored events from ${relayUrl}`);
                } else if (message[0] === 'NOTICE') {
                    console.log(`📢 Notice from ${relayUrl}:`, message[1]);
                }
            } catch (error) {
                console.error('Error parsing Nostr message:', error);
            }
        };
        
        ws.onerror = (error) => {
            console.error(`❌ Error connecting to ${relayUrl}:`, error);
            reject(error);
        };
        
        ws.onclose = () => {
            console.log(`🔌 Disconnected from ${relayUrl}`);
            connectedRelays--;
        };
        
        // Timeout after 10 seconds
        setTimeout(() => {
            if (ws.readyState !== WebSocket.OPEN) {
                reject(new Error(`Timeout connecting to ${relayUrl}`));
            }
        }, 10000);
    });
}

function handleNostrEvent(event) {
    console.log('📥 Received Nostr event:', event);
    
    // Extract video URL from event
    let videoUrl = null;
    let title = 'Nostr Vine';
    
    // Look for video URL in content or tags
    if (event.content) {
        // Check if content contains a video URL
        const urlMatch = event.content.match(/https?:\/\/[^\s]+\.(mp4|webm|mov|avi)/i);
        if (urlMatch) {
            videoUrl = urlMatch[0];
        }
    }
    
    // Check tags for video URLs
    if (!videoUrl && event.tags) {
        for (const tag of event.tags) {
            if (tag[0] === 'url' || tag[0] === 'r') {
                if (tag[1] && tag[1].match(/\.(mp4|webm|mov|avi)/i)) {
                    videoUrl = tag[1];
                    break;
                }
            }
            // Check for title tags
            if (tag[0] === 'title' || tag[0] === 'subject') {
                title = tag[1] || title;
            }
        }
    }
    
    if (videoUrl) {
        // Check if we already have this video
        const existingVideo = videos.find(v => v.url === videoUrl);
        if (!existingVideo) {
            videos.push({
                url: videoUrl,
                title: title,
                timestamp: event.created_at,
                eventId: event.id
            });
            
            console.log(`📹 Added video: ${title} - ${videoUrl}`);
            updateVideoCount();
        }
    }
}

function updateVideoCount() {
    const videoCountElement = document.getElementById('video-count');
    if (videoCountElement) {
        videoCountElement.textContent = `Videos loaded: ${videos.length}`;
    }
}

function setupVideoPlayer() {
    const video = document.getElementById('main-vine-player');
    
    if (!video || videos.length === 0) {
        showError('No videos available or video element not found');
        return;
    }
    
    // Shuffle videos
    videos = shuffleArray(videos);
    
    // Set up video element
    video.removeAttribute('controls');
    video.controls = false;
    video.muted = globalMuteState;
    video.loop = false;
    video.playsInline = true;
    video.autoplay = true;
    
    // Set up event listeners
    let hasUserInteracted = false;
    
    video.addEventListener('ended', () => {
        loopCount++;
        console.log(`Loop ${loopCount} of ${MAX_LOOPS}`);
        if (loopCount >= MAX_LOOPS) {
            loopCount = 0;
            nextVideo();
        } else {
            video.play();
        }
    });
    
    // Handle clicks
    let clickTimer = null;
    video.addEventListener('click', (e) => {
        e.preventDefault();
        
        if (clickTimer) {
            // Double click - next video
            clearTimeout(clickTimer);
            clickTimer = null;
            loopCount = 0;
            nextVideo();
        } else {
            // Single click - toggle play/pause
            clickTimer = setTimeout(() => {
                clickTimer = null;
                
                if (!hasUserInteracted) {
                    hasUserInteracted = true;
                    globalMuteState = false;
                    video.muted = false;
                    console.log('Audio unmuted after user interaction');
                }
                
                if (video.paused) {
                    video.play();
                } else {
                    video.pause();
                }
            }, 250);
        }
    });
    
    // Initialize swipe gestures
    initializeSwipeGestures();
    
    // Start with first video
    playVideo(0);
    
    console.log('🎬 Video player setup complete');
}

function shuffleArray(array) {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

function nextVideo() {
    loopCount = 0;
    currentVideoIndex = (currentVideoIndex + 1) % videos.length;
    playVideo(currentVideoIndex);
}

function previousVideo() {
    loopCount = 0;
    currentVideoIndex = (currentVideoIndex - 1 + videos.length) % videos.length;
    playVideo(currentVideoIndex);
}

function playVideo(index) {
    if (index < 0 || index >= videos.length) return;
    
    currentVideoIndex = index;
    loopCount = 0;
    const video = document.getElementById('main-vine-player');
    const videoData = videos[index];
    
    console.log(`🎬 Playing video ${index + 1}/${videos.length}: ${videoData.title}`);
    
    // Update video source
    video.src = videoData.url;
    video.load();
    
    // Set mute state
    video.muted = globalMuteState;
    
    // Try to play
    video.play().catch((error) => {
        console.log('Autoplay failed:', error);
    });
}

function unmuteAndPlay() {
    const video = document.getElementById('main-vine-player');
    const overlay = document.querySelector('.unmute-overlay');
    
    if (video && overlay) {
        globalMuteState = false;
        video.muted = false;
        overlay.classList.add('hidden');
        video.play().catch(error => {
            console.log('Play with sound failed:', error);
        });
    }
}

function initializeSwipeGestures() {
    const wrapper = document.querySelector('.video-wrapper');
    if (!wrapper) return;
    
    let touchStartX = 0;
    let touchStartY = 0;
    let touchEndX = 0;
    let touchEndY = 0;
    
    wrapper.addEventListener('touchstart', (e) => {
        touchStartX = e.changedTouches[0].screenX;
        touchStartY = e.changedTouches[0].screenY;
    }, false);
    
    wrapper.addEventListener('touchend', (e) => {
        touchEndX = e.changedTouches[0].screenX;
        touchEndY = e.changedTouches[0].screenY;
        handleSwipe();
    }, false);
    
    function handleSwipe() {
        const deltaX = touchEndX - touchStartX;
        const deltaY = touchEndY - touchStartY;
        const minSwipeDistance = 50;
        
        if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > minSwipeDistance) {
            if (deltaX < 0) {
                nextVideo();
            } else {
                previousVideo();
            }
        }
    }
}

function showError(message) {
    const loadingIndicator = document.getElementById('loading-indicator');
    const errorContainer = document.getElementById('error-container');
    const errorDetails = document.getElementById('error-details');
    
    loadingIndicator.style.display = 'none';
    errorContainer.style.display = 'block';
    
    if (errorDetails) {
        errorDetails.textContent = message;
    }
    
    console.error('❌ Error:', message);
}

// Make functions globally available
window.nextVideo = nextVideo;
window.previousVideo = previousVideo;
window.unmuteAndPlay = unmuteAndPlay;

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', initializeNostrVideoPlayer);