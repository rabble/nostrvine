// ABOUTME: Initialize and configure Plyr video player for OpenVine
// ABOUTME: Handles custom controls, playlist management, and touch gestures

// Video playlist data
const videos = [
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750550004/OBzrB2ptzvV_20250620_161945_kmsjzx.mp4',
        title: 'Freestyle Flow',
        author: 'TownsKiller',
        likes: '443,636'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750550038/7vz1u6-8lEo_20250622_111021_z1xgjl.mp4',
        title: 'Boxing Practice',
        author: 'TownsKiller',
        likes: '312,892'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750549997/7vz1u6-8lEo_20250622_110851_vwvzv0.mp4',
        title: 'Sleepy Vibes',
        author: 'TownsKiller',
        likes: '892,455'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750549991/7vz1u6-8lEo_20250622_110754_bofcqh.mp4',
        title: 'Scam Alert',
        author: 'TownsKiller',
        likes: '598,234'
    },
    {
        url: 'https://res.cloudinary.com/dswu0ugmo/video/upload/v1750549977/MnABFeAql0g_20250622_110424_od5jv0.mp4',
        title: 'Viral Content',
        author: 'TownsKiller',
        likes: '721,445'
    }
];

let player;
let currentVideoIndex = 0;

// Initialize Plyr when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    const video = document.getElementById('main-vine-player');
    
    if (video) {
        // Initialize Plyr with custom options
        player = new Plyr(video, {
            controls: ['play', 'mute', 'fullscreen'],
            autoplay: true,
            loop: { active: true },
            clickToPlay: true,
            hideControls: false,
            resetOnEnd: true,
            keyboard: { focused: true, global: false },
            tooltips: { controls: false, seek: false },
            fullscreen: { enabled: true, fallback: true, iosNative: true },
            storage: { enabled: false }
        });
        
        // Style the Plyr controls
        const style = document.createElement('style');
        style.textContent = `
            .plyr {
                --plyr-color-main: #0ae68a;
                --plyr-control-radius: 50%;
            }
            
            .plyr__controls {
                background: transparent;
                position: absolute;
                bottom: 20px;
                right: 20px;
                width: auto;
                padding: 0;
                display: flex;
                flex-direction: column;
                gap: 10px;
            }
            
            .plyr__control {
                background: rgba(0,0,0,0.7);
                width: 40px;
                height: 40px;
                border-radius: 50%;
                margin: 0;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            
            .plyr__control:hover {
                background: rgba(0,0,0,0.9);
            }
            
            .plyr__control svg {
                width: 18px;
                height: 18px;
            }
            
            .plyr__volume,
            .plyr__progress,
            .plyr__time,
            .plyr__menu {
                display: none !important;
            }
            
            .plyr--fullscreen-active .plyr__controls {
                bottom: 40px;
                right: 40px;
            }
        `;
        document.head.appendChild(style);
        
        // Custom event handlers
        player.on('ready', () => {
            console.log('Plyr ready');
            playVideo(0);
        });
        
        player.on('ended', () => {
            // Auto-advance to next video
            nextVideo();
        });
        
        // Add touch event listeners
        const videoContainer = document.querySelector('.video-container');
        if (videoContainer) {
            videoContainer.addEventListener('touchstart', handleTouchStart);
            videoContainer.addEventListener('touchend', handleTouchEnd);
        }
    }
});

// Video control functions
function nextVideo() {
    currentVideoIndex = (currentVideoIndex + 1) % videos.length;
    playVideo(currentVideoIndex);
}

function playVideo(index) {
    if (!player || index < 0 || index >= videos.length) return;
    
    currentVideoIndex = index;
    const videoData = videos[index];
    
    // Update video source
    player.source = {
        type: 'video',
        sources: [{
            src: videoData.url,
            type: 'video/mp4'
        }]
    };
    
    // Play the video
    player.play();
    
    // Update playlist thumbnails
    document.querySelectorAll('.playlist-thumb').forEach((thumb, i) => {
        if (i === index) {
            thumb.classList.add('active');
        } else {
            thumb.classList.remove('active');
        }
    });
    
    // Update video info
    const infoCard = document.querySelector('.video-info-card');
    if (infoCard) {
        infoCard.querySelector('.creator-name').textContent = videoData.author;
        infoCard.querySelector('.video-counter').textContent = `${index + 1} of ${videos.length}`;
        infoCard.querySelector('.loop-count').textContent = `${videoData.likes} Loops`;
    }
}

// Swipe functionality for mobile
let startY = 0;
let endY = 0;

function handleTouchStart(e) {
    startY = e.touches[0].clientY;
}

function handleTouchEnd(e) {
    endY = e.changedTouches[0].clientY;
    handleSwipe();
}

function handleSwipe() {
    const diffY = startY - endY;
    const minSwipeDistance = 50;
    
    if (Math.abs(diffY) > minSwipeDistance) {
        if (diffY > 0) {
            // Swiped up - next video
            nextVideo();
        } else {
            // Swiped down - previous video
            currentVideoIndex = (currentVideoIndex - 1 + videos.length) % videos.length;
            playVideo(currentVideoIndex);
        }
    }
}

// Make functions available globally for onclick handlers
window.playVideo = playVideo;
window.nextVideo = nextVideo;