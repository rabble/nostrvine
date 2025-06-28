// ABOUTME: Vitest configuration for analytics worker testing with Cloudflare Workers environment
// ABOUTME: Configures unit, integration, and e2e test environments for Cloudflare Workers

import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    pool: '@cloudflare/vitest-pool-workers',
    poolOptions: {
      workers: {
        wrangler: {
          configPath: './wrangler.toml',
        },
      },
    },
    globals: true,
    testTimeout: 10000,
  },
});