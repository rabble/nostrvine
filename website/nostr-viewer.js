// ABOUTME: Nostr event viewer for displaying kind 22 videos with author profiles
// ABOUTME: Handles WebSocket connections to relays and real-time event fetching

// Nostr relay configuration - same as mobile app
const DEFAULT_RELAYS = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.nos.social',
    'wss://relay.nostr.band',
    'wss://cache2.primal.net/v1',
];

class NostrViewer {
    constructor() {
        this.relayConnections = new Map();
        this.connectedRelays = new Set();
        this.videoEvent = null;
        this.authorProfile = null;
        this.eventId = null;
        this.subscriptions = new Map();
        this.connectionTimeout = 10000; // 10 seconds
        this.fetchTimeout = 15000; // 15 seconds for event fetching
    }

    async initialize(eventId) {
        this.eventId = eventId;
        console.log('🔍 Initializing Nostr viewer for event:', eventId);
        
        try {
            await this.connectToRelays();
            await this.fetchEventAndProfile();
        } catch (error) {
            console.error('❌ Failed to initialize viewer:', error);
            this.showError('Failed to connect to Nostr network: ' + error.message);
        }
    }

    async connectToRelays() {
        const connectionPromises = DEFAULT_RELAYS.map(url => this.connectToRelay(url));
        
        // Wait for at least one connection to succeed
        const results = await Promise.allSettled(connectionPromises);
        const successful = results.filter(result => result.status === 'fulfilled');
        
        if (successful.length === 0) {
            throw new Error('Could not connect to any Nostr relays');
        }
        
        console.log(`✅ Connected to ${successful.length}/${DEFAULT_RELAYS.length} relays`);
        this.updateRelayStatus();
    }

    async connectToRelay(url) {
        return new Promise((resolve, reject) => {
            console.log('🔌 Connecting to relay:', url);
            
            const ws = new WebSocket(url);
            const timeoutId = setTimeout(() => {
                ws.close();
                reject(new Error(`Connection timeout for ${url}`));
            }, this.connectionTimeout);

            ws.onopen = () => {
                clearTimeout(timeoutId);
                console.log('✅ Connected to relay:', url);
                this.relayConnections.set(url, ws);
                this.connectedRelays.add(url);
                resolve(ws);
            };

            ws.onerror = (error) => {
                clearTimeout(timeoutId);
                console.error('❌ Relay connection error:', url, error);
                reject(new Error(`Failed to connect to ${url}`));
            };

            ws.onclose = () => {
                console.log('🔌 Disconnected from relay:', url);
                this.connectedRelays.delete(url);
                this.relayConnections.delete(url);
                this.updateRelayStatus();
            };

            ws.onmessage = (event) => {
                try {
                    this.handleRelayMessage(url, event.data);
                } catch (error) {
                    console.error('⚠️ Error handling message from', url, ':', error);
                }
            };
        });
    }

    handleRelayMessage(relayUrl, data) {
        try {
            const message = JSON.parse(data);
            const [type, subscriptionId, eventData] = message;

            switch (type) {
                case 'EVENT':
                    this.handleEventMessage(eventData);
                    break;
                case 'EOSE':
                    console.log('📄 End of stored events from', relayUrl);
                    break;
                case 'OK':
                    console.log('✅ Event published successfully to', relayUrl);
                    break;
                case 'NOTICE':
                    console.log('📢 Notice from', relayUrl, ':', message[1]);
                    break;
                default:
                    console.log('📨 Unknown message type:', type, 'from', relayUrl);
            }
        } catch (error) {
            console.error('⚠️ Error parsing message from', relayUrl, ':', error);
        }
    }

    handleEventMessage(eventData) {
        try {
            if (!eventData || !eventData.id) {
                console.warn('⚠️ Received invalid event data');
                return;
            }

            console.log('📨 Received event:', eventData.kind, eventData.id.substring(0, 8));

            if (eventData.kind === 22 && eventData.id === this.eventId) {
                // This is our target video event
                console.log('🎬 Found target video event!');
                this.videoEvent = eventData;
                this.displayVideoEvent();
                
                // Now fetch the author's profile
                if (eventData.pubkey) {
                    this.fetchAuthorProfile(eventData.pubkey);
                }
            } else if (eventData.kind === 0 && this.videoEvent && eventData.pubkey === this.videoEvent.pubkey) {
                // This is the author's profile
                console.log('👤 Found author profile!');
                this.authorProfile = eventData;
                this.displayAuthorProfile();
            }
        } catch (error) {
            console.error('⚠️ Error handling event:', error);
        }
    }

