// ABOUTME: JavaScript integration for Vine-inspired layout with OpenVine functionality
// ABOUTME: Handles video playback, Nostr integration, and UI interactions

// Constants
const ANALYTICS_API = 'https://analytics.openvine.co/analytics';
const VIEW_TRACKING_API = 'https://analytics.openvine.co/analytics/view';
const NOSTR_RELAYS = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.nos.social',
    'wss://relay.nostr.band',
    'wss://cache2.primal.net/v1'
];

// State management
const VineState = {
    videos: [],
    featuredVideoIndex: 0,
    currentCategory: null,
    nostrEventMap: new Map(),
    isLoading: false,
    autoplayTimer: null,
    playlistIndex: 0,
    playlistLoopCount: 0,
    playlistTimer: null,
    playlistMuted: true
};

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', initializeVineApp);

async function initializeVineApp() {
    // Load initial content
    await loadTrendingVideos();
    setupEventListeners();
    setupVideoAutoplay();
    setupPlaylistVideo();
    
    // Check for dark mode preference
    if (localStorage.getItem('vineTheme') === 'dark' || 
        (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
        document.body.classList.add('vine-dark-mode');
    }
}

// Load trending videos from analytics API
async function loadTrendingVideos() {
    try {
        VineState.isLoading = true;
        
        // Fetch trending videos
        const response = await fetch(`${ANALYTICS_API}/trending/vines?limit=30`);
        const data = await response.json();
        
        if (data.vines && data.vines.length > 0) {
            // Fetch actual video data from Nostr
            const eventIds = data.vines.map(v => v.eventId);
            await fetchNostrEvents(eventIds);
            
            // Process videos
            VineState.videos = data.vines.map(vine => {
                const nostrEvent = VineState.nostrEventMap.get(vine.eventId);
                return {
                    id: vine.eventId,
                    url: nostrEvent?.videoUrl || '',
                    thumbnail: nostrEvent?.thumbnailUrl || '',
                    username: nostrEvent?.username || `viner_${vine.eventId.substring(0, 8)}`,
                    avatar: getRandomAvatar(),
                    likes: Math.floor((vine.views || 0) * 0.1),
                    comments: Math.floor((vine.views || 0) * 0.05),
                    reposts: Math.floor((vine.views || 0) * 0.02),
                    views: vine.views || 0,
                    category: nostrEvent?.category || 'general',
                    title: nostrEvent?.title || ''
                };
            }).filter(v => v.url);
            
            updateUI();
        }
    } catch (error) {
        console.error('Error loading trending videos:', error);
        // Load fallback content
        loadFallbackContent();
    } finally {
        VineState.isLoading = false;
    }
}

// Fetch Nostr events
async function fetchNostrEvents(eventIds) {
    const promises = NOSTR_RELAYS.map(relay => 
        fetchEventsFromRelay(relay, eventIds)
    );
    await Promise.allSettled(promises);
}

// Fetch from single relay
function fetchEventsFromRelay(relayUrl, eventIds) {
    return new Promise((resolve) => {
        try {
            const ws = new WebSocket(relayUrl);
            const subscriptionId = 'sub_' + Math.random().toString(36).substring(2);
            
            ws.onopen = () => {
                const filter = { kinds: [22], ids: eventIds };
                ws.send(JSON.stringify(['REQ', subscriptionId, filter]));
            };
            
            ws.onmessage = (event) => {
                try {
                    const message = JSON.parse(event.data);
                    if (message[0] === 'EVENT' && message[2]?.kind === 22) {
                        const parsed = parseVideoEvent(message[2]);
                        if (parsed?.videoUrl) {
                            VineState.nostrEventMap.set(message[2].id, parsed);
                        }
                    } else if (message[0] === 'EOSE') {
                        ws.send(JSON.stringify(['CLOSE', subscriptionId]));
                        setTimeout(() => ws.close(), 100);
                    }
                } catch (err) {
                    console.error('Parse error:', err);
                }
            };
            
            ws.onerror = () => resolve();
            ws.onclose = () => resolve();
            
            setTimeout(() => {
                if (ws.readyState === WebSocket.OPEN) ws.close();
                resolve();
            }, 5000);
        } catch (error) {
            resolve();
        }
    });
}

// Parse video event from Nostr
function parseVideoEvent(event) {
    const data = {
        id: event.id,
        pubkey: event.pubkey,
        content: event.content,
        videoUrl: null,
        title: null,
        thumbnailUrl: null,
        username: null,
        category: null
    };
    
    for (const tag of event.tags || []) {
        if (!tag || tag.length < 2) continue;
        
        switch (tag[0]) {
            case 'url':
                data.videoUrl = tag[1].replace('apt.openvine.co', 'api.openvine.co');
                break;
            case 'title':
                data.title = tag[1];
                break;
            case 'thumb':
                data.thumbnailUrl = tag[1];
                break;
            case 't':
                // Hashtag - use for category
                if (!data.category) {
                    data.category = tag[1].toLowerCase();
                }
                break;
        }
    }
    
    // Extract username from content or use pubkey
    if (event.content) {
        const usernameMatch = event.content.match(/@(\w+)/);
        if (usernameMatch) {
            data.username = usernameMatch[1];
        }
    }
    
    return data;
}

// Update UI with loaded videos
function updateUI() {
    updateFeaturedVideo();
    updateVideoGrid();
    updateTrendingList();
    updatePlaylistVideo();
    updateFeaturedSections();
}

// Update featured video
function updateFeaturedVideo() {
    if (VineState.videos.length === 0) return;
    
    const video = VineState.videos[VineState.featuredVideoIndex];
    const player = document.getElementById('vineFeaturedPlayer');
    const avatar = document.getElementById('featuredAvatar');
    const username = document.getElementById('featuredUsername');
    const likes = document.getElementById('featuredLikes');
    const comments = document.getElementById('featuredComments');
    const reposts = document.getElementById('featuredReposts');
    
    if (player) player.src = video.url;
    if (avatar) avatar.textContent = video.avatar;
    if (username) username.textContent = video.username;
    if (likes) likes.textContent = video.likes.toLocaleString();
    if (comments) comments.textContent = video.comments.toLocaleString();
    if (reposts) reposts.textContent = video.reposts.toLocaleString();
    
    // Track view
    trackVideoView(video);
}

// Update video grid
function updateVideoGrid() {
    const grid = document.getElementById('vineVideoGrid');
    if (!grid) return;
    
    const videosToShow = VineState.currentCategory 
        ? VineState.videos.filter(v => v.category === VineState.currentCategory)
        : VineState.videos;
    
    grid.innerHTML = videosToShow.slice(0, 12).map(video => `
        <div class="vine-grid-item" onclick="playVideo('${video.id}')" data-video-id="${video.id}">
            <div class="vine-grid-thumbnail">
                ${video.thumbnail ? 
                    `<img src="${video.thumbnail}" alt="${video.username}'s vine" loading="lazy">` :
                    `<div style="width: 100%; height: 100%; background: #333; display: flex; align-items: center; justify-content: center; color: #666; font-size: 2rem;">🎬</div>`
                }
                <div class="vine-grid-overlay">
                    <div class="vine-grid-avatar">${video.avatar}</div>
                    <span class="vine-grid-user">${video.username}</span>
                </div>
            </div>
        </div>
    `).join('');
    
    // Add hover preview functionality
    setupHoverPreviews();
}

// Update trending list
function updateTrendingList() {
    const trendingList = document.getElementById('vineTrendingList');
    if (!trendingList) return;
    
    const trendingVideos = [...VineState.videos]
        .sort((a, b) => b.views - a.views)
        .slice(0, 4);
    
    trendingList.innerHTML = trendingVideos.map(video => `
        <div class="vine-user-item" onclick="playVideo('${video.id}')" style="margin-bottom: 12px;">
            <div class="vine-grid-thumbnail" style="width: 80px; height: 80px; flex-shrink: 0;">
                ${video.thumbnail ?
                    `<img src="${video.thumbnail}" alt="${video.username}'s vine" 
                          style="width: 100%; height: 100%; object-fit: cover; border-radius: 8px;">` :
                    `<div style="width: 100%; height: 100%; background: #333; border-radius: 8px; 
                          display: flex; align-items: center; justify-content: center; color: #666;">🎬</div>`
                }
            </div>
            <div class="vine-user-info">
                <h4 style="font-size: 13px;">${video.username}</h4>
                <p style="font-size: 11px;">👁️ ${video.views.toLocaleString()} • ❤️ ${video.likes.toLocaleString()}</p>
            </div>
        </div>
    `).join('');
}

// Setup event listeners
function setupEventListeners() {
    // Search functionality
    const searchInput = document.getElementById('vineSearchInput');
    if (searchInput) {
        searchInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                searchVines();
            }
        });
    }
    
    // Theme toggle
    document.addEventListener('keydown', (e) => {
        if (e.key === 'd' && e.ctrlKey) {
            toggleDarkMode();
        }
    });
}

// Setup video autoplay
function setupVideoAutoplay() {
    // Clear existing timer
    if (VineState.autoplayTimer) {
        clearInterval(VineState.autoplayTimer);
    }
    
    // Auto-advance featured video every 6 seconds
    VineState.autoplayTimer = setInterval(() => {
        VineState.featuredVideoIndex = (VineState.featuredVideoIndex + 1) % VineState.videos.length;
        updateFeaturedVideo();
    }, 6000);
}

// Setup hover previews
function setupHoverPreviews() {
    const gridItems = document.querySelectorAll('.vine-grid-item');
    
    gridItems.forEach(item => {
        let hoverTimer;
        
        item.addEventListener('mouseenter', function() {
            // Start preview after 500ms hover
            hoverTimer = setTimeout(() => {
                const videoId = this.dataset.videoId;
                const video = VineState.videos.find(v => v.id === videoId);
                if (video) {
                    // In real implementation, would preview video
                    this.style.transform = 'scale(1.05)';
                    this.style.zIndex = '10';
                }
            }, 500);
        });
        
        item.addEventListener('mouseleave', function() {
            clearTimeout(hoverTimer);
            this.style.transform = '';
            this.style.zIndex = '';
        });
    });
}

// Play video
function playVideo(videoId) {
    // Navigate to Vine-style video URL
    window.location.href = `/v/${videoId}`;
}

// Search vines
async function searchVines() {
    const query = document.getElementById('vineSearchInput').value.trim();
    if (!query) return;
    
    console.log('Searching for:', query);
    
    // Show loading state
    const grid = document.getElementById('vineVideoGrid');
    if (grid) {
        grid.innerHTML = '<div style="grid-column: 1/-1; text-align: center; padding: 2rem; color: #666;">Searching...</div>';
    }
    
    // Search in current videos first
    const localResults = VineState.videos.filter(v => 
        v.username.toLowerCase().includes(query.toLowerCase()) ||
        v.title.toLowerCase().includes(query.toLowerCase()) ||
        v.category === query.toLowerCase()
    );
    
    if (localResults.length > 0) {
        VineState.currentCategory = null;
        updateVideoGrid();
    } else {
        // Search Nostr relays
        await searchNostrRelays(query);
    }
}

// Search Nostr relays
async function searchNostrRelays(query) {
    // Implementation would search Nostr relays
    // For now, show no results
    const grid = document.getElementById('vineVideoGrid');
    if (grid) {
        grid.innerHTML = '<div style="grid-column: 1/-1; text-align: center; padding: 2rem; color: #666;">No vines found for "' + query + '"</div>';
    }
}

// Filter by category
function filterByCategory(category) {
    console.log('Filtering by:', category);
    VineState.currentCategory = category;
    updateVideoGrid();
    
    // Update UI to show active category
    document.querySelectorAll('.vine-category-item').forEach(item => {
        item.classList.remove('active');
    });
    event.target.classList.add('active');
}

// View profile
function viewProfile(username) {
    console.log('Viewing profile:', username);
    // Navigate to Vine-style profile URL
    window.location.href = `/${encodeURIComponent(username)}`;
}

// Toggle dark mode
function toggleDarkMode() {
    document.body.classList.toggle('vine-dark-mode');
    const isDark = document.body.classList.contains('vine-dark-mode');
    localStorage.setItem('vineTheme', isDark ? 'dark' : 'light');
}

// Track video view
async function trackVideoView(video) {
    if (!video.id) return;
    
    try {
        await fetch(VIEW_TRACKING_API, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                eventId: video.id,
                source: 'website-vine',
                creatorPubkey: video.pubkey || video.username
            })
        });
    } catch (error) {
        console.error('Error tracking view:', error);
    }
}

// Get random avatar emoji
function getRandomAvatar() {
    const avatars = ['🎭', '🎵', '🌟', '🎨', '🎮', '🎬', '🎪', '🎧', '🎸', '🎤', '🎯', '🎲', '🎳', '🎯', '🎪'];
    return avatars[Math.floor(Math.random() * avatars.length)];
}

// Load fallback content
function loadFallbackContent() {
    VineState.videos = [
        {
            id: '1',
            url: 'https://api.openvine.co/media/1750880785012-ad9a31c4',
            thumbnail: 'https://api.openvine.co/media/1750880785012-ad9a31c4/thumb.jpg',
            username: 'maka-senpai',
            avatar: '🎭',
            likes: 6900,
            comments: 420,
            reposts: 169,
            views: 42069,
            category: 'comedy',
            title: 'MY DICK FELL OFF'
        },
        {
            id: '2',
            url: 'https://api.openvine.co/media/1750880795926-82a02417',
            thumbnail: 'https://api.openvine.co/media/1750880795926-82a02417/thumb.jpg',
            username: 'JEDRLEE',
            avatar: '🎵',
            likes: 4200,
            comments: 210,
            reposts: 84,
            views: 31337,
            category: 'music',
            title: 'My "miss you"s were misused'
        }
    ];
    
    updateUI();
}

// Setup playlist video
function setupPlaylistVideo() {
    const player = document.getElementById('vinePlaylistPlayer');
    if (!player) return;
    
    // Update loop count on each loop
    player.addEventListener('ended', () => {
        VineState.playlistLoopCount++;
        updateLoopCount();
        
        // After 4 loops, move to next video
        if (VineState.playlistLoopCount >= 4) {
            VineState.playlistLoopCount = 0;
            VineState.playlistIndex = (VineState.playlistIndex + 1) % VineState.videos.length;
            updatePlaylistVideo();
        }
    });
    
    // Click to unmute
    player.addEventListener('click', () => {
        if (VineState.playlistMuted) {
            VineState.playlistMuted = false;
            player.muted = false;
            // Show temporary unmute indicator
            showUnmuteIndicator();
        } else {
            VineState.playlistMuted = true;
            player.muted = true;
        }
    });
    
    // Also add click handler to the video wrapper
    const videoWrapper = player.closest('.vine-video-wrapper');
    if (videoWrapper) {
        videoWrapper.style.cursor = 'pointer';
        videoWrapper.addEventListener('click', (e) => {
            if (e.target !== player) {
                player.click();
            }
        });
    }
}

// Update playlist video
function updatePlaylistVideo() {
    if (VineState.videos.length === 0) return;
    
    const video = VineState.videos[VineState.playlistIndex];
    const player = document.getElementById('vinePlaylistPlayer');
    const title = document.getElementById('playlistVideoTitle');
    const currentIndex = document.getElementById('currentVideoIndex');
    const totalVideos = document.getElementById('totalVideos');
    
    if (player) {
        player.src = video.url;
        // Preserve the mute state
        player.muted = VineState.playlistMuted;
        player.volume = VineState.playlistMuted ? 0 : 1.0;
        player.play().catch(() => {
            // Autoplay failed, likely needs user interaction
            VineState.playlistMuted = true;
            player.muted = true;
            player.play();
        });
    }
    
    if (title) title.textContent = video.title || `${video.username}'s Vine`;
    if (currentIndex) currentIndex.textContent = VineState.playlistIndex + 1;
    if (totalVideos) totalVideos.textContent = VineState.videos.length;
    
    // Reset loop count for new video
    VineState.playlistLoopCount = 0;
    updateLoopCount();
}

// Update loop count display
function updateLoopCount() {
    const loopCountElement = document.getElementById('loopCount');
    if (loopCountElement) {
        loopCountElement.textContent = VineState.playlistLoopCount;
    }
}

// Update featured sections (Comedy, Viners, Editor's Pick)
function updateFeaturedSections() {
    // Featured in Comedy
    const comedyGrid = document.getElementById('featuredCategoryGrid');
    if (comedyGrid) {
        const comedyVideos = VineState.videos.filter(v => v.category === 'comedy').slice(0, 3);
        // Only update if we have comedy videos to show
        if (comedyVideos.length > 0) {
            comedyGrid.innerHTML = comedyVideos.map(video => `
                <div class="vine-featured-item" onclick="playVideo('${video.id}')">
                    <div class="vine-featured-thumb">
                        <video src="${video.url}" muted loop onloadedmetadata="this.currentTime = 1"></video>
                    </div>
                    <div class="vine-featured-info">
                        <div class="vine-featured-user">
                            <span class="vine-user-avatar-small">${video.avatar}</span>
                            <span class="vine-username-small">${video.username}</span>
                        </div>
                        <p class="vine-featured-caption">${video.title || 'Untitled'}</p>
                        <p class="vine-loop-count-small">${video.views} loops</p>
                    </div>
                </div>
            `).join('');
        }
        // If no comedy videos, keep existing content
    }
    
    // Featured Viners
    const vinersGrid = document.getElementById('featuredVinersGrid');
    if (vinersGrid && VineState.videos.length > 0) {
        const topViners = [...new Set(VineState.videos.map(v => v.username))]
            .slice(0, 5)
            .map(username => {
                const userVideos = VineState.videos.filter(v => v.username === username);
                const totalViews = userVideos.reduce((sum, v) => sum + v.views, 0);
                return { username, avatar: userVideos[0]?.avatar || '🎭', totalViews };
            });
        
        if (topViners.length > 0) {
            vinersGrid.innerHTML = topViners.map(viner => `
                <div class="vine-viner-circle" onclick="viewProfile('${viner.username}')">
                    <div class="vine-viner-avatar" style="background: ${getRandomGradient()}">
                        ${viner.avatar}
                    </div>
                    <p class="vine-viner-name">${viner.username}</p>
                </div>
            `).join('');
        }
    }
    
    // Editor's Pick
    const editorsPick = document.getElementById('editorsPickVideo');
    if (editorsPick && VineState.videos.length > 0) {
        const pickVideo = VineState.videos[Math.floor(Math.random() * VineState.videos.length)];
        editorsPick.innerHTML = `
            <video src="${pickVideo.url}" muted loop autoplay style="width: 100%; height: 100%; object-fit: cover;"></video>
            <div class="vine-editors-overlay">
                <h4>Editor's Pick</h4>
                <p>@${pickVideo.username}</p>
            </div>
        `;
    }
}

// Get random gradient for avatars
function getRandomGradient() {
    const gradients = [
        'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
        'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)',
        'linear-gradient(135deg, #43e97b 0%, #38f9d7 100%)',
        'linear-gradient(135deg, #fa709a 0%, #fee140 100%)'
    ];
    return gradients[Math.floor(Math.random() * gradients.length)];
}

// Show unmute indicator
function showUnmuteIndicator() {
    // Create temporary unmute indicator
    const indicator = document.createElement('div');
    indicator.style.cssText = `
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: rgba(0, 0, 0, 0.8);
        color: white;
        padding: 10px 20px;
        border-radius: 20px;
        font-size: 14px;
        z-index: 1000;
        pointer-events: none;
    `;
    indicator.textContent = '🔊 Sound On';
    document.body.appendChild(indicator);
    
    // Remove after 1 second
    setTimeout(() => {
        indicator.remove();
    }, 1000);
}

// Playlist controls
function showPlaylist(playlistType) {
    console.log('Showing playlist:', playlistType);
    // In real implementation, would load specific playlist
    VineState.playlistIndex = 0;
    VineState.playlistLoopCount = 0;
    updatePlaylistVideo();
}

// Share and like functions
function shareVideo() {
    console.log('Share video');
    // Implementation would share current playlist video
}

function likeVideo() {
    console.log('Like video');
    // Implementation would like current playlist video
}

// Export functions for global access
window.playVideo = playVideo;
window.filterByCategory = filterByCategory;
window.viewProfile = viewProfile;
window.searchVines = searchVines;
window.toggleDarkMode = toggleDarkMode;
window.showPlaylist = showPlaylist;
window.shareVideo = shareVideo;
window.likeVideo = likeVideo;