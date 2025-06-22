// ABOUTME: Cloudflare Workers entry point for OpenVine website
// ABOUTME: Serves static HTML files and handles routing

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    
    // Define static file mappings
    const routes = {
      '/': 'index.html',
      '/about': 'about.html',
      '/about.html': 'about.html',
      '/ios': 'ios.html', 
      '/ios.html': 'ios.html',
      '/android': 'android.html',
      '/android.html': 'android.html'
    };
    
    // Check for exact route match
    let filePath = routes[pathname];
    
    // If no exact match, try to serve the file directly
    if (!filePath) {
      // Remove leading slash and serve file directly
      filePath = pathname.slice(1);
      
      // If empty or doesn't have extension, default to index.html
      if (!filePath || !filePath.includes('.')) {
        filePath = 'index.html';
      }
    }
    
    try {
      // Get the static asset
      const asset = await env.ASSETS.fetch(`https://placeholder.com/${filePath}`);
      
      if (asset.status === 404) {
        // If file not found, serve 404 or redirect to home
        return new Response('Page not found', { status: 404 });
      }
      
      // Set appropriate content type based on file extension
      const contentType = getContentType(filePath);
      const response = new Response(asset.body, {
        headers: {
          'Content-Type': contentType,
          'Cache-Control': 'public, max-age=3600'
        }
      });
      
      return response;
    } catch (error) {
      return new Response('Error loading page', { status: 500 });
    }
  }
};

function getContentType(filePath) {
  const extension = filePath.split('.').pop().toLowerCase();
  
  const mimeTypes = {
    'html': 'text/html; charset=utf-8',
    'css': 'text/css',
    'js': 'application/javascript',
    'ico': 'image/x-icon',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'svg': 'image/svg+xml'
  };
  
  return mimeTypes[extension] || 'text/plain';
}