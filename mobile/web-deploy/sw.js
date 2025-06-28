// ABOUTME: Service Worker for OpenVine - Aggressive caching for Flutter web performance
// ABOUTME: Implements cache-first strategy for static assets and network-first for API calls

const CACHE_NAME = 'openvine-v1.1.0';
const FLUTTER_CACHE = 'openvine-flutter-cache';
const API_CACHE = 'openvine-api-cache';

// Assets to cache immediately on install
const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter_bootstrap.js',
  '/flutter.js',
  '/manifest.json',
  '/favicon.png',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json',
];

// Cache strategies
const CACHE_STRATEGIES = {
  // Static assets - cache first, network fallback
  CACHE_FIRST: 'cache-first',
  // API calls - network first, cache fallback  
  NETWORK_FIRST: 'network-first',
  // Font files - stale while revalidate
  STALE_WHILE_REVALIDATE: 'stale-while-revalidate'
};

// Install event - precache critical assets
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');
  
  event.waitUntil(
    Promise.all([
      // Precache Flutter app shell
      caches.open(FLUTTER_CACHE).then((cache) => {
        console.log('[SW] Precaching Flutter assets');
        return cache.addAll(PRECACHE_ASSETS);
      }),
      // Force activation of new service worker
      self.skipWaiting()
    ])
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');
  
  event.waitUntil(
    Promise.all([
      // Clean up old caches
      caches.keys().then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== CACHE_NAME && 
                cacheName !== FLUTTER_CACHE && 
                cacheName !== API_CACHE) {
              console.log('[SW] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      }),
      // Take control of all pages
      self.clients.claim()
    ])
  );
});

// Fetch event - implement caching strategies
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Allow analytics POST requests to pass through
  if (url.hostname === 'analytics.openvine.co') {
    // Don't intercept analytics requests - let them go straight to network
    return;
  }
  
  // Skip non-GET requests for caching
  if (request.method !== 'GET') {
    return;
  }
  
  // Handle different types of requests
  if (isFlutterAsset(url)) {
    event.respondWith(handleFlutterAsset(request));
  } else if (isApiRequest(url)) {
    event.respondWith(handleApiRequest(request));
  } else if (isFontRequest(url)) {
    event.respondWith(handleFontRequest(request));
  } else if (isImageRequest(url)) {
    event.respondWith(handleImageRequest(request));
  }
});

// Check if request is for Flutter app assets
function isFlutterAsset(url) {
  return url.origin === self.location.origin && (
    url.pathname.endsWith('.js') ||
    url.pathname.endsWith('.wasm') ||
    url.pathname.endsWith('.json') ||
    url.pathname.endsWith('.png') ||
    url.pathname.endsWith('.ico') ||
    url.pathname === '/' ||
    url.pathname.startsWith('/assets/')
  );
}

// Check if request is for API
function isApiRequest(url) {
  return url.hostname === 'api.openvine.co';
}

// Check if request is for fonts
function isFontRequest(url) {
  return url.hostname === 'fonts.googleapis.com' || 
         url.hostname === 'fonts.gstatic.com' ||
         url.pathname.includes('fonts');
}

// Check if request is for images
function isImageRequest(url) {
  return url.pathname.match(/\.(jpg|jpeg|png|gif|webp|svg)$/i);
}

// Handle Flutter assets with cache-first strategy
async function handleFlutterAsset(request) {
  try {
    const cache = await caches.open(FLUTTER_CACHE);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
      console.log('[SW] Serving Flutter asset from cache:', request.url);
      
      // Update cache in background for next time
      fetch(request).then((networkResponse) => {
        if (networkResponse.ok) {
          cache.put(request, networkResponse.clone());
        }
      }).catch(() => {
        // Network failed, keep using cache
      });
      
      return cachedResponse;
    }
    
    // Not in cache, fetch from network
    console.log('[SW] Fetching Flutter asset from network:', request.url);
    const networkResponse = await fetch(request);
    
    if (networkResponse.ok) {
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
  } catch (error) {
    console.error('[SW] Error handling Flutter asset:', error);
    return new Response('Asset not available', { status: 404 });
  }
}

// Handle API requests with network-first strategy
async function handleApiRequest(request) {
  try {
    // Try network first
    console.log('[SW] Fetching API request from network:', request.url);
    const networkResponse = await fetch(request);
    
    if (networkResponse.ok) {
      // Cache successful API responses (but not POST/PUT/DELETE)
      if (request.method === 'GET') {
        const cache = await caches.open(API_CACHE);
        cache.put(request, networkResponse.clone());
      }
    }
    
    return networkResponse;
  } catch (error) {
    // Network failed, try cache
    console.log('[SW] Network failed, trying cache for:', request.url);
    const cache = await caches.open(API_CACHE);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
      console.log('[SW] Serving API response from cache:', request.url);
      return cachedResponse;
    }
    
    // No cache, return error
    console.error('[SW] API request failed and no cache available:', error);
    return new Response('Network error', { status: 503 });
  }
}

// Handle font requests with stale-while-revalidate
async function handleFontRequest(request) {
  try {
    const cache = await caches.open(FLUTTER_CACHE);
    const cachedResponse = await cache.match(request);
    
    // Serve from cache immediately if available
    if (cachedResponse) {
      console.log('[SW] Serving font from cache:', request.url);
      
      // Update cache in background
      fetch(request).then((networkResponse) => {
        if (networkResponse.ok) {
          cache.put(request, networkResponse.clone());
        }
      }).catch(() => {
        // Ignore network errors for background updates
      });
      
      return cachedResponse;
    }
    
    // Not in cache, fetch from network
    console.log('[SW] Fetching font from network:', request.url);
    const networkResponse = await fetch(request);
    
    if (networkResponse.ok) {
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
  } catch (error) {
    console.error('[SW] Error handling font request:', error);
    return fetch(request);
  }
}

// Handle image requests with cache-first strategy
async function handleImageRequest(request) {
  try {
    const cache = await caches.open(FLUTTER_CACHE);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
      console.log('[SW] Serving image from cache:', request.url);
      return cachedResponse;
    }
    
    // Not in cache, fetch from network
    console.log('[SW] Fetching image from network:', request.url);
    const networkResponse = await fetch(request);
    
    if (networkResponse.ok) {
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
  } catch (error) {
    console.error('[SW] Error handling image request:', error);
    return fetch(request);
  }
}

// Handle messages from the app
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data === 'CLEAR_CACHE') {
    console.log('[SW] Clearing all caches...');
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => caches.delete(cacheName))
      );
    });
  }
});

console.log('[SW] Service worker loaded');