    async fetchEventAndProfile() {
        return new Promise((resolve, reject) => {
            const timeoutId = setTimeout(() => {
                reject(new Error('Timeout waiting for video event'));
            }, this.fetchTimeout);

            // Subscribe to the specific event by ID
            const subscription1 = this.subscribeToEvents([{
                ids: [this.eventId],
                kinds: [22]
            }], 'video-event');

            // Wait for video event to be found, then resolve
            const checkComplete = () => {
                if (this.videoEvent) {
                    clearTimeout(timeoutId);
                    resolve();
                }
            };

            // Check periodically if we have the video event
            const checkInterval = setInterval(() => {
                checkComplete();
                if (this.videoEvent) {
                    clearInterval(checkInterval);
                }
            }, 500);
        });
    }

    fetchAuthorProfile(pubkey) {
        console.log('👤 Fetching profile for:', pubkey.substring(0, 8));
        
        // Subscribe to profile events for this author
        this.subscribeToEvents([{
            kinds: [0],
            authors: [pubkey],
            limit: 1
        }], 'author-profile');
    }

    subscribeToEvents(filters, subscriptionId) {
        console.log('🔍 Creating subscription:', subscriptionId, 'with filters:', filters);
        
        const reqMessage = JSON.stringify(['REQ', subscriptionId, ...filters]);
        
        // Send to all connected relays
        for (const [url, ws] of this.relayConnections) {
            if (ws.readyState === WebSocket.OPEN) {
                try {
                    ws.send(reqMessage);
                    console.log('📤 Sent subscription to', url);
                } catch (error) {
                    console.error('❌ Failed to send subscription to', url, ':', error);
                }
            }
        }

        this.subscriptions.set(subscriptionId, filters);
    }

    displayVideoEvent() {
        if (!this.videoEvent) return;

        console.log('🎬 Displaying video event:', this.videoEvent);

        // Track view for analytics (anonymous, no user data)
        this.trackView(this.videoEvent.id);

        // Hide loading, show viewer
        document.getElementById('loading').style.display = 'none';
        document.getElementById('viewer').style.display = 'block';

        // Extract video URL from tags
        const videoUrl = this.getTagValue(this.videoEvent.tags, 'url');
        if (!videoUrl) {
            this.showError('Video URL not found in event');
            return;
        }

        // Set up video element
        const videoElement = document.getElementById('nostr-video');
        videoElement.src = videoUrl;
        videoElement.onerror = () => {
            this.showError('Failed to load video from: ' + videoUrl);
        };

        // Display event content
        document.getElementById('video-description').textContent = 
            this.videoEvent.content || 'No description provided';

        // Display metadata
        document.getElementById('event-id').textContent = 
            this.videoEvent.id.substring(0, 16) + '...';
        
        const publishTime = new Date(this.videoEvent.created_at * 1000);
        document.getElementById('publish-time').textContent = 
            publishTime.toLocaleString();

        // Set up controls
        this.setupVideoControls();
    }

    displayAuthorProfile() {
        if (!this.authorProfile) return;

        console.log('👤 Displaying author profile:', this.authorProfile);

        try {
            const profileData = JSON.parse(this.authorProfile.content);
            
            // Display author name
            const name = profileData.display_name || profileData.name || 'Anonymous User';
            document.getElementById('author-name').textContent = name;
            
            // Display author pubkey (shortened)
            const pubkey = this.authorProfile.pubkey;
            document.getElementById('author-pubkey').textContent = 
                `${pubkey.substring(0, 8)}...${pubkey.substring(-8)}`;
            
            // Set avatar
            const avatarContainer = document.getElementById('author-avatar');
            const initialSpan = document.getElementById('author-initial');
            
            if (profileData.picture) {
                const img = document.createElement('img');
                img.src = profileData.picture;
                img.alt = name;
                img.onerror = () => {
                    // Fallback to initial if image fails
                    initialSpan.textContent = name.charAt(0).toUpperCase();
                };
                avatarContainer.appendChild(img);
                initialSpan.style.display = 'none';
            } else {
                initialSpan.textContent = name.charAt(0).toUpperCase();
            }
            
        } catch (error) {
            console.error('⚠️ Error parsing author profile:', error);
            // Fallback display
            document.getElementById('author-name').textContent = 'Nostr User';
            document.getElementById('author-pubkey').textContent = 
                `${this.authorProfile.pubkey.substring(0, 8)}...`;
        }
    }

