// Worker script for Cloudflare Pages to optimize performance

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    
    // Add security headers and optimize caching
    const response = await env.ASSETS.fetch(request);
    const newHeaders = new Headers(response.headers);
    
    // Security headers
    newHeaders.set("X-Frame-Options", "DENY");
    newHeaders.set("X-Content-Type-Options", "nosniff");
    newHeaders.set("Referrer-Policy", "strict-origin-when-cross-origin");
    
    // Content Security Policy with required domains
    newHeaders.set("Content-Security-Policy", 
      "default-src 'self'; " +
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net https://www.gstatic.com; " +
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
      "img-src 'self' data: https: blob:; " +
      "font-src 'self' data: https://fonts.gstatic.com; " +
      "connect-src 'self' https: wss: ws:; " +
      "media-src 'self' https: blob:;"
    );
    
    // Optimize caching based on file type
    const pathname = url.pathname;
    
    // Immutable assets (hashed filenames)
    if (pathname.match(/\.(js|css|wasm)$/) && pathname.includes('.')) {
      newHeaders.set("Cache-Control", "public, max-age=31536000, immutable");
    }
    // HTML files should not be cached
    else if (pathname.endsWith('.html') || pathname === '/') {
      newHeaders.set("Cache-Control", "no-cache, no-store, must-revalidate");
    }
    // Fonts can be cached for a long time
    else if (pathname.match(/\.(woff2?|ttf|otf)$/)) {
      newHeaders.set("Cache-Control", "public, max-age=31536000");
    }
    // Images can be cached
    else if (pathname.match(/\.(png|jpg|jpeg|gif|webp|svg|ico)$/)) {
      newHeaders.set("Cache-Control", "public, max-age=86400");
    }
    // JSON manifests should have short cache
    else if (pathname.endsWith('.json')) {
      newHeaders.set("Cache-Control", "public, max-age=3600");
    }
    
    // Enable compression hints
    newHeaders.set("Accept-Encoding", "gzip, deflate, br");
    
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: newHeaders
    });
  }
};