// ABOUTME: Video player that loads trending videos from OpenVine analytics API
// ABOUTME: Fetches and plays popular vine videos with view tracking

const TRENDING_API = 'https://analytics.openvine.co/analytics/trending/vines';
const VIEW_TRACKING_API = 'https://analytics.openvine.co/analytics/view';

// Fallback videos while analytics service is being set up
const FALLBACK_VIDEOS = [
    {
        url: 'https://api.openvine.co/media/1750880785012-ad9a31c4',
        title: 'MY DICK FELL OFF',
        eventId: '5000hh3phKM',
        creatorPubkey: 'maka-senpai',
        viewCount: 42069,
        timestamp: Date.now()
    },
    {
        url: 'https://api.openvine.co/media/1750880795926-82a02417',
        title: 'My "miss you"s were misused',
        eventId: '5002Pdq9gIQ',
        creatorPubkey: 'JEDRLEE',
        viewCount: 31337,
        timestamp: Date.now()
    },
    {
        url: 'https://api.openvine.co/media/1750880799493-b5f9ee23',
        title: 'Don\'t wanna sleep, don\'t wanna die',
        eventId: '50021KzJ99l',
        creatorPubkey: 'earth-angel',
        viewCount: 28420,
        timestamp: Date.now()
    },
    {
        url: 'https://api.openvine.co/media/1750880810482-bd49e1f2',
        title: 'Plot twist XD',
        eventId: '5000uxQrIiI',
        creatorPubkey: 'MettaonDarling',
        viewCount: 19885,
        timestamp: Date.now()
    },
    {
        url: 'https://api.openvine.co/media/1750880817654-0c307f02',
        title: 'Afterlife Remix',
        eventId: '500311lva0g',
        creatorPubkey: 'Virtual',
        viewCount: 15234,
        timestamp: Date.now()
    },
    {
        url: 'https://api.openvine.co/media/1750880828791-cd2ac64a',
        title: 'Roblox Death Sound',
        eventId: '5003PhXAQFz',
        creatorPubkey: 'Kenneth-Udut',
        viewCount: 12456,
        timestamp: Date.now()
    },
    {
        url: 'https://api.openvine.co/media/1750880839632-615418e7',
        title: 'Want my pickle?',
        eventId: '5003EnYImK7',
        creatorPubkey: 'mysticalwanheda',
        viewCount: 9876,
        timestamp: Date.now()
    },
    {
        url: 'https://api.openvine.co/media/1750880803099-6b22f0ac',
        title: 'Tokyo Ghoul Turned Me Emo',
        eventId: '5001wzqP32g',
        creatorPubkey: 'lonelyaudios',
        viewCount: 8765,
        timestamp: Date.now()
    },
    {
        url: 'https://api.openvine.co/media/1750880814035-8583318d',
        title: 'Goku vs Beerus',
        eventId: '5002Tj1jxaH',
        creatorPubkey: 'Anim3-Bagel',
        viewCount: 7654,
        timestamp: Date.now()
    },
    {
        url: 'https://api.openvine.co/media/1750880821277-b93f8f5b',
        title: 'I love my bois',
        eventId: '5001t9jpiTB',
        creatorPubkey: 'shinyas-lattes',
        viewCount: 6543,
        timestamp: Date.now()
    }
];

let videos = [];
let currentVideoIndex = 0;
let loopCount = 0;
const MAX_LOOPS = 4;
let globalMuteState = true;
let isUsingFallback = false;
let retryTimer = null;
const RETRY_INTERVAL = 30000; // 30 seconds

// Initialize the trending video player
function initializeTrendingVideoPlayer() {
    console.log('🍇 Initializing trending video grid...');
    loadTrendingVideos();
}

async function loadTrendingVideos() {
    const loadingIndicator = document.getElementById('loading-indicator');
    const errorContainer = document.getElementById('error-container');
    const videosGrid = document.getElementById('videos-grid');
    
    // Always use preloaded videos
    loadingIndicator.style.display = 'block';
    errorContainer.style.display = 'none';
    videosGrid.style.display = 'none';
    
    console.log('📹 Loading trending videos...');
    
    // Use the preloaded videos
    videos = FALLBACK_VIDEOS;
    isUsingFallback = false; // Not really a fallback anymore
    
    // Render the video grid
    renderVideoGrid();
    loadingIndicator.style.display = 'none';
    videosGrid.style.display = 'grid';
    
    console.log(`📹 Loaded ${videos.length} trending videos`);
}