    setupVideoControls() {
        const likeBtn = document.getElementById('like-btn');
        const shareBtn = document.getElementById('share-btn');

        likeBtn.addEventListener('click', () => {
            likeBtn.classList.toggle('liked');
            // TODO: Implement actual liking functionality
            console.log('❤️ Like button clicked');
        });

        shareBtn.addEventListener('click', () => {
            if (navigator.share) {
                navigator.share({
                    title: 'OpenVine Video',
                    text: this.videoEvent?.content || 'Check out this video on OpenVine',
                    url: window.location.href
                });
            } else {
                // Fallback to clipboard
                navigator.clipboard.writeText(window.location.href);
                alert('Link copied to clipboard!');
            }
        });
    }

    getTagValue(tags, tagName) {
        if (!tags) return null;
        const tag = tags.find(t => Array.isArray(t) && t[0] === tagName);
        return tag ? tag[1] : null;
    }

    updateRelayStatus() {
        const statusElement = document.getElementById('relay-status');
        if (this.connectedRelays.size > 0) {
            statusElement.textContent = `${this.connectedRelays.size}/${DEFAULT_RELAYS.length} connected`;
            statusElement.className = 'metadata-value relay-status connected';
        } else {
            statusElement.textContent = 'Disconnected';
            statusElement.className = 'metadata-value relay-status error';
        }
    }

    async trackView(eventId) {
        try {
            // Track view anonymously for trending/popular content
            const trackingData = {
                eventId: eventId,
                source: 'web'
            };
            
            // Include creator pubkey if we have the video event
            if (this.videoEvent && this.videoEvent.pubkey) {
                trackingData.creatorPubkey = this.videoEvent.pubkey;
            }
            
            const response = await fetch('https://analytics.openvine.co/analytics/view', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(trackingData)
            });

            if (response.ok) {
                const data = await response.json();
                console.log('📊 View tracked:', data.views, 'total views');
                
                // Could display view count in UI if desired
                // document.getElementById('view-count').textContent = data.views;
            } else {
                console.warn('⚠️ Analytics tracking failed:', response.status);
            }
        } catch (error) {
            console.warn('⚠️ Analytics tracking error:', error);
            // Don't block video viewing if analytics fails
        }
    }

    showError(message) {
        console.error('❌ Error:', message);
        document.getElementById('loading').style.display = 'none';
        document.getElementById('viewer').style.display = 'none';
        document.getElementById('error').style.display = 'block';
        document.getElementById('error-message').textContent = message;
    }

    dispose() {
        // Close all WebSocket connections
        for (const [url, ws] of this.relayConnections) {
            try {
                ws.close();
            } catch (error) {
                console.warn('⚠️ Error closing connection to', url, ':', error);
            }
        }
        this.relayConnections.clear();
        this.connectedRelays.clear();
        this.subscriptions.clear();
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
    console.log('🚀 NostrViewer initializing...');
    
    // Extract event ID from URL
    const path = window.location.pathname;
    const eventIdMatch = path.match(/\/watch\/([a-f0-9]{64})/);
    
    if (!eventIdMatch) {
        console.error('❌ No valid event ID found in URL');
        document.getElementById('loading').style.display = 'none';
        document.getElementById('error').style.display = 'block';
        document.getElementById('error-message').textContent = 
            'Invalid video URL. Event ID not found.';
        return;
    }
    
    const eventId = eventIdMatch[1];
    console.log('🎯 Target event ID:', eventId);
    
    // Create and initialize viewer
    const viewer = new NostrViewer();
    viewer.initialize(eventId);
    
    // Cleanup on page unload
    window.addEventListener('beforeunload', () => {
        viewer.dispose();
    });
});

// Make viewer globally available for debugging
window.NostrViewer = NostrViewer;