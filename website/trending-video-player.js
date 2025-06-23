// ABOUTME: Video player that loads trending videos from OpenVine analytics API
// ABOUTME: Fetches and plays popular vine videos with view tracking

const TRENDING_API = 'https://analytics.openvine.co/analytics/trending/vines';
const VIEW_TRACKING_API = 'https://analytics.openvine.co/analytics/view';

let videos = [];
let currentVideoIndex = 0;
let loopCount = 0;
const MAX_LOOPS = 4;
let globalMuteState = true;

// Initialize the trending video player
function initializeTrendingVideoPlayer() {
    console.log('🍇 Initializing trending video player...');
    loadTrendingVideos();
}

async function loadTrendingVideos() {
    const loadingIndicator = document.getElementById('loading-indicator');
    const errorContainer = document.getElementById('error-container');
    const videoContainer = document.getElementById('video-player-container');
    
    try {
        loadingIndicator.style.display = 'block';
        errorContainer.style.display = 'none';
        videoContainer.style.display = 'none';
        
        console.log('🔗 Fetching trending videos...');
        
        // Fetch trending videos
        const response = await fetch(`${TRENDING_API}?limit=50`);
        if (!response.ok) {
            throw new Error(`Failed to fetch trending videos: ${response.statusText}`);
        }
        
        const data = await response.json();
        
        if (data.videos && data.videos.length > 0) {
            // Process videos
            videos = data.videos.map(video => ({
                url: video.videoUrl,
                title: video.title || 'Trending Vine',
                eventId: video.eventId,
                creatorPubkey: video.creatorPubkey,
                viewCount: video.viewCount,
                timestamp: video.lastViewed
            }));
            
            console.log(`📹 Found ${videos.length} trending videos`);
            setupVideoPlayer();
            loadingIndicator.style.display = 'none';
            videoContainer.style.display = 'block';
        } else {
            showError('No trending videos available');
        }
        
    } catch (error) {
        console.error('Error loading trending videos:', error);
        showError(`Failed to load videos: ${error.message}`);
    }
}

// Track video view
async function trackVideoView(video) {
    try {
        const viewData = {
            eventId: video.eventId,
            source: 'website',
            creatorPubkey: video.creatorPubkey
        };
        
        await fetch(VIEW_TRACKING_API, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(viewData)
        });
        
        console.log(`📊 Tracked view for video ${video.eventId}`);
    } catch (error) {
        console.error('Error tracking view:', error);
    }
}

function setupVideoPlayer() {
    const video = document.getElementById('main-vine-player');
    
    if (!video || videos.length === 0) {
        showError('No videos available or video element not found');
        return;
    }
    
    // Shuffle videos for variety
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
    
    console.log(`🎬 Playing video ${index + 1}/${videos.length}: ${videoData.title} (${videoData.viewCount} views)`);
    
    // Update video info
    updateVideoInfo(videoData);
    
    // Update video source
    video.src = videoData.url;
    video.load();
    
    // Set mute state
    video.muted = globalMuteState;
    
    // Track view
    trackVideoView(videoData);
    
    // Try to play
    video.play().catch((error) => {
        console.log('Autoplay failed:', error);
    });
}

function updateVideoInfo(videoData) {
    const videoCount = document.getElementById('video-count');
    const videoTitle = document.getElementById('video-title');
    const viewCount = document.getElementById('view-count');
    
    if (videoCount) {
        videoCount.textContent = `Video ${currentVideoIndex + 1} of ${videos.length}`;
    }
    
    if (videoTitle) {
        videoTitle.textContent = videoData.title;
    }
    
    if (viewCount) {
        viewCount.textContent = `${videoData.viewCount.toLocaleString()} views`;
    }
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
document.addEventListener('DOMContentLoaded', initializeTrendingVideoPlayer);