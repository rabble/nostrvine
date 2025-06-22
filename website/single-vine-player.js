// ABOUTME: Single video player with tap controls and auto-advance
// ABOUTME: Advances after 4 loops or on tap, with play/pause functionality

// Video playlist data
const videos = [
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750583297/5eM6tu9HFIu_20250622_162133_lm26h7.mp4',
        title: 'Pokemon Go'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750583234/5dWxnlBmm5Z_20250622_162023_hhgzyl.mp4',
        title: 'Creative Content'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750583001/5BYq6hmrEI3_20250622_161508_xzxskg.mp4',
        title: 'Camp Unplug'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750582248/5B0QQqVuI2X_20250622_161201_bn6cbu.mp4',
        title: '2016 iHeartRadio MMVAs'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750582224/5aLOja21Xpd_20250622_161154_cl9x4x.mp4',
        title: 'Beach Vibes'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750582882/5BxxKKFtz3D_20250622_161501_eo9rxf.mp4',
        title: 'Viral Content'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750585177/5MLQxl73b3E_20250622_162716_gtranc.mp4',
        title: 'Classic Vine 7'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750585224/5upO3pwU9EW_20250622_162948_a5zd5e.mp4',
        title: 'Classic Vine 8'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750585248/5uQxd5EJI7F_20250622_163012_r8gc4b.mp4',
        title: 'Classic Vine 9'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750585262/5Vgj1ahEPJ0_20250622_163242_kca9dj.mp4',
        title: 'Classic Vine 10'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750585281/5W1ab9pELTg_20250622_163404_ftbxh0.mp4',
        title: 'Classic Vine 11'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750585302/5WdX07BAWM3_20250622_163635_gzrktt.mp4',
        title: 'Classic Vine 12'
    }
];

let currentVideoIndex = 0;
let loopCount = 0;
const MAX_LOOPS = 4;

// Shuffle array function
function shuffleArray(array) {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

// Shuffle videos on page load
const shuffledVideos = shuffleArray(videos);

// Track mute state globally
let globalMuteState = true;

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    const video = document.getElementById('main-vine-player');
    
    if (video) {
        // Remove controls
        video.removeAttribute('controls');
        video.controls = false;
        
        // Set up for autoplay
        video.muted = globalMuteState; // Use global mute state
        video.loop = false; // Don't use native loop so we can count
        video.playsInline = true;
        video.autoplay = true;
        
        // Try to unmute after first user interaction
        let hasUserInteracted = false;
        
        // Update initial video source to use shuffled array
        const source = video.querySelector('source');
        if (source && shuffledVideos.length > 0) {
            source.src = shuffledVideos[0].url;
            video.load();
        }
        
        // Track loops
        video.addEventListener('ended', () => {
            loopCount++;
            console.log(`Loop ${loopCount} of ${MAX_LOOPS}`);
            if (loopCount >= MAX_LOOPS) {
                loopCount = 0;
                nextVideo();
            } else {
                // Replay current video
                video.play();
            }
        });
        
        // Handle clicks - single for play/pause, double for next
        let clickTimer = null;
        video.addEventListener('click', (e) => {
            e.preventDefault();
            
            if (clickTimer) {
                // Double click detected - go to next video
                clearTimeout(clickTimer);
                clickTimer = null;
                loopCount = 0;
                nextVideo();
            } else {
                // Single click - toggle play/pause after delay
                clickTimer = setTimeout(() => {
                    clickTimer = null;
                    
                    // Unmute on first interaction
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
        
        // Start with first video
        playVideo(0);
        
        // Indicators removed - no longer creating them
        
        // Update mute overlay icon
        const overlay = document.querySelector('.unmute-overlay');
        if (overlay && video.muted) {
            overlay.classList.remove('hidden');
        }
    }
});

function nextVideo() {
    loopCount = 0; // Reset loop count when manually advancing
    currentVideoIndex = (currentVideoIndex + 1) % shuffledVideos.length;
    playVideo(currentVideoIndex);
}

function playVideo(index) {
    if (index < 0 || index >= shuffledVideos.length) return;
    
    currentVideoIndex = index;
    loopCount = 0;
    const video = document.getElementById('main-vine-player');
    const videoData = shuffledVideos[index];
    
    // Update source
    const source = video.querySelector('source');
    if (source) {
        source.src = videoData.url;
    } else {
        video.src = videoData.url;
    }
    video.load();
    
    // Set mute state from global
    video.muted = globalMuteState;
    
    // Try to play
    video.play().catch((error) => {
        console.log('Autoplay failed:', error);
        // Don't force mute here, let user interaction handle it
    });
    
    // Indicators removed
}

// Indicator functions removed

// Loop counter function removed

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

// Touch/swipe handling
function initializeSwipeGestures() {
    const video = document.getElementById('main-vine-player');
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
        
        // Check if horizontal swipe is greater than vertical
        if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > minSwipeDistance) {
            if (deltaX < 0) {
                // Swipe left - next video
                nextVideo();
            } else {
                // Swipe right - previous video
                previousVideo();
            }
        }
    }
}

function previousVideo() {
    loopCount = 0; // Reset loop count when manually advancing
    currentVideoIndex = (currentVideoIndex - 1 + shuffledVideos.length) % shuffledVideos.length;
    playVideo(currentVideoIndex);
}

// Initialize swipe gestures on load
document.addEventListener('DOMContentLoaded', initializeSwipeGestures);

// Make functions globally available
window.playVideo = playVideo;
window.nextVideo = nextVideo;
window.previousVideo = previousVideo;
window.unmuteAndPlay = unmuteAndPlay;