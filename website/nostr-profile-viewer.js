// ABOUTME: Nostr profile viewer for OpenVine user profiles
// ABOUTME: Handles NIP-05 verification and displays user content

class NostrProfileViewer {
    constructor() {
        this.relays = [
            'wss://relay.damus.io',
            'wss://relay.nostr.band',
            'wss://nos.lol',
            'wss://relay.snort.social',
            'wss://nostr.wine'
        ];
        this.pool = null;
        this.pubkey = null;
        this.username = null;
        this.profile = null;
        this.videos = [];
        this.reposts = [];
        this.likes = [];
    }

    async initialize() {
        // Get username from URL path (Vine-style: /username)
        const path = window.location.pathname.substring(1); // Remove leading slash
        
        // Skip if it's a known page route
        const knownRoutes = ['about', 'trending', 'ios', 'android', 'open-source'];
        if (knownRoutes.includes(path) || path === '' || path.includes('/')) {
            this.showError();
            return;
        }
        
        this.username = decodeURIComponent(path);

        if (!this.username) {
            this.showError();
            return;
        }

        // Initialize SimplePool
        if (window.SimplePool) {
            this.pool = new window.SimplePool();
        } else {
            console.error('SimplePool not loaded');
            this.showError();
            return;
        }

        // Verify NIP-05 and get pubkey
        await this.verifyNIP05();
    }

    async verifyNIP05() {
        try {
            // Fetch NIP-05 verification
            const response = await fetch(`/.well-known/nostr.json?name=${this.username}`);
            if (!response.ok) {
                throw new Error('User not found');
            }

            const data = await response.json();
            const pubkey = data.names[this.username];

            if (!pubkey) {
                throw new Error('User not verified');
            }

            this.pubkey = pubkey;
            
            // Get relays if provided
            if (data.relays && data.relays[pubkey]) {
                this.relays = [...new Set([...data.relays[pubkey], ...this.relays])];
            }

            // Load profile data
            await this.loadProfile();

        } catch (error) {
            console.error('NIP-05 verification failed:', error);
            this.showError();
        }
    }

    async loadProfile() {
        try {
            // Subscribe to user metadata (Kind 0)
            const sub = this.pool.sub(this.relays, [{
                kinds: [0],
                authors: [this.pubkey]
            }]);

            sub.on('event', (event) => {
                if (event.kind === 0) {
                    try {
                        this.profile = JSON.parse(event.content);
                        this.displayProfile();
                    } catch (e) {
                        console.error('Failed to parse profile:', e);
                    }
                }
            });

            // Load user content
            await this.loadUserContent();

            // Hide loading after a timeout
            setTimeout(() => {
                document.getElementById('profile-loading').style.display = 'none';
                document.getElementById('profile-content').style.display = 'block';
            }, 1000);

        } catch (error) {
            console.error('Failed to load profile:', error);
            this.showError();
        }
    }

    displayProfile() {
        if (!this.profile) return;

        // Update profile info
        const displayName = this.profile.display_name || this.profile.name || this.username;
        document.getElementById('user-display-name').textContent = displayName;
        document.getElementById('user-nip05').textContent = `${this.username}@openvine.co`;
        
        // Set avatar
        const avatarImg = document.getElementById('user-avatar');
        if (this.profile.picture) {
            avatarImg.src = this.profile.picture;
            avatarImg.onerror = () => {
                avatarImg.src = `https://api.dicebear.com/7.x/identicon/svg?seed=${this.pubkey}`;
            };
        } else {
            avatarImg.src = `https://api.dicebear.com/7.x/identicon/svg?seed=${this.pubkey}`;
        }

        // Set bio
        if (this.profile.about) {
            document.getElementById('user-bio').textContent = this.profile.about;
        }

        // Update page title and meta tags
        document.title = `${displayName} - OpenVine`;
        document.querySelector('meta[property="og:title"]').content = `${displayName} on OpenVine`;
        document.querySelector('meta[property="og:description"]').content = this.profile.about || `View ${displayName}'s videos on OpenVine`;
        document.querySelector('meta[name="nostr"]').content = this.pubkey;
    }

