// ABOUTME: Simple client-side router for OpenVine watch URLs
// ABOUTME: Handles /watch/eventId routing and loads appropriate content

class OpenVineRouter {
    constructor() {
        this.routes = new Map();
        this.setupRoutes();
        this.init();
    }

    setupRoutes() {
        // Define our routes
        this.routes.set('/', () => this.showHomePage());
        this.routes.set('/watch/:eventId', (params) => this.showWatchPage(params.eventId));
    }

    init() {
        // Handle initial page load
        this.handleRoute();
        
        // Handle browser back/forward
        window.addEventListener('popstate', () => this.handleRoute());
        
        // Intercept navigation links
        document.addEventListener('click', (e) => {
            if (e.target.tagName === 'A' && e.target.hostname === location.hostname) {
                e.preventDefault();
                this.navigateTo(e.target.pathname);
            }
        });
    }

    handleRoute() {
        const path = window.location.pathname;
        console.log('🛤️ Handling route:', path);

        // Try to match routes
        for (const [route, handler] of this.routes) {
            const params = this.matchRoute(route, path);
            if (params !== null) {
                handler(params);
                return;
            }
        }

        // No route matched - show 404 or redirect to home
        console.warn('⚠️ No route matched for:', path);
        this.show404();
    }

    matchRoute(route, path) {
        // Convert route pattern to regex
        const paramNames = [];
        const regexPattern = route.replace(/:([^/]+)/g, (match, paramName) => {
            paramNames.push(paramName);
            return '([^/]+)';
        });

        const regex = new RegExp(`^${regexPattern}$`);
        const match = path.match(regex);

        if (!match) {
            return null;
        }

        // Extract parameters
        const params = {};
        paramNames.forEach((name, index) => {
            params[name] = match[index + 1];
        });

        return params;
    }

    navigateTo(path) {
        window.history.pushState({}, '', path);
        this.handleRoute();
    }

    showHomePage() {
        console.log('🏠 Showing home page');
        // If we're already on index.html, do nothing
        if (window.location.pathname === '/' || window.location.pathname === '/index.html') {
            return;
        }
        // Redirect to index.html
        window.location.href = '/index.html';
    }

    showWatchPage(eventId) {
        console.log('📺 Showing watch page for event:', eventId);
        
        // Validate event ID format (64 character hex string)
        if (!/^[a-f0-9]{64}$/i.test(eventId)) {
            console.error('❌ Invalid event ID format:', eventId);
            this.show404();
            return;
        }

        // Load the watch page content
        this.loadWatchPage(eventId);
    }

    async loadWatchPage(eventId) {
        try {
            // Check if we're already on the watch page
            if (document.getElementById('nostr-video')) {
                // We're already on the watch page, just initialize with new event ID
                if (window.currentViewer) {
                    window.currentViewer.dispose();
                }
                const viewer = new NostrViewer();
                window.currentViewer = viewer;
                await viewer.initialize(eventId);
                return;
            }

            // Load the watch page HTML
            console.log('📄 Loading watch page...');
            const response = await fetch('/watch.html');
            if (!response.ok) {
                throw new Error('Failed to load watch page');
            }
            
            const html = await response.text();
            document.body.innerHTML = html;
            
            // Load the CSS if not already loaded
            if (!document.querySelector('link[href="watch-styles.css"]')) {
                const link = document.createElement('link');
                link.rel = 'stylesheet';
                link.href = 'watch-styles.css';
                document.head.appendChild(link);
            }
            
            // Load the NostrViewer script if not already loaded
            if (!window.NostrViewer) {
                await this.loadScript('/nostr-viewer.js');
            }
            
            // Initialize the viewer
            const viewer = new NostrViewer();
            window.currentViewer = viewer;
            await viewer.initialize(eventId);
            
        } catch (error) {
            console.error('❌ Failed to load watch page:', error);
            this.showError('Failed to load video page: ' + error.message);
        }
    }

    show404() {
        document.body.innerHTML = `
            <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; text-align: center; font-family: Arial, sans-serif;">
                <h1 style="font-size: 4rem; margin: 0; color: #ff6b6b;">404</h1>
                <h2 style="margin: 1rem 0; color: #333;">Page Not Found</h2>
                <p style="color: #666; margin-bottom: 2rem;">The video you're looking for doesn't exist or the URL is invalid.</p>
                <a href="/" style="background: #00D4AA; color: white; padding: 1rem 2rem; text-decoration: none; border-radius: 25px; font-weight: bold;">← Back to Home</a>
            </div>
        `;
    }

    showError(message) {
        document.body.innerHTML = `
            <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; text-align: center; font-family: Arial, sans-serif;">
                <h1 style="font-size: 2rem; margin: 0; color: #ff6b6b;">⚠️ Error</h1>
                <p style="color: #666; margin: 2rem 0; max-width: 500px;">${message}</p>
                <a href="/" style="background: #00D4AA; color: white; padding: 1rem 2rem; text-decoration: none; border-radius: 25px; font-weight: bold;">← Back to Home</a>
            </div>
        `;
    }

    loadScript(src) {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = src;
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }
}

// Initialize router when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    // Only initialize router if we're not already on a specific page
    if (!document.getElementById('nostr-video')) {
        window.router = new OpenVineRouter();
    }
});