// Track video view - disabled since we're not using analytics API
async function trackVideoView(video) {
    // View tracking disabled
    console.log(`📊 View tracking disabled for video: ${video.title}`);
}

function renderVideoGrid() {
    const videosGrid = document.getElementById('videos-grid');
    
    if (!videosGrid || videos.length === 0) {
        showError('No videos available or grid element not found');
        return;
    }
    
    // Clear existing content
    videosGrid.innerHTML = '';
    
    // Create video cards
    videos.forEach((video, index) => {
        const videoCard = createVideoCard(video, index);
        videosGrid.appendChild(videoCard);
    });
    
    console.log('🎬 Video grid rendered');
}

function createVideoCard(videoData, index) {
    const card = document.createElement('div');
    card.className = 'video-card';
    card.onclick = () => openVideoModal(videoData, index);
    
    // Create thumbnail with placeholder
    const thumbnailHtml = `
        <div class="video-thumbnail">
            <video 
                src="${videoData.url}" 
                muted
                preload="metadata"
                onloadedmetadata="this.currentTime = 1"
            ></video>
            <div class="play-overlay">
                <div class="play-icon">▶</div>
            </div>
        </div>
    `;
    
    // Create info section
    const infoHtml = `
        <div class="video-card-info">
            <h3 class="video-card-title">${videoData.title}</h3>
            <div class="video-card-meta">
                <div class="video-views">
                    <span>👁</span>
                    <span>${videoData.viewCount.toLocaleString()}</span>
                </div>
                <div class="video-creator"><a href="/${encodeURIComponent(videoData.creatorPubkey)}" style="color: inherit; text-decoration: none;" onclick="event.stopPropagation();">@${videoData.creatorPubkey}</a></div>
            </div>
        </div>
    `;
    
    card.innerHTML = thumbnailHtml + infoHtml;
    return card;
}

function openVideoModal(videoData, index) {
    const modal = document.getElementById('video-modal');
    const modalVideo = document.getElementById('modal-video-player');
    const modalTitle = document.getElementById('modal-video-title');
    const modalCreator = document.getElementById('modal-video-creator');
    const modalViews = document.getElementById('modal-video-views');
    
    currentVideoIndex = index;
    
    // Update modal content
    modalVideo.src = videoData.url;
    modalTitle.textContent = videoData.title;
    modalCreator.innerHTML = `<a href="/${encodeURIComponent(videoData.creatorPubkey)}" style="color: inherit; text-decoration: none;">@${videoData.creatorPubkey}</a>`;
    modalViews.textContent = `${videoData.viewCount.toLocaleString()} views`;
    
    // Show modal
    modal.style.display = 'flex';
    
    // Set up video loop
    modalVideo.loop = true;
    modalVideo.muted = false;
    
    // Play video
    modalVideo.play().catch(error => {
        console.log('Autoplay failed:', error);
        modalVideo.muted = true;
        modalVideo.play();
    });
    
    // Track view
    trackVideoView(videoData);
}

function closeVideoModal() {
    const modal = document.getElementById('video-modal');
    const modalVideo = document.getElementById('modal-video-player');
    
    // Pause and reset video
    modalVideo.pause();
    modalVideo.src = '';
    
    // Hide modal
    modal.style.display = 'none';
}

// Add event listener for ESC key to close modal
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeVideoModal();
    }
});

// Add event listener to close modal when clicking outside
document.addEventListener('DOMContentLoaded', () => {
    const modal = document.getElementById('video-modal');
    if (modal) {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                closeVideoModal();
            }
        });
    }
});

function shuffleArray(array) {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

// Removed old video player functions as they're no longer needed for grid view

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
window.closeVideoModal = closeVideoModal;

// Removed showFallbackIndicator and startRetryTimer functions as they're no longer needed

// Cleanup on page unload
function cleanup() {
    // No longer need to clean up retry timer
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', initializeTrendingVideoPlayer);
window.addEventListener('beforeunload', cleanup);