// ABOUTME: Simple video player for OpenVine without external dependencies
// ABOUTME: Handles autoplay, looping, and playlist management

// Video playlist data - using new example videos
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
    }
];

let currentVideoIndex = 0;

// Initialize video player when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    // Find the main video in the first vine item
    const video = document.querySelector('.vine-video.main-video');
    
    if (video) {
        // Remove native controls completely
        video.removeAttribute('controls');
        video.controls = false;
        
        // Set up video for autoplay
        video.muted = false; // Play with sound
        video.loop = true;
        video.playsInline = true;
        video.autoplay = true;
        
        // Hide ALL controls with aggressive CSS
        const style = document.createElement('style');
        style.textContent = `
            #main-vine-player {
                pointer-events: none !important;
            }
            
            #main-vine-player::-webkit-media-controls {
                display: none !important;
            }
            #main-vine-player::-webkit-media-controls-enclosure {
                display: none !important;
            }
            #main-vine-player::-webkit-media-controls-panel {
                display: none !important;
            }
            #main-vine-player::-webkit-media-controls-start-playback-button {
                display: none !important;
            }
            #main-vine-player::-webkit-media-controls-overlay-play-button {
                display: none !important;
            }
            #main-vine-player::-webkit-media-controls-play-button {
                display: none !important;
            }
            #main-vine-player::-moz-media-controls {
                display: none !important;
            }
            #main-vine-player::media-controls {
                display: none !important;
            }
            
            .video-container {
                position: relative;
                cursor: pointer;
            }
        `;
        document.head.appendChild(style);
        
        // Remove ALL custom controls - we don't want ANY controls visible
        
        // Handle video events
        video.addEventListener('loadeddata', () => {
            video.play().catch(() => {
                // Silent catch for autoplay policies
            });
        });
        
        video.addEventListener('ended', () => {
            nextVideo();
        });
        
        // Add click handler to vine items
        document.querySelectorAll('.vine-item').forEach((item, index) => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                console.log(`Clicked video ${index}: ${videos[index].title}`);
                playVideo(index);
            });
        });
        
        // Start with first video
        playVideo(0);
    }
});

// Video control functions
function togglePlayPause() {
    const video = document.getElementById('main-vine-player');
    
    if (video.paused) {
        video.play();
    } else {
        video.pause();
    }
}

function toggleMute() {
    const video = document.getElementById('main-vine-player');
    video.muted = !video.muted;
}

function nextVideo() {
    currentVideoIndex = (currentVideoIndex + 1) % videos.length;
    playVideo(currentVideoIndex);
}

function playVideo(index) {
    if (index < 0 || index >= videos.length) return;
    
    currentVideoIndex = index;
    const video = document.getElementById('main-vine-player');
    const videoData = videos[index];
    
    // Update video source
    const source = video.querySelector('source');
    if (source) {
        source.src = videoData.url;
    } else {
        video.src = videoData.url;
    }
    video.load();
    
    // Force autoplay
    video.play().catch((error) => {
        console.log('Autoplay failed:', error);
        // If autoplay with sound fails, show play button or require user interaction
        video.muted = false;
    });
    
    // Update active vine item
    document.querySelectorAll('.vine-item').forEach((item, i) => {
        if (i === index) {
            item.classList.add('active');
            // Move video to active item
            const targetThumbnail = item.querySelector('.vine-thumbnail');
            const currentVideo = document.querySelector('.vine-video.main-video');
            if (currentVideo && targetThumbnail) {
                targetThumbnail.innerHTML = '';
                targetThumbnail.appendChild(currentVideo);
            }
        } else {
            item.classList.remove('active');
        }
    });
    
    // No video info to update since we removed the sidebar
}

// Make functions globally available
window.togglePlayPause = togglePlayPause;
window.toggleMute = toggleMute;
window.nextVideo = nextVideo;
window.playVideo = playVideo;