    async loadUserContent() {
        // Subscribe to user's videos (Kind 22), reposts (Kind 6), and reactions (Kind 7)
        const sub = this.pool.sub(this.relays, [
            {
                kinds: [22], // Videos
                authors: [this.pubkey],
                limit: 50
            },
            {
                kinds: [6], // Reposts
                authors: [this.pubkey],
                limit: 50
            },
            {
                kinds: [7], // Reactions
                authors: [this.pubkey],
                limit: 100
            }
        ]);

        // Also get follower/following counts
        const followSub = this.pool.sub(this.relays, [
            {
                kinds: [3], // Contact lists
                authors: [this.pubkey],
                limit: 1
            },
            {
                kinds: [3], // Others following this user
                '#p': [this.pubkey],
                limit: 500
            }
        ]);

        sub.on('event', (event) => {
            if (event.kind === 22) {
                this.videos.push(event);
                this.updateVideoCount();
                this.displayVideo(event);
            } else if (event.kind === 6) {
                this.reposts.push(event);
                this.loadRepostedVideo(event);
            } else if (event.kind === 7 && event.content === '+' || event.content === '❤️') {
                this.likes.push(event);
                this.loadLikedVideo(event);
            }
        });

        let followingCount = 0;
        let followerCount = 0;

        followSub.on('event', (event) => {
            if (event.kind === 3) {
                if (event.pubkey === this.pubkey) {
                    // User's contact list
                    const tags = event.tags.filter(tag => tag[0] === 'p');
                    followingCount = tags.length;
                    document.getElementById('following-count').textContent = followingCount;
                } else {
                    // Someone following this user
                    followerCount++;
                    document.getElementById('follower-count').textContent = followerCount;
                }
            }
        });
    }

    updateVideoCount() {
        document.getElementById('video-count').textContent = this.videos.length;
    }

    displayVideo(event) {
        const videoGrid = document.getElementById('videos-grid');
        const videoItem = this.createVideoItem(event);
        videoGrid.appendChild(videoItem);
    }

    createVideoItem(event) {
        const item = document.createElement('div');
        item.className = 'video-item';
        item.onclick = () => window.location.href = `/watch/${event.id}`;

        // Extract video URL from event
        const urlTag = event.tags.find(tag => tag[0] === 'url');
        const videoUrl = urlTag ? urlTag[1] : null;

        if (videoUrl) {
            const video = document.createElement('video');
            video.src = videoUrl;
            video.muted = true;
            video.loop = true;
            video.playsInline = true;
            
            // Play on hover
            item.onmouseenter = () => video.play().catch(() => {});
            item.onmouseleave = () => {
                video.pause();
                video.currentTime = 0;
            };

            item.appendChild(video);
        }

        // Add overlay with stats
        const overlay = document.createElement('div');
        overlay.className = 'video-overlay';
        
        const stats = document.createElement('div');
        stats.className = 'video-stats';
        stats.innerHTML = `
            <span>👁 ${Math.floor(Math.random() * 10000)}</span>
            <span>❤️ ${Math.floor(Math.random() * 1000)}</span>
        `;
        
        overlay.appendChild(stats);
        item.appendChild(overlay);

        return item;
    }

    async loadRepostedVideo(repostEvent) {
        // Find the original video event
        const eTag = repostEvent.tags.find(tag => tag[0] === 'e');
        if (!eTag) return;

        const originalEventId = eTag[1];
        
        // Fetch the original event
        const sub = this.pool.sub(this.relays, [{
            ids: [originalEventId]
        }]);

        sub.on('event', (event) => {
            if (event.kind === 22) {
                const repostsGrid = document.getElementById('reposts-grid');
                const videoItem = this.createVideoItem(event);
                repostsGrid.appendChild(videoItem);
            }
        });
    }

    async loadLikedVideo(likeEvent) {
        // Find the liked video event
        const eTag = likeEvent.tags.find(tag => tag[0] === 'e');
        if (!eTag) return;

        const likedEventId = eTag[1];
        
        // Fetch the liked event
        const sub = this.pool.sub(this.relays, [{
            ids: [likedEventId]
        }]);

        sub.on('event', (event) => {
            if (event.kind === 22) {
                const likesGrid = document.getElementById('likes-grid');
                const videoItem = this.createVideoItem(event);
                likesGrid.appendChild(videoItem);
            }
        });
    }

    showError() {
        document.getElementById('profile-loading').style.display = 'none';
        document.getElementById('profile-error').style.display = 'block';
    }
}

// Tab switching functionality
document.addEventListener('DOMContentLoaded', () => {
    const tabs = document.querySelectorAll('.tab-button');
    const grids = document.querySelectorAll('.content-grid');

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            // Remove active class from all tabs
            tabs.forEach(t => t.classList.remove('active'));
            // Add active class to clicked tab
            tab.classList.add('active');

            // Hide all grids
            grids.forEach(g => g.style.display = 'none');
            // Show selected grid
            const selectedTab = tab.dataset.tab;
            document.getElementById(`${selectedTab}-grid`).style.display = 'grid';
        });
    });

    // Load nostr-tools if not already loaded
    if (!window.SimplePool) {
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/nostr-tools/lib/nostr.bundle.js';
        script.onload = () => {
            // Initialize profile viewer
            const viewer = new NostrProfileViewer();
            viewer.initialize();
        };
        document.head.appendChild(script);
    } else {
        // Initialize profile viewer
        const viewer = new NostrProfileViewer();
        viewer.initialize();
    }
});