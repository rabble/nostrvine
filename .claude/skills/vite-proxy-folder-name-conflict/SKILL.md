---
name: vite-proxy-folder-name-conflict
description: |
  Fix 404 errors for frontend JS files when using Vite proxy. Use when: (1) Browser shows
  "Failed to load resource: 404" for JS/JSX files that exist on disk, (2) Vite serves HTML
  instead of JavaScript for module imports, (3) You have a client folder named "api" (or
  similar) AND a Vite proxy configured for "/api". The proxy intercepts requests for
  client-side files when folder names match proxy paths. Applies to Vite, Vite+React,
  Vite+Vue projects with dev server proxy configuration.
author: Claude Code
version: 1.0.0
date: 2026-01-21
---

# Vite Proxy Folder Name Conflict

## Problem

Frontend JavaScript/JSX files return 404 errors even though they exist on disk. The browser
console shows errors like:

```
usePeople.js:1 Failed to load resource: the server responded with a status of 404 (Not Found)
useMedia.js:1 Failed to load resource: the server responded with a status of 404 (Not Found)
```

The files exist at paths like `src/client/api/hooks/usePeople.js`, but Vite returns 404 or
serves HTML instead of JavaScript.

## Context / Trigger Conditions

This issue occurs when ALL of these conditions are true:

1. **Vite dev server** with proxy configuration in `vite.config.js`:
   ```javascript
   server: {
     proxy: {
       '/api': {
         target: 'http://localhost:3001',
         changeOrigin: true,
       },
     },
   }
   ```

2. **Client-side folder** with the same name as the proxy path:
   ```
   src/client/
   ├── api/           ← Folder name matches proxy path "/api"
   │   ├── client.js
   │   └── hooks/
   │       ├── usePeople.js
   │       └── useMedia.js
   ```

3. **Imports** that resolve to the proxied path:
   ```javascript
   // In src/client/pages/Directory.jsx
   import { usePeople } from '../api/hooks/usePeople.js';
   // Vite transforms this to: /api/hooks/usePeople.js
   // This matches the proxy rule and gets sent to backend!
   ```

## Root Cause

Vite's module resolution transforms relative imports to absolute paths. When you import
`../api/hooks/usePeople.js` from a page, Vite resolves it to `/api/hooks/usePeople.js`.

The proxy configuration matches paths starting with `/api` and forwards them to the backend
server. Since `/api/hooks/usePeople.js` starts with `/api`, it gets proxied to the backend
instead of being served as a static file.

The backend doesn't have a route for `/api/hooks/usePeople.js`, so it returns 404.

## Solution

**Option 1: Rename the client folder (Recommended)**

Rename the conflicting folder to something that won't match the proxy path:

```bash
# Rename api to services (or lib, helpers, etc.)
mv src/client/api src/client/services

# Update all imports
find src/client -name "*.jsx" -o -name "*.js" | xargs sed -i '' 's|from.*['"'"'"]\.\.\/api|from "../services|g'
```

**Option 2: Use a different proxy path**

Change the proxy path to something more specific:

```javascript
// vite.config.js
server: {
  proxy: {
    '/api/v1': {  // More specific path
      target: 'http://localhost:3001',
      changeOrigin: true,
    },
  },
}
```

**Option 3: Configure proxy to exclude certain patterns**

Use a custom function to exclude certain paths:

```javascript
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:3001',
      changeOrigin: true,
      bypass: (req) => {
        // Don't proxy requests for JS/TS files
        if (req.url.match(/\.(js|jsx|ts|tsx|mjs)$/)) {
          return req.url;
        }
      },
    },
  },
}
```

## Verification

After applying the fix:

1. Clear Vite's cache: `rm -rf node_modules/.vite`
2. Restart the dev server: `npm run dev`
3. Check browser console - 404 errors should be gone
4. Verify the app loads and API calls still work

Test both:
- Frontend file serving: `curl http://localhost:5173/services/hooks/usePeople.js` should return JavaScript
- API proxying: `curl http://localhost:5173/api/people` should return JSON from backend

## Example

**Before (broken):**
```
src/client/
├── api/                    ← Conflicts with proxy
│   └── hooks/
│       └── usePeople.js
├── pages/
│   └── Directory.jsx       ← import from '../api/hooks/usePeople.js'

vite.config.js:
  proxy: { '/api': 'http://localhost:3001' }

Result: Browser gets 404 for usePeople.js
```

**After (fixed):**
```
src/client/
├── services/               ← Renamed to avoid conflict
│   └── hooks/
│       └── usePeople.js
├── pages/
│   └── Directory.jsx       ← import from '../services/hooks/usePeople.js'

vite.config.js:
  proxy: { '/api': 'http://localhost:3001' }  ← Unchanged

Result: Frontend files served correctly, API still proxied
```

## Notes

- This issue is not specific to React—it affects any Vite project with proxies
- Common conflicting folder names: `api`, `graphql`, `socket`, `ws`
- The issue only manifests in development (Vite dev server); production builds don't have this problem
- If using TypeScript path aliases, ensure they also avoid proxy path conflicts
- Always clear Vite's cache (`node_modules/.vite`) after changing folder structure

## Related Issues

- Similar issues can occur with other dev servers (webpack-dev-server, Create React App)
- If using a monorepo, check proxy configs in both root and package-level configs
